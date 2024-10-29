#######################################################
# Get sorted (reg_from,reg_to) of inter-regional lines
#######################################################
function get_sorted_region_tuples(lines::Vector{PSY.Branch}, region_names::Vector{String})
    region_idxs = Dict(name => idx for (idx, name) in enumerate(region_names))

    line_from_to_reg_idxs = similar(lines, Tuple{Int, Int})

    for (l, line) in enumerate(lines)
        from_name = PSY.get_name(PSY.get_area(PSY.get_from_bus(line)))
        to_name = PSY.get_name(PSY.get_area(PSY.get_to_bus(line)))

        from_idx = region_idxs[from_name]
        to_idx = region_idxs[to_name]

        line_from_to_reg_idxs[l] =
            from_idx < to_idx ? (from_idx, to_idx) : (to_idx, from_idx)
    end

    return line_from_to_reg_idxs
end

#######################################################
# Get sorted lines and other indices necessary for PRAS
#######################################################
function get_sorted_lines(lines::Vector{PSY.Branch}, region_names::Vector{String})
    line_from_to_reg_idxs = get_sorted_region_tuples(lines, region_names)
    line_ordering = sortperm(line_from_to_reg_idxs)

    sorted_lines = lines[line_ordering]
    sorted_from_to_reg_idxs = line_from_to_reg_idxs[line_ordering]
    interface_reg_idxs = unique(sorted_from_to_reg_idxs)

    # Ref tells Julia to use interfaces as Vector, only broadcasting over
    # lines_sorted
    interface_line_idxs = searchsorted.(Ref(sorted_from_to_reg_idxs), interface_reg_idxs)

    return sorted_lines, interface_reg_idxs, interface_line_idxs
end

#######################################################
# Make PRAS Lines and Interfaces
#######################################################
function make_pras_interfaces(sorted_lines::Vector{PSY.Branch},interface_reg_idxs::Vector{Tuple{Int64, Int64}},
                              interface_line_idxs::Vector{UnitRange{Int64}},N::Int64)
    num_interfaces = length(interface_reg_idxs)
    interface_regions_from = first.(interface_reg_idxs)
    interface_regions_to = last.(interface_reg_idxs)
    num_lines = length(sorted_lines)

    # Lines
    line_names = PSY.get_name.(sorted_lines)
    line_cats = string.(typeof.(sorted_lines))

    line_forward_cap = Matrix{Int64}(undef, num_lines, N);
    line_backward_cap = Matrix{Int64}(undef, num_lines, N);
    line_λ = Matrix{Float64}(undef, num_lines, N); # Not currently available/ defined in PowerSystems
    line_μ = Matrix{Float64}(undef, num_lines, N); # Not currently available/ defined in PowerSystems

    for i in 1:num_lines
        line_forward_cap[i,:] = fill.(floor.(Int,getfield(line_rating(sorted_lines[i]),:forward_capacity)),1,N);
        line_backward_cap[i,:] = fill.(floor.(Int,getfield(line_rating(sorted_lines[i]),:backward_capacity)),1,N);

        ext = PSY.get_ext(sorted_lines[i])
        λ = 0.0;
        μ = 1.0;
        if ((haskey(ext,"outage_probability") && haskey(ext,"recovery_probability")))
            λ = ext["outage_probability"];
            μ = ext["recovery_probability"];
        else
            @warn "No outage information is available in ext of $(PSY.get_name(sorted_lines[i])). Using nominal outage and recovery probabilities for this line."
        end
    
        line_λ[i,:] = fill(λ,1,N); # Not currently available/ defined in PowerSystems # should change when we have this
        line_μ[i,:] = fill(μ,1,N); # Not currently available/ defined in PowerSystems
    end

    new_lines = PRAS.Lines{N, 1, PRAS.Hour, PRAS.MW}(
        line_names,
        line_cats,
        line_forward_cap,
        line_backward_cap,
        line_λ,
        line_μ,
    )

    interface_forward_capacity_array = Matrix{Int64}(undef, num_interfaces, N)
    interface_backward_capacity_array = Matrix{Int64}(undef, num_interfaces, N)

     for i in 1:num_interfaces
        interface_forward_capacity_array[i,:] =  sum(line_forward_cap[interface_line_idxs[i],:],dims=1)
        interface_backward_capacity_array[i,:] =  sum(line_backward_cap[interface_line_idxs[i],:],dims=1)
    end

    new_interfaces = PRAS.Interfaces{N, PRAS.MW}(
        interface_regions_from,
        interface_regions_to,
        interface_forward_capacity_array,
        interface_backward_capacity_array,
    )

    return new_lines, new_interfaces
end
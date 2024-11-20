"""
Use PSCB to build RTS-GMLC System and add outage data
as a Supplmental Attribute
"""
function get_rts_gmlc_outage()
    rts_da_sys = PSCB.build_system(PSCB.PSISystems, "RTS_GMLC_DA_sys")

    ###########################################
    # Parse the gen.csv and add OutageData
    # SupplementalAttribute to components for
    # which we have this data
    ###########################################
    gen_for_data = CSV.read(joinpath(@__DIR__, "descriptors/gen.csv"), DataFrames.DataFrame)

    for row in DataFrames.eachrow(gen_for_data)
        λ, μ = PRASInterface.rate_to_probability(row.FOR, row["MTTR Hr"])
        transition_data = PSY.GeometricDistributionForcedOutage(;
            mean_time_to_recovery=row["MTTR Hr"],
            outage_transition_probability=λ,
        )
        comp = PSY.get_component(PSY.Generator, rts_da_sys, row["GEN UID"])

        if ~(isnothing(comp))
            PSY.add_supplemental_attribute!(rts_da_sys, comp, transition_data)
            @info "Added outage data supplemental attribute to $(row["GEN UID"]) generator"
        else
            @warn "$(row["GEN UID"]) generator doesn't exist in the System."
        end
    end
    return rts_da_sys
end

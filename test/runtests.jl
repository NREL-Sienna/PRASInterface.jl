using PRASInterface
using Test

import Aqua
import PowerSystems
import PowerSystemCaseBuilder
import CSV
import DataFrames
import Dates
import Test
import TimeSeries
using Dates: DateTime

const PSY = PowerSystems
const PSCB = PowerSystemCaseBuilder

include("rts_gmlc.jl")

@testset "Aqua.jl" begin
    Aqua.test_unbound_args(PRASInterface)
    Aqua.test_undefined_exports(PRASInterface)
    Aqua.test_ambiguities(PRASInterface)
    Aqua.test_stale_deps(PRASInterface)
    Aqua.test_deps_compat(PRASInterface)
end

#=
Don't add your tests to runtests.jl. Instead, create files named

    test-title-for-my-test.jl

The file will be automatically included inside a `@testset` with title "Title For My Test".
=#
for (root, dirs, files) in walkdir(@__DIR__)
    for file in files
        if isnothing(match(r"^test.*\.jl$", file))
            continue
        end
        title = titlecase(replace(splitext(file[6:end])[1], "-" => " "))
        @testset "$title" begin
            include(file)
        end
    end
end
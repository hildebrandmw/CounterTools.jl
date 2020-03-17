using CounterTools
using Test

# Function for compiling read/write tests
function compile_test_program(program; ntimes = 10, array_size = 100000000)
    commands = [
        "g++",
        "-march=native",
        "-mtune=native",
        "-mcmodel=large",
        "-DSTREAM_ARRAY_SIZE=$array_size",
        "-O3",
        "-fopenmp",
        joinpath(@__DIR__, "programs", program),
        "-o",
        joinpath(@__DIR__, "programs", first(splitext(program))),
    ]
    run(`$commands`)
end

function run_test_program(program; cpunodebind=0, membind=0)
    path = joinpath(@__DIR__,  "programs", first(splitext(program)))
    run(`numactl --cpunodebind=$cpunodebind --membind=$membind $path`)
    return nothing
end

include("core.jl")
include("uncore.jl")

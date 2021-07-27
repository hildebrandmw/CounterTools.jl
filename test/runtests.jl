using CounterTools
using Test

# Function for compiling read/write tests
function compile_test_program(kernel; ntimes = 10, array_size = 100000000)
    commands = [
        "g++",
        "-march=native",
        "-mtune=native",
        "-mcmodel=large",
        "-DSTREAM_ARRAY_SIZE=$array_size",
        "-DFUNCTION=$kernel",
        "-DNTIMES=$ntimes",
        "-O3",
        "-fopenmp",
        joinpath(@__DIR__, "programs", "stream.cpp"),
        "-o",
        joinpath(@__DIR__, "programs", "stream"),
    ]
    run(`$commands`)
end

function run_test_program(program = "stream"; cpunodebind=0, membind=0)
    path = joinpath(@__DIR__,  "programs", program)
    run(`numactl --cpunodebind=$cpunodebind --membind=$membind $path`)
    return nothing
end

# include("record.jl")
# include("indexzero.jl")
# include("utils.jl")
# include("uncore/handle.jl")
# include("uncore/cha.jl")
# include("core.jl")
include("uncore.jl")

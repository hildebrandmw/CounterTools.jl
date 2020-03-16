# Tools for dealing with setting the affinity of
const libaffinity = joinpath(DEPSDIR, "libaffinity.so")
dlopen(libaffinity)

# When we get the current affinity from the `C` code, we're receiving a `C` allocated object
# which needs to be freed at some point.
#
# We wrap the returned pointer in this `PtrWrap` mutable struct and attach a finalizer
# which calls `free` on the pointer.
mutable struct PtrWrap
    ptr::Ptr{Cvoid}
end

free(W::PtrWrap) = ccall((:jl_free, libaffinity), Cvoid, (Ptr{Cvoid},), W.ptr)

function getaffinity()
    affinity = ccall((:jl_get_affinity, libaffinity), Ptr{Cvoid}, (Int64,), getpid())

    # Stop the memory leak!
    wrap = PtrWrap(affinity)
    finalizer(free, wrap)
    return wrap
end

function setaffinity(pid, cpu::IndexZero)
    return ccall((:jl_set_affinity, libaffinity), Cvoid, (Int64, Int64,), pid, value(cpu))
end

setaffinity(pid, cpu::Integer) = setaffinity(pid, indexzero(cpu))
setaffinity(cpu) = setaffinity(getpid(), cpu)

function setaffinity(pid, wrap::PtrWrap)
    ccall((:jl_reset_affinity, libaffinity), Cvoid, (Int64, Ptr{Cvoid},), pid, wrap.ptr)
    return nothing
end
setaffinity(wrap::PtrWrap) = setaffinity(getpid(), wrap)


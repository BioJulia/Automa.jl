# SizedMemory
# ===========

immutable SizedMemory
    ptr::Ptr{UInt8}
    len::UInt
end

"""
    SizedMemory(data)

Create a `SizedMemory` object from `data`.

`data` must implement `Base.pointer` and `Base.sizeof` methods.  For example,
`String` and `Vector{UInt8}` support these methods. Note that it is user's
responsibility to keep the `data` object alive during `SizedMemory`'s lifetime
because it does not have a reference to the object.
"""
function SizedMemory(data, len::Integer=(pointerend(data) + 1) - pointer(data))
    return SizedMemory(pointer(data), len)
end

function pointerend(data)
    return pointer(data, sizeof(data))
end

function Base.checkbounds(mem::SizedMemory, i::Integer)
    if 1 ≤ i ≤ mem.len
        return
    end
    throw(BoundsError(i))
end

function Base.getindex(mem::SizedMemory, i::Integer)
    @boundscheck checkbounds(mem, i)
    return unsafe_load(mem.ptr, i)
end

function Base.endof(mem::SizedMemory)
    return Int(mem.len)
end

function Base.length(mem::SizedMemory)
    return Int(mem.len)
end

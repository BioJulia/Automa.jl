# Precondition
# ============

@compat primitive type 8 Value end

const NONE  = reinterpret(Value, 0x00)
const TRUE  = reinterpret(Value, 0x01)
const FALSE = reinterpret(Value, 0x02)
const BOTH  = reinterpret(Value, 0x03)

function Base.convert(::Type{UInt8}, v::Value)
    return reinterpret(UInt8, v)
end

function Base.convert(::Type{Value}, b::UInt8)
    return reinterpret(Value, b)
end

function Base.:|(v1::Value, v2::Value)
    return convert(Value, convert(UInt8, v1) | convert(UInt8, v2))
end

function Base.:&(v1::Value, v2::Value)
    return convert(Value, convert(UInt8, v1) & convert(UInt8, v2))
end


immutable Precondition
    names::Vector{Symbol}
    values::Vector{Value}
end

function Precondition()
    return Precondition(Symbol[], Value[])
end

function Base.getindex(precond::Precondition, name::Symbol)
    i = findfirst(n -> n == name, precond.names)
    if i == 0
        return BOTH
    else
        return precond.values[i]
    end
end

function Base.push!(precond::Precondition, kv::Pair{Symbol,Value})
    name, value = kv
    i = findfirst(n -> n == name, precond.names)
    if i == 0
        push!(precond.names, name)
        push!(precond.values, value)
    else
        precond.values[i] |= value
    end
    return precond
end

function precondition_names(precond::Precondition)
    return copy(precond.names)
end

function conflicts(precond1::Precondition, precond2::Precondition)
    for (n1, v1) in precond1
        if (v1 & precond2[n1]) == NONE
            return true
        end
    end
    return false
end

function Base.start(precond::Precondition)
    @assert length(precond.names) == length(precond.values)
    return 1
end

function Base.done(precond::Precondition, i)
    return i > endof(precond.names)
end

function Base.next(precond::Precondition, i)
    return (precond.names[i], precond.values[i]), i + 1
end

function isconditioned(precond::Precondition)
    for v in precond.values
        if v != BOTH
            return true
        end
    end
    return false
end

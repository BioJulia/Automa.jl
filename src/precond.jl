# Precondition
# ============

primitive type Value 8 end

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


struct Precondition
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
    if i == nothing
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

function Base.iterate(precond::Precondition, i=1)
    if i > length(precond.names)
        return nothing
    end
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

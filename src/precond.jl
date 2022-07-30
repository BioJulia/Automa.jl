# Precondition
# ============

# See comments on Precondition.
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

# A Precondition is a list of conditions. Each condition has a symbol, which is used to
# look up in a dict for an Expr object like :(a > 1) that should evaluate to a Bool.
# This allows Automa to add if/else statements in generated code, like
# if (a > 1) && (b < 5) for a Precondition with two symbols.
# The Value is whether the condition is negated.
# Automa's optimization of the graph may negate, or manipulate the expressions using
# boolean logic.
# There are four options for expr E:
# 1. E & !E  (i.e. always false. This code is never even generated, just a literal false is)
# 2. E (i.e. the pure condition)
# 3. !E (i.e. the negated condition)
# 4. E | !E (i.e. always true. Like 1., this is encoded as a literal `true` in generated code).
struct Precondition
    names::Vector{Symbol}
    values::Vector{Value}
end

function Precondition()
    return Precondition(Symbol[], Value[])
end

function Base.:(==)(p1::Precondition, p2::Precondition)
    return p1.names == p2.names && p1.values == p2.values
end

function Base.getindex(precond::Precondition, name::Symbol)
    i = findfirst(n -> n == name, precond.names)
    if i === nothing
        return BOTH
    else
        return precond.values[i]
    end
end

function Base.push!(precond::Precondition, kv::Pair{Symbol,Value})
    name, value = kv
    i = findfirst(n -> n == name, precond.names)
    if i === nothing
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

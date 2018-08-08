# Stable Set
# ==========

mutable struct StableSet{T} <: Base.AbstractSet{T}
    dict::StableDict{T, Nothing}

    function StableSet{T}() where T
        return new{T}(StableDict{T, Nothing}())
    end
end

function StableSet(vals)
    set = StableSet{eltype(vals)}()
    for v in vals
        push!(set, v)
    end
    return set
end

function Base.copy(set::StableSet)
    newset = StableSet{eltype(set)}()
    newset.dict = copy(set.dict)
    return newset
end

function Base.length(set::StableSet)
    return length(set.dict)
end

function Base.eltype(::Type{StableSet{T}}) where T
    return T
end

function Base.:(==)(set1::StableSet, set2::StableSet)
    if length(set1) == length(set2)
        for x in set1
            if x ∉ set2
                return false
            end
        end
        return true
    end
    return false
end

function Base.hash(set::StableSet, h::UInt)
    h = hash(Base.hashs_seed, h)
    for x in set
        h = xor(h, hash(x))
    end
    return h
end

function Base.in(val, set::StableSet)
    return haskey(set.dict, val)
end

function Base.push!(set::StableSet, val)
    v = convert(eltype(set), val)
    if v ∉ set
        set.dict[v] = nothing
    end
    return set
end

function Base.pop!(set::StableSet)
    return pop!(set.dict)[1]
end

function Base.delete!(set::StableSet, val)
    delete!(set.dict, val)
    return set
end

function Base.union!(set::StableSet, xs)
    for x in xs
        push!(set, x)
    end
    return set
end

function Base.union(set::StableSet, xs)
    return union!(copy(set), xs)
end

function Base.filter(f::Function, set::StableSet)
    newset = Set{eltype(set)}()
    for x in set
        if f(x)
            push!(newset, x)
        end
    end
    return newset
end

function Base.iterate(set::StableSet, s=iterate(set.dict))
    if s == nothing
        return nothing
    end
    return s[1][1], iterate(set.dict, s[2])
end

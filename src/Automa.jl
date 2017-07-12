__precompile__()

module Automa

import Compat: @compat, xor, take!
import DataStructures: DefaultDict, OrderedDict, OrderedSet

#const Dict = OrderedDict
#const Set = OrderedSet

#=
type Dict{K,V} <: Associative{K,V}
    data::Vector{Tuple{K,V}}
end

function Dict{K,V}() where {K,V}
    return Dict{K,V}(Tuple{K,V}[])
end

function Dict(kvs::Pair{K,V}...) where {K,V}
    return Dict{K,V}([(k, v) for (k, v) in kvs])
end

function Dict(vals)
    return Dict([(k, v) for (k, v) in vals])
end

function Base.copy(dict::Dict{K,V}) where {K,V}
    return Dict{K,V}(copy(dict.data))
end

function Base.length(dict::Dict)
    return length(dict.data)
end

function Base.eltype(::Type{Dict{K,V}}) where {K,V}
    return Tuple{K,V}
end

function Base.haskey(dict::Dict, key)
    for (k, v) in dict.data
        if k == key
            return true
        end
    end
    return false
end

function Base.getindex(dict::Dict, key)
    for (k, v) in dict.data
        if k == key
            return v
        end
    end
    throw(KeyError(key))
end

function Base.get!(dict::Dict, key, default)
    if haskey(dict, key)
        return dict[key]
    end
    dict[key] = default
    return default
end

function Base.get!(f::Function, dict::Dict, key)
    if haskey(dict, key)
        return dict[key]
    end
    default = f()
    dict[key] = default
    return default
end

function Base.setindex!(dict::Dict, val, key)
    for (i, (k, v)) in enumerate(dict.data)
        if k == key
            dict.data[i] = (key, val)
            return dict
        end
    end
    resize!(dict.data, length(dict.data) + 1)
    dict.data[end] = (key, val)
    return dict
end

function Base.start(dict::Dict)
    return 1
end

function Base.done(dict::Dict, i)
    return i > endof(dict.data)
end

function Base.next(dict::Dict, i)
    return dict.data[i], i + 1
end

type Set{T} <: AbstractSet{T}
    dict::Dict{T,Void}
end

function Set{T}() where T
    return Set{T}(Dict{T,Void}())
end

function Set(vals)
    return Set(Dict([(v, nothing) for v in vals]))
end

function Base.length(set::Set)
    return length(set.dict)
end

function Base.eltype(::Type{Set{T}}) where T
    return T
end

function Base.haskey(set::Set, val)
    return haskey(set.dict, val)
end

function Base.push!(set::Set, val)
    if !haskey(set, val)
        set.dict[val] = nothing
    end
    return set
end

function Base.pop!(set::Set)
    return pop!(set.dict.data)[1]
end

function Base.delete!(set::Set, val)
    for (i, (v, _)) in enumerate(set.dict.data)
        if v == val
            deleteat!(set.dict.data, i)
            break
        end
    end
    return set
end

function Base.union!(set::Set, xs)
    for x in xs
        push!(set, x)
    end
    return set
end

function Base.union(set::Set, xs)
    return union!(copy(set), xs)
end

function Base.start(set::Set)
    return start(set.dict)
end

function Base.done(set::Set, s)
    return done(set.dict, s)
end

function Base.next(set::Set, s)
    item, s = next(set.dict, s)
    return item[1], s
end

function Base.copy(set::Set{T}) where T
    return Set{T}(copy(set.dict))
end

function Base.filter(p::Function, set::Set{T}) where T
    ret = Set{T}()
    for x in set
        if p(x)
            push!(ret, x)
        end
    end
    return ret
end
=#

include("sdict.jl")
include("sset.jl")

const Dict = StableDict
const Set = StableSet

include("byteset.jl")
include("re.jl")
include("precond.jl")
include("action.jl")
include("edge.jl")
include("nfa.jl")
include("dfa.jl")
include("machine.jl")
include("traverser.jl")
include("dot.jl")
include("memory.jl")
include("codegen.jl")
include("tokenizer.jl")

end # module

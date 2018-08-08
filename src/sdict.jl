# Stable Dictionary
# =================

mutable struct StableDict{K, V} <: AbstractDict{K, V}
    slots::Vector{Int}
    keys::Vector{K}
    vals::Vector{V}
    used::Int
    nextidx::Int

    function StableDict{K, V}() where {K, V}
        size = 16
        slots = zeros(Int, size)
        keys = Vector{K}(undef, size)
        vals = Vector{V}(undef, size)
        return new{K,V}(slots, keys, vals, 0, 1)
    end

    function StableDict(dict::StableDict{K, V}) where {K, V}
        copy = StableDict{K, V}()
        for (k, v) in dict
            copy[k] = v
        end
        return copy
    end
end

function StableDict(kvs::Pair{K, V}...) where {K, V}
    dict = StableDict{K, V}()
    for (k, v) in kvs
        dict[k] = v
    end
    return dict
end

function StableDict{K, V}(kvs) where {K, V}
    dict = StableDict{K, V}()
    for (k, v) in kvs
        dict[k] = v
    end
    return dict
end

function StableDict(kvs)
    return StableDict([Pair(k, v) for (k, v) in kvs]...)
end

function StableDict()
    return StableDict{Any, Any}()
end

function Base.copy(dict::StableDict)
    return StableDict(dict)
end

function Base.length(dict::StableDict)
    return dict.used
end

function Base.haskey(dict::StableDict, key)
    _, j = indexes(dict, convert(keytype(dict), key))
    return j > 0
end

function Base.getindex(dict::StableDict, key)
    _, j = indexes(dict, convert(keytype(dict), key))
    if j == 0
        throw(KeyError(key))
    end
    return dict.vals[j]
end

function Base.get!(dict::StableDict, key, default)
    if haskey(dict, key)
        return dict[key]
    end
    val = convert(valtype(dict), default)
    dict[key] = val
    return val
end

function Base.get!(f::Function, dict::StableDict, key)
    if haskey(dict, key)
        return dict[key]
    end
    val = convert(valtype(dict), f())
    dict[key] = val
    return val
end

function Base.setindex!(dict::StableDict, val, key)
    k = convert(keytype(dict), key)
    v = convert(valtype(dict), val)
    @label index
    i, j = indexes(dict, k)
    if j == 0
        if dict.nextidx > lastindex(dict.keys)
            expand!(dict)
            @goto index
        end
        dict.keys[dict.nextidx] = k
        dict.vals[dict.nextidx] = v
        dict.slots[i] = dict.nextidx
        dict.used += 1
        dict.nextidx += 1
    else
        dict.slots[i] = j
        dict.keys[j] = k
        dict.vals[j] = v
    end
    return dict
end

function Base.delete!(dict::StableDict, key)
    k = convert(keytype(dict), key)
    i, j = indexes(dict, k)
    if j > 0
        dict.slots[i] = -j
        dict.used -= 1
    end
    return dict
end

function Base.pop!(dict::StableDict)
    if isempty(dict)
        throw(ArgumentError("empty"))
    end
    i = dict.slots[argmax(dict.slots)]
    key = dict.keys[i]
    val = dict.vals[i]
    delete!(dict, key)
    return key => val
end

function Base.iterate(dict::StableDict)
    if length(dict) == 0
        return nothing
    end
    if dict.used == dict.nextidx - 1
        keys = dict.keys[1:dict.used]
        vals = dict.vals[1:dict.used]
    else
        idx = sort!(dict.slots[dict.slots .> 0])
        @assert length(idx) == length(dict)
        keys = dict.keys[idx]
        vals = dict.vals[idx]
    end
    return (keys[1] => vals[1]), (2, keys, vals)
end

function Base.iterate(dict::StableDict, st)
    i = st[1]
    if i > length(st[2])
        return nothing
    end
    return (st[2][i] => st[3][i]), (i + 1, st[2], st[3])
end

function hashindex(key, sz)
    return (reinterpret(Int, hash(key)) & (sz-1)) + 1
end

function indexes(dict, key)
    sz = length(dict.slots)
    h = hashindex(key, sz)
    i = 0
    while i < sz
        j = mod1(h + i, sz)
        k = dict.slots[j]
        if k == 0
            return j, k
        elseif k > 0 && isequal(dict.keys[k], key)
            return j, k
        end
        i += 1
    end
    return 0, 0
end

function expand!(dict)
    sz = length(dict.slots)
    newsz = sz * 2
    newslots = zeros(Int, newsz)
    resize!(dict.keys, newsz)
    resize!(dict.vals, newsz)
    for i in 1:sz
        j = dict.slots[i]
        if j > 0
            k = hashindex(dict.keys[j], newsz)
            while newslots[mod1(k, newsz)] != 0
                k += 1
            end
            newslots[mod1(k, newsz)] = j
        end
    end
    dict.slots = newslots
    return dict
end

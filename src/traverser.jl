# Node Traverser
# ==============

immutable Traverser{T}
    start::T
end

function traverse(start::Union{NFANode,DFANode})
    return Traverser(start)
end

function Base.eltype{T}(::Type{Traverser{T}})
    return T
end

function Base.iteratorsize{T}(::Type{Traverser{T}})
    return Base.SizeUnknown()
end

function Base.start(t::Traverser)
    visited = Set{eltype(t)}()
    unvisited = Set([t.start])
    return visited, unvisited
end

function Base.done(t::Traverser, state)
    _, unvisited = state
    return isempty(unvisited)
end

function Base.next(t::Traverser{NFANode}, state)
    visited, unvisited = state
    s = pop!(unvisited)
    push!(visited, s)
    for (_, T) in s.trans.trans, t in T
        if t ∉ visited
            push!(unvisited, t)
        end
    end
    for t in s.trans[:eps]
        if t ∉ visited
            push!(unvisited, t)
        end
    end
    return s, (visited, unvisited)
end

function Base.next(t::Traverser{DFANode}, state)
    visited, unvisited = state
    s = pop!(unvisited)
    push!(visited, s)
    for (t, _) in values(s.next)
        if t ∉ visited
            push!(unvisited, t)
        end
    end
    return s, (visited, unvisited)
end

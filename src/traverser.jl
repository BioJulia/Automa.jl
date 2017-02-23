# Node Traverser
# ==============

immutable Traverser{T}
    start::T
end

function Base.eltype{T}(::Type{Traverser{T}})
    return T
end

function Base.iteratorsize{T}(::Type{Traverser{T}})
    return Base.SizeUnknown()
end

function traverse(start::Union{NFANode,DFANode,Node})
    return Traverser(start)
end

function Base.start{T}(t::Traverser{T})
    visited = Set{T}()
    unvisited = Set([t.start])
    return visited, unvisited
end

function Base.done(t::Traverser, state)
    return isempty(state[2])
end

function Base.next(t::Traverser, state)
    visited, unvisited = state
    s = pop!(unvisited)
    push!(visited, s)
    for (_, t) in s.edges
        if t ∉ visited
            push!(unvisited, t)
        end
    end
    return s, (visited, unvisited)
end

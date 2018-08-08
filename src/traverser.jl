# Node Traverser
# ==============

struct Traverser{T}
    start::T
end

function Base.eltype(::Type{Traverser{T}}) where T
    return T
end

function Compat.IteratorSize(::Type{Traverser{T}}) where T
    return Base.SizeUnknown()
end

function traverse(start::Union{NFANode,DFANode,Node})
    return Traverser(start)
end

function Base.iterate(t::Traverser{T}, state=nothing) where T
    if state == nothing
        state = (visited = Set{T}(), unvisited = Set([t.start]))
    end
    if isempty(state.unvisited)
        return nothing
    end
    s = pop!(state.unvisited)
    push!(state.visited, s)
    for (_, t) in s.edges
        if t ∉ state.visited
            push!(state.unvisited, t)
        end
    end
    return s, state
end

#=
function Base.start(t::Traverser{T}) where T
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
=#

# Node Traverser
# ==============

struct Traverser{T}
    start::T
end

function Base.eltype(::Type{Traverser{T}}) where T
    return T
end

function Base.IteratorSize(::Type{Traverser{T}}) where T
    return Base.SizeUnknown()
end

function traverse(start::Union{NFANode,DFANode,Node})
    return Traverser(start)
end

function Base.iterate(t::Traverser{T}, state=nothing) where T
    if state === nothing
        state = (visited = Set{T}(), unvisited = [t.start])
    end
    if isempty(state.unvisited)
        return nothing
    end
    s = pop!(state.unvisited)
    push!(state.visited, s)
    for (_, t) in s.edges
        if t ∉ state.visited && t ∉ state.unvisited
            push!(state.unvisited, t)
        end
    end
    return s, state
end

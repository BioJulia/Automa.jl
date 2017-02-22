# Edge
# ====

immutable Edge
    labels::ByteSet
    preconds::Set{Precondition}
    actions::Set{Action}
end

function Edge(labels::ByteSet)
    return Edge(labels, Set{Precondition}(), Set{Action}())
end

function Edge(labels::ByteSet, actions::Union{Set{Action},Vector{Action}})
    return Edge(labels, Set{Precondition}(), Set(actions))
end

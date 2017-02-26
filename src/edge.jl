# Edge
# ====

immutable Edge
    labels::ByteSet
    preconds::Set{Precondition}
    actions::ActionList
end

function Edge(labels::ByteSet)
    return Edge(labels, Set{Precondition}(), ActionList())
end

function Edge(labels::ByteSet, actions::ActionList)
    return Edge(labels, Set{Precondition}(), actions)
end

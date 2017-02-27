# Edge
# ====

immutable Edge
    labels::ByteSet
    preconds::PreconditionSet
    actions::ActionList
end

function Edge(labels::ByteSet)
    return Edge(labels, PreconditionSet(), ActionList())
end

function Edge(labels::ByteSet, actions::ActionList)
    return Edge(labels, PreconditionSet(), actions)
end

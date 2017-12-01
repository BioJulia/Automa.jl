# Edge
# ====

struct Edge
    labels::ByteSet
    precond::Precondition
    actions::ActionList
end

function Edge(labels::ByteSet)
    return Edge(labels, Precondition(), ActionList())
end

function Edge(labels::ByteSet, actions::ActionList)
    return Edge(labels, Precondition(), actions)
end

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

# Don't override isless, because I don't want to figure out how
# to hash correctly. It's fine, we only use this for sorting in order_machine
function in_sort_order(e1::Edge, e2::Edge)
    # First check edges
    for (i,j) in zip(e1.labels, e2.labels)
        if i < j
            return true
        elseif j < i
            return false
        end
    end
    l1, l2 = length(e1.labels), length(e2.labels)
    if l1 < l2
        return true
    elseif l2 < l1
        return false
    end

    # Then check preconditions
    p1, p2 = e1.precond, e2.precond
    lp1, lp2 = length(p1.names), length(p2.names)
    for i in 1:min(lp1, lp2)
        isless(p1.names[i], p2.names[i]) && return true
        isless(p2.names[i], p1.names[i]) && return false
        u1, u2 = convert(UInt8, p1.values[i]), convert(UInt8, p2.values[i])
        u1 < u2 && return true
        u2 < u1 && return false
    end
    lp1 < lp2 && return true
    lp2 < lp1 && return false

    # A machine should never have two indistinguishable edges
    # so if we reach here, something went wrong
    error()
end

"""Check if two edges have preconditions that could be disambiguating.
I.e. can an FSM distinguish the edges based on their conditions?
"""
function has_potentially_conflicting_precond(e1::Edge, e2::Edge)
    # This is true for most edges, to check it first
    isempty(e1.precond.names) && isempty(e2.precond.names) && return false

    symbols = union(Set(e1.precond.names), Set(e2.precond.names))
    for symbol in symbols
        v1 = e1.precond[symbol]
        v2 = e2.precond[symbol]

        # NONE means the edge can never be taken, so they are trivially disambiguated
        (v1 == NONE || v2 == NONE) && return true

        # If they are the same, they cannot be used to distinguish
        v1 == v2 || return true
    end
    return false
end

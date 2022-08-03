# Edge
# ====

# An edge connects two nodes in the FSM. The labels is a set of bytes that, if the
# input is in that set, the edge may be taken.
# Precond is like an if-statement, if that condition is fulfilled, take the edge
# The actions is a list of names of Julia code to execute, if edge is taken.
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
# The criterion is arbitrary, but ordering must be transitive,
# and this function must deterministically return a Bool when comparing
# two edges from the same node in a Machine
function in_sort_order(e1::Edge, e2::Edge)
    # First check labels
    lab1, lab2 = e1.labels, e2.labels
    len1, len2 = length(lab1), length(lab2)
    len1 < len2 && return true
    len2 < len1 && return false
    for (i,j) in zip(lab1, lab2)
        i < j && return true
        j < i && return false
    end

    # Then check preconditions
    p1, p2 = e1.precond, e2.precond
    lp1, lp2 = length(p1.names), length(p2.names)
    lp1 < lp2 && return true
    lp2 < lp1 && return false
    for i in 1:min(lp1, lp2)
        isless(p1.names[i], p2.names[i]) && return true
        isless(p2.names[i], p1.names[i]) && return false
        u1, u2 = convert(UInt8, p1.values[i]), convert(UInt8, p2.values[i])
        u1 < u2 && return true
        u2 < u1 && return false
    end

    # A machine should never have two indistinguishable edges
    # so if we reach here, something went wrong.
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

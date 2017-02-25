# Precondition
# ============

immutable Precondition
    name::Symbol
    value::Bool
end

function conflicts(p::Precondition, Q::Set{Precondition})
    for q in Q
        if q.name == p.name && q.value != p.value
            return true
        end
    end
    return false
end

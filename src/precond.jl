# Precondition
# ============

immutable Precondition
    name::Symbol
    value::Bool
end

immutable PreconditionSet
    data::Vector{Precondition}
end

function PreconditionSet()
    return PreconditionSet(Precondition[])
end

function Base.push!(set::PreconditionSet, precond::Precondition)
    for p in set.data
        if p.name == precond.name && p.value == precond.value
            return set
        end
    end
    push!(set.data, precond)
    return set
end

function precondition_names(precond::PreconditionSet)
    return unique([p.name for p in precond.data])
end

function conflicts(set1::PreconditionSet, set2::PreconditionSet)
    for p1 in set1, p2 in set2
        if p1.name == p2.name && p1.value != p2.value
            return true
        end
    end
    return false
end

function Base.start(set::PreconditionSet)
    return 1
end

function Base.done(set::PreconditionSet, i)
    return i > endof(set.data)
end

function Base.next(set::PreconditionSet, i)
    return set.data[i], i + 1
end

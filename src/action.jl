# Action
# ======

immutable Action
    name::Symbol
    order::Int
end

function sorted_actions(actions::Set{Action})
    return sort!(collect(actions), by=a->a.order)
end

function sorted_unique_action_names(actions::Set{Action})
    names = Symbol[]
    for a in sorted_actions(actions)
        if a.name ∉ names
            push!(names, a.name)
        end
    end
    return names
end

# Action
# ======

struct Action
    name::Symbol
    order::Int
end

# An action list type.
# * Action names are unique.
# * Actions are sorted by its order.
struct ActionList
    actions::Vector{Action}

    function ActionList(actions::Vector{Action}=Action[])
        list = new(Action[])
        union!(list, actions)
        return list
    end
end

function Base.:(==)(l1::ActionList, l2::ActionList)
    if length(l1) != length(l2)
        return false
    end
    for i in 1:lastindex(l1.actions)
        if l1.actions[i].name != l2.actions[i].name
            return false
        end
    end
    return true
end

function Base.hash(list::ActionList, h::UInt)
    for a in list
        h = xor(h, hash(a.name))
    end
    return h
end

function Base.push!(list::ActionList, action::Action)
    i = findfirst(a -> a.name == action.name, list.actions)
    if i != nothing
        if action.order < list.actions[i].order
            list.actions[i] = action  # replace
        end
    else
        push!(list.actions, action)
    end
    sort!(list.actions, by=a->a.order)
    return list
end

function Base.union!(list::ActionList, actions::Union{ActionList,Vector{Action}})
    for a in actions
        push!(list, a)
    end
    return list
end

function Base.length(list::ActionList)
    return length(list.actions)
end

function Base.iterate(list::ActionList, i=1)
    if i > length(list.actions)
        return nothing
    end
    return list.actions[i], i + 1
end

function action_names(list::ActionList)
    return [a.name for a in list.actions]
end

# DOT Language
# ============

function nfa2dot(nfa::NFA)
    out = IOBuffer()
    println(out, "digraph {")
    println(out, "  graph [ rankdir = LR ];")
    println(out, "  0 -> 1;")
    println(out, "  0 [ shape = point ];")
    serials = Dict(s => i for (i, s) in enumerate(traverse(nfa.start)))
    for s in keys(serials)
        println(out, "  $(serials[s]) [ shape = $(s == nfa.final ? "doublecircle" : "circle") ];")
        for (e, t) in s.edges
            println(out, " $(serials[s]) -> $(serials[t]) [ label = \"$(edge2str(e))\" ];")
        end
    end
    println(out, "}")
    return String(take!(out))
end

function dfa2dot(dfa::DFA)
    out = IOBuffer()
    println(out, "digraph {")
    println(out, "  graph [ rankdir = LR ];")
    println(out, "  start -> 1;")
    println(out, "  start [ shape = point ];")
    serials = Dict(s => i for (i, s) in enumerate(traverse(dfa.start)))
    for s in keys(serials)
        println(out, "  $(serials[s]) [ shape = $(s.final ? "doublecircle" : "circle") ];")
        for (e, t) in s.edges
            println(out, "  $(serials[s]) -> $(serials[t]) [ label = \"$(edge2str(e))\" ];")
        end
        if !isempty(s.eof_actions)
            println(out, "  eof$(serials[s]) [ shape = point ];")
            println(out, "  $(serials[s]) -> eof$(serials[s]) [ label = \"$(eof_label(s.eof_actions))\", style = dashed ];")
        end
    end
    println(out, "}")
    return String(take!(out))
end

function machine2dot(machine::Machine)
    out = IOBuffer()
    println(out, "digraph {")
    println(out, "  graph [ rankdir = LR ];")
    println(out, "  start -> 1;")
    println(out, "  start [ shape = point ];")
    for s in traverse(machine.start)
        println(out, "  $(s.state) [ shape = $(s.state ∈ machine.final_states ? "doublecircle" : "circle") ];")
        for (e, t) in s.edges
            println(out, "  $(s.state) -> $(t.state) [ label = \"$(edge2str(e))\" ];")
        end
        if haskey(machine.eof_actions, s.state) && !isempty(machine.eof_actions[s.state])
            println(out, "  eof$(s.state) [ shape = point ];")
            println(out, "  $(s.state) -> eof$(s.state) [ label = \"$(eof_label(machine.eof_actions[s.state]))\", style = dashed ];")
        end
    end
    println(out, "}")
    return String(take!(out))
end

function edge2str(edge::Edge)
    out = IOBuffer()

    function printbyte(b, inrange)
        # TODO: does this work?
        if inrange && b == UInt8('-')
            print(out, "\\\\-")
        elseif inrange && b == UInt8(']')
            print(out, "\\\\]")
        else
            print(out, escape_string(b ≤ 0x7f ? escape_string(string(Char(b))) : @sprintf("\\x%x", b)))
        end
    end

    # output labels
    if isempty(edge.labels)
        print(out, 'ϵ')
    elseif length(edge.labels) == 1
        print(out, '\'')
        printbyte(first(edge.labels), false)
        print(out, '\'')
    else
        print(out, '[')
        for r in range_encode(edge.labels)
            if length(r) == 1
                printbyte(first(r), true)
            elseif length(r) == 2
                printbyte(first(r), true)
                printbyte(last(r), true)
            else
                @assert length(r) > 1
                printbyte(first(r), true)
                print(out, '-')
                printbyte(last(r), true)
            end
        end
        print(out, ']')
    end

    # output conditions
    if !isempty(edge.precond)
        print(out, '(')
        join(out, ((value == NONE ? "false" : value == TRUE ? name : value == FALSE ? string("!", name) : "true") for (name, value) in edge.precond), ',')
        print(out, ')')
    end

    # output actions
    if !isempty(edge.actions)
        print(out, '/')
        join(out, action_names(edge.actions), ',')
    end

    return String(take!(out))
end

function eof_label(actions::ActionList)
    out = IOBuffer()
    print(out, "EOF")
    if !isempty(actions)
        print(out, '/')
        join(out, action_names(actions), ',')
    end
    return String(take!(out))
end

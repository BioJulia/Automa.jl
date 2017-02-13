# DOT Language
# ============

function nfa2dot(nfa::NFA)
    buf = IOBuffer()
    println(buf, "digraph {")
    println(buf, "  graph [ rankdir = LR ];")
    println(buf, "  0 -> 1;")
    println(buf, "  0 [ shape = point ];")
    serial = 0
    serials = Dict(nfa.start => (serial += 1))

    function trace(s, label)
        for t in s.trans[label]
            if !haskey(serials, t)
                serials[t] = (serial += 1)
                push!(unvisited, t)
            end
            actions = s.actions[(label, t)]
            println(buf, "  $(serials[s]) -> $(serials[t]) [ label = \"$(label2str(label, actions))\" ];")
        end
    end

    unvisited = Set([nfa.start])
    while !isempty(unvisited)
        s = pop!(unvisited)
        for l in 0x00:0xff
            trace(s, l)
        end
        trace(s, :eps)
    end
    for (node, serial) in serials
        shape = node == nfa.final ? "doublecircle" : "circle"
        println(buf, "  $(serial) [ shape = $(shape) ];")
    end
    println(buf, "}")
    return @compat String(take!(buf))
end

function dfa2dot(dfa::DFA)
    buf = IOBuffer()
    println(buf, "digraph {")
    println(buf, "  graph [ rankdir = LR ];")
    println(buf, "  start -> 1;")
    println(buf, "  start [ shape = point ];")
    println(buf, "  final [ shape = point ];")
    serial = 0
    serials = Dict(dfa.start => (serial += 1))
    unvisited = Set([dfa.start])
    while !isempty(unvisited)
        s = pop!(unvisited)
        for (l, t) in compact_transition(s.trans.trans)
            if !haskey(serials, t)
                serials[t] = (serial += 1)
                push!(unvisited, t)
            end
            label = label2str(l, s.actions[l])
            println(buf, "  $(serials[s]) -> $(serials[t]) [ label = \"$(label)\" ];")
        end
        if s.final
            label = label2str(:eof, s.actions[:eof])
            println(buf, "  $(serials[s]) -> final [ label = \"$(label)\", style = dashed ];")
        end
    end
    for (node, serial) in serials
        shape = node.final ? "doublecircle" : "circle"
        println(buf, "  $(serial) [ shape = $(shape) ];")
    end
    println(buf, "}")
    return @compat String(take!(buf))
end

function label2str(label, actions)
    if isempty(actions)
        return label2str(label)
    else
        return string(label2str(label), '/', actions2str(actions))
    end
end

function label2str(label)
    if label == :eps
        return "ε"
    elseif label == :eof
        return "EOF"
    elseif isa(label, ByteSet)
        if length(label) == 1
            return escape_string(byte2str(first(label), false))
        else
            @assert length(label) != 0
            ss = []
            hyphen = false
            for r in compact_labels(label)
                if length(r) == 1
                    if first(r) == UInt8('-')
                        hyphen = true
                    else
                        push!(ss, byte2str(first(r), true))
                    end
                else
                    push!(ss, byte2str(first(r), true), '-', byte2str(last(r), true))
                end
            end
            if hyphen
                # put hyphen first
                unshift!(ss, byte2str(UInt8('-'), true))
            end
            return escape_string(string('[', join(ss), ']'))
        end
    else
        return escape_string(repr(label))
    end
end

function byte2str(b::UInt8, unquote::Bool)
    if b == UInt8(']')
        s = "'\\]'"
    elseif b ≤ 0x7f
        s = repr(Char(b))
    else
        s = @sprintf("'\\x%x'", b)
    end
    if unquote
        s = s[2:end-1]
    end
    return s
end

function actions2str(actions)
    return join(sorted_unique_action_names(actions), ',')
end

# Regular Expression
# ==================

type RE
    head::Symbol
    args::Vector
    actions::Dict{Symbol,Vector{Symbol}}
end

function RE(head::Symbol, args::Vector)
    return RE(head, args, Dict())
end

function byte(b::UInt8)
    return RE(:byte, [b])
end

function range(r::UnitRange{UInt8})
    return RE(:range, [r])
end

function Base.cat(re::RE)
    return RE(:cat, [re])
end

function Base.cat(re1::RE, re::RE...)
    return RE(:cat, [re1, re...])
end

function alt(re1::RE, re::RE...)
    return RE(:alt, [re1, re...])
end

function rep(re::RE)
    return RE(:rep, [re])
end

function opt(re::RE)
    return RE(:alt, [re, RE(:cat, [])])
end

function isec(re1::RE, re2::RE)
    return RE(:isec, [re1, re2])
end

function diff(re1::RE, re2::RE)
    return RE(:diff, [re1, re2])
end

macro re_str(s::String)
    return desugar(parse(unescape_string(s)))
end

# Parse a regular expression string using the shunting-yard algorithm.
function parse(str::String)
    if isempty(str)
        return RE(:cat, [])
    end

    # stacks
    operands = RE[]
    operators = Symbol[]

    function pop_and_apply!()
        op = pop!(operators)
        if op == :rep || op == :rep1 || op == :opt
            arg = pop!(operands)
            push!(operands, RE(op, [arg]))
        elseif op == :alt
            arg2 = pop!(operands)
            arg1 = pop!(operands)
            push!(operands, RE(:alt, [arg1, arg2]))
        elseif op == :cat
            arg2 = pop!(operands)
            arg1 = pop!(operands)
            push!(operands, RE(:cat, [arg1, arg2]))
        else
            error(op)
        end
    end

    s = start(str)
    lastc = typemax(Char)
    while !done(str, s)
        c, s = next(str, s)
        # @show c operands operators
        # insert :cat operator if needed
        if !isempty(operands) && c ∉ ('*', '+', '?', '|', ')') && lastc ∉ ('|', '(')
            while !isempty(operators) && prec(:cat) ≤ prec(last(operators))
                pop_and_apply!()
            end
            push!(operators, :cat)
        end
        if c == '*'
            while !isempty(operators) && prec(:rep) ≤ prec(last(operators))
                pop_and_apply!()
            end
            push!(operators, :rep)
        elseif c == '+'
            while !isempty(operators) && prec(:rep1) ≤ prec(last(operators))
                pop_and_apply!()
            end
            push!(operators, :rep1)
        elseif c == '?'
            while !isempty(operators) && prec(:opt) ≤ prec(last(operators))
                pop_and_apply!()
            end
            push!(operators, :opt)
        elseif c == '|'
            while !isempty(operators) && prec(:alt) ≤ prec(last(operators))
                pop_and_apply!()
            end
            push!(operators, :alt)
        elseif c == '('
            push!(operators, :lparen)
        elseif c == ')'
            while !isempty(operators) && last(operators) != :lparen
                pop_and_apply!()
            end
            pop!(operators)
        elseif c == '['
            class, s = parse_class(str, s)
            push!(operands, class)
        elseif c == '.'
            push!(operands, range(0x00:0xff))
        else
            push!(operands, byte(UInt8(c)))
        end
        lastc = c
    end

    while !isempty(operators)
        pop_and_apply!()
    end

    @assert length(operands) == 1
    return first(operands)
end

function prec(op::Symbol)
    if op == :rep || op == :rep1 || op == :opt
        return 3
    elseif op == :cat
        return 2
    elseif op == :alt
        return 1
    elseif op == :lparen
        return 0
    else
        error()
    end
end

function parse_class(str, s)
    chars = []
    while !done(str, s)
        c, s = next(str, s)
        if c == ']'
            break
        else
            push!(chars, c)
        end
    end
    if !isempty(chars) && first(chars) == '^'
        head = :cclass
        shift!(chars)
    else
        head = :class
    end
    args = []
    while !isempty(chars)
        c = shift!(chars)
        if !isempty(chars) && first(chars) == '-' && length(chars) ≥ 2
            push!(args, UInt8(c):UInt8(chars[2]))
            shift!(chars)
            shift!(chars)
        else
            push!(args, UInt8(c):UInt8(c))
        end
    end
    return RE(head, args), s
end

function desugar(re::RE)
    if re.head == :class
        return RE(:alt, [range(r) for r in re.args], re.actions)
    elseif re.head == :cclass
        return RE(:alt, [range(r) for r in complement_ranges(re.args)], re.actions)
    elseif re.head == :byte || re.head == :range
        return re
    elseif re.head == :rep1
        arg = desugar(re.args[1])
        return RE(:cat, [arg, rep(arg)], re.actions)
    elseif re.head == :opt
        arg = desugar(re.args[1])
        return RE(:alt, [arg, RE(:cat, [])], re.actions)
    else
        return RE(re.head, [desugar(arg) for arg in re.args], re.actions)
    end
end

function complement_ranges(ranges)
    comp = Set(0x00:0xff)
    for r in ranges
        setdiff!(comp, r)
    end
    return compact_labels(collect(comp))
end

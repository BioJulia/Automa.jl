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

macro re_str(s::String)
    return desugar(parse(unescape_string(s)))
end

function parse(str::String)
    if isempty(str)
        return RE(:cat, [])
    end

    # stacks
    operands = RE[]
    operators = Symbol[]

    function pop_and_apply!()
        op = pop!(operators)
        if op == :rep || op == :rep1 || op == :maybe
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
        # @show c operators operators
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
            while !isempty(operators) && prec(:maybe) ≤ prec(last(operators))
                pop_and_apply!()
            end
            push!(operators, :maybe)
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
            set, s = parse_set(str, s)
            push!(operands, RE(:set, [set]))
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
    if op == :rep || op == :rep1 || op == :maybe
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

function parse_set(str, s)
    firstc = peek(str, s)
    if isnull(firstc)
        error("missing ]")
    elseif get(firstc) == '^'
        _, s = next(str, s)
        complement = true
    else
        complement = false
    end
    set = Set{UInt8}()
    lastc = typemax(Char)
    while !done(str, s)
        c, s = next(str, s)
        if c == ']'
            break
        elseif c == '-'
            c, s = next(str, s)
            union!(set, UInt8(c′) for c′ in lastc:c)
        else
            push!(set, UInt8(c))
        end
        lastc = c
    end
    if complement
        set = setdiff(Set{UInt8}(0x00:0xff), set)
    end
    return set, s
end

function peek(str, s)
    if done(str, s)
        return Nullable{Char}()
    else
        return Nullable(next(str, s)[1])
    end
end

function desugar(re::RE)
    if re.head == :set
        set = re.args[1]
        return RE(:alt, [byte(b) for b in 0x00:0xff if b ∈ set])
    elseif re.head == :byte
        return re
    elseif re.head == :rep1
        arg = desugar(re.args[1])
        return cat(arg, rep(arg))
    elseif re.head == :maybe
        arg = desugar(re.args[1])
        return alt(arg, RE(:cat, []))
    else
        return RE(re.head, [desugar(arg) for arg in re.args])
    end
end

# Regular Expression
# ==================

module RegExp

import DataStructures: DefaultDict
import Automa: ByteSet

function gen_empty_names()
    return Symbol[]
end

type RE
    head::Symbol
    args::Vector
    actions::DefaultDict{Symbol,Vector{Symbol},typeof(gen_empty_names)}
    when::Nullable{Symbol}
end

function RE(head::Symbol, args::Vector)
    return RE(head, args, DefaultDict{Symbol,Vector{Symbol}}(gen_empty_names), Nullable{Symbol}())
end

const Primitive = Union{RE,ByteSet,UInt8,UnitRange{UInt8},Char,String,Vector{UInt8}}

function primitive(re::RE)
    return re
end

const PRIMITIVE = (:set, :byte, :range, :class, :cclass, :char, :str, :bytes)

function primitive(set::ByteSet)
    return RE(:set, [set])
end

function primitive(byte::UInt8)
    return RE(:byte, [byte])
end

function primitive(range::UnitRange{UInt8})
    return RE(:range, [range])
end

function primitive(char::Char)
    return RE(:char, [char])
end

function primitive(str::String)
    return RE(:str, [str])
end

function primitive(bs::Vector{UInt8})
    return RE(:bytes, copy(bs))
end

function cat(xs::Primitive...)
    return RE(:cat, [map(primitive, xs)...])
end

function alt(x::Primitive, xs::Primitive...)
    return RE(:alt, [primitive(x), map(primitive, xs)...])
end

function rep(x::Primitive)
    return RE(:rep, [primitive(x)])
end

function rep1(x::Primitive)
    return RE(:rep1, [primitive(x)])
end

function opt(x::Primitive)
    return RE(:opt, [primitive(x)])
end

function isec(x::Primitive, y::Primitive)
    return RE(:isec, [primitive(x), primitive(y)])
end

function diff(x::Primitive, y::Primitive)
    return RE(:diff, [primitive(x), primitive(y)])
end

function neg(x::Primitive)
    return RE(:neg, [primitive(x)])
end

function any()
    return primitive(0x00:0xff)
end

function ascii()
    return primitive(0x00:0x7f)
end

function space()
    return primitive(ByteSet([UInt8(c) for c in "\t\v\f\n\r "]))
end

Base.:*(re1::RE, re2::RE) = cat(re1, re2)
Base.:|(re1::RE, re2::RE) = alt(re1, re2)
Base.:&(re1::RE, re2::RE) = isec(re1, re2)
Base.:\(re1::RE, re2::RE) = diff(re1, re2)
Base.:!(re::RE) = neg(re)

macro re_str(s::String)
    return parse(unescape_string(escape_re_string(s)))
end

const METACHAR = ".*+?()[]\\|"

function escape_re_string(str::String)
    buf = IOBuffer()
    escape_re_string(buf, str)
    return String(take!(buf))
end

function escape_re_string(io::IO, str::String)
    s = start(str)
    while !done(str, s)
        c, s = next(str, s)
        if c == '\\' && !done(str, s)
            c′, s′ = next(str, s)
            if c′ ∈ METACHAR
                print(io, "\\\\")
                c, s = c′, s′
            end
        end
        print(io, c)
    end
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
    need_cat = false
    while !done(str, s)
        c, s = next(str, s)
        # @show c operands operators
        if need_cat && c ∉ ('*', '+', '?', '|', ')')
            while !isempty(operators) && prec(:cat) ≤ prec(last(operators))
                pop_and_apply!()
            end
            push!(operators, :cat)
        end
        need_cat = c ∉ ('|', '(')
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
            push!(operands, any())
        elseif c == '\\' && !done(str, s)
            c, s′ = next(str, s)
            if c ∈ METACHAR
                push!(operands, primitive(c))
                s = s′
            end
        else
            push!(operands, primitive(c))
        end
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
        elseif c == '\\'
            if done(str, s)
                error("missing ]")
            end
            c, s = next(str, s)
            push!(chars, c)
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
    if isempty(chars)
        error("empty class")
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

function shallow_desugar(re::RE)
    head = re.head
    args = re.args
    if head == :rep1
        return RE(:cat, [args[1], rep(args[1])])
    elseif head == :opt
        return RE(:alt, [args[1], RE(:cat, [])])
    elseif head == :neg
        return RE(:diff, [rep(any()), args[1]])
    elseif head == :byte
        return RE(:set, [ByteSet(args[1])])
    elseif head == :range
        return RE(:set, [ByteSet(args[1])])
    elseif head == :class
        return RE(:set, [foldl(union, ByteSet(), map(ByteSet, args))])
    elseif head == :cclass
        return RE(:set, [foldl(setdiff, ByteSet(0x00:0xff), map(ByteSet, args))])
    elseif head == :char
        bytes = convert(Vector{UInt8}, string(args[1]))
        return RE(:cat, [RE(:set, [ByteSet(b)]) for b in bytes])
    elseif head == :str
        bytes = convert(Vector{UInt8}, args[1])
        return RE(:cat, [RE(:set, [ByteSet(b)]) for b in bytes])
    elseif head == :bytes
        return RE(:cat, [RE(:set, [ByteSet(b)]) for b in args])
    else
        if head ∉ (:set, :cat, :alt, :rep, :isec, :diff)
            error("cannot desugar ':$(head)'")
        end
        return RE(head, args)
    end
end

end

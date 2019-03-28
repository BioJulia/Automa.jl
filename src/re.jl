# Regular Expression
# ==================

module RegExp

import Automa: ByteSet
import DataStructures: DefaultDict

function gen_empty_names()
    return Symbol[]
end

mutable struct RE
    head::Symbol
    args::Vector
    actions::DefaultDict{Symbol, Vector{Symbol}, typeof(gen_empty_names)}
    when::Union{Symbol, Nothing}
end

function RE(head::Symbol, args::Vector)
    return RE(head, args, DefaultDict{Symbol, Vector{Symbol}}(gen_empty_names), nothing)
end

const Primitive = Union{RE, ByteSet, UInt8, UnitRange{UInt8}, Char, String, Vector{UInt8}}

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

macro re_str(str::String)
    parse(str)
end

const METACHAR = raw".*+?()[]\|-^"

# Parse a regular expression string using the shunting-yard algorithm.
function parse(str::String)
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

    cs = iterate(str)
    if cs == nothing
        return RE(:cat, [])
    end
    need_cat = false
    while cs != nothing
        c, s = cs
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
            class, cs = parse_class(str, s)
            push!(operands, class)
            continue
        elseif c == '.'
            push!(operands, any())
        elseif c == '\\'
            if iterate(str, s) === nothing
                c = '\\'
            else
                c, s = unescape(str, s)
            end
            push!(operands, primitive(c))
        else
            push!(operands, primitive(c))
        end
        cs = iterate(str, s)
    end

    while !isempty(operators)
        pop_and_apply!()
    end

    @assert length(operands) == 1
    return first(operands)
end

# Operator's precedence.
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
        @assert false
    end
end

function parse_class(str, s)
    chars = Tuple{Bool, Char}[]
    cs = iterate(str, s)
    while cs != nothing
        c, s = cs
        if c == ']'
            cs = iterate(str, s)
            break
        elseif c == '\\'
            if iterate(str, s) === nothing
                error("missing ]")
            end
            c, s = unescape(str, s)
            push!(chars, (true, c))
        else
            push!(chars, (false, c))
        end
        cs = iterate(str, s)
    end
    if !isempty(chars) && !first(chars)[1] && first(chars)[2] == '^'
        head = :cclass
        popfirst!(chars)
    else
        head = :class
    end
    if isempty(chars)
        error("empty class")
    end

    args = []
    while !isempty(chars)
        c = popfirst!(chars)[2]
        if !isempty(chars) && !first(chars)[1] && first(chars)[2] == '-' && length(chars) ≥ 2
            push!(args, UInt8(c):UInt8(chars[2][2]))
            popfirst!(chars)
            popfirst!(chars)
        else
            push!(args, UInt8(c):UInt8(c))
        end
    end
    return RE(head, args), cs
end

function unescape(str::String, s::Int)
    invalid() = throw(ArgumentError("invalid escape sequence"))
    ishex(b) = '0' ≤ b ≤ '9' || 'A' ≤ b ≤ 'F' || 'a' ≤ b ≤ 'f'
    cs = iterate(str, s)
    cs === nothing && invalid()
    c, s = cs
    if c == 'a'
        return '\a', s
    elseif c == 'b'
        return '\b', s
    elseif c == 't'
        return '\t', s
    elseif c == 'n'
        return '\n', s
    elseif c == 'v'
        return '\v', s
    elseif c == 'r'
        return '\r', s
    elseif c == '0'
        return '\0', s
    elseif c ∈ METACHAR
        return c, s
    elseif c == 'x'
        cs1 = iterate(str, s)
        (cs1 === nothing || !ishex(cs1[1])) && invalid()
        cs2 = iterate(str, cs1[2])
        (cs2 === nothing || !ishex(cs2[1])) && invalid()
        c1, c2 = cs1[1], cs2[1]
        return first(unescape_string("\\x$(c1)$(c2)")), cs2[2]
    elseif c == 'u' || c == 'U'
        throw(ArgumentError("escaped Unicode sequence is not supported"))
    else
        throw(ArgumentError("invalid escape sequence: \\$(c)"))
    end
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
        return RE(:set, [foldl(union, map(ByteSet, args), init=ByteSet())])
    elseif head == :cclass
        return RE(:set, [foldl(setdiff, map(ByteSet, args), init=ByteSet(0x00:0xff))])
    elseif head == :char
        bytes = convert(Vector{UInt8}, codeunits(string(args[1])))
        return RE(:cat, [RE(:set, [ByteSet(b)]) for b in bytes])
    elseif head == :str
        bytes = convert(Vector{UInt8}, codeunits(args[1]))
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

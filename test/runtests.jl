
if VERSION >= v"0.7-"
    using Test
else
    using Base.Test
end

import Automa
import Automa.RegExp: @re_str

import Compat: contains, lastindex

@testset "SizedMemory" begin
    # Vector{UInt8}
    mem = Automa.SizedMemory(b"bar")
    @test lastindex(mem) === length(mem) === 3
    @test mem[1] === UInt8('b')
    @test mem[2] === UInt8('a')
    @test mem[3] === UInt8('r')
    @test_throws BoundsError mem[0]
    @test_throws BoundsError mem[4]

    # String
    mem = Automa.SizedMemory("bar")
    @test lastindex(mem) === length(mem) === 3
    @test mem[1] === UInt8('b')
    @test mem[2] === UInt8('a')
    @test mem[3] === UInt8('r')
    @test_throws BoundsError mem[0]
    @test_throws BoundsError mem[4]

    # SubString
    mem = Automa.SizedMemory(SubString("xbar", 2, 4))
    @test lastindex(mem) === length(mem) === 3
    @test mem[1] === UInt8('b')
    @test mem[2] === UInt8('a')
    @test mem[3] === UInt8('r')
    @test_throws BoundsError mem[0]
    @test_throws BoundsError mem[4]
end

@testset "DOT" begin
    re = re"[A-Za-z_][A-Za-z0-9_]*"
    re.actions[:enter] = [:enter]
    re.actions[:exit]  = [:exit]
    nfa = Automa.re2nfa(re)
    @test startswith(Automa.nfa2dot(nfa), "digraph")
    dfa = Automa.nfa2dfa(nfa)
    @test startswith(Automa.dfa2dot(dfa), "digraph")
    machine = Automa.compile(re)
    @test startswith(Automa.machine2dot(machine), "digraph")
    @test contains(repr(nfa.start), r"^Automa\.NFANode\(.*\)$")
    @test contains(repr(dfa.start), r"^Automa\.DFANode\(.*\)$")
    @test contains(repr(machine.start), r"^Automa\.Node\(.*\)$")
end

@testset "Determinacy" begin
    # see https://github.com/BioJulia/Automa.jl/issues/19
    notmach(re) = Automa.machine2dot(Automa.compile(re)) != Automa.machine2dot(Automa.compile(re))
    for re in (re"0?11|0?12", re"0?12|0?1*")
        @test count(_->notmach(re), 1:1000) == 0
    end
end

include("test01.jl")
include("test02.jl")
include("test03.jl")
include("test04.jl")
include("test05.jl")
include("test06.jl")
include("test07.jl")
include("test08.jl")
include("test09.jl")
include("test10.jl")
include("test11.jl")
include("test12.jl")
include("test13.jl")
include("test14.jl")
include("test15.jl")
include("test16.jl")

module TestFASTA

if VERSION >= v"0.7-"
    using Test
else
    using Base.Test
end

@testset "FASTA" begin
    include("../example/fasta.jl")
    @test records[1].identifier == "NP_003172.1"
    @test records[1].description == "brachyury protein isoform 1 [Homo sapiens]"
    @test records[1].sequence[1:5] == b"MSSPG"
    @test records[1].sequence[end-4:end] == b"SPPSM"
end
end

module TestNumbers

if VERSION >= v"0.7-"
    using Test
else
    using Base.Test
end

@testset "Numbers" begin
    include("../example/numbers.jl")
    @test tokens == [(:dec,"1"),(:hex,"0x0123BEEF"),(:oct,"0o754"),(:float,"3.14"),(:float,"-1e4"),(:float,"+6.022045e23")]
    @test status == :ok
    @test startswith(Automa.machine2dot(machine), "digraph")

    notmach(re) = Automa.machine2dot(Automa.compile(re)) != Automa.machine2dot(Automa.compile(re))
    @test count(_->notmach(numbers), 1:15) == 0
end
end

module TestTokenizer

if VERSION >= v"0.7-"
    using Test
else
    using Base.Test
end

@testset "MiniJulia" begin
    include("../example/tokenizer.jl")
    @test tokens[1:14] == [
        (:identifier,"quicksort"),
        (:lparen,"("),
        (:identifier,"xs"),
        (:rparen,")"),
        (:spaces," "),
        (:equal,"="),
        (:spaces," "),
        (:identifier,"quicksort!"),
        (:lparen,"("),
        (:identifier,"copy"),
        (:lparen,"("),
        (:identifier,"xs"),
        (:rparen,")"),
        (:rparen,")")]
    @test tokens[end-5:end] == [
        (:keyword,"return"),
        (:spaces," "),
        (:identifier,"j"),
        (:newline,"\n"),
        (:keyword,"end"),
        (:newline,"\n")]
end
end


# TODO: The follwoing tests are written using the deprecated syntax; should be
# removed in the future.

module Test1
    import Automa
    import Automa.RegExp: @re_str
    import Compat: lastindex

    if VERSION >= v"0.7-"
        using Test
    else
        using Base.Test
    end

    re = re""

    re.actions[:enter] = [:enter_re]
    re.actions[:exit] = [:exit_re]

    machine = Automa.compile(re)
    @test ismatch(r"^Automa.Machine\(<.*>\)$", repr(machine))

    last, actions = Automa.execute(machine, "")
    @test last == 0
    @test actions == [:enter_re, :exit_re]
    last, actions = Automa.execute(machine, "a")
    @test last < 0
    @test actions == []

    init_code = Automa.generate_init_code(machine)
    exec_code = Automa.generate_exec_code(machine, actions=:debug)

    @eval function validate(data)
        logger = Symbol[]
        $(init_code)
        p_end = p_eof = lastindex(data)
        $(exec_code)
        return cs == 0, logger
    end

    @test validate(b"") == (true, [:enter_re, :exit_re])
    @test validate(b"a") == (false, Symbol[])

    # inlined code
    exec_code = Automa.generate_exec_code(machine, actions=:debug, code=:inline)
    @eval function validate2(data)
        logger = Symbol[]
        $(init_code)
        p_end = p_eof = lastindex(data)
        $(exec_code)
        return cs == 0, logger
    end
    @test validate2(b"") == (true, [:enter_re, :exit_re])
    @test validate2(b"a") == (false, Symbol[])

    # goto code
    exec_code = Automa.generate_exec_code(machine, actions=:debug, code=:goto)
    @eval function validate3(data)
        logger = Symbol[]
        $(init_code)
        p_end = p_eof = lastindex(data)
        $(exec_code)
        return cs == 0, logger
    end
    @test validate3(b"") == (true, [:enter_re, :exit_re])
    @test validate3(b"a") == (false, Symbol[])
end

module Test2
    import Automa
    import Automa.RegExp: @re_str
    const re = Automa.RegExp
    import Compat: lastindex

    if VERSION >= v"0.7-"
        using Test
    else
        using Base.Test
    end

    a = re.rep('a')
    b = re.cat('b', re.rep('b'))
    ab = re.cat(a, b)

    a.actions[:enter] = [:enter_a]
    a.actions[:exit] = [:exit_a]
    a.actions[:final] = [:final_a]
    b.actions[:enter] = [:enter_b]
    b.actions[:exit] = [:exit_b]
    b.actions[:final] = [:final_b]
    ab.actions[:enter] = [:enter_re]
    ab.actions[:exit] = [:exit_re]
    ab.actions[:final] = [:final_re]

    machine = Automa.compile(ab)

    last, actions = Automa.execute(machine, "ab")
    @test last == 0
    @test actions == [:enter_re,:enter_a,:final_a,:exit_a,:enter_b,:final_b,:final_re,:exit_b,:exit_re]

    init_code = Automa.generate_init_code(machine)
    exec_code = Automa.generate_exec_code(machine, actions=:debug)

    @eval function validate(data)
        logger = Symbol[]
        $(init_code)
        p_end = p_eof = lastindex(data)
        $(exec_code)
        return cs == 0, logger
    end

    @test validate(b"b") == (true, [:enter_re,:enter_a,:exit_a,:enter_b,:final_b,:final_re,:exit_b,:exit_re])
    @test validate(b"a") == (false, [:enter_re,:enter_a,:final_a])
    @test validate(b"ab") == (true, [:enter_re,:enter_a,:final_a,:exit_a,:enter_b,:final_b,:final_re,:exit_b,:exit_re])
    @test validate(b"abb") == (true, [:enter_re,:enter_a,:final_a,:exit_a,:enter_b,:final_b,:final_re,:final_b,:final_re,:exit_b,:exit_re])

    # inlined code
    exec_code = Automa.generate_exec_code(machine, actions=:debug, code=:inline)
    @eval function validate2(data)
        logger = Symbol[]
        $(init_code)
        p_end = p_eof = lastindex(data)
        $(exec_code)
        return cs == 0, logger
    end
    @test validate2(b"b") == (true, [:enter_re,:enter_a,:exit_a,:enter_b,:final_b,:final_re,:exit_b,:exit_re])
    @test validate2(b"a") == (false, [:enter_re,:enter_a,:final_a])
    @test validate2(b"ab") == (true, [:enter_re,:enter_a,:final_a,:exit_a,:enter_b,:final_b,:final_re,:exit_b,:exit_re])
    @test validate2(b"abb") == (true, [:enter_re,:enter_a,:final_a,:exit_a,:enter_b,:final_b,:final_re,:final_b,:final_re,:exit_b,:exit_re])

    # goto code
    exec_code = Automa.generate_exec_code(machine, actions=:debug, code=:goto)
    @eval function validate3(data)
        logger = Symbol[]
        $(init_code)
        p_end = p_eof = lastindex(data)
        $(exec_code)
        return cs == 0, logger
    end
    @test validate3(b"b") == (true, [:enter_re,:enter_a,:exit_a,:enter_b,:final_b,:final_re,:exit_b,:exit_re])
    @test validate3(b"a") == (false, [:enter_re,:enter_a,:final_a])
    @test validate3(b"ab") == (true, [:enter_re,:enter_a,:final_a,:exit_a,:enter_b,:final_b,:final_re,:exit_b,:exit_re])
    @test validate3(b"abb") == (true, [:enter_re,:enter_a,:final_a,:exit_a,:enter_b,:final_b,:final_re,:final_b,:final_re,:exit_b,:exit_re])
end

module Test3
    import Automa
    import Automa.RegExp: @re_str
    const re = Automa.RegExp
    import Compat: lastindex
    if VERSION >= v"0.7-"
        using Test
    else
        using Base.Test
    end

    header = re"[ -~]*"
    newline = re"\r?\n"
    sequence = re.rep(re.cat(re"[A-Za-z]*", newline))
    fasta = re.rep(re.cat('>', header, newline, sequence))

    machine = Automa.compile(fasta)
    init_code = Automa.generate_init_code(machine)
    exec_code = Automa.generate_exec_code(machine)

    @eval function validate(data)
        $(init_code)
        p_end = p_eof = lastindex(data)
        $(exec_code)
        return cs == 0
    end

    @test validate(b"") == true
    @test validate(b">\naa\n") == true
    @test validate(b">seq1\n") == true
    @test validate(b">seq1\na\n") == true
    @test validate(b">seq1\nac\ngt\n") == true
    @test validate(b">seq1\r\nacgt\r\n") == true
    @test validate(b">seq1\nac\n>seq2\ngt\n") == true
    @test validate(b"a") == false
    @test validate(b">") == false
    @test validate(b">seq1\na") == false
    @test validate(b">seq1\nac\ngt") == false

    exec_code = Automa.generate_exec_code(machine, code=:inline)
    @eval function validate2(data)
        $(init_code)
        p_end = p_eof = lastindex(data)
        $(exec_code)
        return cs == 0
    end
    @test validate2(b"") == true
    @test validate2(b">\naa\n") == true
    @test validate2(b">seq1\n") == true
    @test validate2(b">seq1\na\n") == true
    @test validate2(b">seq1\nac\ngt\n") == true
    @test validate2(b">seq1\r\nacgt\r\n") == true
    @test validate2(b">seq1\nac\n>seq2\ngt\n") == true
    @test validate2(b"a") == false
    @test validate2(b">") == false
    @test validate2(b">seq1\na") == false
    @test validate2(b">seq1\nac\ngt") == false

    exec_code = Automa.generate_exec_code(machine, code=:goto)
    @eval function validate3(data)
        $(init_code)
        p_end = p_eof = lastindex(data)
        $(exec_code)
        return cs == 0
    end
    @test validate3(b"") == true
    @test validate3(b">\naa\n") == true
    @test validate3(b">seq1\n") == true
    @test validate3(b">seq1\na\n") == true
    @test validate3(b">seq1\nac\ngt\n") == true
    @test validate3(b">seq1\r\nacgt\r\n") == true
    @test validate3(b">seq1\nac\n>seq2\ngt\n") == true
    @test validate3(b"a") == false
    @test validate3(b">") == false
    @test validate3(b">seq1\na") == false
    @test validate3(b">seq1\nac\ngt") == false
end

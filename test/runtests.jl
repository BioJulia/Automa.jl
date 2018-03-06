
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


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

module TestStream

import Automa
import Automa.RegExp: @re_str
import Automa.Stream: @mark, @relpos, @abspos
using TranscodingStreams
using Base.Test

# Test 1
machine = let
    line = re"[^\r\n]*"
    newline = re"\r?\n"
    Automa.compile(line * newline)
end
Automa.Stream.generate_reader(:readline, machine) |> eval
@testset "Scanning a line" begin
    for (data, state) in [
            ("\n",      :ok),
            ("foo\n",   :ok),
            ("foo\r\n", :ok),
            ("",        :incomplete),
            ("\r",      :incomplete),
            ("foo",     :incomplete),
            ("\r\r",    :error),
            ("\r\nx",   :error),
            ("foo\nx",  :error),]
        s = readline(NoopStream(IOBuffer(data)))
        if state == :ok
            @test s == 0
        elseif state == :incomplete
            @test s > 0
        else
            @test s < 0
        end
    end
end

# Test 2
machine = let
    alphanum = re"[A-Za-z0-9]+"
    alphanum.actions[:enter] = [:start_alphanum]
    alphanum.actions[:exit]  = [:end_alphanum]
    whitespace = re"[ \t\r\n]*"
    Automa.compile(whitespace * alphanum * whitespace)
end
actions = Dict(
   :start_alphanum => :(@mark; start_alphanum = @relpos(p)),
   :end_alphanum   => :(end_alphanum = @relpos(p-1)),
)
initcode = :(start_alphanum = end_alphanum = 0)
returncode = :(return cs == 0 ? String(data[@abspos(start_alphanum):@abspos(end_alphanum)]) : "")
Automa.Stream.generate_reader(:stripwhitespace, machine, actions=actions, initcode=initcode, returncode=returncode) |> eval
@testset "Stripping whitespace" begin
    for (data, value) in [
            ("x", "x"),
            (" foo ", "foo"),
            ("  \r\n123\n  ", "123"),
            ("   abc123   ", "abc123"),
            ("", ""),
            ("  12+3 ", ""),
           ]
        for bufsize in [1:5; 100]
            @test stripwhitespace(NoopStream(IOBuffer(data), bufsize=bufsize)) == value
        end
    end
end

# Three-column BED file format.
cat = Automa.RegExp.cat
rep = Automa.RegExp.rep
machine = let
    chrom = re"[^\t]+"
    chrom.actions[:exit] = [:chrom]
    chromstart = re"[0-9]+"
    chromstart.actions[:exit] = [:chromstart]
    chromend = re"[0-9]+"
    chromend.actions[:exit] = [:chromend]
    record = cat(chrom, '\t', chromstart, '\t', chromend)
    record.actions[:enter] = [:mark]
    bed = rep(cat(record, re"\r?\n"))
    Automa.compile(bed)
end
#write("bed.dot", Automa.machine2dot(machine))
#run(`dot -Tsvg -o bed.svg bed.dot`)
actions = Dict(
    :mark => :(@mark; mark = @relpos(p)),
    :chrom => :(chrom = @relpos(p-1)),
    :chromstart => :(chromstart = @relpos(p-1)),
    :chromend => :(chromend = @relpos(p-1); found = true; @escape)
)
initcode = :(mark = chrom = chromstart = chromend = 0; found = false)
loopcode = :(found && @goto __return__)
returncode = quote
    if found
        return String(data[@abspos(mark):@abspos(chrom)]),
               parse(Int, String(data[@abspos(chrom)+2:@abspos(chromstart)])),
               parse(Int, String(data[@abspos(chromstart)+2:@abspos(chromend)]))
    else
        return ("", -1, 0)
    end
end
Automa.Stream.generate_reader(:readrecord!, machine, stateful=true, actions=actions, initcode=initcode, loopcode=loopcode, returncode=returncode) |> eval

@testset "Three-column BED (stateful)" begin
    stream = NoopStream(IOBuffer("""chr1\t10\t200\n"""))
    state = Automa.Stream.MachineState(machine.start_state)
    @test readrecord!(stream, state) == ("chr1", 10, 200)
    @test readrecord!(stream, state) == ("", -1, 0)
    @test state.cs == 0
    stream = NoopStream(IOBuffer("""1\t10\t200000\nchr12\t0\t21000\r\nchrM\t123\t12345\n"""))
    state = Automa.Stream.MachineState(machine.start_state)
    @test readrecord!(stream, state) == ("1", 10, 200000)
    @test readrecord!(stream, state) == ("chr12", 0, 21000)
    @test readrecord!(stream, state) == ("chrM", 123, 12345)
    @test readrecord!(stream, state) == ("", -1, 0)
    @test state.cs == 0
end

end

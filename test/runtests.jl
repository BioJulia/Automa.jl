import Automa
import Automa.RegExp: @re_str

using Test

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

@testset "RegExp" begin
    @test_throws ArgumentError("invalid escape sequence: \\o") Automa.RegExp.parse("\\o")
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
    @test occursin(r"^Automa\.NFANode\(.*\)$", repr(nfa.start))
    @test occursin(r"^Automa\.DFANode\(.*\)$", repr(dfa.start))
    @test occursin(r"^Automa\.Node\(.*\)$", repr(machine.start))
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
include("test17.jl")
include("test18.jl")

module TestFASTA
using Test
@testset "FASTA" begin
    include("../example/fasta.jl")
    @test records[1].identifier == "NP_003172.1"
    @test records[1].description == "brachyury protein isoform 1 [Homo sapiens]"
    @test records[1].sequence[1:5] == b"MSSPG"
    @test records[1].sequence[end-4:end] == b"SPPSM"
end
end

module TestNumbers
using Test
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
using Test
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
import Automa.Stream: @mark, @markpos, @relpos, @abspos
using TranscodingStreams
using Test

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
initcode = :(cs = state; mark = chrom = chromstart = chromend = 0; found = false)
loopcode = :(found && @goto __return__)
returncode = quote
    if found
        return (
            String(data[@abspos(mark):@abspos(chrom)]),
            parse(Int, String(data[@abspos(chrom)+2:@abspos(chromstart)])),
            parse(Int, String(data[@abspos(chromstart)+2:@abspos(chromend)]))),
            cs
    else
        return ("", -1, 0), cs
    end
end
Automa.Stream.generate_reader(:readrecord!, machine, arguments=(:(state::Int),), actions=actions, initcode=initcode, loopcode=loopcode, returncode=returncode) |> eval

@testset "Three-column BED (stateful)" begin
    stream = NoopStream(IOBuffer("""chr1\t10\t200\n"""))
    state = machine.start_state
    val, state = readrecord!(stream, state)
    @test val == ("chr1", 10, 200)
    val, state = readrecord!(stream, state)
    @test val == ("", -1, 0)
    @test state == 0
    stream = NoopStream(IOBuffer("""1\t10\t200000\nchr12\t0\t21000\r\nchrM\t123\t12345\n"""))
    state = machine.start_state
    val, state = readrecord!(stream, state)
    @test val == ("1", 10, 200000)
    val, state = readrecord!(stream, state)
    @test val == ("chr12", 0, 21000)
    val, state = readrecord!(stream, state)
    @test val == ("chrM", 123, 12345)
    val, state = readrecord!(stream, state)
    @test val == ("", -1, 0)
    @test state == 0
end

# FASTA
mutable struct Record
    data::Vector{UInt8}
    identifier::UnitRange{Int}
    description::UnitRange{Int}
    sequence::UnitRange{Int}
end

function Record()
    return Record(UInt8[], 1:0, 1:0, 1:0)
end

function initialize!(record::Record)
    empty!(record.data)
    record.identifier = record.description = record.sequence = 1:0
    return record
end

machine = let re = Automa.RegExp
    newline = re"\r?\n"

    identifier = re"[!-~]*"
    identifier.actions[:enter] = [:pos]
    identifier.actions[:exit] = [:identifier]

    description = re"[!-~][ -~]*"
    description.actions[:enter] = [:pos]
    description.actions[:exit] = [:description]

    header = re.cat('>', identifier, re.opt(re" " * description))
    header.actions[:exit] = [:header]

    letters = re"[A-Za-z*-]*"
    letters.actions[:enter] = [:mark, :pos]
    letters.actions[:exit] = [:letters]

    sequence = re.cat(letters, re.rep(newline * letters))

    record = re.cat(header, newline, sequence)
    record.actions[:enter] = [:mark]
    record.actions[:exit] = [:record]

    fasta = re.rep(record)

    Automa.compile(fasta)
end

actions = Dict(
    :mark => :(@mark),
    :pos => :(pos = @relpos(p)),
    :identifier => :(record.identifier = pos:@relpos(p-1)),
    :description => :(record.description = pos:@relpos(p-1)),
    :header => :(append!(record.data, data[@markpos():p-1]); push!(record.data, UInt8('\n'))),
    :letters => quote
        if isempty(record.sequence)
            record.sequence = length(record.data)+1:length(record.data)
        end
        record.sequence = first(record.sequence):last(record.sequence)+p-@abspos(pos)
        append!(record.data, data[@abspos(pos):p-1])
    end,
    :record => quote
        found = true
        @escape
    end
)
initcode = quote
    cs = state
    pos = 0
    found = false
    initialize!(record)
end
loopcode = quote
    found && @goto __return__
end
context = Automa.CodeGenContext(generator=:goto)
Automa.Stream.generate_reader(
    :readrecord!,
    machine,
    arguments=(:(state::Int), :(record::$(Record)),),
    actions=actions,
    context=context,
    initcode=initcode,
    loopcode=loopcode,
) |> eval

@testset "Streaming FASTA" begin
    stream = NoopStream(IOBuffer(""))
    state = machine.start_state
    record = Record()
    @test readrecord!(stream, state, record) == 0

    stream = NoopStream(IOBuffer("""
    >seq1 hogehoge
    ACGT
    TGCA
    """), bufsize=10)
    state = machine.start_state
    record = Record()
    @test readrecord!(stream, state, record) == 0
    @test String(record.data[record.identifier]) == "seq1"
    @test String(record.data[record.description]) == "hogehoge"
    @test String(record.data[record.sequence]) == "ACGTTGCA"

    stream = NoopStream(IOBuffer("""
    >seq1 1st sequence
    NANANANA
    >seq2 2nd sequence
    -----AAA
    GGGGG---
    """), bufsize=10)
    state = machine.start_state
    record = Record()
    state = readrecord!(stream, state, record)
    @test state > 0
    @test String(record.data[record.identifier]) == "seq1"
    @test String(record.data[record.description]) == "1st sequence"
    @test String(record.data[record.sequence]) == "NANANANA"
    state = readrecord!(stream, state, record)
    @test state == 0
    @test String(record.data[record.identifier]) == "seq2"
    @test String(record.data[record.description]) == "2nd sequence"
    @test String(record.data[record.sequence]) == "-----AAAGGGGG---"

    stream = NoopStream(IOBuffer("""
    >seq1 1st sequence

    N
    ANANANA
    >seq2 2nd sequence
    -----AAA

    GGGG

    G---


    """), bufsize=10)
    state = machine.start_state
    record = Record()
    state = readrecord!(stream, state, record)
    @test state > 0
    @test String(record.data[record.identifier]) == "seq1"
    @test String(record.data[record.description]) == "1st sequence"
    @test String(record.data[record.sequence]) == "NANANANA"
    state = readrecord!(stream, state, record)
    @test state == 0
    @test String(record.data[record.identifier]) == "seq2"
    @test String(record.data[record.description]) == "2nd sequence"
    @test String(record.data[record.sequence]) == "-----AAAGGGGG---"
end

end

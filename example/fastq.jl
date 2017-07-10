# FASTQ file parser
# =================

import Automa
import Automa.RegExp: @re_str

fastq_machine = (function ()
    cat = Automa.RegExp.cat
    rep = Automa.RegExp.rep
    opt = Automa.RegExp.opt

    newline = let
        lf = re"\n"
        lf.actions[:enter] = [:count_line]

        cat(re"\r?", lf)
    end

    header = let
        at = cat('@')
        at.when = :qlen_eq_slen
        identifier = re"[!-~]*"
        identifier.actions[:enter] = [:mark]
        identifier.actions[:exit] = [:identifier]
        description = re"[!-~][ -~]*"
        description.actions[:enter] = [:mark]
        description.actions[:exit] = [:description]

        cat(at, identifier, opt(cat(re" ", description)))
    end

    sequence = let
        sletters = re"[A-Za-z]*"
        sletters.actions[:enter] = [:mark]
        sletters.actions[:exit] = [:sletters]

        cat(sletters, rep(cat(newline, sletters)))
    end

    qheader = cat('+', re"[!-~]*", opt(cat(re" [!-~][ -~]*")))

    quality = let
        qletter1 = re"[!-~]"
        qletter1.when = :qlen_lt_slen
        qletters = opt(cat(qletter1, re"[!-~]*"))
        qletters.actions[:enter] = [:mark]
        qletters.actions[:exit] = [:qletters]

        cat(qletters, rep(cat(newline, qletters)))
    end

    record = cat(
        header, newline,
        sequence, newline,
        qheader, newline,
        quality, newline)
    record.actions[:enter] = [:mark_record]
    record.actions[:exit] = [:record]

    fastq = rep(record)

    return Automa.compile(fastq)
end)()

# write("fastq.dfa.dot", Automa.machine2dot(fastq_machine))
# run(`dot -Tsvg -o fastq.dfa.svg fastq.dfa.dot`)

fastq_actions = Dict(
    :qlen_lt_slen => :(qlen <  record.seqlen),
    :qlen_eq_slen => :(qlen == record.seqlen),
    :count_line => :(linenum += 1),
    :mark => :(mark = p),
    :mark_record => quote
        if reader.mark_record == 0  # first record
            reader.mark_record = p
        end
        mark_record = p
    end,
    :identifier => :(record.identifier = (mark+1:p) - reader.mark_record),
    :description => :(record.description = (mark+1:p) - reader.mark_record),
    :sletters => quote
        record.seqlen += p - mark
        if isempty(record.sequence)
            record.sequence = (mark+1:p) - reader.mark_record
        else
            record.sequence = first(record.sequence):(p-reader.mark_record)
        end
    end,
    :qletters => quote
        qlen += p - mark
        if isempty(record.quality)
            record.quality = (mark+1:p) - reader.mark_record
        else
            record.quality = first(record.quality):(p-reader.mark_record)
        end
    end,
    :record => :(found_record = true; @escape))

type FASTQReader{T<:IO}
    input::T
    cs::Int
    data::Vector{UInt8}
    p::Int
    p_end::Int
    p_eof::Int
    mark_record::Int
    linenum::Int
end

function FASTQReader(input::IO)
    return FASTQReader(input, fastq_machine.start_state, Vector{UInt8}(4 * 2^10), 1, 0, -1, 0, 1)
end

function readbyte!(s::IOStream, p::Ptr, nb::Integer)
    nr::Int = 0
    while nr < nb && !eof(s)
        nr += ccall(:ios_readall, Csize_t, (Ptr{Void}, Ptr{Void}, Csize_t), s.ios, p + nr, nb - nr)
    end
    return nr
end

function readbyte!(s::IOBuffer, p::Ptr, nb::Integer)
    nr = min(nb, nb_available(s))
    unsafe_read(s, p, nr)
    return nr
end

type FASTQRecord
    data::Vector{UInt8}
    identifier::UnitRange{Int}
    description::UnitRange{Int}
    sequence::UnitRange{Int}  # seqlen == length(sequence) iff sequence is written in a line
    quality::UnitRange{Int}   # seqlen == length(quality) iff base quality is written in a line
    seqlen::Int
end

function FASTQRecord()
    return FASTQRecord(UInt8[], 1:0, 1:0, 1:0, 1:0, 0)
end

function init!(record::FASTQRecord)
    record.identifier = 1:0
    record.description = 1:0
    record.sequence = 1:0
    record.quality = 1:0
    record.seqlen = 0
    return record
end

function Base.show(io::IO, record::FASTQRecord)
    println(io, summary(record), ':')
    println(io, "   identifier: ", String(record.data[record.identifier]))
    println(io, "  description: ", String(record.data[record.description]))
    println(io, "     sequence: ", String(record.data[record.sequence]))
      print(io, "      quality: ", String(record.data[record.quality]))
end

context = Automa.CodeGenContext(generator=:goto, checkbounds=false)
@eval function readfastq!(reader::FASTQReader, record::FASTQRecord)
    cs = reader.cs
    data = reader.data
    p = reader.p
    p_end = reader.p_end
    p_eof = reader.p_eof
    linenum = reader.linenum
    mark = mark_record = 0
    qlen = 0
    found_record = false

    if cs < 0
        error("the reader is in error state")
    elseif cs == 0
        error("the reader is finished")
    end

    init!(record)

    while true
        $(Automa.generate_exec_code(context, fastq_machine, actions=fastq_actions))

        reader.cs = cs
        reader.p = p
        reader.p_end = p_end
        reader.p_eof = p_eof
        reader.linenum = linenum

        if found_record
            if length(record.data) < p - reader.mark_record
                resize!(record.data, p - reader.mark_record)
            end
            copy!(record.data, 1, reader.data, reader.mark_record, p - reader.mark_record)
            reader.mark_record = mark_record
            break
        elseif cs < 0
            error("parse error on line $(linenum) ($(repr(String(reader.data[p:min(p+6,p_end)]))))")
        elseif cs == 0
            throw(EOFError())
        else
            # refill data buffer
            @assert p > p_end
            data_start = reader.mark_record
            if data_start > 0
                copy!(data, 1, data, data_start, endof(data) - data_start - 1)
                shift = data_start - 1
                p -= shift
                p_end -= shift
                mark -= shift
                mark_record -= shift
                reader.mark_record -= shift
            end
            n = readbyte!(reader.input, pointer(data, p), endof(data) - p)
            p_end += n
            if eof(reader.input)
                p_eof = p_end
            end
        end
    end

    return record
end

reader = FASTQReader(IOBuffer("""
@SRR1238088.23.1 HWI-ST499:111:D0G94ACXX:1:1101:6631:2166 length=102
AAAGCGTTCTCTTCCGTCAGCCTTCTTCCGCTTCTGTCGTCCTCCGCAACCGTGCCACCTCCCTCACCGTCCGTGCCGCTTCCTCCTACGCCGATGAGCTTC
+SRR1238088.23.1 HWI-ST499:111:D0G94ACXX:1:1101:6631:2166 length=102
CCCFFFFFHHHHHJIJIJJJJJJJJJJJJJJJJJJJIJJJJIJJJJJJJJJJHHHFFFFFEDDEDDDDDDDDDBDBBDDDDDDDDDDDDDDDDDDDDDDDDC
@SRR1238088.24.1 HWI-ST499:111:D0G94ACXX:1:1101:6860:2182 length=102
GGAGGATACAGCGGCGGCGGCGGCGGTTACTCCTCAAGAGGTGGTGGTGGCGGAAGCTACGGTGGTGGAAGACGTGAGGGAGGAGGAGGATACGGTGGTGGC
+SRR1238088.24.1 HWI-ST499:111:D0G94ACXX:1:1101:6860:2182 length=102
CCCFFFFFHHHGHJJJJJJFDDDDBDBDBCACDCDCDC8AB>AD5?@7@DDDDBDDDDCDDD3<@0<@ACDBCB<<ABDD9@D<<@8?D?9::?B3?B5?BC
"""))

records = FASTQRecord[]
try
    while reader.cs > 0
        record = FASTQRecord()
        readfastq!(reader, record)
        push!(records, record)
    end
catch ex
    if !isa(ex, EOFError)
        rethrow()
    end
end

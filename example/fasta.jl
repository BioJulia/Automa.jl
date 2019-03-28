# A simple and practical FASTA file parser
# ========================================

import Automa
import Automa.RegExp: @re_str
const re = Automa.RegExp

# Create a machine of FASTA.
fasta_machine = (function ()
    # First, describe FASTA patterns in regular expression.
    lf          = re"\n"
    newline     = re"\r?" * lf
    identifier  = re"[!-~]*"
    description = re"[!-~][ -~]*"
    letters     = re"[A-Za-z*-]*"
    sequence    = re.cat(letters, re.rep(newline * letters))
    record      = re.cat('>', identifier, re.opt(re" " * description), newline, sequence)
    fasta       = re.rep(record)

    # Second, bind action names to each regular expression.
    lf.actions[:enter]          = [:count_line]
    identifier.actions[:enter]  = [:mark]
    identifier.actions[:exit]   = [:identifier]
    description.actions[:enter] = [:mark]
    description.actions[:exit]  = [:description]
    letters.actions[:enter]     = [:mark]
    letters.actions[:exit]      = [:letters]
    record.actions[:exit]       = [:record]

    # Finally, compile the final FASTA pattern into a state machine.
    return Automa.compile(fasta)
end)()

# It is useful to visualize the state machine for debugging.
# write("fasta.dot", Automa.machine2dot(fasta_machine))
# run(`dot -Tsvg -o fasta.svg fasta.dot`)

# Bind Julia code to each action name (see the `parse_fasta` function defined below).
fasta_actions = Dict(
    :count_line  => :(linenum += 1),
    :mark        => :(mark = p),
    :identifier  => :(identifier = mark == 0 ? "" : String(data[mark:p-1]); mark = 0),
    :description => :(description = mark == 0 ? "" : String(data[mark:p-1]); mark = 0),
    :letters     => :(mark > 0 && unsafe_write(buffer, pointer(data, mark), p - mark); mark = 0),
    :record      => :(push!(records, FASTARecord(identifier, description, take!(buffer)))))

# Define a type to store a FASTA record.
mutable struct FASTARecord
    identifier::String
    description::String
    sequence::Vector{UInt8}
end

# Generate a parser function from `fasta_machine` and `fasta_actions`.
context = Automa.CodeGenContext(generator=:goto, checkbounds=false)
@eval function parse_fasta(data::Union{String,Vector{UInt8}})
    # Initialize variables you use in the action code.
    records = FASTARecord[]
    mark = 0
    linenum = 1
    identifier = description = ""
    buffer = IOBuffer()

    # Initialize variables used by the state machine.
    $(Automa.generate_init_code(context, fasta_machine))
    p_end = p_eof = lastindex(data)

    # This is the main loop to iterate over the input data.
    $(Automa.generate_exec_code(context, fasta_machine, fasta_actions))

    # Check the last state the machine reached.
    if cs != 0
        error("failed to parse on line ", linenum)
    end

    # Finally, return records accumulated in the action code.
    return records
end

# Run the FASTA parser.
records = parse_fasta("""
>NP_003172.1 brachyury protein isoform 1 [Homo sapiens]
MSSPGTESAGKSLQYRVDHLLSAVENELQAGSEKGDPTERELRVGLEESELWLRFKELTNEMIVTKNGRR
MFPVLKVNVSGLDPNAMYSFLLDFVAADNHRWKYVNGEWVPGGKPEPQAPSCVYIHPDSPNFGAHWMKAP
VSFSKVKLTNKLNGGGQIMLNSLHKYEPRIHIVRVGGPQRMITSHCFPETQFIAVTAYQNEEITALKIKY
NPFAKAFLDAKERSDHKEMMEEPGDSQQPGYSQWGWLLPGTSTLCPPANPHPQFGGALSLPSTHSCDRYP
TLRSHRSSPYPSPYAHRNNSPTYSDNSPACLSMLQSHDNWSSLGMPAHPSMLPVSHNASPPTSSSQYPSL
WSVSNGAVTPGSQAAAVSNGLGAQFFRGSPAHYTPLTHPVSAPSSSGSPLYEGAAAATDIVDSQYDAAAQ
GRLIASWTPVSPPSM
""")

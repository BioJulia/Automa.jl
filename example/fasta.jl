# A simple and practical FASTA file parser
# ========================================

using Automa

# Create a machine of FASTA.
fasta_machine = let
    # First, describe FASTA patterns in regular expression.
    newline     = re"\r?\n"
    identifier  = re"[!-~]*"
    description = re"[!-~][ -~]*"
    letters     = re"[A-Za-z*-]+"
    sequence    = letters * rep(newline * letters)
    record      = '>' * identifier * opt(' ' * description) * newline * sequence
    fasta       = opt(record) * rep(newline * record) * rep(newline)

    # Second, bind action names to each regular expression.
    onenter!(identifier,  :mark)
    onexit!( identifier,  :identifier)
    onenter!(description, :mark)
    onexit!( description, :description)
    onenter!(letters,     :mark)
    onexit!( letters,     :letters)
    onenter!(record,      :record)

    # Finally, compile the final FASTA pattern into a state machine.
    compile(fasta)
end

# It is useful to visualize the state machine for debugging.
# write("fasta.dot", Automa.machine2dot(fasta_machine))
# run(`dot -Tsvg -o fasta.svg fasta.dot`)

# Bind Julia code to each action name (see the `parse_fasta` function defined below).
fasta_actions = Dict(
    :mark        => :(mark = p),
    :identifier  => :(identifier = String(data[mark:p-1]); mark = 0),
    :description => :(description = iszero(mark) ? nothing : String(data[mark:p-1])),
    :letters     => quote
        linelen = p - mark
        length(buffer) < seqlen + linelen && resize!(buffer, seqlen + linelen)
        GC.@preserve data buffer unsafe_copyto!(pointer(buffer) + seqlen, pointer(data, mark), linelen)
        seqlen += linelen
    end,
    :record      => quote
        record_seen && push!(records, FASTARecord(identifier, description, String(buffer[1:seqlen])))
        seqlen = 0
        record_seen = true
    end
)

# Define a type to store a FASTA record.
struct FASTARecord
    identifier::String
    description::Union{Nothing, String}
    sequence::String
end

# Generate a parser function from `fasta_machine` and `fasta_actions`.
context = CodeGenContext(generator=:goto)
@eval function parse_fasta(data::AbstractVector{UInt8})
    # Initialize variables you use in the action code.
    records = FASTARecord[]
    mark = 0
    seqlen = 0
    record_seen = false
    identifier = ""
    description = nothing
    buffer = UInt8[]

    # Generate code for initialization and main loop
    $(generate_code(context, fasta_machine, fasta_actions))
    record_seen && push!(records, FASTARecord(identifier, description, String(buffer[1:seqlen])))

    # Finally, return records accumulated in the action code.
    return records
end
parse_fasta(s::Union{String, SubString{String}}) = parse_fasta(codeunits(s))
parse_fasta(io::IO) = parse_fasta(read(io))

# Run the FASTA parser.
data = """>NP_003172.1 brachyury protein isoform 1 [Homo sapiens]
MSSPGTESAGKSLQYRVDHLLSAVENELQAGSEKGDPTERELRVGLEESELWLRFKELTNEMIVTKNGRR
MFPVLKVNVSGLDPNAMYSFLLDFVAADNHRWKYVNGEWVPGGKPEPQAPSCVYIHPDSPNFGAHWMKAP
VSFSKVKLTNKLNGGGQIMLNSLHKYEPRIHIVRVGGPQRMITSHCFPETQFIAVTAYQNEEITALKIKY
NPFAKAFLDAKERSDHKEMMEEPGDSQQPGYSQWGWLLPGTSTLCPPANPHPQFGGALSLPSTHSCDRYP
TLRSHRSSPYPSPYAHRNNSPTYSDNSPACLSMLQSHDNWSSLGMPAHPSMLPVSHNASPPTSSSQYPSL
WSVSNGAVTPGSQAAAVSNGLGAQFFRGSPAHYTPLTHPVSAPSSSGSPLYEGAAAATDIVDSQYDAAAQ
GRLIASWTPVSPPSM
>sp|P01308|INS_HUMAN Insulin OS=Homo sapiens OX=9606 GN=INS PE=1 SV=1
MALWMRLLPLLALLALWGPDPAAAFVNQHLCGSHLVEALYLVCGERGFFYTPKTRREAED
LQVGQVELGGGPGAGSLQPLALEGSLQKRGIVEQCCTSICSLYQLENYCN
"""
records = parse_fasta(data)

# Uncomment to benchmark
# let
#     data2 = repeat(data, 10_000)
#     seconds = (@timed parse_fasta(data2)).time
#     MBs = (sizeof(data2) / 1e6) / seconds
#     println("Parsed FASTA at $(round(MBs; digits=2)) MB/s")
# end

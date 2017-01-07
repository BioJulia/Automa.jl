using Automa
using Automa.RegExp
const re = Automa.RegExp

# Describe a pattern in regular expression.
newline     = re"\r?\n"
identifier  = re"[!-~]*"
description = re"[!-~][ -~]*"
header      = re.cat(identifier, re.opt(re.cat(re" ", description)))
sequence    = re.rep(re.cat(re"[!-~]*", newline))
fasta       = re.rep(re.cat(re">", header, newline, sequence))

# Register actions.
newline.actions[:enter]     = [:newline]
identifier.actions[:enter]  = [:mark]
identifier.actions[:exit]   = [:identifier]
description.actions[:enter] = [:mark]
description.actions[:exit]  = [:description]
sequence.actions[:enter]    = [:mark]
sequence.actions[:exit]     = [:sequence]

# Compile a machine with actions.
actions = Dict(
    :newline     => :(linenum += 1),
    :mark        => :(mark = p),
    :identifier  => :(identifier = String(data[mark:p-1])),
    :description => :(description = String(data[mark:p-1])),
    :sequence    => quote
        seqs[identifier] = FASTARecord(description, data[mark:p-1])
        identifier = ""
        description = ""
    end
)
machine = compile(fasta)
init_code = generate_init_code(machine)
exec_code = generate_exec_code(machine, actions=actions)

type FASTARecord
    description::String
    sequence::Vector{UInt8}
end

# Generate a function to run the machine.
@eval function parse_fasta(data::Vector{UInt8})
    seqs = Dict{String,FASTARecord}()
    identifier = ""
    description = ""
    mark = 0
    linenum = 1
    $(init_code)
    p_end = p_eof = endof(data)
    $(exec_code)
    if !(cs in $(machine.final_states))
        error("failed to parse at line ", linenum)
    end
    return seqs
end

# Run the machine.
seqs = parse_fasta(b"""
>foo
ACGT
ACGT
>bar some description
ACGTACGT
""")

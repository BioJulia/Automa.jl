# Automa

[![Build Status](https://travis-ci.org/bicycle1885/Automa.jl.svg?branch=master)](https://travis-ci.org/bicycle1885/Automa.jl)

[![Coverage Status](https://coveralls.io/repos/bicycle1885/Automa.jl/badge.svg?branch=master&service=github)](https://coveralls.io/github/bicycle1885/Automa.jl?branch=master)

[![codecov.io](http://codecov.io/github/bicycle1885/Automa.jl/coverage.svg?branch=master)](http://codecov.io/github/bicycle1885/Automa.jl?branch=master)

A Julia package for text validation and parsing based on state machine compiler.

This is a [FASTA](https://en.wikipedia.org/wiki/FASTA_format) parser using
Automa.jl:
```julia
using Automa
const re = Automa.RegExp

# Describe a pattern in regular expression.
newline     = re"\r?\n"
identifier  = re"[!-~]*"
description = re"[!-~][ -~]*"
header      = re.cat(identifier, re.opt(re.cat(re" ", description)))
sequence    = re.rep(re.cat(re"[A-Za-z]*", newline))
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
init_code = generate_init(machine)
exec_code = generate_exec(machine, actions=actions)

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
```

Automa.jl
=========

[![Docs Latest](https://img.shields.io/badge/docs-latest-blue.svg)](https://biojulia.github.io/Automa.jl/latest/)
[![Build Status](https://travis-ci.org/BioJulia/Automa.jl.svg?branch=master)](https://travis-ci.org/BioJulia/Automa.jl)
[![codecov.io](http://codecov.io/github/BioJulia/Automa.jl/coverage.svg?branch=master)](http://codecov.io/github/BioJulia/Automa.jl?branch=master)

A Julia package for text validation, parsing, and tokenizing based on state machine compiler.

![Schema of Automa.jl](/docs/src/figure/Automa.png)

Automa.jl compiles regular expressions into Julia code, which is then compiled
into low-level machine code by the Julia compiler. Automa.jl is designed to
generate very efficient code to scan large text data, which is often much faster
than handcrafted code. Automa.jl can insert arbitrary Julia code that will be
executed in state transitions. This makes it possible, for example, to extract
substrings that match a part of a regular expression.

This is a number literal tokenizer using Automa.jl ([numbers.jl](example/numbers.jl)):
```julia
# A tokenizer of octal, decimal, hexadecimal and floating point numbers
# =====================================================================

import Automa
import Automa.RegExp: @re_str
const re = Automa.RegExp

# Describe patterns in regular expression.
oct      = re"0o[0-7]+"
dec      = re"[-+]?[0-9]+"
hex      = re"0x[0-9A-Fa-f]+"
prefloat = re"[-+]?([0-9]+\.[0-9]*|[0-9]*\.[0-9]+)"
float    = prefloat | re.cat(prefloat | re"[-+]?[0-9]+", re"[eE][-+]?[0-9]+")
number   = oct | dec | hex | float
numbers  = re.cat(re.opt(number), re.rep(re" +" * number), re" *")

# Register action names to regular expressions.
number.actions[:enter] = [:mark]
oct.actions[:exit]     = [:oct]
dec.actions[:exit]     = [:dec]
hex.actions[:exit]     = [:hex]
float.actions[:exit]   = [:float]

# Compile a finite-state machine.
machine = Automa.compile(numbers)

# This generates a SVG file to visualize the state machine.
# write("numbers.dot", Automa.machine2dot(machine))
# run(`dot -Tpng -o numbers.png numbers.dot`)

# Bind an action code for each action name.
actions = Dict(
    :mark  => :(mark = p),
    :oct   => :(emit(:oct)),
    :dec   => :(emit(:dec)),
    :hex   => :(emit(:hex)),
    :float => :(emit(:float)),
)

# Generate a tokenizing function from the machine.
context = Automa.CodeGenContext()
@eval function tokenize(data::String)
    tokens = Tuple{Symbol,String}[]
    mark = 0
    $(Automa.generate_init_code(context, machine))
    p_end = p_eof = lastindex(data)
    emit(kind) = push!(tokens, (kind, data[mark:p-1]))
    $(Automa.generate_exec_code(context, machine, actions))
    return tokens, cs == 0 ? :ok : cs < 0 ? :error : :incomplete
end

tokens, status = tokenize("1 0x0123BEEF 0o754 3.14 -1e4 +6.022045e23")
```

This emits tokens and the final status:

    ~/.j/v/Automa (master) $ julia -qL example/numbers.jl
    julia> tokens
    6-element Array{Tuple{Symbol,String},1}:
     (:dec,"1")
     (:hex,"0x0123BEEF")
     (:oct,"0o754")
     (:float,"3.14")
     (:float,"-1e4")
     (:float,"+6.022045e23")

    julia> status
    :ok

The compiled deterministic finite automaton (DFA) looks like this:
![DFA](/docs/src/figure/numbers.png)

For more details, see [fasta.jl](/example/fasta.jl) and read the docs page.

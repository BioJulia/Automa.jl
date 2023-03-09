```@meta
CurrentModule = Automa
DocTestSetup = quote
    using TranscodingStreams
    using Automa
end
```

# Debugging Automa

!!! danger 
    All Automa's debugging tools are NOT part of the API and are subject to change without warning.
    You can use them during development, but do NOT rely on their behaviour in your final code.

Automa is a complicated package, and the process of indirectly designing parsers by first designing a machine can be error prone.
Therefore, it's crucial to have good debugging tooling.

## Revise
Revise is not able to update Automa-generated functions.
To make your feedback loop faster, you can manually re-run the code that defines the Automa functions - usually this is much faster than modifying the package and reloading it.

## Ambiguity check
It is easy to accidentally create a machine where it is undecidable what actions should be taken.
For example:

```jldoctest
machine = let
    alphabet = re"BC"
    band = onenter!(re"BBA", :cool_band)
    compile(re"XYZ A" * (alphabet | band))
end

# output
ERROR: Ambiguous NFA.
[...]
```

Consider what the machine should do once it observes the two first bytes `AB` of the input:
Is the `B` part of `alphabet` (in which case it should do nothing), or is it part of `band` (in which case it should do the action `:cool_band`)? It's impossible to tell.

Automa will not compile this, and will raise the error:
```
ERROR: Ambiguous NFA.
```

Note the error shows an example input which will trigger the ambiguity: `XYZ A`, then `B`.
By simply running the input through in your head, you may discover yourself how the error happens.

In the example above, the error was obvious, but consider this example:

```jldoctest
fasta_machine = let
    header = re"[a-z]+"
    seq_line = re"[ACGT]+"
    sequence = seq_line * rep('\n' * seq_line)
    record = onexit!('>' * header * '\n' * sequence, :emit_record)
    compile(rep(record * '\n') * opt(record))
end

# output
ERROR: Ambiguous NFA.
[...]
```

It's the same problem: After a sequence line you observe `\n`: Is this the end of the sequence, or just a newline before another sequence line?

To work around it, consider when you know _for sure_ you are out of the sequence: It's not before you see a new `>`, or end-of-file.
In a sense, the trailing `\n` really IS part of the sequence.
So, really, your machine should regex similar to this

```jldoctest debug1; output = false
fasta_machine = let
    header = re"[a-z]+"
    seq_line = re"[ACGT]+"
    sequence = rep1(seq_line * '\n')
    record = onexit!('>' * header * '\n' * sequence, :emit_record)

    # A special record that can avoid a trailing newline, but ONLY if it's the last record
    record_eof = '>' * header * '\n' * seq_line * rep('\n' * seq_line) * opt('\n')
    compile(rep(record * '\n') * opt(record_eof))
end
@assert fasta_machine isa Automa.Machine

# output
```

When all else fails, you can also pass `unambiguous=false` to the `compile` function - but beware!
Ambiguous machines has undefined behaviour if you get into an ambiguous situation.

## Create `Machine` flowchart
The function `machine2dot(::Machine)` will return a string with a Graphviz `.dot` formatted flowchart of the machine.
Graphviz can then convert the dot file to an SVG function.

On my computer (with Graphviz and Firefox installed), I can use the following Julia code to display a flowchart of a machine.
Note that `dot` is the command-line name of Graphviz.

```julia
function display_machine(m::Machine)
    open("/tmp/machine.dot", "w") do io
        println(io, Automa.machine2dot(m))
    end
    run(pipeline(`dot -Tsvg /tmp/machine.dot`, stdout="/tmp/machine.svg"))
    run(`firefox /tmp/machine.svg`)
end
```

The following function are Automa internals, but they might help with more advanced debugging:
* `re2nfa` - create an NFA from an Automa regex
* `nfa2dot` - create a dot-formatted string from an nfa
* `nfa2dfa` - create a DFA from an NFA
* `dfa2dot` - create a dot-formatted string from a DFA

## Running machines in debug mode
The function `generate_code` takes an argument `actions`. If this is `:debug`, then all actions in the given `Machine` will be replaced by `:(push!(logger, action_name))`.
Hence, given a FASTA machine, you could create a debugger function:

```jldoctest debug1; output = false
 @eval function debug(data)
    logger = []
    $(generate_code(fasta_machine, :debug))
    logger
end

# output
debug (generic function with 1 method)
```

Then see all the actions executed in order, by doing:

```julia
julia> debug(">abc\nTAG")
4-element Vector{Any}:
 :mark
 :header
 :mark
 :seqline
 :record
```

Note that if your machine relies on its actions to work correctly, for example by actions modifying `p`,
this kind of debugger will not work, as it replaces all actions.

## More advanced debuggning
The file `test/debug.jl` contains extra debugging functionality and may be `include`d.
In particular it defines the functions `debug_execute` and `create_debug_function`.

The function of `create_debug_function(::Machine; ascii=false)` is best demonstrated:

```julia
machine = let
    letters = onenter!(re"[a-z]+", :enter_letters)
    compile(onexit!(letters * re",[0-9]," * letters, :exiting_regex))
end
eval(create_debug_function(machine; ascii=true))
(end_state, transitions) = debug_compile("abc,5,d!")
@show end_state
transitions
```

Will create the following output:
```
end state = -6
7-element Vector{Tuple{Char, Int64, Vector{Symbol}}}:
 ('a', 2, [:enter_letters])
 ('b', 2, [])
 ('c', 2, [])
 (',', 3, [])
 ('5', 4, [])
 (',', 5, [])
 ('d', 6, [:enter_letters])
```

Where each 3-tuple in the input corresponds to the input byte (displayed as a `Char` if `ascii` is set to `true`), the Automa state reached on reading the letter, and the actions executed.

The `debug_execute` function works the same as the `debug_compile`, but does not need to be generated first, and can be run directly on an Automa regex:

```julia
julia> debug_execute(re"[A-z]+", "abc1def"; ascii=true)
(-3, Tuple{Union{Nothing, Char}, Int64, Vector{Symbol}}[('a', 2, []), ('b', 3, []), ('c', 3, [])])
```

```@docs
machine2dot
```

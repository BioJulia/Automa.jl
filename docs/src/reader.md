```@meta
CurrentModule = Automa
DocTestSetup = quote
    using TranscodingStreams
    using Automa
end
```

# Creating a `Reader` type
The use of `generate_reader` as we learned in the previous section "Parsing from an io" has an issue we need to address:
While we were able to read multiple records from the reader by calling `read_record` multiple times, no state was preserved between these calls, and so, no state can be preserved between reading individual records.
This is also what made it necessary to clumsily reset `p` after emitting each record.

Imagine you have a format with two kinds of records, A and B types.
A records must come before B records in the file.
Hence, while a B record can appear at any time, once you've seen a B record, there can't be any more A records.
When reading records from the file, you must be able to store whether you've seen a B record.

We address this by creating a `Reader` type which wraps the IO being parsed, and which store any state we want to preserve between records.
Let's stick to our simplified FASTA format parsing sequences into `Seq` objects:

```jldoctest reader1; output = false
struct Seq
    name::String
    seq::String
end

machine = let
    header = onexit!(onenter!(re"[a-z]+", :mark_pos), :header)
    seqline = onexit!(onenter!(re"[ACGT]+", :mark_pos), :seqline)
    record = onexit!(re">" * header * '\n' * rep1(seqline * '\n'), :record)
    compile(rep(record))
end
@assert machine isa Automa.Machine

# output

```

This time, we use the following `Reader` type:
```jldoctest reader1; output = false
mutable struct Reader{S <: TranscodingStream}
    io::S
    automa_state::Int
end

Reader(io::TranscodingStream) = Reader{typeof(io)}(io, 1)
Reader(io::IO) = Reader(NoopStream(io))

# output
Reader
```

The `Reader` contains an instance of `TranscodingStream` to read from, and stores the Automa state between records.
The beginning state of Automa is always 1.
We can now create our reader function like below.
There are only three differences from the definitions in the previous section:
* I no longer have the code to decrement `p` in the `:record` action - because we can store the Automa state between records such that the machine can handle beginning in the middle of a record if necessary, there is no need to reset the value of `p` in order to restore the IO to the state right before each record.
* I return `(cs, state)` instead of just `state`, because I want to update the Automa state of the Reader, so when it reads the next record, it begins in the same state where the machine left off from the previous state
* In the arguments, I add `start_state`, and in the `initcode` I set `cs` to the start state, so the machine begins from the correct state

```jldoctest reader1; output = false
actions = Dict{Symbol, Expr}(
    :mark_pos => :(@mark),
    :header => :(header = String(data[@markpos():p-1])),
    :seqline => :(append!(seqbuffer, data[@markpos():p-1])),
    :record => quote
        seq = Seq(header, String(seqbuffer))
        found_sequence = true
        @escape
    end
)

generate_reader(
    :read_record,
    machine;
    actions=actions,
    arguments=(:(start_state::Int),),
    initcode=quote
        seqbuffer = UInt8[]
        found_sequence = false
        header = ""
        cs = start_state
    end,
    loopcode=quote
        if (is_eof && p > p_end) || found_sequence
            @goto __return__
        end
    end,
    returncode=:(found_sequence ? (cs, seq) : throw(EOFError()))
) |> eval

# output
read_record (generic function with 1 method)
```

We then create a function that reads from the `Reader`, making sure to update the `automa_state` of the reader:

```jldoctest reader1; output = false
function read_record(reader::Reader)
    (cs, seq) = read_record(reader.io, reader.automa_state)
    reader.automa_state = cs
    return seq
end

# output
read_record (generic function with 2 methods)
```

Let's test it out:

```jldoctest reader1
julia> reader = Reader(IOBuffer(">a\nT\n>tag\nGAG\nATATA\n"));

julia> read_record(reader)
Seq("a", "T")

julia> read_record(reader)
Seq("tag", "GAGATATA")

julia> read_record(reader)
ERROR: EOFError: read end of file
```
```@meta
CurrentModule = Automa
DocTestSetup = quote
    using TranscodingStreams
    using Automa
end
```

# Text validators
The simplest use of Automa is to simply match a regex.
It's unlikely you are going to want to use Automa for this instead of Julia's built-in regex engine PCRE, unless you need the extra performance that Automa brings over PCRE.
Nonetheless, it serves as a good starting point to introduce Automa.

Suppose we have the FASTA regex from the regex page:

```jldoctest val1
julia> fasta_regex = let
           header = re"[a-z]+"
           seqline = re"[ACGT]+"
           record = '>' * header * '\n' * rep1(seqline * '\n')
           rep(record)
       end;
```

## Buffer validator
Automa comes with a convenience function `generate_buffer_validator`:

Given a regex (`RE`) like the one above, we can do:

```jldoctest val1
julia> eval(generate_buffer_validator(:validate_fasta, fasta_regex));

julia> validate_fasta
validate_fasta (generic function with 1 method)
```

And we now have a function that checks if some data matches the regex:
```jldoctest val1
julia> validate_fasta(">hello\nTAGAGA\nTAGAG") # missing trailing newline
0

julia> validate_fasta(">helloXXX") # Error at byte index 7
7

julia> validate_fasta(">hello\nTAGAGA\nTAGAG\n") # nothing; it matches
```

## IO validators
For large files, having to read the data into a buffer to validate it may not be possible.
Automa also supports creating IO validators with the `generate_io_validator` function:

This works very similar to `generate_buffer_validator`, but the generated function takes an `IO`, and has a different return value:
* If the data matches, still return `nothing`
* Else, return (byte, (line, column)) where byte is the first errant byte, and (line, column) the position of the byte. If the errant byte is a newline, column is 0. If the input reaches unexpected EOF, byte is `nothing`, and (line, column) points to the last line/column in the IO:

```julia val1
julia> eval(generate_io_validator(:validate_io, fasta_regex));

julia> validate_io(IOBuffer(">hello\nTAGAGA\n"))

julia> validate_io(IOBuffer(">helX"))
(0x58, (1, 5))

julia> validate_io(IOBuffer(">hello\n\n"))
(0x0a, (3, 0))

julia> validate_io(IOBuffer(">hello\nAC"))
(nothing, (2, 2))
```

## Reference
```@docs
Automa.generate_buffer_validator
Automa.generate_io_validator
Automa.compile
```

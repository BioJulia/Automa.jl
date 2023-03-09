```@meta
CurrentModule = Automa
DocTestSetup = quote
    using TranscodingStreams
    using Automa
end
```

# Regex
Automa regex (of the type `Automa.RE`) are conceptually similar to the Julia built-in regex.
They are made using the `@re_str` macro, like this: `re"ABC[DEF]"`.

Automa regex matches individual bytes, not characters. Hence, `re"Æ"` (with the UTF-8 encoding `[0xc3, 0x86]`) is equivalent to `re"\xc3\x86"`, and is considered the concatenation of two independent input bytes.

The `@re_str` macro supports the following content:
* Literal symbols, such as `re"ABC"`, `re"\xfe\xa2"` or `re"Ø"`
* `|` for alternation, as in `re"A|B"`, meaning "`A` or `B`". 
* Byte sets with `[]`, like `re"[ABC]"`.
  This means any of the bytes in the brackets, e.g. `re"[ABC]"` is equivalent to `re"A|B|C"`.
* Inverted byte sets, e.g. `re"[^ABC]"`, meaning any byte, except those in `re[ABC]`.
* Repetition, with `X*` meaning zero or more repetitions of X
* `+`, where `X+` means `XX*`, i.e. 1 or more repetitions of X
* `?`, where `X?` means `X | ""`, i.e. 0 or 1 occurrences of X. It applies to the last element of the regex
* Parentheses to group expressions, like in `A(B|C)?`

You can combine regex with the following operations:
* `*` for concatenation, with `re"A" * re"B"` being the same as `re"AB"`.
  Regex can also be concatenated with `Char`s and `String`s, which will cause the chars/strings to be converted to regex first.
* `|` for alternation, with `re"A" | re"B"` being the same as `re"A|B"`
* `&` for intersection of regex, i.e. for regex `A` and `B`, the set of inputs matching `A & B` is exactly the intersection of the inputs match `A` and those matching `B`.
  As an example, `re"A[AB]C+D?" & re"[ABC]+"` is `re"ABC"`.
* `\` for difference, such that for regex `A` and `B`, `A \ B` creates a new regex matching all those inputs that match `A` but not `B`.
* `!` for inversion, such that `!re"[A-Z]"` matches all other strings than those which match `re"[A-Z]"`.
  Note that `!re"a"` also matches e.g. `"aa"`, since this does not match `re"a"`.

Finally, the funtions `opt`, `rep` and `rep1` is equivalent to the operators `?`, `*` and `+`, so i.e. `opt(re"a" * rep(re"b") * re"c")` is equivalent to `re"(ab*c)?"`.

## Example
Suppose we want to create a regex that matches a simplified version of the FASTA format.
This "simple FASTA" format is defined like so:

* The format is a series of zero or more _records_, concatenated
* A _record_ consists of the concatenation of:
    - A leading '>'
    - A header, composed of one or more letters in 'a-z',
    - A newline symbol '\n'
    - A series of one or more _sequence lines_
* A _sequence line_ is the concatenation of:
    - One or more symbols from the alphabet [ACGT]
    - A newline

We can represent this concisely as a regex: `re"(>[a-z]+\n([ACGT]+\n)+)*"`
To make it easier to read,  we typically construct regex incrementally, like such:

```jldoctest; output = false
fasta_regex = let
    header = re"[a-z]+"
    seqline = re"[ACGT]+"
    record = '>' * header * '\n' * rep1(seqline * '\n')
    rep(record)
end
@assert fasta_regex isa RE

# output

```

## Reference
```@docs
RE
@re_str
```

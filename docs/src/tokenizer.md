```@meta
CurrentModule = Automa
DocTestSetup = quote
    using TranscodingStreams
    using Automa
end
```

# Tokenizers (lexers)
A _tokenizer_ or a _lexer_ is a program that breaks down an input text into smaller chunks, and classifies them as one of several _tokens_.
For example, consider an imagininary format that only consists of nested tuples of strings containing letters, like this:

```
(("ABC", "v"),(("x", ("pj",(("a", "k")), ("L")))))
```

Any text of this format can be broken down into a sequence of the following tokens:
* Left parenthesis: `re"\("`
* Right parenthesis: `re"\)"`
* Comma: `re","`
* Quote: `re"\""`
* Spaces: `re" +"`
* Letters: `re"[A-Za-z]+"`

Such that e.g. `("XY", "A")` can be represented as `lparent, quote, XY, quote, comma, space, quote A quote rparens`.

Breaking the text down to its tokens is called tokenization or lexing. Note that lexing in itself is not sufficient to parse the format: Lexing is _context unaware_, so e.g. the test `"((A` can be perfectly well tokenized to `quote lparens lparens A`, even if it's invalid.

The purpose of tokenization is to make subsequent parsing easier, because each part of the text has been classified. That makes it easier to, for example, to search for letters in the input. Instead of having to muck around with regex to find the letters, you use regex once to classify all text.

## Making and using a tokenizer
Let's use the example above to create a tokenizer.
The most basic default tokenizer uses `UInt32` as tokens: You pass in a list of regex matching each token, then evaluate the resulting code:

```jldoctest tok1
julia> make_tokenizer(
           [re"\(", re"\)", re",", re"\"", re" +", re"[a-zA-Z]+"]
       ) |> eval
```

Since the default tokenizer uses `UInt32` as tokens, you can then obtain a lazy iterator of tokens by calling `tokenize(UInt32, data)`:

```jldoctest tok1
julia> iterator = tokenize(UInt32, """("XY", "A")"""); typeof(iterator)
Tokenizer{UInt32, String, 1}
```

This will return `Tuple{Int64, Int32, UInt32}` elements, with each element being:
* The start index of the token
* The length of the token
* The token itself, in this example `UInt32(1)` for '(', `UInt32(2)` for ')' etc: 

```jldoctest tok1
julia> collect(iterator)
10-element Vector{Tuple{Int64, Int32, UInt32}}:
 (1, 1, 0x00000001)
 (2, 1, 0x00000004)
 (3, 2, 0x00000006)
 (5, 1, 0x00000004)
 (6, 1, 0x00000003)
 (7, 1, 0x00000005)
 (8, 1, 0x00000004)
 (9, 1, 0x00000006)
 (10, 1, 0x00000004)
 (11, 1, 0x00000002)
```

Any data which could not be tokenized is given the error token `UInt32(0)`:
```jldoctest tok1
julia> collect(tokenize(UInt32, "XY!!)"))
3-element Vector{Tuple{Int64, Int32, UInt32}}:
 (1, 2, 0x00000006)
 (3, 2, 0x00000000)
 (5, 1, 0x00000002)
```

Both `tokenize` and `make_tokenizer` takes an optional argument `version`, which is `1` by default.
This sets the last parameter of the `Tokenizer` struct, and as such allows you to create multiple different tokenizers with the same element type.

## Using enums as tokens
Using `UInt32` as tokens is not very convenient - so it's possible to use enums to create the tokenizer:

```jldoctest tok2
julia> @enum Token error lparens rparens comma quot space letters

julia> make_tokenizer((error, [
           lparens => re"\(",
           rparens => re"\)",
           comma => re",",
           quot => re"\"",
           space => re" +",
           letters => re"[a-zA-Z]+"
        ])) |> eval

julia> collect(tokenize(Token, "XY!!)"))
3-element Vector{Tuple{Int64, Int32, Token}}:
 (1, 2, letters)
 (3, 2, error)
 (5, 1, rparens)
```

To make it even easier, you can define the enum and the tokenizer in one go:
```jldoctest; output = false
tokens = [
    :lparens => re"\(",
    :rparens => re"\)",
    :comma => re",",
    :quot => re"\"",
    :space => re" +",
    :letters => re"[a-zA-Z]+"
]
@eval @enum Token error $(first.(tokens)...)
make_tokenizer((error, 
    [Token(i) => j for (i,j) in enumerate(last.(tokens))]
)) |> eval

# output

```

## Token disambiguation
It's possible to create a tokenizer where the different token regexes overlap:
```jldoctest
julia> make_tokenizer([re"[ab]+", re"ab*", re"ab"]) |> eval
```

In this case, an input like `ab` will match all three regex.
Which tokens are emitted is determined by two rules:

First, the emitted tokens will be as long as possible.
So, the input `aa` could be emitted as one token of the regex `re"[ab]+"`, two tokens of the same regex, or of two tokens of the regex `re"ab*"`.
In this case, it will be emitted as a single token of `re"[ab]+"`, since that will make the first token as long as possible (2 bytes), whereas the other options would only make it 1 byte long.

Second, tokens with a higher index in the input array beats previous tokens.
So, `a` will be emitted as `re"ab*"`, as its index of 2 beats the previous regex `re"[ab]+"` with the index 1, and `ab` will match the third regex.

If you don't want emitted tokens to depend on these priority rules, you can set the optional keyword `unambiguous=true` in the `make_tokenizer` function, in which case `make_tokenizer` will error if any input text could be broken down into different tokens.
However, note that this may cause most tokenizers to error when being built, as most tokenization processes are ambiguous.

## Reference
```@docs
Automa.Tokenizer
Automa.tokenize
Automa.make_tokenizer
```
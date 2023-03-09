# Automa.jl

[![Docs Latest](https://img.shields.io/badge/docs-latest-blue.svg)](https://biojulia.github.io/Automa.jl/latest/)
[![codecov.io](http://codecov.io/github/BioJulia/Automa.jl/coverage.svg?branch=master)](http://codecov.io/github/BioJulia/Automa.jl?branch=master)

Automa is a regex-to-Julia compiler.
By compiling regex to Julia code in the form of `Expr` objects,
Automa provides facilities to create efficient and robust regex-based lexers, tokenizers and parsers using Julia's metaprogramming capabilities. 
You can view Automa as a regex engine that can insert arbitrary Julia code into its input matching process, which will be executed when certain parts of the regex matches an input.

![Schema of Automa.jl](figure/Automa.png)

Automa is designed to generate very efficient code to scan large text data, often much faster than handcrafted code.

For more information [read the documentation](https://biojulia.github.io/Automa.jl/latest/), or read the examples below and in the `examples/` directory in this repository.

## Examples
### Validate some text only is composed of ASCII alphanumeric characters
```julia
using Automa

generate_buffer_validator(:validate_alphanumeric, re"[a-zA-Z0-9]*") |> eval

for s in ["abc", "aU81m", "!,>"]
    println("$s is alphanumeric? $(isnothing(validate_alphanumeric(s)))")
end
```

### Making a lexer
```julia
using Automa

tokens = [
    :identifier => re"[A-Za-z_][0-9A-Za-z_!]*",
    :lparens => re"\(",
    :rparens => re"\)",
    :comma => re",",
    :quot => re"\"",
    :space => re"[\t\f ]+",
];
@eval @enum Token errortoken $(first.(tokens)...)
make_tokenizer((errortoken, 
    [Token(i) => j for (i,j) in enumerate(last.(tokens))]
)) |> eval

collect(tokenize(Token, """(alpha, "beta15")"""))
```

### Make a simple TSV file parser
```julia
using Automa

machine = let
    name = onexit!(onenter!(re"[^\t\r\n]+", :mark), :name)
    field = onexit!(onenter!(re"[^\t\r\n]+", :mark), :field)
    nameline = name * rep('\t' * name)
    record = onexit!(field * rep('\t' * field), :record)
    compile(nameline * re"\r?\n" * record * rep(re"\r?\n" * record) * rep(re"\r?\n"))
end

actions = Dict(
    :mark => :(pos = p),
    :name => :(push!(headers, String(data[pos:p-1]))),
    :field => quote
        n_fields += 1
        push!(fields, String(data[pos:p-1]))
    end,
    :record => quote
        n_fields == length(headers) || error("Malformed TSV")
        n_fields = 0
    end
)

@eval function parse_tsv(data)
    headers = String[]
    fields = String[]
    pos = n_fields = 0
    $(generate_code(machine, actions))
    (headers, reshape(fields, length(headers), :))
end

header, data = parse_tsv("a\tabc\n12\t13\r\nxyc\tz\n\n")
```
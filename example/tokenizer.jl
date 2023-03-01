using Automa

# Create an enum to store the tokens in. I define the enum in its own module
# in order to not clutter the Main namespace with all the variants.
module Tokens
    using Automa
    minijulia = [
        :identifier   => re"[A-Za-z_][0-9A-Za-z_!]*",
        :comma        => re",",
        :colon        => re":",
        :semicolon    => re";",
        :dot          => re"\.",
        :question     => re"\?",
        :equal        => re"=",
        :lparen       => re"\(",
        :rparen       => re"\)",
        :lbracket     => re"\[",
        :rbracket     => re"]",
        :lbrace       => re"{",
        :rbrace       => re"}",
        :dollar       => re"$",
        :and          => re"&&",
        :or           => re"\|\|",
        :typeannot    => re"::",
        :keyword      => re"break|const|continue|else|elseif|end|for|function|if|return|type|using|while",
        :operator     => re"-|\+|\*|/|%|&|\||^|!|~|>|<|<<|>>|>=|<=|=>|==|===",
        :macrocall    => re"@" * re"[A-Za-z_][0-9A-Za-z_!]*",
        :integer      => re"[0-9]+",
        :comment      => re"#[^\r\n]*",
        :char         => '\'' * (re"[ -&(-~]" | ('\\' * re"[ -~]")) * '\'',
        :string       => '"' * rep(re"[ !#-~]" | re"\\\\\"") * '"',
        :triplestring => "\"\"\"" * (re"[ -~]*" \ re"\"\"\"") * "\"\"\"",
        :newline      => re"\r?\n",
        :spaces       => re"[\t ]+",
    ]
    @eval @enum Token error $(first.(minijulia)...)
    export Token
end

using .Tokens: Token

make_tokenizer((
    Tokens.error,
    [Tokens.Token(i) => regex for (i, regex) in enumerate(last.(Tokens.minijulia))]
)) |> eval

code = """
quicksort(xs) = quicksort!(copy(xs))
quicksort!(xs) = quicksort!(xs, 1, length(xs))

function quicksort!(xs, lo, hi)
    if lo < hi
        p = partition(xs, lo, hi)
        quicksort!(xs, lo, p - 1)
        quicksort!(xs, p + 1, hi)
    end
    return xs
end

function partition(xs, lo, hi)
    pivot = div(lo + hi, 2)
    pvalue = xs[pivot]
    xs[pivot], xs[hi] = xs[hi], xs[pivot]
    j = lo
    @inbounds for i in lo:hi-1
        if xs[i] <= pvalue
            xs[i], xs[j] = xs[j], xs[i]
            j += 1
        end
    end
    xs[j], xs[hi] = xs[hi], xs[j]
    return j
end
"""

# For convenience, let's convert it to (string, token) tuples
# even though it's inefficient to store them as individual strings
tokens = map(tokenize(Token, code)) do (start, len, token)
    (code[start:start+len-1], token)
end

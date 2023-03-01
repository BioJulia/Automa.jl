# There are other tokenizer tests, e.g. test09 and in runtests
module TestTokenizer

using Automa
using Test

@testset "Tokenizer" begin
    for goto in (false, true)
        make_tokenizer(:token_iter, compile([
            re"ADF",
            re"[A-Z]+",
            re"[abcde]+",
            re"abc",
            re"ab[a-z]"
        ]); goto=goto) |> eval
        tokenize(x) = collect(token_iter(x))

        # Empty
        @test tokenize("") == []

        # Only error
        @test tokenize("!"^11) == [(1, 11, 0)]

        # Longest token wins
        @test tokenize("abca") == [(1, 4, 3)]
        @test tokenize("ADFADF") == [(1, 6, 2)]
        @test tokenize("AD") == [(1, 2, 2)]

        # Ties are broken with last token
        @test tokenize("ADF") == [(1, 3, 2)]
        @test tokenize("abc") == [(1, 3, 5)]
        @test tokenize("abe") == [(1, 3, 5)]
    end
end

end # module
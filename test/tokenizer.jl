# There are other tokenizer tests, e.g. test09 and in runtests
module TestTokenizer

using Automa
using Test

@testset "Tokenizer" begin
    # TODO: This could be a loop over (false, true),
    # but Julia #51267 prevents this for now
    make_tokenizer([
        re"ADF",
        re"[A-Z]+",
        re"[abcde]+",
        re"abc",
        re"ab[a-z]"
    ]; goto=false, version=1) |> eval

    make_tokenizer([
        re"ADF",
        re"[A-Z]+",
        re"[abcde]+",
        re"abc",
        re"ab[a-z]"
    ]; goto=true, version=2) |> eval

    for f in (
        (i -> collect(tokenize(UInt32, i, 1))),
        (i -> collect(tokenize(UInt32, i, 2)))
    )
        # Empty
        @test f("") == []

        # Only error
        @test f("!"^11) == [(1, 11, 0)]

        # Longest token wins
        @test f("abca") == [(1, 4, 3)]
        @test f("ADFADF") == [(1, 6, 2)]
        @test f("AD") == [(1, 2, 2)]

        # Ties are broken with last token
        @test f("ADF") == [(1, 3, 2)]
        @test f("abc") == [(1, 3, 5)]
        @test f("abe") == [(1, 3, 5)]
    end
end

end # module
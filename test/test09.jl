module Test09

using Automa
using Test

@testset "Test09" begin
    eval(make_tokenizer([
        re"a",
        re"a*b",
        re"cd"
    ]))

    tokenize(x) = collect(Automa.tokenize(UInt32, x))

    @test tokenize("") == []
    @test tokenize("a") == [(1, 1, 1)]
    @test tokenize("b") == [(1, 1, 2)]
    
    @test tokenize("aa") == [(1,1,1), (2,1,1)]
    @test tokenize("ab") == [(1,2,2)]
    @test tokenize("aaa") == [(1,1,1), (2,1,1), (3,1,1)]
    @test tokenize("aab") == [(1,3,2)]
    @test tokenize("abaabba") == [(1,2,2), (3,3,2), (6,1,2), (7,1,1)]

    @test tokenize("c") == [(1, 1, 0)]
    @test tokenize("ac") == [(1, 1, 1), (2, 1, 0)]
    @test tokenize("abc") == [(1, 2, 2), (3, 1, 0)]
    @test tokenize("acb") == [(1, 1, 1), (2, 1, 0), (3, 1, 2)]
    @test tokenize("cdc") == [(1, 2, 3), (3, 1, 0)]
end

end

module Test09

import Automa
import Automa.RegExp: @re_str
const re = Automa.RegExp
using Test

@testset "Test09" begin
    tokenizer = Automa.compile(
        re"a"      => :(emit(:a, ts:te)),
        re"a*b"    => :(emit(:ab, ts:te)),
    )
    ctx = Automa.CodeGenContext()

    @eval function tokenize(data)
        $(Automa.generate_init_code(ctx, tokenizer))
        p_end = p_eof = sizeof(data)
        tokens = Tuple{Symbol,String}[]
        emit(kind, range) = push!(tokens, (kind, data[range]))
        while p ≤ p_eof && cs > 0
            $(Automa.generate_exec_code(ctx, tokenizer))
        end
        if cs < 0
            error()
        end
        return tokens
    end

    @test tokenize("") == []
    @test tokenize("a") == [(:a, "a")]
    @test tokenize("b") == [(:ab, "b")]
    @test tokenize("aa") == [(:a, "a"), (:a, "a")]
    @test tokenize("ab") == [(:ab, "ab")]
    @test tokenize("aaa") == [(:a, "a"), (:a, "a"), (:a, "a")]
    @test tokenize("aab") == [(:ab, "aab")]
    @test tokenize("abaabba") == [(:ab, "ab"), (:ab, "aab"), (:ab, "b"), (:a, "a")]
    @test_throws ErrorException tokenize("c")
    @test_throws ErrorException tokenize("ac")
    @test_throws ErrorException tokenize("abc")
    @test_throws ErrorException tokenize("acb")
end

end

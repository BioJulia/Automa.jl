# Test codegencontext
@testset "CodeGenContext" begin
    @test_throws ArgumentError Automa.CodeGenContext(generator=:fdjfhkdj)
    @test_throws ArgumentError Automa.CodeGenContext(generator=:goto, getbyte=identity)
end

import Automa
const re = Automa.RegExp
import Automa.RegExp: @re_str

@testset "SIMD generator" begin
    regex = let
        seq = re"[A-Z]+"
        name = re"[a-z]+"
        rec = re">"  * name * re"\n" * seq
        re.opt(rec) * re.rep(re"\n" * rec)
    end

    context = Automa.CodeGenContext(generator=:goto)

    eval(Automa.generate_validator_function(:is_valid_fasta, regex, true))

    s1 = ">seq\nTAGGCTA\n>hello\nAJKGMP"
    s2 = ">seq1\nTAGGC"
    s3 = ">verylongsequencewherethesimdkicksinmakeitevenlongertobesure\nQ"

    for (seq, isvalid) in [(s1, true), (s2, false), (s3, true)]
        @test is_valid_fasta(seq) isa (isvalid ? Nothing : Integer)
    end
end
    

# Test codegencontext
@testset "CodeGenContext" begin
    @test_throws ArgumentError Automa.CodeGenContext(generator=:fdjfhkdj)
    @test_throws ArgumentError Automa.CodeGenContext(generator=:goto, getbyte=identity)
end

using Automa

@testset "SIMD generator" begin
    regex = let
        seq = re"[A-Z]+"
        name = re"[a-z]+"
        rec = re">"  * name * re"\n" * seq
        opt(rec) * rep(re"\n" * rec)
    end

    context = CodeGenContext(generator=:goto)

    eval(generate_buffer_validator(:is_valid_fasta, regex, true))

    s1 = ">seq\nTAGGCTA\n>hello\nAJKGMP"
    s2 = ">seq1\nTAGGC"
    s3 = ">verylongsequencewherethesimdkicksinmakeitevenlongertobesure\nQ"

    for (seq, isvalid) in [(s1, true), (s2, false), (s3, true)]
        @test is_valid_fasta(seq) isa (isvalid ? Nothing : Integer)
    end
end
    

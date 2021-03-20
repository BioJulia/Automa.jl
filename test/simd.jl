# Test codegencontext
@testset "CodeGenContext" begin
    @test_throws ArgumentError Automa.CodeGenContext(generator=:fdjfhkdj)
    @test_throws ArgumentError Automa.CodeGenContext(generator=:simd)
    @test_throws ArgumentError Automa.CodeGenContext(generator=:simd, checkbounds=false, loopunroll=2)
    @test_throws ArgumentError Automa.CodeGenContext(generator=:simd, checkbounds=false, getbyte=identity)
end

import Automa
const re = Automa.RegExp
import Automa.RegExp: @re_str

@testset "SIMD generator" begin
    machine = let
        seq = re"[A-Z]+"
        name = re"[a-z]+"
        rec = re">"  * name * re"\n" * seq
        Automa.compile(re.opt(rec) * re.rep(re"\n" * rec))
    end

    context = Automa.CodeGenContext(generator=:simd, checkbounds=false)

    @eval function is_valid_fasta(data::String)
        $(Automa.generate_init_code(context, machine))
        p_end = p_eof = ncodeunits(data)
        $(Automa.generate_exec_code(context, machine, nothing))
        return p == ncodeunits(data) + 1
    end

    s1 = ">seq\nTAGGCTA\n>hello\nAJKGMP"
    s2 = ">seq1\nTAGGC"
    s3 = ">verylongsequencewherethesimdkicksin\nQ"

    for (seq, isvalid) in [(s1, true), (s2, false), (s3, true)]
        @test is_valid_fasta(seq) == isvalid
    end
end
    

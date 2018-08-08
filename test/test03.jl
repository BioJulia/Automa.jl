module Test03

import Automa
import Automa.RegExp: @re_str
using Test

@testset "Test03" begin
    re = Automa.RegExp
    header = re"[ -~]*"
    newline = re"\r?\n"
    sequence = re.rep(re.cat(re"[A-Za-z]*", newline))
    fasta = re.rep(re.cat('>', header, newline, sequence))

    machine = Automa.compile(fasta)

    for generator in (:table, :inline, :goto), checkbounds in (true, false), clean in (true, false)
        ctx = Automa.CodeGenContext(generator=generator, checkbounds=checkbounds, clean=clean)
        init_code = Automa.generate_init_code(ctx, machine)
        exec_code = Automa.generate_exec_code(ctx, machine)
        validate = @eval function (data)
            $(init_code)
            p_end = p_eof = lastindex(data)
            $(exec_code)
            return cs == 0
        end
        @test validate(b"") == true
        @test validate(b">\naa\n") == true
        @test validate(b">seq1\n") == true
        @test validate(b">seq1\na\n") == true
        @test validate(b">seq1\nac\ngt\n") == true
        @test validate(b">seq1\r\nacgt\r\n") == true
        @test validate(b">seq1\nac\n>seq2\ngt\n") == true
        @test validate(b"a") == false
        @test validate(b">") == false
        @test validate(b">seq1\na") == false
        @test validate(b">seq1\nac\ngt") == false
    end
end

end

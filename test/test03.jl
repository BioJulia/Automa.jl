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

    for generator in (:table, :goto), checkbounds in (true, false), clean in (true, false)
        # Test the default CTX, if none is passed.
        # We use the otherwise invalid combinarion :goto && checkbounds to do this
        (init_code, exec_code) = if generator == :goto && checkbounds
            (Automa.generate_init_code(machine), Automa.generate_exec_code(machine))
        else
            ctx = Automa.CodeGenContext(generator=generator, checkbounds=checkbounds, clean=clean)
            (Automa.generate_init_code(ctx, machine), Automa.generate_exec_code(ctx, machine))
        end
        validate = @eval function (data)
            $(init_code)
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

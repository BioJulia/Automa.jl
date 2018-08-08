module Test05

import Automa
import Automa.RegExp: @re_str
using Test

@testset "Test05" begin
    re = Automa.RegExp

    keyword = re"if|else|end|while"
    ident = re.diff(re"[a-z]+", keyword)
    token = re.alt(keyword, ident)

    keyword.actions[:exit] = [:keyword]
    ident.actions[:exit] = [:ident]

    machine = Automa.compile(token)

    for generator in (:table, :inline, :goto), checkbounds in (true, false), clean in (true, false)
        ctx = Automa.CodeGenContext(generator=generator, checkbounds=checkbounds, clean=clean)
        init_code = Automa.generate_init_code(ctx, machine)
        exec_code = Automa.generate_exec_code(ctx, machine, :debug)
        validate = @eval function (data)
            logger = Symbol[]
            $(init_code)
            p_end = p_eof = lastindex(data)
            $(exec_code)
            return cs == 0, logger
        end
        @test validate(b"if") == (true, [:keyword])
        @test validate(b"else") == (true, [:keyword])
        @test validate(b"end") == (true, [:keyword])
        @test validate(b"while") == (true, [:keyword])
        @test validate(b"e") == (true, [:ident])
        @test validate(b"eif") == (true, [:ident])
        @test validate(b"i") == (true, [:ident])
        @test validate(b"iff") == (true, [:ident])
        @test validate(b"1if") == (false, [])
    end
end

end

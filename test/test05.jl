module Test05

using Automa
using Test

@testset "Test05" begin
    re = Automa.RegExp

    keyword = re"if|else|end|while"
    ident = re.diff(re"[a-z]+", keyword)
    token = re.alt(keyword, ident)

    onexit!(keyword, :keyword)
    onexit!(ident, :ident)

    machine = Automa.compile(token)

    for generator in (:table, :goto), clean in (true, false)
        ctx = Automa.CodeGenContext(generator=generator, clean=clean)
        code = Automa.generate_code(ctx, machine, :debug)
        validate = @eval function (data)
            logger = Symbol[]
            $(code)
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

module Test02

using Automa
using Test

@testset "Test02" begin
    re = Automa.RegExp

    a = re.rep('a')
    b = re.cat('b', re.rep('b'))
    ab = re.cat(a, b)

    onenter!(a, :enter_a)
    onexit!(a, :exit_a)
    onfinal!(a, :final_a)
    onenter!(b, :enter_b)
    onexit!(b, :exit_b)
    onfinal!(b, :final_b)
    onenter!(ab, :enter_re)
    onexit!(ab, :exit_re)
    onfinal!(ab, :final_re)

    machine = Automa.compile(ab)

    last, actions = Automa.execute(machine, "ab")
    @test last == 0
    @test actions == [:enter_re,:enter_a,:final_a,:exit_a,:enter_b,:final_b,:final_re,:exit_b,:exit_re]

    for generator in (:table, :goto), clean in (true, false)
        ctx = Automa.CodeGenContext(generator=generator, clean=clean)
        code = (Automa.generate_code(ctx, machine, :debug))
        validate = @eval function (data)
            logger = Symbol[]
            $(code)
            return cs == 0, logger
        end
        @test validate(b"b") == (true, [:enter_re,:enter_a,:exit_a,:enter_b,:final_b,:final_re,:exit_b,:exit_re])
        @test validate(b"a") == (false, [:enter_re,:enter_a,:final_a])
        @test validate(b"ab") == (true, [:enter_re,:enter_a,:final_a,:exit_a,:enter_b,:final_b,:final_re,:exit_b,:exit_re])
        @test validate(b"abb") == (true, [:enter_re,:enter_a,:final_a,:exit_a,:enter_b,:final_b,:final_re,:final_b,:final_re,:exit_b,:exit_re])
    end
end

end

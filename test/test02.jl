module Test02

using Automa
using Test

@testset "Test02" begin
    a = rep('a')
    b = 'b' * rep('b')
    ab = a * b
    abc = ab * 'c'

    onenter!(a, :enter_a)
    onexit!(a, :exit_a)
    onenter!(b, :enter_b)
    onexit!(b, :exit_b)
    onenter!(ab, :enter_ab)
    onexit!(ab, :exit_ab)
    onfinal!(abc, :final_abc)

    machine = Automa.compile(ab | abc)

    last, actions = Automa.execute(machine, "abc")
    @test last == 0
    @test actions == [:enter_ab,:enter_a,:exit_a,:enter_b,:exit_b,:exit_ab, :final_abc]

    for generator in (:table, :goto), clean in (true, false)
        ctx = Automa.CodeGenContext(generator=generator, clean=clean)
        code = (Automa.generate_code(ctx, machine, :debug))
        validate = @eval function (data)
            logger = Symbol[]
            $(code)
            return cs == 0, logger
        end
        @test validate(b"b") == (true, [:enter_ab,:enter_a,:exit_a,:enter_b,:exit_b,:exit_ab])
        @test validate(b"a") == (false, [:enter_ab,:enter_a])
        @test validate(b"ab") == (true, [:enter_ab,:enter_a,:exit_a,:enter_b,:exit_b,:exit_ab])
        @test validate(b"abb") == (true, [:enter_ab,:enter_a,:exit_a,:enter_b,:exit_b,:exit_ab])
        @test validate(b"aabc") == (true, [:enter_ab, :enter_a, :exit_a, :enter_b, :exit_b, :exit_ab, :final_abc])
    end
end

end

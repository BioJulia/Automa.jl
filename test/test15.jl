module Test15

using Automa
using Test

@testset "Test15" begin
    a = re"a+"
    onenter!(a, :enter)
    onall!(a, :all)
    onexit!(a, :exit)
    b = re"b+"
    onenter!(b, :enter)
    onall!(b, :all)
    onexit!(b, :exit)
    ab = Automa.RegExp.cat(a, b)

    machine = Automa.compile(ab)
    last, actions = Automa.execute(machine, "ab")
    @test last == 0
    @test actions == [:enter, :all, :exit, :enter, :all, :exit]

    for generator in (:table, :goto), clean in (true, false)
        ctx = Automa.CodeGenContext(generator=generator, clean=clean)
        validate = @eval function (data)
            logger = Symbol[]
            $(Automa.generate_code(ctx, machine, :debug))
            return logger, cs == 0 ? :ok : cs < 0 ? :error : :incomplete
        end
        @test validate(b"ab") == ([:enter, :all, :exit, :enter, :all, :exit], :ok)
    end
end

end

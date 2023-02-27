module Test14

using Automa
import Automa.RegExp: @re_str
const re = Automa.RegExp
using Test

@testset "Test14" begin
    a = re"a*"
    machine = Automa.compile(a)

    ctx = Automa.CodeGenContext(generator=:table)
    @eval function validate_table(data)
        $(Automa.generate_init_code(ctx, machine))
        $(Automa.generate_exec_code(ctx, machine))
        return p, cs
    end

    ctx = Automa.CodeGenContext(generator=:goto)
    @eval function validate_goto(data)
        $(Automa.generate_init_code(ctx, machine))
        $(Automa.generate_exec_code(ctx, machine))
        return p, cs
    end

    @test validate_table(b"")   == validate_goto(b"")
    @test validate_table(b"a")  == validate_goto(b"a")
    @test validate_table(b"b")  == validate_goto(b"b")
    @test validate_table(b"ab") == validate_goto(b"ab")
end

end

module TestInputError

using Automa
using Test

@testset "Input error" begin
    machine = compile(re"xyz")
    @eval function test_input_error(data)
        $(generate_code(machine))
    end

    @test_throws Exception test_input_error("a")
end

end # module

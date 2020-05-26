module Test19

import Automa
import Automa.RegExp: @re_str
const re = Automa.RegExp
using Test

@testset "Test19" begin
    # Ambiguous exit statement
    A = re"XY"
    B = re"XZ"
    A.actions[:enter] = [:enter_A]
    @test_throws ErrorException Automa.compile(A | B)

    # Ambiguous, but no action in ambiguity
    A = re"XY"
    A.actions[:exit] = [:exit_A]
    @test Automa.compile(A | B) isa Automa.Machine

    A = re"aa"
    B = re"a+"
    @test Automa.compile(A | B) isa Automa.Machine

    A.actions[:enter] = [:enter_A]
    @test_throws ErrorException Automa.compile(A | B)

    A = re"aa"
    A.actions[:exit] = [:exit_A]
    @test_throws ErrorException Automa.compile(A | B)
end

end

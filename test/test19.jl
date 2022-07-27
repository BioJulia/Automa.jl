module Test19

import Automa
import Automa.RegExp: @re_str
const re = Automa.RegExp
using Test

@testset "Test19" begin
    # Ambiguous enter statement
    A = re"XY"
    B = re"XZ"
    A.actions[:enter] = [:enter_A]
    @test_throws ErrorException Automa.compile(A | B)
    @test Automa.compile(A | B, unambiguous=false) isa Automa.Machine

    # Ambiguous, but no action in ambiguity
    A = re"XY"
    A.actions[:exit] = [:exit_A]
    @test Automa.compile(A | B) isa Automa.Machine

    A = re"aa"
    B = re"a+"
    @test Automa.compile(A | B) isa Automa.Machine

    A.actions[:enter] = [:enter_A]
    @test_throws ErrorException Automa.compile(A | B)
    @test Automa.compile(A | B, unambiguous=false) isa Automa.Machine

    A = re"aa"
    A.actions[:exit] = [:exit_A]
    @test_throws ErrorException Automa.compile(A | B)
    @test Automa.compile(A | B, unambiguous=false) isa Automa.Machine

    # Harder test case
    A = re"AAAAB"
    B = re"A+C"
    A.actions[:exit] = [:exit_A]
    B.actions[:exit] = [:exit_B]
    @test Automa.compile(A | B) isa Automa.Machine

    # Test that conflicting edges can be known to be distinct
    # with different conditions.
    A = re"XY"
    A.when = :cond
    B = re"XZ"
    A.actions[:enter] = [:enter_A]
    @test Automa.compile(A | B, unambiguous=true) isa Automa.Machine
end

end

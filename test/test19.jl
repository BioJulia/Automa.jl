module Test19

using Automa
import Automa.RegExp: @re_str
const re = Automa.RegExp
using Test

@testset "Test19" begin
    # Ambiguous enter statement
    A = re"XY"
    B = re"XZ"
    onenter!(A, :enter_A)
    @test_throws ErrorException compile(A | B)
    @test compile(A | B, unambiguous=false) isa Automa.Machine

    # Ambiguous, but no action in ambiguity
    A = re"XY"
    onexit!(A, :exit_A)
    @test compile(A | B) isa Automa.Machine

    A = re"aa"
    B = re"a+"
    @test Automa.compile(A | B) isa Automa.Machine

    onenter!(A, :enter_A)
    @test_throws ErrorException compile(A | B)
    @test compile(A | B, unambiguous=false) isa Automa.Machine

    A = re"aa"
    onexit!(A, :exit_A)
    @test_throws ErrorException compile(A | B)
    @test compile(A | B, unambiguous=false) isa Automa.Machine

    # Harder test case
    A = re"AAAAB"
    B = re"A+C"
    onexit!(A, :exit_A)
    onexit!(B, :exit_B)
    @test compile(A | B) isa Automa.Machine

    # Test that conflicting edges can be known to be distinct
    # with different conditions.
    A = re"XY"
    precond!(A, :cond)
    B = re"XZ"
    onenter!(A, :enter_A)
    @test compile(A | B, unambiguous=true) isa Automa.Machine
end

end

module Test13

using Automa
using Test

# Some cases of regex I've seen fail
@testset "Test13" begin
    for (regex, good_strings, bad_strings) in [
        (re"[AB]" & re"A", ["A"], ["B", "AA", "AB"]),
        (re"(A|B|C|D)" \ re"[A-C]", ["D"], ["AC", "A", "B", "DD"]),
        (!re"A[BC]D?E", ["ABCDE", "ABCE"], ["ABDE", "ACE", "ABE"])
    ]
        for goto in (false, true)
            @eval $(Automa.generate_validator_function(:validate, regex, goto))
            for string in good_strings
                @test validate(string) === nothing
            end
            for string in bad_strings
                @test validate(string) !== nothing
            end
        end
    end
end

end # module

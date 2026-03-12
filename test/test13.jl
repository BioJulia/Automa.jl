module Test13

using Automa
using Test

# Some cases of regex I've seen fail
@testset "Test13" begin
    for (i, (regex, good_strings, bad_strings)) in enumerate([
        (re"[AB]" & re"A", ["A"], ["B", "AA", "AB"]),
        (re"(A|B|C|D)" \ re"[A-C]", ["D"], ["AC", "A", "B", "DD"]),
        (!re"A[BC]D?E", ["ABCDE", "ABCE"], ["ABDE", "ACE", "ABE"])
    ])
        for (j, goto) in enumerate((false, true))
            fname = Symbol(:validate_, i, '_', j)
            @eval $(Automa.generate_buffer_validator(fname, regex; goto=goto, docstring=false))
            f = @eval $fname
            for string in good_strings
                @test f(string) === nothing
            end
            for string in bad_strings
                @test f(string) !== nothing
            end
        end
    end
end

end # module

module Test18

using Automa
using Automa.RegExp: @re_str
using Test

@testset "Test18" begin
    regex = re"\0\a\b\t\n\v\r\x00\xff\xFF[\\][^\\]"
    for (i, goto) in enumerate((false, true))
        fname = Symbol(:validate_, i)
        @eval $(Automa.generate_buffer_validator(fname, regex; goto=goto, docstring=false))
        f = @eval $fname

        # Bad input types
        @test_throws Exception f(18)
        @test_throws Exception f('a')
        @test_throws Exception f(0x01:0x02)

        @test f(b"\0\a\b\t\n\v\r\x00\xff\xFF\\!") === nothing
        bad_input = b"\0\a\b\t\n\v\r\x00\xff\xFF\\\\\\"
        @test f(bad_input) == lastindex(bad_input)
        bad_input = b"\0\a\b\t\n\v\r\x00\xff\xFF\\"
        @test f(bad_input) == 0
    end
end

end

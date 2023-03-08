module Validator

using Automa
using TranscodingStreams: NoopStream
using Test

@testset "Validator" begin
    regex = re"a(bc)*|(def)|x+" | re"def" | re"x+"
    eval(Automa.generate_buffer_validator(:foobar, regex, false))
    eval(Automa.generate_buffer_validator(:barfoo, regex, true))

    eval(Automa.generate_io_validator(:io_bar, regex; goto=false))
    eval(Automa.generate_io_validator(:io_foo, regex; goto=true))

    for good_data in [
        "def"
        "abc"
        "abcbcbcbcbc"
        "x"
        "xxxxxx"
    ]
        @test foobar(good_data) ===
            barfoo(good_data) ===
            io_foo(IOBuffer(good_data)) ===
            io_bar(IOBuffer(good_data)) ===
            io_bar(NoopStream(IOBuffer(good_data))) ===
            nothing
    end

    for bad_data in [
        "",
        "abcabc",
        "abcbb",
        "abcbcb",
        "defdef",
        "xabc"
    ]
        @test foobar(bad_data) ===
            barfoo(bad_data) !==
            nothing

        @test io_foo(IOBuffer(bad_data)) ==
            io_bar(IOBuffer(bad_data)) ==
            io_bar(NoopStream(IOBuffer(bad_data))) !=
            nothing
    end
end

@testset "Multiline validator" begin
    regex = re"(>[a-z]+\n)+"
    eval(Automa.generate_io_validator(:io_bar_2, regex; goto=false))
    eval(Automa.generate_io_validator(:io_foo_2, regex; goto=true))

    let data = ">abc"
        @test io_bar_2(IOBuffer(data)) == io_foo_2(IOBuffer(data)) == (nothing, (1, 4))
    end

    let data = ">abc:a"
        @test io_bar_2(IOBuffer(data)) == io_foo_2(IOBuffer(data)) == (UInt8(':'), (1, 5))
    end

    let data = ">"
        @test io_bar_2(IOBuffer(data)) == io_foo_2(IOBuffer(data)) == (nothing, (1, 1))
    end

    let data = ""
        @test io_bar_2(IOBuffer(data)) == io_foo_2(IOBuffer(data)) == (nothing, (1, 0))
    end

    let data = ">abc\n>def\n>ghi\n>j!"
        @test io_bar_2(IOBuffer(data)) == io_foo_2(IOBuffer(data)) == (UInt8('!'), (4, 3))
    end

    let data = ">abc\n;"
        @test io_bar_2(IOBuffer(data)) == io_foo_2(IOBuffer(data)) == (UInt8(';'), (2, 1))
    end 
end

@testset "Reported column" begin
    regex = re"([a-z][a-z]+)(\n[a-z][a-z]+)*"
    eval(Automa.generate_io_validator(:io_foo_3, regex; goto=false))

    function test_reported_pos(data)
        # Test with a small buffer size
        io = NoopStream(IOBuffer(data); bufsize=8)
        y = io_foo_3(io)
        y === nothing ? nothing : last(y)
    end

    for (data, result) in [
        ("abcd", nothing),
        ('a'^10 * '!', (1, 11)),
        ('a'^10 * "\nabc!", (2, 4)),
        ("abcdef\n\n", (3, 0)),
        ('a'^8 * '!', (1, 9)),
        ('a'^8 * "\n" * 'a'^20 * '!', (2, 21)),
        ('a'^7 * '!', (1, 8)),
        ('a'^8, nothing),
        ("abc!", (1, 4)),
        ("", (1, 0)),
        ("a", (1, 1)),
        ("ab\na", (2, 1)),
        ("ab\naa\n\n", (4, 0))
    ]
        @test test_reported_pos(data) == result
    end
end

end # module
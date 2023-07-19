module TestByteSet

using Automa: Automa, ByteSet
using Test


function test_membership(members)
    bs = ByteSet(members)
    refset = Set{UInt8}([UInt8(i) for i in  members])
    @test refset == Set{UInt8}(collect(bs))
    @test all(i -> in(i, bs), refset)
end

function test_inversion(bs)
    inv = ~bs
    all = true
    for i in 0x00:0xff
        all &= (in(i, bs) ⊻ in(i, inv))
    end
    @test all
end

@testset "Instantiation" begin
    @test isempty(ByteSet())
    @test iszero(length(ByteSet()))

    for set in ["hello", "kdjy82zxxcbnpw", [0x00, 0x1a, 0xff, 0xf8, 0xd2]]
        test_membership(set)
    end
end

@testset "Min/max" begin
    @test_throws ArgumentError maximum(ByteSet())
    @test_throws ArgumentError minimum(ByteSet())
    @test minimum(ByteSet("xylophone")) == UInt8('e')
    @test maximum(ByteSet([0xa1, 0x0f, 0x4e, 0xf1, 0x40, 0x39])) == 0xf1
end

@testset "Contiguity" begin
    @test Automa.is_contiguous(ByteSet(0x03:0x41))
    @test Automa.is_contiguous(ByteSet())
    @test Automa.is_contiguous(ByteSet(0x51))
    @test Automa.is_contiguous(ByteSet(0xc1:0xd2))
    @test Automa.is_contiguous(ByteSet(0x00:0xff))

    @test !Automa.is_contiguous(ByteSet([0x12:0x3a; 0x3c:0x4a]))
    @test !Automa.is_contiguous(ByteSet([0x01, 0x02, 0x04, 0x05]))
end

@testset "Inversion" begin
    test_inversion(ByteSet())
    test_inversion(ByteSet(0x00:0xff))
    test_inversion(ByteSet([0x04, 0x06, 0x91, 0x92]))
    test_inversion(ByteSet(0x54:0x71))
    test_inversion(ByteSet(0x12:0x11))
    test_inversion(ByteSet("abracadabra"))
end

@testset "Set operations" begin
    sets = map(ByteSet, [
        [],
        [0x00:0xff;],
        [0x00:0x02; 0x04; 0x19],
        [0x01; 0x03; 0x09; 0xa1; 0xa1],
        [0x41:0x8f; 0xd1:0xe1; 0xa0:0xf0],
        [0x81:0x89; 0xd0:0xd0]
    ])
    ssets = map(Set, sets)
    for (s1, ss1) in zip(sets, ssets), (s2, ss2) in zip(sets, ssets)
        for f in [union, intersect, symdiff, setdiff]
            @test Set(f(s1, s2)) == f(ss1, ss2)
        end
        @test isdisjoint(s1, s2) == isdisjoint(ss1, ss2)
    end
end

end # module

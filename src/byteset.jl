struct ByteSet <: AbstractSet{UInt8}
    data::NTuple{4, UInt64}
    ByteSet(x::NTuple{4, UInt64}) = new(x)
end

ByteSet() = ByteSet((UInt64(0), UInt64(0), UInt64(0), UInt64(0)))
Base.length(s::ByteSet) = mapreduce(count_ones, +, s.data)
Base.isempty(s::ByteSet) = s === ByteSet()

function ByteSet(it)
    a = b = c = d = UInt64(0)
    for i in it
        vi = convert(UInt8, i)
        if vi < 0x40
            a |= UInt(1) << ((vi - 0x00) & 0x3f)
        elseif vi < 0x80
            b |= UInt(1) << ((vi - 0x40) & 0x3f)
        elseif vi < 0xc0
            c |= UInt(1) << ((vi - 0x80) & 0x3f)
        else
            d |= UInt(1) << ((vi - 0xc0) & 0x3f)
        end
    end
    ByteSet((a, b, c, d))
end

function Base.minimum(s::ByteSet)
    y = iterate(s)
    y === nothing ? Base._empty_reduce_error() : first(y)
end

function Base.maximum(s::ByteSet)
    offset = 0x03 * UInt8(64)
    for i in 0:3
        @inbounds bits = s.data[4 - i]
        iszero(bits) && continue
        return ((3-i)*64 + (64 - leading_zeros(bits)) - 1) % UInt8
    end
    Base._empty_reduce_error()
end

function Base.in(byte::UInt8, s::ByteSet)
    i, o = divrem(byte, UInt8(64))
    @inbounds !(iszero(s.data[i & 0x03 + 0x01] >>> (o & 0x3f) & UInt(1)))
end

@inline function Base.iterate(s::ByteSet, state=UInt(0))
    ioffset, offset = divrem(state, UInt(64))
    n = UInt(0)
    while iszero(n)
        ioffset > 3 && return nothing
        n = s.data[ioffset + 1] >>> offset
        offset *= !iszero(n)
        ioffset += 1
    end
    tz = trailing_zeros(n)
    result = (64 * (ioffset - 1) + offset + tz) % UInt8
    (result, UInt(result) + UInt(1))
end

function Base.:~(s::ByteSet)
    a, b, c, d = s.data
    ByteSet((~a, ~b, ~c, ~d))
end

is_contiguous(s::ByteSet) = isempty(s) || (maximum(s) - minimum(s) + 1 == length(s))

Base.union(a::ByteSet, b::ByteSet) = ByteSet(map(|, a.data, b.data))
Base.intersect(a::ByteSet, b::ByteSet) = ByteSet(map(&, a.data, b.data))
Base.symdiff(a::ByteSet, b::ByteSet) = ByteSet(map(⊻, a.data, b.data))
Base.setdiff(a::ByteSet, b::ByteSet) = ByteSet(map((i,j) -> i & ~j, a.data, b.data))
Base.isdisjoint(a::ByteSet, b::ByteSet) = isempty(intersect(a, b))

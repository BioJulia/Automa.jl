# Byte Set
# ========

immutable ByteSet
    a::UInt64
    b::UInt64
    c::UInt64
    d::UInt64
end

function ByteSet(bytes::Union{AbstractVector{UInt8},Set{UInt8}})
    a = b = c = d = UInt64(0)
    for byte in bytes
        if byte < 0x40
            a |= UInt64(1) << (byte - 0x00)
        elseif byte < 0x80
            b |= UInt64(1) << (byte - 0x40)
        elseif byte < 0xc0
            c |= UInt64(1) << (byte - 0x80)
        else
            d |= UInt64(1) << (byte - 0xc0)
        end
    end
    return ByteSet(a, b, c, d)
end

function Base.in(byte::UInt8, set::ByteSet)
    if byte < 0x40
        return set.a & (UInt64(1) << (byte - 0x00)) != 0
    elseif byte < 0x80
        return set.b & (UInt64(1) << (byte - 0x40)) != 0
    elseif byte < 0xc0
        return set.c & (UInt64(1) << (byte - 0x80)) != 0
    else
        return set.d & (UInt64(1) << (byte - 0xc0)) != 0
    end
end

Base.eltype(::Type{ByteSet}) = UInt8

function Base.show(io::IO, set::ByteSet)
    print(io, summary(set), "([", join(repr.(collect(set)), ','), "])")
end

function Base.length(set::ByteSet)
    return count_ones(set.a) + count_ones(set.b) + count_ones(set.c) + count_ones(set.d)
end

function Base.start(set::ByteSet)
    return set.a, set.b, set.c, set.d
end

function Base.done(::ByteSet, abcd)
    a, b, c, d = abcd
    return a == 0 && b == 0 && c == 0 && d == 0
end

function Base.next(::ByteSet, abcd)
    a, b, c, d = abcd
    if a != 0
        byte = UInt8(trailing_zeros(a))
        a = xor(a, UInt64(1) << byte)
        byte += 0x00
    elseif b != 0
        byte = UInt8(trailing_zeros(b))
        b = xor(b, UInt64(1) << byte)
        byte += 0x40
    elseif c != 0
        byte = UInt8(trailing_zeros(c))
        c = xor(c, UInt64(1) << byte)
        byte += 0x80
    else
        byte = UInt8(trailing_zeros(d))
        d = xor(d, UInt64(1) << byte)
        byte += 0xc0
    end
    return byte, (a, b, c, d)
end

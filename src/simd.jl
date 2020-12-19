const v256 = Vec{32, UInt8}
const v128 = Vec{16, UInt8}
const BVec = Union{v128, v256}
const _ZERO_v256 = v256(ntuple(i -> VecElement{UInt8}(0x00), 32))

# Discover if the system CPU has SSSE or AVX2 instruction sets
let
    llvmpaths = filter(lib -> occursin(r"LLVM\b", basename(lib)), Libdl.dllist())
    if length(llvmpaths) != 1
        throw(ArgumentError("Found multiple LLVM libraries"))
    end
    libllvm = Libdl.dlopen(llvmpaths[1])
    gethostcpufeatures = Libdl.dlsym(libllvm, :LLVMGetHostCPUFeatures)
    features_cstring = ccall(gethostcpufeatures, Cstring, ())
    features = split(unsafe_string(features_cstring), ',')
    Libc.free(features_cstring)
    # Need both SSE2 and SSSE3
    @eval const SSSE3 = $(any(isequal("+ssse3"), features) & any(isequal("+sse2"), features))
    @eval const AVX2 = $(any(isequal("+avx2"), features))
    @eval const DEFVEC = AVX2 ? v256 : v128
end

"""
    vpcmpeqb(a::BVec, b::BVec) -> BVec

Compare vectors `a` and `b` element wise and return a vector with `0x00`
where elements are not equal, and `0xff` where they are. Maps to the `vpcmpeqb`
AVX2 CPU instruction, or the `pcmpeqb` SSE2 instruction.
"""
function vpcmpeqb end

"""
    vpshufb(a::BVec, b::BVec) -> BVec

Maps to the AVX2 `vpshufb` instruction or the SSSE3 `pshufb` instruction depending
on the width of the BVec.
"""
function vpshufb end

"""
    vec_uge(a::BVec, b::BVec) -> BVec

Compare vectors `a` and `b` element wise and return a vector with `0xff`
where `a[i] ≥ b[i]``, and `0x00` otherwise. Implemented efficiently for CPUs
with the `vpcmpeqb` and `vpmaxub` instructions.

See also: [`vpcmpeqb`](@ref)
"""
function vec_uge end

let
    # icmp eq instruction yields bool (i1) values. We extend with sext to 0x00/0xff.
    # since that's the native output of vcmpeqb instruction, LLVM will optimize it
    # to just that.
    vpcmpeqb_template = """%res = icmp eq <N x i8> %0, %1
    %resb = sext <N x i1> %res to <N x i8>
    ret <N x i8> %resb
    """

    uge_template = """%res = icmp uge <N x i8> %0, %1
    %resb = sext <N x i1> %res to <N x i8>
    ret <N x i8> %resb
    """

    for N in (16, 32)
        T = NTuple{N, VecElement{UInt8}}
        ST = Vec{N, UInt8}
        instruction_set = N == 16 ? "ssse3" : "avx2"
        instruction_tail = N == 16 ? ".128" : ""
        intrinsic = "llvm.x86.$(instruction_set).pshuf.b$(instruction_tail)"
        vpcmpeqb_code = replace(vpcmpeqb_template, "<N x" => "<$(sizeof(T)) x")

        @eval @inline function vpcmpeqb(a::$ST, b::$ST)
            $(ST)(Base.llvmcall($vpcmpeqb_code, $T, Tuple{$T, $T}, a.data, b.data))
        end

        @eval @inline function vpshufb(a::$ST, b::$ST)
            $(ST)(ccall($intrinsic, llvmcall, $T, ($T, $T), a.data, b.data))
        end

        @eval const $(Symbol("_SHIFT", string(8N))) = $(ST)(ntuple(i -> 0x01 << ((i-1)%8), $N))
        @eval @inline bitshift_ones(shift::$ST) = vpshufb($(Symbol("_SHIFT", string(8N))), shift)

        uge_code = replace(uge_template, "<N x" => "<$(sizeof(T)) x")
        @eval @inline function vec_uge(a::$ST, b::$ST)
            $(ST)(Base.llvmcall($uge_code, $T, Tuple{$T, $T}, a.data, b.data))
        end
    end
end

# This assembly is quite roundabout, but somehow a direct icmp of a 256-bit
# vector bitcast to i256 to 0 compiles inefficiently when put within a loop.
# Maybe change this in the future if LLVM starts behaving itself.
@inline @generated function haszerolayout(v::BVec)
    W = sizeof(v)
    str = """%integers = bitcast <$W x i8> %0 to <2 x i$(4W)>
    %extract0 = extractelement <2 x i$(4W)> %integers, i32 0
    %extract1 = extractelement <2 x i$(4W)> %integers, i32 1
    %orres = or i$(4W) %extract0, %extract1
    %comparison = icmp eq i$(4W) %orres, 0
    %bool = zext i1 %comparison to i8
    ret i8 %bool"""
    Expr(:block, Expr(:meta,:inline), Expr(:call, :(Base.llvmcall), str, :Bool,
        :(Tuple{NTuple{$W,Core.VecElement{UInt8}}}), :(v.data)))
end

@inline function leading_zero_bytes(v::v256)
    eqzero = vpcmpeqb(v, _ZERO_v256).data
    packed = ccall("llvm.x86.avx2.pmovmskb", llvmcall, UInt32, (NTuple{32, VecElement{UInt8}},), eqzero)
    @static if ENDIAN_BOM == 0x04030201
        return trailing_ones(packed)
    else
        return leading_ones(packed)
    end
end

# vpmovmskb requires AVX2, so we fall back to this.
@inline function leading_zero_bytes(v::v128)
    n = 0
    @inbounds for i in v.data
        iszero(i.value) || break
        n += 1
    end
    return n
end

@inline function loadvector(::Type{T}, p::Ptr) where {T <: BVec}
    unsafe_load(Ptr{T}(p))
end

# We have this to keep the same constant mask in memory.
@inline shrl4(x) = x >>> 0x04

Base.:~(x::ByteSet) = ByteSet(~x.a, ~x.b, ~x.c, ~x.d)
iscontiguous(x::ByteSet) = maximum(x) - minimum(x) == length(x) - 1

@inline function zerovec_generic(x::T, topzero::T, topone::T) where {T <: BVec}
    lower = vpshufb(topzero, x)
    upper = vpshufb(topone, x ⊻ 0b10000000)
    bitmap = lower | upper
    return bitmap & bitshift_ones(shrl4(x))
end

# If all values are within 128 of each other. We set offset to downshift values
# to 0x00:0x7f. If invert is set, this yields a vector of zeros if none of the inputs
# are within the shifted 0x00:0x7f range.
# If not inverted, all inputs with top bit will be set to 0x00, and then inv'd to 0xff.
# This will cause all shifts to fail.
# If inverted and ascii, we set offset to 0x80
@inline function zerovec_128(x::T, lut::T, offset::UInt8, f::Function) where {T <: BVec}
    y = x - offset
    bitmap = f(vpshufb(lut, y))
    return bitmap & bitshift_ones(shrl4(y))
end

@inline function zerovec_8elem(x::T, lut1::T, lut2::T) where {T <: BVec}
    # Get a 8-bit bitarray of the possible ones
    mask = vpshufb(lut1, x & 0b00001111)
    shifted = vpshufb(lut2, shrl4(x))
    return vpcmpeqb(shifted, mask & shifted)
end

# Here's one where they're 16 apart at most.
@inline function zerovec_16(x::T, lut::T, offset::UInt8) where {T <: BVec}
    y = x - offset
    lower = vpshufb(lut, y & 0b00001111)
    return lower | (y & 0b11110000) 
end

# One where it's a single range. After subtracting low, all values below end
# up above due to overflow and we can simply do a single ge check
@inline function zerovec_range(x::BVec, low::UInt8, len::UInt8)
    vec_uge((x - low), typeof(x)(len))
end

# One where, in all the disallowed values, the lower nibble is unique.
# This one is surprisingly common and very efficient.
# If all 0x80:0xff are allowed, the mask can be 0xff, and is compiled away
@inline function zerovec_inv_nibble(x::T, lut::T, mask::UInt8) where {T <: BVec}
    # If upper bit is set, vpshufb yields 0x00. 0x00 is not equal to any bytes with the
    # upper biset set, so the comparison will return 0x00, allowing it.
    return vpcmpeqb(x, vpshufb(lut, x & mask))
end


# Same as above, but inverted. Even better!
@inline function zerovec_nibble(x::T, lut::T, mask::UInt8) where {T <: BVec}
    return x ⊻ vpshufb(lut, x & mask)
end

# Simplest of all!
@inline zerovec_not(x::BVec, y::UInt8) = vpcmpeqb(x, typeof(x)(y))
@inline zerovec_same(x::BVec, y::UInt8) = x ⊻ y

function load_lut(::Type{T}, v::Vector{UInt8}) where {T <: BVec}
    T === v256 && (v = repeat(v, 2))
    return unsafe_load(Ptr{T}(pointer(v)))
end  

function generic_luts(::Type{T}, byteset::ByteSet, offset::UInt8, invert::Bool) where {
    T <: BVec}
    # If ascii, we set each allowed bit, but invert after vpshufb. Hence, if top bit
    # is set, it returns 0x00 and is inverted to 0xff, guaranteeing failure
    topzero = fill(invert ? 0xff : 0x00, 16)
    topone = copy(topzero)
    for byte in byteset
        byte -= offset
        # Lower 4 bits is used in vpshufb, so it's the index into the LUT
        index = (byte & 0x0f) + 0x01
        # Upper bit sets which of the two bitmaps we use.
        bitmap = (byte & 0x80) == 0x80 ? topone : topzero
        # Bits 5,6,7 from lowest control the shift. If, after a shift, the bit
        # aligns with a zero, it's in the bitmask
        shift = (byte >> 0x04) & 0x07
        bitmap[index] ⊻= 0x01 << shift
    end
    return load_lut(T, topzero), load_lut(T, topone)
end

function elem8_luts(::Type{T}, byteset::ByteSet) where {T <: BVec}
    allowed_mask = fill(0xff, 16)
    bitindices = fill(0x00, 16)
    for (i, byte) in enumerate(byteset)
        bitindex = 0x01 << (i - 1)
        allowed_mask[(byte & 0x0f) + 0x01] ⊻= bitindex
        bitindices[(byte >>> 0x04) + 0x01] ⊻= bitindex
    end
    return load_lut(T, allowed_mask), load_lut(T, bitindices)
end

function within16_lut(::Type{T}, byteset::ByteSet) where {T <: BVec}
    offset = minimum(byteset)
    lut = fill(0x01, 16)
    for byte in byteset
        lut[(byte - offset) + 1] = 0x00
    end
    return load_lut(T, lut)
end

function unique_lut(::Type{T}, byteset::ByteSet, invert::Bool) where {T <: BVec}
    # The default, unset value of the vector v must be one where v[x & 0x0f + 1] ⊻ x
    # is never accidentally zero.
    allowed = collect(0x01:0x10)
    for byte in (invert ? ~byteset : byteset)
        allowed[(byte & 0b00001111) + 1] = byte
    end
    return load_lut(T, allowed)
end 

########## Testing code below
function gen_zero_generic(::Type{T}, sym::Symbol, x::ByteSet) where {T <: BVec}
    lut1, lut2 = generic_luts(T, x, 0x00, true)
    return :(Automa.zerovec_generic($sym, $lut1, $lut2))
end

function gen_zero_8elem(::Type{T}, sym::Symbol, x::ByteSet) where {T <: BVec}
    lut1, lut2 = elem8_luts(T, x)
    return :(Automa.zerovec_8elem($sym, $lut1, $lut2))
end

function gen_zero_128(::Type{T}, sym::Symbol, x::ByteSet, ascii::Bool, inverted::Bool) where {T <: BVec}
    if ascii && !inverted
        offset, f, invert = 0x00, ~, false
    elseif ascii && inverted
        offset, f, invert = 0x80, ~, false
    elseif !ascii && !inverted
        offset, f, invert = minimum(x), ~, false
    else
        offset, f, invert = minimum(~x), identity, true
    end
    lut = generic_luts(T, x, offset, invert)[1]
    return :(Automa.zerovec_128($sym, $lut, $offset, $f))
end

function gen_zero_16(::Type{T}, sym::Symbol, x::ByteSet) where {T <: BVec}
    lut = within16_lut(T, x)
    return :(Automa.zerovec_16($sym, $lut, $(minimum(x))))
end

function gen_zero_range(::Type{T}, sym::Symbol, x::ByteSet) where {T <: BVec}
    return :(Automa.zerovec_range($sym, $(minimum(x)), $(UInt8(length(x)))))
end

function gen_zero_inv_range(::Type{T}, sym::Symbol, x::ByteSet) where {T <: BVec}
    # An inverted range is the same as a shifted range, because UInt8 arithmetic
    # is circular. So we can simply adjust the shift, and return regular vec_range
    return :(Automa.zerovec_range($sym, $(maximum(~x) + 0x01), $(UInt8(length(x)))))
end

function gen_zero_nibble(::Type{T}, sym::Symbol, x::ByteSet, invert::Bool) where {T <: BVec}
    lut = unique_lut(T, x, invert)
    mask = maximum(invert ? ~x : x) > 0x7f ? 0x0f : 0xff
    if invert
        return :(Automa.zerovec_inv_nibble($sym, $lut, $mask))
    else
        return :(Automa.zerovec_nibble($sym, $lut, $mask))
    end
end

function gen_zero_same(::Type{T}, sym::Symbol, x::ByteSet) where {T <: BVec}
    return :(Automa.zerovec_same($sym, $(minimum(x))))
end

function gen_zero_not(::Type{T}, sym::Symbol, x::ByteSet) where {T <: BVec}
    :(Automa.zerovec_not($sym, $(minimum(~x))))
end

# TODO: Make something useful of this.
function gen_zero_code(::Type{T}, sym::Symbol, x::ByteSet) where {T <: BVec}
    if length(x) == 1
        expr = gen_zero_same(T, sym, x)
    elseif length(x) == 255
        return gen_zero_not(T, sym, x)
    elseif length(x) == length(Set([i & 0x0f for i in x]))
        expr = gen_zero_nibble(T, sym, x, false)
    elseif length(~x) == length(Set([i & 0x0f for i in ~x]))
        expr = gen_zero_nibble(T, sym, x, true)
    elseif iscontiguous(x)
        expr = gen_zero_range(T, sym, x)
    elseif iscontiguous(~x)
        expr = gen_zero_inv_range(T, sym, x)
    elseif maximum(x) - minimum(x) < 16
        expr = gen_zero_16(T, sym, x)
    elseif minimum(x) > 127
        expr = gen_zero_128(T, sym, x, true, true)
    elseif maximum(x) < 128
        expr = gen_zero_128(T, sym, x, true, false)
    elseif maximum(~x) - minimum(~x) < 128
        expr = gen_zero_128(T, sym, x, false, true)
    elseif maximum(x) - minimum(x) < 128
        expr = gen_zero_128(T, sym, x, false, false)
    elseif length(x) < 9
        expr = gen_zero_8elem(T, sym, x)
    else
        expr = gen_zero_generic(T, sym, x)
    end
    return expr
end

import ..NiLang: ⊕, ⊖, NEG, CONJ, ROT, IROT
@i function ⊖(a!::GVar, b::GVar)
    val(a!) ⊖ val(b)
    grad(b) ⊕ grad(a!)
end

@i function NEG(a!::GVar)
    NEG(val(a!))
    NEG(grad(a!))
end

@i function CONJ(a!::GVar)
    CONJ(val(a!))
    CONJ(grad(a!))
end

@i function ⊖(*)(out!::GVar, x::GVar, y::GVar)
    val(out!) -= val(x) * val(y)
    grad(x) += grad(out!) * val(y)'
    grad(y) += val(x)' * grad(out!)
end

@i function ⊖(/)(out!::GVar{T}, x::GVar, y::GVar) where T
    val(out!) -= val(x)/val(y)
    grad(x) += grad(out!)/val(y)
    @anc a1::T
    @anc a2::T
    a1 += val(x)*grad(out!)
    a2 += val(a1)/val(y)
    grad(y) -= a2/val(y)
    a2 -= val(a1)/val(y)
    a1 -= val(x)*grad(out!)
end

@i function IROT(a::GVar, b::GVar, θ::GVar)
    IROT(val(a), val(b), val(θ))
    NEG(val(θ))
    val(θ) ⊖ π/2
    ROT(grad(a), grad(b), val(θ))
    grad(θ) += val(a) * grad(a)
    grad(θ) += val(b) * grad(b)
    val(θ) ⊕ π/2
    NEG(val(θ))
    ROT(grad(a), grad(b), π/2)
end
#=
macro nograd(ex)
    @match ex begin
        :($f($(args...))) => :(
            @i function $f($(_render_type.(args)...))
            end
        )
    end
end

function _render_type(ex)
    @match ex begin
        :($x::$tp) => :($x::GVar{$tp})
        :($x) => :($x::GVar)
        _=>error("expect argument like `x::T` or `x`, got $ex")
    end
end

@nograd XOR(a!, b)
@nograd SWAP(a!, b!)
=#
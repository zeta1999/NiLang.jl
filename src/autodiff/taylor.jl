export HessianData, taylor_hessian, local_hessian

struct HessianData{T}
    x::T
    gradient::AbstractVector{T}
    hessian::AbstractArray{T}
    index::Int
end

size_paramspace(hd::HessianData) = length(hd.gradient)
NiLang.AD.grad(hd::HessianData) = hd.gradient[hd.index]
NiLang.value(hd::HessianData) = hd.x
function NiLang.chfield(hd::HessianData, ::typeof(value), val)
    chfield(hd, Val(:x), val)
end
function NiLang.chfield(hd::HessianData, ::typeof(grad), val)
    hd.gradient[hd.index] = val
    hd
end

# dL^2/dx/dy = ∑(dL^2/da/db)*da/dx*db/dy
# https://arxiv.org/abs/1206.6464
@i function ⊖(*)(out!::HessianData, x::HessianData, y::HessianData)
    @anc hdata = out!.hessian
    ⊖(*)(out!.x, x.x, y.x)
    # hessian from hessian
    for i=1:size_paramspace(out!)
        hdata[x.index, i] += y.x * hdata[out!.index, i]
        hdata[y.index, i] += x.x * hdata[out!.index, i]
    end
    for i=1:size_paramspace(out!)
        hdata[i, x.index] += y.x * hdata[i, out!.index]
        hdata[i, y.index] += x.x * hdata[i, out!.index]
    end

    # hessian from jacobian
    hdata[x.index, y.index] ⊕ grad(out!)
    hdata[y.index, x.index] ⊕ grad(out!)

    # update gradients
    grad(x) += grad(out!) * value(y)
    grad(y) += value(x) * grad(out!)
end

@i function NEG(x!::HessianData)
    @anc hdata = x!.hessian
    NEG(x!.x)
    # hessian from hessian
    for i=1:size_paramspace(x!)
        NEG(hdata[x!.index, i])
        NEG(hdata[i, x!.index])
    end

    # update gradients
    NEG(grad(x!))
end

@i function CONJ(x!::HessianData)
    @anc hdata = x!.hessian
    CONJ(x!.x)
    # hessian from hessian
    for i=1:size_paramspace(x!)
        CONJ(hdata[x!.index, i])
        CONJ(hdata[i, x!.index])
    end

    # update gradients
    CONJ(grad(x!))
end

@i function ⊖(identity)(out!::HessianData, x::HessianData)
    @anc hdata = out!.hessian
    ⊖(identity)(out!.x, x.x)
    # hessian from hessian
    for i=1:size_paramspace(out!)
        hdata[x.index, i] ⊕ hdata[out!.index, i]
    end
    for i=1:size_paramspace(out!)
        hdata[i, x.index] ⊕ hdata[i, out!.index]
    end

    # update gradients
    grad(x) ⊕ grad(out!)
end

@i function SWAP(x!::HessianData, y!::HessianData)
    @anc hdata = x!.hessian
    SWAP(x!.x, y!.x)
    # hessian from hessian
    for i=1:size_paramspace(x!)
        SWAP(hdata[x!.index, i], hdata[y!.index, i])
    end
    for i=1:size_paramspace(x!)
        SWAP(hdata[i, x!.index], hdata[i, y!.index])
    end

    # update gradients
    SWAP(grad(x!), grad(y!))
end

@i function ⊖(/)(out!::HessianData{T}, x::HessianData{T}, y::HessianData{T}) where T
    ⊖(/)(out!.x, x.x, y.x)
    @anc hdata = out!.hessian
    @anc binv = zero(T)
    @anc binv2 = zero(T)
    @anc binv3 = zero(T)
    @anc a3 = zero(T)
    @anc xjac = zero(T)
    @anc yjac = zero(T)
    @anc yyjac = zero(T)
    @anc xyjac = zero(T)

    @routine jacs begin
        # compute dout/dx and dout/dy
        xjac += 1.0/value(y)
        binv2 += xjac^2
        binv3 += xjac^3
        yjac -= value(x)*binv2
        a3 += value(x)*binv3
        yyjac += 2*a3
        xyjac ⊖ binv2
    end
    # hessian from hessian
    for i=1:size_paramspace(out!)
        hdata[x.index, i] += xjac * hdata[out!.index, i]
        hdata[y.index, i] += yjac * hdata[out!.index, i]
    end
    for i=1:size_paramspace(out!)
        hdata[i, x.index] += xjac * hdata[i, out!.index]
        hdata[i, y.index] += yjac * hdata[i, out!.index]
    end

    # hessian from jacobian
    out!.hessian[y.index, y.index] += yyjac*grad(out!)
    out!.hessian[x.index, y.index] += xyjac*grad(out!)
    out!.hessian[y.index, x.index] += xyjac*grad(out!)

    # update gradients
    grad(x) += grad(out!) * xjac
    grad(y) += yjac * grad(out!)

    ~@routine jacs
end

@i function ⊖(^)(out!::HessianData{T}, x::HessianData{T}, n::HessianData{T}) where T
    ⊖(^)(out!.x, x.x, n.x)
    @anc hdata = out!.hessian
    @anc logx = zero(T)
    @anc logx2 = zero(T)
    @anc powerxn = zero(T)
    @anc anc1 = zero(T)
    @anc anc2 = zero(T)
    @anc xjac = zero(T)
    @anc njac = zero(T)
    @anc hxn = zero(T)
    @anc hxx = zero(T)
    @anc hnn = zero(T)
    @anc nminus1 = zero(T)

    # compute jacobians
    @routine getjac begin
        nminus1 ⊕ n.x
        nminus1 ⊖ 1
        powerxn += x.x^n.x
        logx += log(x.x)
        out!.x ⊕ powerxn

        # dout!/dx = n*x^(n-1)
        anc1 += x^nminus1
        xjac += anc1 * value(n)
        # dout!/dn = logx*x^n
        njac += logx*powerxn

        # for hessian
        logx2 += logx^2
        anc2 += xjac/x
        hxn ⊕ anc1
        hxn += xjac * logx
        hxx += anc2 * nminus1
        hnn += logx2 * powerxn
    end

    # hessian from hessian
    for i=1:size_paramspace(out!)
        hdata[i, x.index] += hdata[i, out!.index] * xjac
        hdata[i, n.index] += hdata[i, out!.index] * njac
    end
    for i=1:size_paramspace(out!)
        hdata[x.index, i] += hdata[out!.index, i] * xjac
        hdata[n.index, i] += hdata[out!.index, i] * njac
    end

    # hessian from jacobian
    # Dnn = x^n*log(x)^2
    # Dxx = (-1 + n)*n*x^(-2 + n)
    # Dxn = Dnx = x^(-1 + n) + n*x^(-1 + n)*log(x)
    out!.hessian[x.index, x.index] += hxx * grad(out!)
    out!.hessian[n.index, n.index] += hnn * grad(out!)
    out!.hessian[x.index, n.index] += hxn * grad(out!)
    out!.hessian[n.index, x.index] += hxn * grad(out!)

    # update gradients
    grad(x) += grad(out!) * xjac
    grad(n) += grad(out!) * njac

    ~@routine getjac
end

@i function IROT(a!::HessianData{T}, b!::HessianData{T}, θ::HessianData{T}) where T
    @anc hdata = a!.hessian
    @anc s = zero(T)
    @anc c = zero(T)
    @anc ca = zero(T)
    @anc sb = zero(T)
    @anc sa = zero(T)
    @anc cb = zero(T)
    @anc θ2 = zero(T)
    IROT(value(a!), value(b!), value(θ))

    @routine temp begin
        θ2 ⊖ value(θ)
        θ2 ⊖ π/2
        s += sin(value(θ))
        c += cos(value(θ))
        ca += c * value(a!)
        sb += s * value(b!)
        sa += s * value(a!)
        cb += c * value(b!)
    end

    # update gradient, #1
    for i=1:size_paramspace(a!)
        ROT(hdata[i, a!.index], hdata[i, b!.index], θ2)
        hdata[i, θ.index] += value(a!) * hdata[i, a!.index]
        hdata[i, θ.index] += value(b!) * hdata[i, b!.index]
        ROT(hdata[i, a!.index], hdata[i, b!.index], π/2)
    end
    for i=1:size_paramspace(a!)
        ROT(hdata[a!.index, i], hdata[b!.index, i], θ2)
        hdata[θ.index, i] += value(a!) * hdata[a!.index, i]
        hdata[θ.index, i] += value(b!) * hdata[b!.index, i]
        ROT(hdata[a!.index, i], hdata[b!.index, i], π/2)
    end

    # update local hessian
    a!.hessian[a!.index, θ.index] -= s * grad(a!)
    a!.hessian[b!.index, θ.index] -= c * grad(a!)
    a!.hessian[θ.index, a!.index] -= s * grad(a!)
    a!.hessian[θ.index, b!.index] -= c * grad(a!)
    a!.hessian[θ.index, θ.index] -= ca * grad(a!)
    a!.hessian[θ.index, θ.index] += sb * grad(a!)

    a!.hessian[a!.index, θ.index] += c * grad(b!)
    a!.hessian[b!.index, θ.index] -= s * grad(b!)
    a!.hessian[θ.index, a!.index] += c * grad(b!)
    a!.hessian[θ.index, b!.index] -= s * grad(b!)
    a!.hessian[θ.index, θ.index] -= sa * grad(b!)
    a!.hessian[θ.index, θ.index] -= cb * grad(b!)

    # update gradients
    ROT(grad(a!), grad(b!), θ2)
    grad(θ) += value(a!) * grad(a!)
    grad(θ) += value(b!) * grad(b!)
    ROT(grad(a!), grad(b!), π/2)

    ~@routine temp
end

function local_hessian(f, args; kwargs=())
    nargs = length(args)
    hes = zeros(nargs,nargs,nargs)
    @instr f(args...)
    for j=1:nargs
        gdata = zeros(nargs)
        gdata[j] += 1
        hdata = zeros(nargs,nargs)
        largs = [HessianData(arg, gdata, hdata, i) for (i, arg) in enumerate(args)]
        @instr (~f)(largs...)
        hes[:,:,j] .= largs[1].hessian
    end
    hes
end

function taylor_hessian(f, args::Tuple; kwargs=Dict())
    @assert count(x -> x isa Loss, args) == 1
    N = length(args)

    iloss = 0
    for i=1:length(args)
        if tget(args,i) isa Loss
            iloss += identity(i)
        end
    end
    @instr (~Loss)(tget(args, iloss))

    @instr f(args...)
    grad = zeros(N); grad[iloss] = 1.0
    hess = zeros(N, N)
    args = [HessianData(x, grad, hess, i) for (i,x) in enumerate(args)]
    @instr (~f)(args...)
    args[1].hessian
end

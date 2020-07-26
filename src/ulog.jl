using LogarithmicNumbers
export gaussian_log, gaussian_nlog
export ULogarithmic

@i @inline function (:*=(identity))(x::T, y::T) where T<:ULogarithmic
    x.log += y.log
end

for (OP1, OP2, OP3) in [(:*, :+, :(+=)), (:/, :-, :(-=))]
	@eval @i @inline function (:*=($OP1))(out!::T, x::T, y::T) where T<:ULogarithmic
	    out!.log += $OP2(x.log, y.log)
	end

	@eval @i @inline function (:*=($OP1))(out!::T, x::Real, y::Real) where T<:ULogarithmic
	    out!.log += log(x)
		$(Expr(OP3, :(out!.log), :(log(y))))
	end

	@eval @i @inline function (:*=($OP1))(out!::T, x::T, y::Real) where T<:ULogarithmic
	    out!.log += x.log
		$(Expr(OP3, :(out!.log), :(log(y))))
	end

	@eval @i @inline function (:*=($OP1))(out!::T, x::Real, y::T) where T<:ULogarithmic
	    out!.log += log(x)
		$(Expr(OP3, :(out!.log), :(y.log)))
	end
end

gaussian_log(x) = log1p(exp(x))
gaussian_nlog(x) = log1p(-exp(x))

@i function (:*=)(+)(out!::ULogarithmic{T}, x::ULogarithmic{T}, y::ULogarithmic{T}) where {T}
	@invcheckoff if (x.log == y.log, ~)
		out!.log += x.log
		out!.log += log(2)
	elseif (x.log ≥ y.log, ~)
		out!.log += x.log
		y.log -= x.log
		out!.log += gaussian_log(y.log)
		y.log += x.log
	else
		out!.log += y.log
		x.log -= y.log
		out!.log += gaussian_log(x.log)
		x.log += y.log
	end
end

@i function (:*=)(-)(out!::ULogarithmic{T}, x::ULogarithmic{T}, y::ULogarithmic{T}) where {T}
	@safe @assert x.log ≥ y.log
	@invcheckoff if (!iszero(x), ~)
		out!.log += x.log
		y.log -= x.log
		out!.log += gaussian_nlog(y.log)
		y.log += x.log
	end
end

@i function :(*=)(convert)(out!::ULogarithmic{T}, y::ULogarithmic) where T
    out!.log += convert((@skip! T), y.log)
end

@i function :(*=)(convert)(out!::ULogarithmic{T}, y::T) where T<:Real
    out!.log += log(y)
end

Base.convert(::Type{T}, x::ULogarithmic{T}) where {T<:Fixed} = exp(x.log)

function NiLangCore.deanc(x::T, v::T) where T<:ULogarithmic
    x === v || NiLangCore.deanc(x.log, v.log)
end

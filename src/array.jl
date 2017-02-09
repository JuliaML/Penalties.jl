# PenaltyFunctions that evaluate on the entire array only
# TODO:
# - GeneralizedL1Penalty?
# - FusedL1Penalty

#------------------------------------------------------------------# abstract methods
value{T <: Number}(p::ArrayPenalty, A::AA{T}, s::T) = s * value(p, A)

prox!{T <: Number}(p::ArrayPenalty, A::AA{T}) = _prox!(p, A, p.λ)
prox!{T <: Number}(p::ArrayPenalty, A::AA{T}, s::T) = _prox!(p, A, s * p.λ)
prox{T <: Number}(p::ArrayPenalty, A::AA{T}) = prox!(p, deepcopy(A))
prox{T <: Number}(p::ArrayPenalty, A::AA{T}, s::T) = prox!(p, deepcopy(A), s)


#----------------------------------------------------------------# NuclearNormPenalty
type NuclearNormPenalty{T <: Number} <: ArrayPenalty
    λ::T
end
NuclearNormPenalty(λ::Number = 0.1) = NuclearNormPenalty(λ)

function value{T <: Number}(p::NuclearNormPenalty{T}, A::AA{T, 2})
    if size(A, 1) > size(A, 2)
        return trace(sqrtm(A'A))
    else
        return trace(sqrtm(A * A'))
    end
end

function _prox!{T <: Number}(p::NuclearNormPenalty{T}, A::AA{T, 2}, s::T)
    svdecomp = svdfact!(A)
    soft_thresh!(svdecomp.S, s)
    copy!(A, full(svdecomp))
end


#-----------------------------------------------------------------# GroupLassoPenalty
"Group Lasso Penalty.  Able to set the entire vector (group) to 0."
type GroupLassoPenalty{T <: Number} <: ArrayPenalty
    λ::T
end
GroupLassoPenalty(λ::Number = 0.1) = GroupLassoPenalty(λ)

value{T <: Number}(p::GroupLassoPenalty{T}, A::AA{T, 1}) = vecnorm(A)

function _prox!{T <: Number}(p::GroupLassoPenalty{T}, A::AA{T, 1}, s::T)
    denom = vecnorm(A)
    if denom <= s
        fill!(A, zero(T))
    else
        scaling = p.λ / denom
        for i in eachindex(A)
            @inbounds A[i] = A[i] - scaling * A[i]
        end
    end
    A
end

#-----------------------------------------------------------------# MahalanobisPenalty
"""
    MahalanobisPenalty(λ, C)

Supports a Mahalanobis distance penalty (`xᵀCᵀCx` for a vector `x`).
"""
type MahalanobisPenalty{T <: Number} <: ArrayPenalty
    λ::T
    C::AA{T,2}
    CtC::AA{T,2}
    sλ::T
    CtC_Isλ::Base.LinAlg.LU{T, Array{T,2}} # LU factorization of C'C + I/sλ
end
function MahalanobisPenalty{T}(λ::T, C::AA{T,2}, s::T=one(T))
    MahalanobisPenalty(λ, C, C'C, s*λ, lufact(C'C + I/(λ*s)))
end
function MahalanobisPenalty{T}(C::AA{T,2}, s::T=one(T))
    MahalanobisPenalty(one(T), C, C'C, s, lufact(C'C + I/s))
end

value{T <: Number}(p::MahalanobisPenalty{T}, x) = T(0.5) * p.λ * sum(abs2, p.C * x)

function _prox!{T <: Number}(p::MahalanobisPenalty{T}, A::AA{T, 1}, sλ::T)
    if sλ != p.sλ
        p.sλ = sλ
        p.CtC_Isλ = lufact(p.CtC + I/sλ)
    end

    scale!(A, 1 / sλ)
    A_ldiv_B!(p.CtC_Isλ, A) # overwrites result in A
end

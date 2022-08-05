symm(A::AbstractMatrix) = 0.5*(A + A')
symm(x::AbstractVector, n) = symm(reshape(x, n, n))
symm_row(A::AbstractMatrix, n) = hcat([vec(symm(x, n)) for x in eachrow(A)]...)'
cartesian_to_index(i, j; N) = N*(j-1)+i

aupr(p::AbstractVector, r::AbstractVector) = dot(p[1:end-1], abs.(r[2:end]-r[1:end-1]))

function prec_rec_rate(J::AbstractMatrix, Z::AbstractMatrix, q::Real; J_thresh = 0.5)
    edges_true = (abs.(J) .>= J_thresh)
    edges_infer = (Z .>= q * maximum(Z))
    tp = sum(edges_true .& edges_infer)
    fp = sum(.!edges_true .& edges_infer)
    fn = sum(edges_true .& .!edges_infer)
    return [tp/(tp+fp), tp/(tp+fn)]
end

function prec_rec_rate(J::AbstractMatrix, Z::AbstractMatrix, Nq::Integer; kwargs...)
    hcat([0, 1], [prec_rec_rate(J, Z, q; kwargs...) for q in range(0, 1; length = Nq)]...)'
end

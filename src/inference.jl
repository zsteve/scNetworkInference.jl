function get_MI_undir(X::AbstractMatrix, p::AbstractSparseVector, genes_i::Vector{Int}, genes_j::Vector{Int})
    # undirected mutual information
    @assert length(genes_i) == length(genes_j)
    mi = zeros(length(genes_i))
    for k = 1:length(genes_i)
        mi[k] = genes_i[k] == genes_j[k] ? 0 : get_mutual_information(discretized_joint_distribution_undir(p, X, genes_i[k], genes_j[k]))
    end
    mi
end

function get_MI_undir(X::AbstractMatrix, prod::AbstractSparseMatrix, genes_i::Vector{Int}, genes_j::Vector{Int})
    # undirected mutual information
    @assert length(genes_i) == length(genes_j)
    mi = zeros(length(genes_i))
    for k = 1:length(genes_i)
        mi[k] = genes_i[k] == genes_j[k] ? 0 : get_mutual_information(discretized_joint_distribution_undir(prod, X, genes_i[k], genes_j[k]))
    end
    mi
end


function get_MI(X::AbstractMatrix, coupling_fw::AbstractSparseMatrix, coupling_rev::AbstractSparseMatrix, genes_prev::Vector{Int}, genes_next::Vector{Int}; rev = false)
    @assert length(genes_prev) == length(genes_next)
    mi_fwd = zeros(length(genes_prev))
    mi_rev = zeros(length(genes_prev))
    for j = 1:length(genes_prev)
        mi_fwd[j] = get_conditional_mutual_information(discretized_joint_distribution(coupling_fw, X, X, genes_prev[j], genes_next[j]))
        if rev
            mi_rev[j] = get_conditional_mutual_information(discretized_joint_distribution(coupling_rev, X, X, genes_next[j], genes_prev[j]))
        end
    end
    mi_fwd, mi_rev
end

# implementation for timeseries (only fw)
function get_MI(X0::AbstractMatrix, X1::AbstractMatrix, coupling::AbstractSparseMatrix, genes_prev::Vector{Int}, genes_next::Vector{Int})
    @assert length(genes_prev) == length(genes_next)
    mi = zeros(length(genes_prev))
    for j = 1:length(genes_prev)
        mi[j] = get_conditional_mutual_information(discretized_joint_distribution(coupling, X0, X1, genes_prev[j], genes_next[j]))
    end
    mi
end


# implementation uses precomputed discretizations for each gene
function get_MI(X::AbstractMatrix, coupling_fw::AbstractMatrix, coupling_rev::AbstractMatrix, genes_prev::Vector{Int}, genes_next::Vector{Int}, binids_all::AbstractVector, binedges_all::AbstractVector)
    @assert length(genes_prev) == length(genes_next)
    mi_fwd = zeros(length(genes_prev))
    mi_rev = zeros(length(genes_prev))
    @inbounds for j = 1:length(genes_prev)
        mi_fwd[j] = get_conditional_mutual_information(discretized_joint_distribution(coupling_fw, 
                    binids_all[genes_prev[j]], binids_all[genes_next[j]], binids_all[genes_next[j]],
                    binedges_all[genes_prev[j]], binedges_all[genes_next[j]], binedges_all[genes_next[j]]))
        mi_rev[j] = get_conditional_mutual_information(discretized_joint_distribution(coupling_rev,
                    binids_all[genes_next[j]], binids_all[genes_prev[j]], binids_all[genes_prev[j]], 
                    binedges_all[genes_next[j]], binedges_all[genes_prev[j]], binedges_all[genes_prev[j]]))
    end
    mi_fwd, mi_rev
end

# implementation uses sampling and InformationMeasures.jl discretization.
function get_MI(X::AbstractMatrix, coupling_fw::AbstractMatrix, coupling_rev::AbstractMatrix, genes_prev::Vector{Int}, genes_next::Vector{Int}, N::Int = 1000, nbins = 5)
    # construct initial distribution at time t 
    function get_idxs(idxs::Vector{Int}, Nrow::Int)
        idxs_prev = ((idxs.-1) .% Nrow) .+ 1 # prev
        idxs_next = ((idxs.-1) .÷ Nrow) .+ 1; # next
        idxs_prev, idxs_next
    end
    @assert length(genes_prev) == length(genes_next)
    mi_fwd = zeros(length(genes_prev))
    mi_rev = zeros(length(genes_prev))
    # compute coupling 
    # idxs_fwd = rand(DiscreteNonParametric(1:length(coupling_fw), reshape(coupling_fw, :)), N);
    idxs_fwd = rand(DiscreteNonParametric(cartesian_to_index.(findnz(coupling_fw)[1:2]...; N = size(coupling_fw, 1)), findnz(coupling_fw)[3]), N);
    idxs_prev_fwd, idxs_next_fwd = get_idxs(idxs_fwd, size(coupling_fw, 1))
    idxs_rev = rand(DiscreteNonParametric(cartesian_to_index.(findnz(coupling_rev)[1:2]...; N = size(coupling_rev, 1)), findnz(coupling_rev)[3]), N);
    idxs_next_rev, idxs_prev_rev = get_idxs(idxs_rev, size(coupling_rev, 1))
    @inbounds for j = 1:length(genes_prev)
        mi_fwd[j] = get_conditional_mutual_information(X[idxs_prev_fwd, genes_prev[j]], X[idxs_next_fwd, genes_next[j]], X[idxs_prev_fwd, genes_next[j]]; mode = "uniform_width", number_of_bins = nbins)
        mi_rev[j] = get_conditional_mutual_information(X[idxs_prev_rev, genes_prev[j]], X[idxs_next_rev, genes_next[j]], X[idxs_prev_rev, genes_next[j]]; mode = "uniform_width", number_of_bins = nbins)
    end
    return mi_fwd, mi_rev
end

function CLR(x)
    [0.5*sqrt.(relu(zscore(x[i, :])[j]).^2 + relu(zscore(x[:, j])[i]).^2) for i = 1:size(x, 1), j = 1:size(x, 2)]
end

function wCLR(x)
    [0.5*sqrt.(relu(zscore(x[i, :])[j]).^2 + relu(zscore(x[:, j])[i]).^2)*x[i, j] for i = 1:size(x, 1), j = 1:size(x, 2)]
end

function compute_coupling(X::AbstractMatrix, i::Int, R::SparseMatrixCSC)
    pi = ((collect(1:size(X, 1)) .== i)'*1.0) * R 
    sparse(reshape(pi, :, 1)) .* R
end

function compute_coupling(X::AbstractMatrix, i::Int, P::SparseMatrixCSC, R::SparseMatrixCSC)
    pi = ((collect(1:size(X, 1)) .== i)'*1.0) * R 
    sparse(reshape(pi, :, 1)) .* P
end

function compute_coupling(X::AbstractMatrix, i::Int, P::SparseMatrixCSC, QT::SparseMatrixCSC, R::SparseMatrixCSC)
    # given: Q a transition matrix t -> t-1; P a transition matrix t -> t+1
    # and π a distribution at time t
    # computes coupuling on (t-1, t+1) as Q'(πP)
    pi = ((collect(1:size(X, 1)) .== i)'*1.0) * R 
    QT * (sparse(reshape(pi, :, 1)) .* P)
end

apply_clr(A, n_genes) = hcat(map(x -> vec(wCLR(reshape(x, n_genes, n_genes))), eachrow(A))...)'
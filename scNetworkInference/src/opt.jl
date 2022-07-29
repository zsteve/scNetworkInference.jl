prox_l1(x; λ = 1.0) = sign(x)*relu(abs(x) - λ)

function fitsp(G::AbstractMatrix, L::AbstractMatrix, α; ρ = 0.05, λ1 = 25.0, λ2 = 0.075, maxiter = 2500)
    # scaling factors
    L_scaled = L # sqrt.(α) * L * sqrt.(α)
    X = G;
    Z = G;
    W = zero(G);
    ΔX, ΔZ, ΔW = 0, 0, 0
    @showprogress for iter = 1:maxiter
        # X_new = ((1+ρ)I + λ1*L) \ (G - ρ*(W-Z));
        X_new = (α + λ1*L_scaled + ρ*I) \ (α*G + ρ*(Z-W)); 
        # Z_new = prox_l1.(X_new+W; λ = λ2/ρ);
        Z_new = hcat([prox_l1.(X_new[i, :]+W[i, :]; λ = λ2*diag(α)[i]/ρ) for i = 1:size(L, 1)]...)';
        W_new = W + X_new - Z_new
        ΔX, ΔZ, ΔW = norm(X-X_new, Inf), norm(Z-Z_new, Inf), norm(W-W_new, Inf)
        X = X_new; Z = Z_new; W = W_new
    end
    @info "ΔX = $(ΔX), ΔZ = $(ΔZ), ΔW = $(ΔW)"
    @info "tr(X'LX) = $(tr(X'*L_scaled*X)), 0.5|X-G|^2 = $(0.5*norm(X-G)), |X|1 = $(norm(X, 1))"
    Z
end

function fitsp(G::AbstractMatrix, L::AbstractMatrix; ρ = 0.05, λ1 = 25.0, λ2 = 0.075, maxiter = 2500)
    # scaling factors
    X = G;
    Z = G;
    W = zero(G);
    ΔX, ΔZ, ΔW = 0, 0, 0
    @showprogress for iter = 1:maxiter
        X_new = ((1+ρ)I + λ1*L) \ (G - ρ*(W-Z));
        Z_new = prox_l1.(X_new+W; λ = λ2/ρ);
        W_new = W + X_new - Z_new
        ΔX, ΔZ, ΔW = norm(X-X_new, Inf), norm(Z-Z_new, Inf), norm(W-W_new, Inf)
        X = X_new; Z = Z_new; W = W_new
    end
    @info "ΔX = $(ΔX), ΔZ = $(ΔZ), ΔW = $(ΔW)"
    @info "tr(X'LX) = $(tr(X'*L*X)), 0.5|X-G|^2 = $(0.5*norm(X-G)), |X|1 = $(norm(X, 1))"
    Z
end


function fitsp_mean(G; ρ = 0.01, λ = 0.001, maxiter = 100)
    x = zeros(size(G, 1))
    z = zeros(size(G, 1))
    w = zeros(size(G, 1))
    Δx, Δz, Δw = 0, 0, 0
    @showprogress for iter = 1:maxiter
        x_new =  (mean(G; dims = 2) + ρ*(z-w))/(1+ρ)
        z_new = prox_l1.(x_new + w; λ = λ/ρ)
        w_new = w + x_new - z_new
        Δx, Δz, Δw = norm(x-x_new, Inf), norm(z-z_new, Inf), norm(w-w_new, Inf)
        x = x_new; z = z_new; w = w_new
    end
    @info "Δx = $(Δx), Δz = $(Δz), Δw = $(Δw)"
    x
end
"""
    MultivariateNormalModel(prior)
This is the base type for the model with `MvNormal` likelihood and `NormalWishart`
prior. This is the most commonly used multivariate model.

```julia
MultivariateNormalModel(prior)          # Creates a model with a given NormalGamma prior.
MultivariateNormalModel(μ0, κ0, T0, ν0) # Creates a model with the given hyperparameters
MultivariateNormalModel(ss)             # Creates a model with prior mean and prior covariance
                                        # inferred from the data using an MvNormalStats object
                                        # and default values elsewhere.
MultivariateNormalModel(d)              # Creates a model with dimension d and default
                                        # hyperparameters (zeros(d), 1e-8, eye(d), d)
MultivariateNormalModel()               # Creates a model with dimension 2 and default
                                        # hyperparameters (zeros(2), 1e-8, eye(2), 2.0)
```
"""
struct MultivariateNormalModel <: ConjugateModel
  prior::NormalInverseWishart
end

function MultivariateNormalModel(μ0::Array{Float64,1}, κ0::Float64, T0::Array{Float64,2}, ν0::Float64)
  MultivariateNormalModel(NormalInverseWishart(μ0, κ0, T0, ν0))
end
function MultivariateNormalModel(Y::Array{Float64,2})
  ss=suffstats(MvNormal, Y)
  MultivariateNormalModel(ss)
end
function MultivariateNormalModel(ss::MvNormalStats)
  nu=Float64(length(ss.m))
  Ψ0=Symmetric(inv(ss.s2/ss.tw/nu))
  p=NormalInverseWishart(ss.m, 1e-8, cholesky(Ψ0), nu)
  MultivariateNormalModel(p)
end
function MultivariateNormalModel(d::Int64)
  p=NormalInverseWishart(zeros(d), 1e-8, eye(d), d*1.0)
  MultivariateNormalModel(p)
end
function MultivariateNormalModel()
  d=2
  p=NormalInverseWishart(zeros(d), 1e-8, eye(d), d*1.0)
  MultivariateNormalModel(p)
end

function pdf_likelihood(model::MultivariateNormalModel, y::Array{Float64,1}, θ::Tuple{Array{Float64,1},Array{Float64,2}})
  pdf(MvNormal(θ...), y)
end
function sample_posterior(model::MultivariateNormalModel, Y::Array{Float64,2})
  p=posterior_canon(model.prior,suffstats(MvNormal,Y))
  rand(p)
end
function sample_posterior(model::MultivariateNormalModel, y::Array{Float64,1})
  p=posterior_canon(model.prior,suffstats(MvNormal,reshape(y,(length(y),1))))
  rand(p)
end
function marginal_likelihood(model::MultivariateNormalModel, y::Array{Float64,1})
  d=length(y)
  p = model.prior
  mu0 = p.mu
  kappa0 = p.kappa
  LamC0 = p.Lamchol
  nu0 = p.nu

  kappa = kappa0 + 1
  nu = nu0 + 1
  mu = (kappa0.*mu0 + y) ./ kappa

  Lam0 = LamC0.L*LamC0.U
  z = p.zeromean ? y : y - mu0
  Lam = Lam0 + kappa0/kappa*(z*z')

  exp(-d/2*log(π) + logmvgamma(d,nu/2) - logmvgamma(d,nu0/2) + nu0/2*logdet(Lam0) - nu/2*logdet(Lam) + d/2 * (log(kappa0) - log(kappa)))
end
function standard_form(model::MultivariateNormalModel, ϕ::Tuple{Array{Float64,1}, Array{Float64,2}})
  (ϕ[1], inv(ϕ[2]))
end
function parameter_names(model::MultivariateNormalModel)
  ("Mean", "Covariance Matrix")
end

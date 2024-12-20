@defcomp utility begin
    # Define sector index used in this component
    sector = Index()
    
    # Define variables to be computed in this component
    c   = Variable(index=[time])    # CES aggregate of food and manufacturing goods 
    cn  = Variable(index=[time])    # CES aggregate utility of combined consumption and ecosystem services 
    U   = Variable(index=[time])    # Per capita utility
    wt  = Variable(index=[time])    # Running welfare total
    W   = Variable()                # Total welfare
    uf  = Variable(index=[time])    # Partial utility of food
    
    # Define parameters to be used as exogenous input to this component
    m       = Parameter(index=[time])   # Aggregate per capita manufacturing goods (1000 2005 USD)
    ftot    = Parameter(index=[time])   # Total food consumption per capita (kcal)
    n       = Parameter(index=[time])   # Value of ecosystems services per capita (1000 2005 USD)
    L       = Parameter(index=[time])   # Population (millions)
    σᶜ      = Parameter()               # Elasticity of substitution between food and manufacturing goods
    σᵘ      = Parameter()               # Elasticity of substitution between consumption aggregate and ecosystem services
    σᶠ      = Parameter()               # Elasticity of substitution between plant-based and animal-based foods
    φᶜ      = Parameter()               # Weight of manufactured goods in consumption aggregate
    φᵘ      = Parameter()               # Weight of ecosystem services in utility
    φᶠ      = Parameter()               # Weight of animal-based foods in food utility
    η       = Parameter()               # Elasticity of marginal utility with respect to combined consumption and ecosystem services
    ρ       = Parameter()               # Pure social rate of time preference
    Θᶠ      = Parameter()               # Minimum level of caloric intake per capita (kcal)
    f       = Parameter(index=[time, sector])   # Food consumption per capita (kcal)

    function run_timestep(p, v, d, t)
        # Convenience sector references
        fp = d.sector[2]
        fa = d.sector[3]

        food_check = (p.f[t, fp] + p.f[t, fa]) > p.Θᶠ

        # Compute CES aggregate of food consumption 
        v.uf[t] = food_check ? CES(p.f[t, fp], p.f[t, fa], phi=p.φᶠ, sigma=p.σᶠ) / 100 : 0   # At baseline, this should result in roughly 700, so we normalise to single-digits (ish)

        # Compute CES aggregate of food and manufacturing goods
        v.c[t] = CES(v.uf[t], p.m[t], phi=p.φᶜ, sigma=p.σᶜ)

        # Compute aggregate utility of consumption and ecosystem services
        v.cn[t] = CES(v.c[t], p.n[t], phi=p.φᵘ, sigma=p.σᵘ)

        # Compute per capita utility
        v.U[t] = v.cn[t]^(1 - p.η)/(1 - p.η)

        # Compute running welfare total
        if is_first(t)
            v.wt[t] = v.U[t] * p.L[t]
        else
            v.wt[t] = v.wt[t - 1] + v.U[t] * p.L[t] * (1 + p.ρ)^(first_year(t) - gettime(t)) 
        end

        # Compute total welfare
        if is_last(t)
            v.W = v.wt[t]
        end

    end
end
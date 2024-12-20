@defcomp livestock begin
    # Define sector index used in this component
    sector = Index()

    # Define variables to be computed in this component
    OUTPUT  = Variable(index=[time, sector])    # Total agricultural animal-based output (Exacalories)
    LK      = Variable(index=[time, sector])    # Labour-capital aggregate
    XF      = Variable(index=[time, sector])    # Land-crop aggregate

    # Define parameters to be used as exogenous input to this component
    A   = Parameter(index=[time, sector])   # Total factor productivity for livestock production
    L   = Parameter(index=[time, sector])   # Labour input for livestock production (billions)
    K   = Parameter(index=[time, sector])   # Capital input for livestock production (trillion 2005 USD)
    υ   = Parameter(index=[time, sector])   # Relative productivity of land for livestock production
    X   = Parameter(index=[time, sector])   # Land area used for livestock production (billion hectares)
    Pˡ  = Parameter(index=[time])           # Crop input for livestock production (Exacalories)
    α   = Parameter()                       # Labour-capital aggregate elasticity with respect to capital
    αˡ  = Parameter()                       # Land-crop aggregate elasticity with respect to land
    σ   = Parameter(index=[sector])         # Elasticity of substitution between labour-capital and land-feed aggregates
    φ   = Parameter(index=[sector])         # Importance of land-feed aggregate in crop production
    υ0  = Parameter(index=[sector])         # Initial land productivity

    function run_timestep(p, v, d, t)
        i = d.sector[3] # Convenience sector reference

        # Compute labour-capital aggregate
        v.LK[t, i] = CES(p.L[t, i], p.K[t, i], phi=p.α, sigma=1)
        
        # Compute land-crop aggregate
        if is_first(t)
            v.XF[t, i] = CES(p.Pˡ[t], p.υ0[i] * p.X[t, i], phi=p.αˡ, sigma=1)
        else
            v.XF[t, i] = CES(p.Pˡ[t], p.υ[t, i] * p.X[t, i], phi=p.αˡ, sigma=1)
        end
        
        # Compute total livestock output
        v.OUTPUT[t, i]  = p.A[t, i] * CES(v.LK[t, i], v.XF[t, i], phi=p.φ[i], sigma=p.σ[i])
    end
end
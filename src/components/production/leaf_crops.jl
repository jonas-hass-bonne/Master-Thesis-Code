@defcomp crops begin
    # Define sector index used in this component
    sector = Index()

    # Define variables to be computed in this component
    OUTPUT  = Variable(index=[time, sector])    # Total agricultural crop output (Exacalories)
    LK      = Variable(index=[time, sector])    # Labour-capital aggregate

    # Define parameters to be used as exogenous input to this component
    A   = Parameter(index=[time, sector])   # Total factor productivity for crop production
    L   = Parameter(index=[time, sector])   # Labour input for crop production (billions)
    K   = Parameter(index=[time, sector])   # Capital input for crop production (trillion 2005 USD)
    υ   = Parameter(index=[time, sector])   # Relative productivity of land for plant-based agricultural production
    X   = Parameter(index=[time, sector])   # Land area used for crop production (billion hectares)
    α   = Parameter()                       # Labour-capital aggregate elasticity with respect to capital
    σ   = Parameter(index=[sector])         # Elasticity of substitution between labour-capital and land
    φ   = Parameter(index=[sector])         # Importance of land in crop production
    υ0  = Parameter(index=[sector])         # Initial land productivity

    function run_timestep(p, v, d, t)
        i = d.sector[2] # Convenience sector reference
        
        # Compute the labour-capital aggregate
        v.LK[t, i] = CES(p.L[t, i], p.K[t, i], phi=p.α, sigma=1)
        
        # Compute total crop output
        if is_first(t)
            v.OUTPUT[t, i] = p.A[t, i] * CES(v.LK[t, i], p.υ0[i] * p.X[t, i], phi=p.φ[i], sigma=p.σ[i])
        else    
            v.OUTPUT[t, i] = p.A[t, i] * CES(v.LK[t, i], p.υ[t, i] * p.X[t, i], phi=p.φ[i], sigma=p.σ[i])
        end
    end
end
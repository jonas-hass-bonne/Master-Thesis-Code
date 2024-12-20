@defcomp manufacturing begin
    # Define sector index used in this component
    sector = Index()

    # Define variables to be computed in this component
    OUTPUT  = Variable(index=[time, sector])    # Output of manufacturing goods (trillion 2005 USD)

    # Define parameters to be used as exogenous input to this component
    A       = Parameter(index=[time, sector])   # Manufacturing total factor productivity
    L       = Parameter(index=[time, sector])   # Labour input for manufacturing production (billions)
    K       = Parameter(index=[time, sector])   # Capital input for manufacturing production (trillion 2005 USD)
    α       = Parameter()               # Output elasticity with respect to capital

    function run_timestep(p, v, d, t)
        # Compute total manufacturing output
        i = d.sector[1] # Convenience sector reference
        v.OUTPUT[t, i] = p.A[t, i] * CES(p.L[t, i], p.K[t, i], phi=p.α, sigma=1)
    end
end
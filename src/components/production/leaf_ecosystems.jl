@defcomp ecosystems begin
    # Define sector index used in this component
    sector = Index()
    # Define variables to be computed in this component
    OUTPUT  = Variable(index=[time, sector])    # Value of ecosystem services (trillions 2005 USD)

    # Define parameters to be used as exogenous input to this component
    A   = Parameter(index=[time, sector])   # Total factor productivity for ecosystem services
    X   = Parameter(index=[time, sector])   # Total land area left for ecosystems (billion hectares)
    υ   = Parameter(index=[time, sector])   # Relative productivity of land for ecosystem services
    α   = Parameter()                       # Ecosystem services elasticity with respect to land area
    υ0  = Parameter(index=[sector])         # Initial land productivity

    function run_timestep(p, v, d, t)
        i = d.sector[4] # Convenience sector reference

        # Compute total supply of ecosystem services
        if is_first(t)
            v.OUTPUT[t, i] = p.A[t, i] * CES(1, p.υ0[i] * p.X[t, i], phi=p.α, sigma=1)
        else
            v.OUTPUT[t, i] = p.A[t, i] * CES(1, p.υ[t, i] * p.X[t, i], phi=p.α, sigma=1)
        end
    end
end
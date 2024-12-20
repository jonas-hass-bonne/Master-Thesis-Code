@defcomp land begin
    # Define sector index used in this component
    sector = Index()

    # Define variables to be computed in this component
    X   = Variable(index=[time, sector])    # Land area in each sector (billion hectares)

    # Define parameters to be used as exogenous input to this component
    ξ       = Parameter(index=[time, sector])   # Share of total land area in each sector
    Xtot    = Parameter()                       # Total land area (billion hectares)

    function run_timestep(p, v, d, t)
        # Identify relevant sector id's
        residual_id = d.sector[4]
        prod_id = d.sector[2:3]
        # Compute land use in each sector
        v.X[t, prod_id] = p.Xtot .* p.ξ[t, prod_id]
        v.X[t, residual_id] = p.Xtot * (1 - sum(p.ξ[t, prod_id]))
    end
end
@defcomp labour begin
    # Define sector index used in this component
    sector = Index()

    # Define variables to be computed in this component
    L   = Variable(index=[time, sector])    # Labour force in each sector (millions)

    # Define parameters to be used as exogenous input to his component
    ξ       = Parameter(index=[time, sector])   # Labour share in each sector
    Ltot    = Parameter(index=[time])           # Total labour force (millions)

    function run_timestep(p, v, d, t)
        # Identify relevant sector id's
        residual_id = d.sector[3]
        prod_id = d.sector[1:2]
        # Compute labour in each sector
        v.L[t, prod_id] = p.Ltot[t] .* p.ξ[t, prod_id]
        v.L[t, residual_id] = p.Ltot[t] * (1 - sum(p.ξ[t, prod_id]))

    end
end
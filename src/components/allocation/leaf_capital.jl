@defcomp capital begin
    # Define sector index used in this component
    sector = Index()

    # Define variables to be computed in this component
    K   = Variable(index=[time, sector])    # Capital for each sector (trillion 2005 USD)

    # Define parameters to be used as exogenous input to this component
    ξ       = Parameter(index=[time, sector])   # Capital share in each sector
    Ktot    = Parameter(index=[time])           # Total stock of capital
    K0      = Parameter()                       # Initial total stock of capital

    function run_timestep(p, v, d, t)
        # Identify relevant sector id's
        residual_id = d.sector[3]
        prod_id = d.sector[1:2]
        if is_first(t)
             # Compute capital in each sector
            v.K[t, prod_id] = p.K0 .* p.ξ[t, prod_id]
            v.K[t, residual_id] = p.K0 * (1 - sum(p.ξ[t, prod_id]))
        else
            # Compute capital in each sector
            v.K[t, prod_id] = p.Ktot[t] .* p.ξ[t, prod_id]
            v.K[t, residual_id] = p.Ktot[t] * (1 - sum(p.ξ[t, prod_id]))
        end
    end
end
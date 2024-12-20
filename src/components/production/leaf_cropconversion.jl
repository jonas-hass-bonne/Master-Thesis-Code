@defcomp cropconversion begin
    # Define sector index used in this component
    sector = Index()

    # Define variables to be computed in this component
    Pᶜ = Variable(index=[time])     # Crops for consumption
    Pˡ = Variable(index=[time])     # Crops for livestock production

    # Define parameters to be used as exogenous input to this component
    OUTPUT  = Parameter(index=[time, sector])   # Total crop production
    ξ       = Parameter(index=[time])           # Share of crops for consumption

    function run_timestep(p, v, d, t)
        i = d.sector[2] # Convenience sector reference
        
        # Compute crops for consumption
        v.Pᶜ[t] = p.OUTPUT[t, i] * p.ξ[t]
        
        # Compute crops for livestock production
        v.Pˡ[t] = p.OUTPUT[t, i] * (1 - p.ξ[t])
    end
end
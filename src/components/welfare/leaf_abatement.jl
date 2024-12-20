@defcomp abatement begin
    # Define sector index to be used in this component
    sector  = Index()
    ghg     = Index()

    # Define variables to be computed in this component
    Λ       = Variable(index=[time, sector, ghg])   # Abatement cost as a share of manufacturing output for each sector
    Λtot    = Variable(index=[time])                # Total abatement cost across sectors as share of manufacturing output

    # Define parameters to be used as exogenous input to this component
    μ   = Parameter(index=[time, sector, ghg])  # Share of emissions abated for each sector
    θ¹  = Parameter(index=[time, sector, ghg])  # Abatement cost multiplier for each sector
    θ²  = Parameter(index=[sector, ghg])        # Abatement cost exponent for each sector

    function run_timestep(p, v, d, t)
        # Compute abatement costs in each sector
        v.Λ[t, :, :] = p.θ¹[t, :, :] .* p.μ[t, :, :] .^ p.θ²[:, :]

        # Compute total abatement costs
        v.Λtot[t] = sum(v.Λ[t, :, :])
    end
end
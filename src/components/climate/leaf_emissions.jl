@defcomp emissions begin
    # Define sector index used in this component
    sector  = Index()
    ghg     = Index()
    
    # Define variables to be computed in this component
    E       = Variable(index=[time, sector, ghg])   # GHG emissions from each sector (Gt/Mt CO2/CH4/N2O per year)
    Etot    = Variable(index=[time, ghg])           # Total GHG emissions (Gt/Mt CO2/CH4/N2O per year)

    # Define parameters to be used as exogenous input to this component
    OUTPUT  = Parameter(index=[time, sector])       # Output from each sector (trillion 2005 USD)
    γ       = Parameter(index=[time, sector, ghg])  # Emission intensity in each sector (ton CO2 per 1000 2005 USD)
    μ       = Parameter(index=[time, sector, ghg])  # Emission abatement share in each sector
    Etot_scc = Parameter(index=[time, ghg])         # Temporary SCC calculation strategy

    # Define a function containing the equations to be computed in this component
    function run_timestep(p, v, d, t)
        # Compute emissions from each sector
        v.E[t, :, :] = p.γ[t, :, :] .* (1 .- p.μ[t, :, :]) .* p.OUTPUT[t, :]

        # Compute total emissions
        v.Etot[t, :] = sum(v.E[t, :, :]; dims=1)[:] .+ p.Etot_scc[t, :]    # Sum over sectors
    end
end
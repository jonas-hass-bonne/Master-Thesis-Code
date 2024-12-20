@defcomp forcings begin
    # Define additional index used in the component
    ghg = Index()

    # Define variables to be computed in this component
    O   = Variable(index=[time])    # Forcing from CO2 (W/m²)

    # Define parameters to be used as exogenous input to this component
    Gₐ  = Parameter(index=[time, ghg])  # Sum of carbon in all reservoirs (Gt C)
    Oₑₓ = Parameter(index=[time])       # External forcing (W/m²)
    #Gₐ₀ = Parameter()               # Initial carbon stock (Gt CO2)  
    C₀  = Parameter(index=[ghg])        # Initial concentration (ppm) 
    E2C = Parameter(index=[ghg])        # Conversion factor between carbon emissions and atmospheric carbon concentrations (ppm/Gt C)
    ϵ₁  = Parameter(index=[ghg])        # Weight of logarithmic response
    ϵ₂  = Parameter(index=[ghg])        # Weight of linear response
    ϵ₃  = Parameter(index=[ghg])        # Weight of square-root response

    function run_timestep(p, v, d, t)
        # Compute forcings from CO2
        v.O[t] = sum(p.ϵ₁[:] .* log.((p.C₀[:] .+ p.Gₐ[t, :] .* p.E2C[:]) ./ (p.C₀[:])) 
                        .+ p.ϵ₂[:] .* ((p.C₀[:]  .+ p.Gₐ[t, :] .* p.E2C[:]) .- (p.C₀[:])) 
                        .+ p.ϵ₃[:] .* (sqrt.(p.C₀[:] .+ p.Gₐ[t, :] .* p.E2C[:]) .- sqrt.(p.C₀[:])) 
                        ) + p.Oₑₓ[t]
    end
end
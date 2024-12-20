@defcomp gas_cycle begin
    # Define additional index used in the component
    reservoir   = Index()
    ghg         = Index()

    # Define variables to be computed in this component
    R    = Variable(index=[time, reservoir, ghg])   # Carbon in each reservoir (Gt C)
    Gₐ   = Variable(index=[time, ghg])              # Total carbon across reservoir (Gt C)
    Gᵤ   = Variable(index=[time, ghg])              # Total accumulated emissions (Gt C)
    β    = Variable(index=[time, ghg])              # Decay-rate adjustment parameter
    Ecum = Variable(index=[time, ghg])              # Cumulative emissions (Gt CO2)

    # Define parameters to be used as exogenous input to this component
    E   = Parameter(index=[time, ghg])      # Total emissions (Gt CO2 per year)
    T   = Parameter(index=[time])           # Atmospheric temperature increase (Degrees celsius)
    g₀  = Parameter(index=[ghg])            # Calibration parameter for the value of β
    g₁  = Parameter(index=[ghg])            # Calibration parameter for the gradient of β
    r₀  = Parameter(index=[ghg])            # Baseline iIRF₁₀₀ response
    rᵤ  = Parameter(index=[ghg])            # Effect of accumulated emissions on iIRF₁₀₀
    rₜ  = Parameter(index=[ghg])            # Effect of temperature on iIRF₁₀₀
    rₐ  = Parameter(index=[ghg])            # Effect of atmospheric concentrations on iIRF₁₀₀
    τ   = Parameter(index=[reservoir, ghg]) # Baseline decay-rate for each reservoir
    a   = Parameter(index=[reservoir, ghg]) # Share of emissions going to each reservoir
    E2R = Parameter(index=[ghg])            # Conversion factor from emissions to reservoir units
    R0  = Parameter(index=[reservoir, ghg]) # Initial carbon in each reservoir (Gt C)
    β0  = Parameter(index=[ghg])            # Initial decay-rate adjustment parameter
    T0  = Parameter()                       # Initial temperature
    Ecum0 = Parameter(index=[ghg])          # Initial cumulative emissions

    function run_timestep(p, v, d, t)
        
        # Compute the value of each reservoir
        if !is_last(t)
            dt = gettime(t + 1) - gettime(t)        # Declare variable for storing timestep length
            if is_first(t)
                v.β[t, :] = p.β0[:]
            end
            for g in d.ghg  # Iterate over greenhouse gases
                for r in d.reservoir
                    decay_rate = dt ./ (v.β[t, g] .* p.τ[r, g]) # Auxiliary variable to make code comparable to original FAIR code
                    decay_factor = exp.(-decay_rate)            # Auxiliary variable to make code comparable to original FAIR code
                    if is_first(t)
                        v.R[t, r, g] = p.R0[r, g] # Old implementation: p.a[r] .* p.E[t] * (12/44) ./ decay_rate .* (1 .- decay_factor)
                    end
                    v.R[t + 1, r, g] = p.a[r, g] .* p.E[t, g] .* p.E2R[g] ./ decay_rate .* (1 .- decay_factor) .+ v.R[t, r, g] .* decay_factor
                end
            end
        end
        
        # Compute the new value of gas across reservoirs           
        for g in d.ghg
            v.Gₐ[t, g] = sum(v.R[t, :, g])
        end

        # Compute the new value of accumulated emissions
        if is_first(t)
            v.Ecum[t, :] = p.E[t, :] + p.Ecum0[:]
        else
            v.Ecum[t, :] = v.Ecum[t - 1, :] + p.E[t, :]
        end

        # Adjust cumulative emissions for current stocks in gas reservoirs
        v.Gᵤ[t, :] = v.Ecum[t, :] .* p.E2R[:] .- v.Gₐ[t, :]

        # Compute the new value of β
        if is_first(t)
            v.β[t + 1, :] = p.g₀[:] .* exp.((p.r₀[:] .+ p.rᵤ[:] .* v.Gᵤ[t, :] .+ p.rₜ[:] .* p.T0 .+ p.rₐ[:] .* v.Gₐ[t, :]) ./ p.g₁[:])
        elseif !is_last(t)
            v.β[t + 1, :] = p.g₀[:] .* exp.((p.r₀[:] .+ p.rᵤ[:] .* v.Gᵤ[t, :] .+ p.rₜ[:] .* p.T[t] .+ p.rₐ[:] .* v.Gₐ[t, :]) ./ p.g₁[:])
        end
    end
end
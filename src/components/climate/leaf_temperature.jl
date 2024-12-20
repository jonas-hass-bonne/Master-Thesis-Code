@defcomp temperature begin
    # Define additional index used in the component
    box = Index()

    # Define variables to be computed in this component
    T       = Variable(index=[time])        # Surface temperature (Degrees celsius)
    Tmax    = Variable(index=[time])        # Maximum surface temperature (Degrees celsius)
    S       = Variable(index=[time, box]) # Thermal boxes (Degrees celsius)

    # Define parameters to be used as exogenous input to this component
    O   = Parameter(index=[time])   # Radiative forcings (W/m²)
    q   = Parameter(index=[box])  # Equilibrium thermal response 
    d   = Parameter(index=[box])  # Thermal response timescale
    S0  = Parameter(index=[box])  # Initial values for thermal boxes
    T0  = Parameter()               # Initial temperature

    function run_timestep(p, v, d, t)
        # Compute change in each thermal box
        if is_first(t)
            v.S[t, :] = p.S0[:]
        else
            dt = gettime(t) - gettime(t - 1)
            decay_factor = exp.(- dt ./ p.d[:])
            v.S[t, :] = p.q[:] .* p.O[t] .* (1 .- decay_factor) .+ v.S[t - 1, :] .* decay_factor
            # for b in d.boxes
            #     dt = gettime(t) - gettime(t - 1)    # Declare variable for storing timestep length
            #     decay_factor = exp.(- dt ./ p.d[b])      # Auxiliary variable to make code comparable to original FAIR code
            #     v.S[t, b] = p.q[b] .* p.O[t] .* (1 .- decay_factor) .- v.S[t - 1, b] .* decay_factor
            # end
        end

        # Compute change in surface temperature
        if !is_last(t)
            v.T[t + 1] = sum(v.S[t, :]) # Forward-looking temperature change
        end
        if is_first(t)  # Initial temperatures
            v.T[t] = p.T0
            v.Tmax[t] = v.T[t]
        else
            v.Tmax[t] = max(v.T[t], v.Tmax[t - 1]) # Iteratively update Tmax
        end
    end
end
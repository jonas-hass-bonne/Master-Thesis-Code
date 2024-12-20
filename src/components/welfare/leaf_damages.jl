@defcomp damages begin
    # Define sector index used in this component
    sector = Index()

    # Define variables to be computed in this component
    Ω   = Variable(index=[time])            # Damages as a share of manufacturing Base.with_output_color
    υ   = Variable(index=[time, sector])    # Land productivity across sectors

    # Define parameters to be used as exogenous input to this component
    T       = Parameter(index=[time])   # Surface temperature (Degrees celsius)
    Tmax    = Parameter(index=[time])   # Maximum surface temperature (Degrees celsius)
    ψ¹      = Parameter(index=[sector]) # Linear damage coefficient for each sector
    ψ²      = Parameter(index=[sector]) # Quadratic damage coefficient for each sector
    ϕ       = Parameter(index=[sector]) # Approximate share of damages which are permanent across sectors
    υ0      = Parameter(index=[sector]) # Initial land productivity in each sector

    function run_timestep(p, v, d, t)
        # Convenience sector references
        m = d.sector[1]     # Manufacturing
        i = d.sector[2:end] # Non-manufacturing
        
        # Compute damages as a share of manufacturing output
        v.Ω[t] = (p.ψ¹[m] * p.T[t] + p.ψ²[m] * p.T[t]^2) / 
                 (1 + p.ψ¹[m] * p.T[t] + p.ψ²[m] * p.T[t]^2)
        
        # Compute productivity of various land uses
        if is_first(t)
            v.υ[t, i] = p.υ0[i]
        end
        if !is_last(t)
            for idx in i
                v.υ[t + 1, idx] = p.T[t] >= 0 ? 
                                  1 / (1 + p.ψ²[idx] * (1 - p.ϕ[idx] ) * p.T[t]^2 + p.ψ²[idx] * p.ϕ[idx] * p.Tmax[t]^2) : 
                                  1 / (1 + exp(p.T[t] + log((1 + p.ψ²[idx] * p.ϕ[idx] * p.Tmax[t]^2 - p.υ0[idx]) / p.υ0[idx] ))) 
            end
        end
    end
end
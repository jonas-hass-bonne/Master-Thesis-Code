@defcomp consumption begin
    # Define sector index used in this component
    sector = Index()

    # Define variables to be computed in this component
    n       = Variable(index=[time])            # Value of ecosystems services per capita (1000 2005 USD)
    ftot    = Variable(index=[time])            # Aggregate food consumption per capita (kcal)
    m       = Variable(index=[time])            # Manufacturing consumption per capita (1000 2005 USD)
    f       = Variable(index=[time, sector])    # Food consumption per capita across sectors (kcal)
    YNET    = Variable(index=[time])            # Manufacturing output net of damages and abatement (trillion 2005 USD)

    # Define parameters to be used as exogenous input to this component
    Ω       = Parameter(index=[time])           # Damages as a fraction of manufacturing output
    Λ       = Parameter(index=[time])           # Total abatement costs as a fraction of manufacturing output
    L       = Parameter(index=[time])           # Population (billions)
    OUTPUT  = Parameter(index=[time, sector])   # Output for each sector (trillion 2005 USD)
    Pᶜ      = Parameter(index=[time])           # Plant based food for consumption (trillion kcal)
    s       = Parameter(index=[time])           # Savings rate for capital investments (share)
    m_scc   = Parameter(index=[time])           # Temporary SCC calculation strategy

    function run_timestep(p, v, d, t)
        # Convenience sector references
        m = d.sector[1]
        f = d.sector[2:3]
        fp = d.sector[2]
        fa = d.sector[3]
        e = d.sector[4]

        # Compute net manufacuring output
        v.YNET[t] = (1 - p.Ω[t]) * p.OUTPUT[t, m]

        # Compute output per capita
        v.m[t]  = (v.YNET[t] * (1 - p.Λ[t] - p.s[t])) / (p.L[t]) + p.m_scc[t]
        v.f[t, fa] = p.OUTPUT[t, fa] / p.L[t] * 1e6 / 365 # Convert from gigacalories to kilocalories per day
        v.f[t, fp] = p.Pᶜ[t] / p.L[t] * 1e6 / 365 # Convert from gigacalories to kilocalories per day
        v.n[t]  = p.OUTPUT[t, e] / (p.L[t])

        # Compute aggregate food consumption per capita
        v.ftot[t] = sum(v.f[t, f])
    end
end
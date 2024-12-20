@defcomp investments begin
    # Define variables to be computed in this component
    Ktot    = Variable(index=[time])    # Total capital stocks (trillion 2005 USD)

    # Define parameters to be used as exogenous input to this component
    YNET    = Parameter(index=[time])   # Net manufacturing output
    s       = Parameter(index=[time])   # Capital investments savings rate
    δ       = Parameter()               # Depreciation rate of capital
    K0      = Parameter()               # Initial total capital stock

    function run_timestep(p, v, d, t)
        if is_first(t)
            v.Ktot[t] = p.K0
        end
        if !is_last(t)
            # Compute next period capital
            v.Ktot[t + 1] = (1 - p.δ) * v.Ktot[t] + p.s[t] * p.YNET[t]
        end
    end
end
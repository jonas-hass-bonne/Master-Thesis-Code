@defcomposite FAiR_climate begin
    # Add the gas cycle component
    Component(gas_cycle)
    # Link variables of the gas cycle component to symbols
    # in this composite component
    R       = Variable(gas_cycle.R)
    Gₐ      = Variable(gas_cycle.Gₐ)
    Gᵤ      = Variable(gas_cycle.Gᵤ)
    β       = Variable(gas_cycle.β)
    Ecum    = Variable(gas_cycle.Ecum)     
    # Link parameters of the gas cycle component to symbols
    # in this composite component
    E       = Parameter(gas_cycle.E)
    g₀      = Parameter(gas_cycle.g₀)
    g₁      = Parameter(gas_cycle.g₁)
    r₀      = Parameter(gas_cycle.r₀)
    rᵤ      = Parameter(gas_cycle.rᵤ)
    rₜ      = Parameter(gas_cycle.rₜ)
    rₐ      = Parameter(gas_cycle.rₐ)
    τ       = Parameter(gas_cycle.τ)
    a       = Parameter(gas_cycle.a)
    R0      = Parameter(gas_cycle.R0)
    β0      = Parameter(gas_cycle.β0)
    Ecum0   = Parameter(gas_cycle.Ecum0)

    # Add the radiative forcing component
    Component(forcings)
    # Link variables of the forcing component to symbols
    # in the composite component
    O       = Variable(forcings.O)
    # Connect total gas reservoir stocks parameter in forcing component
    # to total gas reservoir stocks variable from the gas cycle component
    connect(forcings.Gₐ, gas_cycle.Gₐ)
    # Link parameters in this composite component to 
    # parameters in the forcing component
    Oₑₓ     = Parameter(forcings.Oₑₓ)
    C₀      = Parameter(forcings.C₀)
    E2C     = Parameter(forcings.E2C)
    ϵ₁      = Parameter(forcings.ϵ₁)
    ϵ₂      = Parameter(forcings.ϵ₂)
    ϵ₃      = Parameter(forcings.ϵ₃)

    # Add the temperature component
    Component(temperature)
    # Link variable of the temperature component to symbols
    # in the composite component
    T       = Variable(temperature.T)
    Tmax    = Variable(temperature.Tmax)
    S       = Variable(temperature.S)
    # Connect CO2 forcing parameter in temperature component to
    # forcing variable from the forcing component
    connect(temperature.O, forcings.O)
    # Connect temperature parameter in gas cycle component to
    # temperature variable from the temperature component
    connect(gas_cycle.T, temperature.T)
    # Link parameters in this composite component to
    # parameters in the temperature component
    q       = Parameter(temperature.q)
    d       = Parameter(temperature.d)
    S0      = Parameter(temperature.S0)

    # Declare initial temperature as shared parameter
    T0      = Parameter(gas_cycle.T0, temperature.T0)
end
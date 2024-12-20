@defcomposite allocation begin
    # Add the capital component
    Component(capital)
    # Link variables of the capital component to symbols
    # in the composite component
    K   = Variable(capital.K)
    # Link parameters of the capital component to symbols 
    # in this composite component
    ξᵏ      = Parameter(capital.ξ)
    Ktot    = Parameter(capital.Ktot)
    K0      = Parameter(capital.K0)

    # Add the labour component
    Component(labour)
    # Link variables of the labour component to symbols
    # in this composite component
    L   = Variable(labour.L)
    # Link parameters of the labour component to symbols
    # in this composite component
    ξˡ      = Parameter(labour.ξ)
    Ltot    = Parameter(labour.Ltot)

    # Add the land component
    Component(land)
    # Link variables of the land component to symbols
    # in this composite component
    X   = Variable(land.X)
    # Link parameters of the land component to symbols
    # in this composite component
    ξˣ      = Parameter(land.ξ)
    Xtot    = Parameter(land.Xtot)
end
@defcomposite production begin
    # Add the component for computing manufacturing output
    Component(manufacturing)

    # Add the component for computing ecosystem services
    Component(ecosystems)
    # Link parameters of the ecosystem component to symbols
    # in this composite component
    αᵉ  = Parameter(ecosystems.α)
    
    # Add the component for computing agricultural crop output
    Component(crops)

    # Add component to split crop output 
    # between consumption and livestock purposes
    Component(cropconversion)
    # Link variables of the cropconversion component to symbols
    # in this composite component
    Pᶜ = Variable(cropconversion.Pᶜ)
    Pˡ = Variable(cropconversion.Pˡ)
    # Connect crop supply parameter in cropconversion component
    # to the crop supply variable in the crops component
    connect(cropconversion.OUTPUT, crops.OUTPUT)
    # Link parameters of the cropconversion component to symbols
    # in this composite component
    ξᶠ  = Parameter(cropconversion.ξ)

    # Add component to compute livestock output
    Component(livestock)

    # Connect feed supply parameter in livestock component
    # to the feed supply variable in the cropconversion component
    connect(livestock.Pˡ, cropconversion.Pˡ)
    # Link parameters of the livestock component to symbols
    # in this composite component
    αˡ  = Parameter(livestock.αˡ)

    # Add component to aggregate outputs from different sectors in one array
    Component(aggregation)
    # Link variables of the aggregation component to symbols
    # in this composite component
    OUTPUT  = Variable(aggregation.OUTPUT)
    LK      = Variable(aggregation.LK)
    XF      = Variable(aggregation.XF)
    # # Connect output, labour-capital aggregates and land-feed aggregates
    # from various sectors to the aggregation component
    connect(aggregation.mOUTPUT, manufacturing.OUTPUT)
    connect(aggregation.eOUTPUT, ecosystems.OUTPUT)
    connect(aggregation.pOUTPUT, crops.OUTPUT)
    connect(aggregation.aOUTPUT, livestock.OUTPUT)
    connect(aggregation.pLK, crops.LK)
    connect(aggregation.aLK, livestock.LK)
    connect(aggregation.aXF, livestock.XF)

    # Declaration of shared parameters
    A       = Parameter(manufacturing.A, ecosystems.A, crops.A, livestock.A)
    L       = Parameter(manufacturing.L, crops.L, livestock.L)
    K       = Parameter(manufacturing.K, crops.K, livestock.K)
    X       = Parameter(ecosystems.X, crops.X, livestock.X)
    α       = Parameter(manufacturing.α, crops.α, livestock.α)
    υ       = Parameter(ecosystems.υ, crops.υ, livestock.υ)
    υ0      = Parameter(ecosystems.υ0, crops.υ0, livestock.υ0)
    σˢ      = Parameter(crops.σ, livestock.σ) 
    φˢ      = Parameter(crops.φ, livestock.φ)
end
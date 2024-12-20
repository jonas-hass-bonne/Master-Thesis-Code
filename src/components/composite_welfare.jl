@defcomposite welfare begin
    # Add the damages component
    Component(damages)
    # Link variables of the damages component to symbols
    # in this composite component
    Ω   = Variable(damages.Ω)
    υ   = Variable(damages.υ)
    # Link parameters of the damages component to symbols
    # in this composite component
    T       = Parameter(damages.T)
    Tmax    = Parameter(damages.Tmax) 
    ψ¹      = Parameter(damages.ψ¹)            
    ψ²      = Parameter(damages.ψ²)
    ϕ       = Parameter(damages.ϕ)
    υ0      = Parameter(damages.υ0)

    # Add the abatement component
    Component(abatement)
    # Link variables of the abatement component to symbols
    # in this composite component
    Λ       = Variable(abatement.Λ)
    Λtot    = Variable(abatement.Λtot)
    # Link parameters of the abatement component to symbols
    # in this composite component
    μ   = Parameter(abatement.μ)
    θ¹  = Parameter(abatement.θ¹)
    θ²  = Parameter(abatement.θ²)

    # Add the consumption component
    Component(consumption)
    # Link variables of the consumption component to symbols
    # in this composite component
    n       = Variable(consumption.n)
    ftot    = Variable(consumption.ftot)
    m       = Variable(consumption.m)
    f       = Variable(consumption.f)
    YNET    = Variable(consumption.YNET)
    # Connect damage and abatement costs parameters in
    # consumption component to their respective variables
    # from the damages and abatement modules respecitvely
    connect(consumption.Ω, damages.Ω)    
    connect(consumption.Λ, abatement.Λtot)
    # Link parameters of the consumption component to symbols
    # in this composite component
    OUTPUT  = Parameter(consumption.OUTPUT)
    Pᶜ      = Parameter(consumption.Pᶜ)
    m_scc   = Parameter(consumption.m_scc)

    # Add the utility component
    Component(utility)
    # Link variables of the utility component to symbols
    # in this composite component
    c   = Variable(utility.c)
    cn  = Variable(utility.cn)
    U   = Variable(utility.U)
    wt  = Variable(utility.wt)
    W   = Variable(utility.W)
    uf  = Variable(utility.uf)
    # Connect manufacturing goods, ecosystem services and
    # food consumption parameters in the utility component
    # to their respective variables from the consumption component 
    connect(utility.m, consumption.m)
    connect(utility.ftot, consumption.ftot)
    connect(utility.n, consumption.n)
    connect(utility.f, consumption.f)
    # Link parameters of the utility component to symbols
    # in this composite component
    σᶜ  = Parameter(utility.σᶜ)
    σᵘ  = Parameter(utility.σᵘ)
    σᶠ  = Parameter(utility.σᶠ)
    φᶜ  = Parameter(utility.φᶜ)
    φᵘ  = Parameter(utility.φᵘ)
    φᶠ  = Parameter(utility.φᶠ)
    η   = Parameter(utility.η)
    ρ   = Parameter(utility.ρ)
    Θᶠ  = Parameter(utility.Θᶠ)

    # Add the investments component
    Component(investments)
    # Link variables of the investments components to symbols
    # in this composite component
    Ktot = Variable(investments.Ktot)
    # Connect net manufacturing production parameter in
    # the investments component to net manufacturing
    # production variable in the consumption component
    connect(investments.YNET, consumption.YNET)
    # Link parameters in this composite component to 
    # parameters in the investments component
    δ   = Parameter(investments.δ)      
    K0  = Parameter(investments.K0)      
    
    # Declaration that population and savings rate is the same across components
    Ltot = Parameter(consumption.L, utility.L)
    s = Parameter(consumption.s, investments.s)
end

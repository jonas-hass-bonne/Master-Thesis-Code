@defcomp aggregation begin
    # Define sector index used in this component
    sector = Index()

    # Define variables to be computed in this component
    OUTPUT  = Variable(index=[time, sector])    # Gross output in each sector
    LK      = Variable(index=[time, sector])    # Labour-capital aggregates in relevant sectors
    XF      = Variable(index=[time, sector])    # Land-feed aggregates in relevant sectors
    # Define parameters to be used as exogenous input to this component
    mOUTPUT = Parameter(index=[time, sector])   # Gross output in the manufacturing sector
    eOUTPUT = Parameter(index=[time, sector])   # Gross output in the ecosystem sector
    pOUTPUT = Parameter(index=[time, sector])   # Gross output in the plant-based agricultural sector
    aOUTPUT = Parameter(index=[time, sector])   # Gross output in the animal-based agricultural sector
    pLK     = Parameter(index=[time, sector])   # Labour-capital aggregate in the plant-based agricultural sector
    aLK     = Parameter(index=[time, sector])   # Labour-capital aggregate in the animal-based agricultural sector
    aXF     = Parameter(index=[time, sector])   # Land-feed aggregate in the animal-based agricultural sector

    function run_timestep(p, v, d, t)
        # Convenience sector references
        (m, fp, fa, e)  = (d.sector[i] for i in 1:4)
        # Loop through sectors and assign to appropiate variables
        for (i, x) in zip([m, fp, fa, e], [p.mOUTPUT[t, m], p.pOUTPUT[t, fp], p.aOUTPUT[t, fa], p.eOUTPUT[t, e]])
            v.OUTPUT[t, i] = x
            if i == fp
                v.LK[t, i] = p.pLK[t, fp]
            elseif i == fa
                v.LK[t, i] = p.aLK[t, fa]
                v.XF[t, i] = p.aXF[t, fa]
            end
        end
    end
end
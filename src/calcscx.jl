
"""
    calc_sc_gas(m::Mimi.AbstractModel, gas::AbstractString)

Wrapper function for calculating social cost of various greenhouse gases
"""
function calc_sc_gas(m::Mimi.AbstractModel, gas::AbstractString)
    if gas == "CO2"
        sc_out = calc_scc(m)
    elseif gas == "CH4"
        sc_out = calc_scm(m)
    elseif gas == "N2O"
        sc_out = calc_scn(m)
    else
        error("$gas is not a valid selection of greenhouse gas")
    end

    return sc_out
end

"""
    calc_scc(m::Mimi.AbstractModel)

Wrapper function for calculating the social cost of carbon in each year
"""
function calc_scc(m::Mimi.AbstractModel)
    outVec = fill(0., length(Mimi.dimension(m, :time)))
    for t in eachindex(outVec)
        outVec[t] = calc_scc(m, t)
    end

    return outVec
end

"""
    calc_scc(m::Mimi.AbstractModel, t::Integer)

Calculate the social cost of carbon at the specified year `t`
"""
function calc_scc(m::Mimi.AbstractModel, t::Integer)
    timeperiods = length(Mimi.dimension(m, :time))
    update_vec = fill(0., timeperiods)
    update_vec[t] = 1.
    mmem = create_marginal_model(m, 1.)
    mmc = create_marginal_model(m, 1.)
    update_param!(mmem.modified, :climate, :Etot_scc, [update_vec fill(0., timeperiods) fill(0., timeperiods)])
    update_param!(mmc.modified, :welfare, :m_scc, update_vec)
    run(mmem)
    run(mmc)
    return mmem[:welfare, :W]/mmc[:welfare, :W] * -1e-6
end

"""
    calc_scm(m::Mimi.AbstractModel)

Wrapper function for calculating the social cost of methane in each year
"""
function calc_scm(m::Mimi.AbstractModel)
    outVec = fill(0., length(Mimi.dimension(m, :time)))
    for t in eachindex(outVec)
        outVec[t] = calc_scm(m, t)
    end

    return outVec
end

"""
    calc_scm(m::Mimi.AbstractModel, t::Integer)

Calculate the social cost of methane at the specified year `t`
"""
function calc_scm(m::Mimi.AbstractModel, t::Integer)
    timeperiods = length(Mimi.dimension(m, :time))
    update_vec = fill(0., timeperiods)
    update_vec[t] = 1.
    mmem = create_marginal_model(m, 1.)
    mmc = create_marginal_model(m, 1.)
    update_param!(mmem.modified, :climate, :Etot_scc, [fill(0., timeperiods) update_vec fill(0., timeperiods)])
    update_param!(mmc.modified, :welfare, :m_scc, update_vec)
    run(mmem)
    run(mmc)
    return mmem[:welfare, :W]/mmc[:welfare, :W] * -1e-3
end

"""
    calc_scn(m::Mimi.AbstractModel)

Wrapper function for calculating the social cost of carbon in each year
"""
function calc_scn(m::Mimi.AbstractModel)
    outVec = fill(0., length(Mimi.dimension(m, :time)))
    for t in eachindex(outVec)
        outVec[t] = calc_scn(m, t)
    end

    return outVec
end

"""
    calc_scn(m::Mimi.AbstractModel, t::Integer)

Calculate the social cost of nitrous oxide at the specified year `t`
"""
function calc_scn(m::Mimi.AbstractModel, t::Integer)
    timeperiods = length(Mimi.dimension(m, :time))
    update_vec = fill(0., timeperiods)
    update_vec[t] = 1.
    mmem = create_marginal_model(m, 1.)
    mmc = create_marginal_model(m, 1.)
    update_param!(mmem.modified, :climate, :Etot_scc, [fill(0., timeperiods) fill(0., timeperiods) update_vec])
    update_param!(mmc.modified, :welfare, :m_scc, update_vec)
    run(mmem)
    run(mmc)
    return mmem[:welfare, :W]/mmc[:welfare, :W] * -1e-3
end
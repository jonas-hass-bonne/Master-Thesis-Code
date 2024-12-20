####################################
# This file provides functions for #
# optimizing a Mimi model          #
####################################

using ForwardDiff   # For use in gradient approximation

# NOTE - Currently, the function is hard-coded to assume that the following components and
# parameters will be specified in the following order:
# components = [:welfare, :welfare, :production], the 2-dimensional :allocation parameters are not supported
# parameters = [:s, :μ, :ξᶠ]
# This should be revisited in a future revision to allow for a more flexible specification

function ModelOptim(m::Mimi.AbstractModel, components::Union{Symbol, Vector{Symbol}}, parameters::Union{Symbol, Vector{Symbol}}; 
                    upper_bounds::Union{Nothing, Vector{<:Real}}=nothing, lower_bounds=nothing)

    # Construct a model instance for optimizing
    m_inst = deepcopy(m)  
    run(m_inst)

    timeperiods = collect(values(m.md.dim_dict[:time]))
    paramsizeVec = [*(1, size(m[comp, param])[2:end]...) for (comp, param) in zip(components, parameters)]
    totalyearvars = sum(paramsizeVec)
    yearvaridx = [i == 1 ? range(1, cumsum(paramsizeVec)[i]) : range(1 + cumsum(paramsizeVec)[i - 1], cumsum(paramsizeVec)[i]) for i in eachindex(paramsizeVec)]
    totalvars = length(timeperiods)*totalyearvars

    # Define bounds for the optimisation problem
    # Default is upper bound of 1 and lower bound of 0
    if upper_bounds === nothing
        upper = fill(1., length(timeperiods), totalyearvars) # Default behaviour, constant upper bound of 1
    else
        if length(upper_bounds) == totalvars # Bounds specified for each parameter in each year
            upper = reshape(upper_bounds, (length(timeperiods), totalyearvars)) # Ensure correct shape
        elseif length(upper_bounds) == totalyearvars    # One bound specified for each parameter value in a year
            # Broadcast the upper bounds across all years
            upper = reduce(vcat, [reshape(upper_bounds, :, totalyearvars) for _ in eachindex(timeperiods)])
        elseif length(upper_bounds) == length(parameters)   # One bound specified for each parameter
            # Expand upper bounds to all parameters and broadcast over all years
            upper = [upper_bounds[i] for (i, comp, param) in zip(eachindex(upper_bounds), components, parameters) 
                            for _ in 1:*(1, size(m[comp, param])[2:end]...)]
            upper = reduce(vcat, [reshape(upper, :, totalyearvars) for _ in eachindex(timeperiods)])
        elseif length(upper_bounds) == length(timeperiods) # One bound specified for each timeperiod
            println("WARNING: Only one upper bound was specified for each timeperiod")
            println("Consider specifying upper bounds for each parameter explicitly")
            println("Broadcasting the specified bound across parameters")
            
            upper = reduce(hcat, [upper_bounds for _ in 1:totalyearvars])
        else
            errnumber = length(upper_bounds)
            error("""The amount of upper bounds specified exceeds the number of total variables
                     The total number of variables is $totalvars while the amount of upper bounds are $errnumber""")
            
        end
    end

    if lower_bounds === nothing
        lower = fill(0., length(timeperiods), totalyearvars) # Default behaviour, constant lower bound of 0
    else
        if length(lower_bounds) == totalvars # Bounds specified for each parameter in each year
            lower = reshape(lower_bounds, (length(timeperiods), totalyearvars)) # Ensure correct shape
        elseif length(lower_bounds) == totalyearvars    # One bound specified for each parameter value in a year
            # Broadcast the upper bounds across all years
            lower = reduce(vcat, [reshape(lower_bounds, :, totalyearvars) for _ in eachindex(timeperiods)])
        elseif length(lower_bounds) == length(parameters)   # One bound specified for each parameter
            # Expand upper bounds to all parameters and broadcast over all years
            lower = [lower_bounds[i] for (i, comp, param) in zip(eachindex(lower_bounds), components, parameters) 
                            for _ in 1:*(1, size(m[comp, param])[2:end]...)]
            lower = reduce(vcat, [reshape(lower, :, totalyearvars) for _ in eachindex(timeperiods)])
        elseif length(lower_bounds) == length(timeperiods) # One bounds specified for each timeperiod
            println("WARNING: Only one lower bound was specified for each timeperiod")
            println("Consider specifying lower bounds for each parameter explicitly")
            println("Broadcasting the specified bound across parameters")
            
            lower = reduce(hcat, [lower_bounds for _ in 1:totalyearvars])
        else
            errnumber = length(lower_bounds)
            error("""The amount of lower bounds specified exceeds the number of total variables
                     The total number of variables is $totalvars while the amount of lower bounds are $errnumber""")
            
        end
    end

    ######################################################################
    ### THE DEFINITION OF VARIATIONAL CONSTRAINTS SHOULD BE REFACTORED ### 
    ### TO BE GIVEN AS EXPLICIT ARGUMENTS IN SOME FUTURE REVISION TO   ###
    ### ALLOW FOR FLEXIBLE CONSTRAINT SPECIFICATION AND HANDLING       ###
    ######################################################################                         

    # Define variational constraint for food consumption allocation

    # NOTE - Since the latest refactoring of the model structure, this constraint is 
    # no longer needed, since CES aggregate of food consumption is passed on through
    # the utility nest with a catch of zero if total food supply is insufficient

    # Explicit animal production function for easier constraint evaluation
    function animalProduction(m::Mimi.AbstractModel, year::Integer, ξ::Number)
        A = m[:production, :A][year, 3]
        φˡ = m[:production, :φˢ][3]
        σˡ = m[:production, :σˢ][3]
        αˡ = m[:production, :αˡ]
        α = m[:production, :α]

        K = m[:production, :K][year, 3]
        L = m[:production, :L][year, 3]
        X = m[:production, :X][year, 3]
        Fᶜ = m[:production, :OUTPUT][year, 2]
        υ = m[:production, :υ][year, 3]

        LK = CES(L, K, phi=α, sigma=1)
        XF = CES((1 .- ξ) .* Fᶜ, υ .* X, phi=αˡ, sigma=1)
        Fᵃ = A * CES(LK, XF, phi=φˡ, sigma=σˡ)
        return Fᵃ
    end
    
    # Nested root-finding for plant-based agricultural usage split
    function nestedRootEval(m::Mimi.AbstractModel, year::Integer, ξ::Number)
        L = m[:welfare, :Ltot][year]
        fᶜ = m[:welfare, :OUTPUT][year, 2] / L
        φᶠ = m[:welfare, :φᶠ]
        σᶠ = m[:welfare, :σᶠ]

        localFunc(ξ) = animalProduction(m, year, ξ) / L
        fˡ = localFunc(ξ)
        fˡprime = ForwardDiff.derivative(localFunc, ξ)

        return (1 - φᶠ) * (ξ * fᶜ)^(-1/σᶠ)*fᶜ + φᶠ*fˡ^(-1/σᶠ)*fˡprime
    end

    # Evaluate nested root using current model parameter
    function nestedRootEval(m::Mimi.AbstractModel, year::Integer)
        ξ = m[:production, :ξᶠ][year]
        return nestedRootEval(m, year, ξ)
    end

    # Define a vector of root functions for each time period
    localRootFuncVec = [x -> nestedRootEval(m, i, x) for i in timeperiods]
    localRootFuncid = (:production, :ξᶠ)

    # Really inflexible specification of constraints, but should suffice for now
    # NOTE - Again, since the refactoring of the solution algorithm (slightly hard-coded)
    # these constraints are no longer relevant as search is undertaken in the implied
    # 2-dimensional grid-box (still assuming convexity along both dimensions)

    # Define variational constraint for feasibility of savings and abatement policy
    function feasibilityConstraint(xx::Vector{<:Real}, model::Mimi.AbstractModel, components::Vector{Symbol}, parameters::Vector{Symbol}, year::Integer)
        robust_update_param_year!(model, components, parameters, year, xx)
        run(model)

        return model[:welfare, :s][year] + model[:welfare, :Λtot][year] - 1.0
    end

    function allocationConstraintK(xx::Vector{<:Real}, model::Mimi.AbstractModel, components::Vector{Symbol}, parameters::Vector{Symbol}, year::Integer)
        robust_update_param_year!(model, components, parameters, year, xx)
        run(model)

        return sum(model[:allocation, :ξᵏ][year, 1:2]) - 1.0
    end

    function allocationConstraintL(xx::Vector{<:Real}, model::Mimi.AbstractModel, components::Vector{Symbol}, parameters::Vector{Symbol}, year::Integer)
        robust_update_param_year!(model, components, parameters, year, xx)
        run(model)

        return sum(model[:allocation, :ξˡ][year, 1:2]) - 1.0
    end

    function allocationConstraintX(xx::Vector{<:Real}, model::Mimi.AbstractModel, components::Vector{Symbol}, parameters::Vector{Symbol}, year::Integer)
        robust_update_param_year!(model, components, parameters, year, xx)
        run(model)

        return sum(model[:allocation, :ξˣ][year, 2:3]) - 1.0
    end

    ineqConstraint = Function[feasibilityConstraint]
    ineqConstraintid = [[1, 2]]    # This is super inflexibly specified, should be given as an input to the function
    varFlags = [false, false, false] #, true, true, true]  # Again, completely ad-hoc junk but you know what it is

    # DEPRECATED METHOD FOR CONSTRAINT DEFINITION - If specified, define temperature constraint
    # if t_max !== nothing
    #     append!(ineqConstraint, Function[model -> maximum(model[:climatedynamics, :TATM]) - t_max])
    # end

    ######################################################################
    
    # Define method to construct objective function for a specific year
    function baseobjective_year(model::Mimi.AbstractModel, components::Vector{Symbol}, parameters::Vector{Symbol}, objective::Function, year::Integer)
        function out_objective(xx::Vector)
            robust_update_param_year!(model, components, parameters, year, xx)
            run(model)
            return objective(model) 
        end
        return out_objective
    end

    ###########################################################################
    ### THE APPROACH TO GENERATING AN INITIAL POINT FOR THE FUNCTION SHOULD ###
    ### BE RECONSIDERED IN A FUTURE REVISION TO INTEGRATE WITH FLEXIBLE     ###
    ### SPECIFICATION OF VARIATIONAL CONSTRAINTS AND TO CONSIDER WHETHER A  ###
    ### ZERO-ARGUMENT FUNCTION IS THE BEST SUITED GENERATION METHOD         ###
    ###########################################################################

    # Define a function returning an initial point satisfying constraints
    function init_gen()

        ### OUTDATED WITH NEW STRUCTURE OF INEQUALITY CONSTRAINTS #####
        ### CONSIDER REWORKING IN FUTURE REVISION IF STILL RELEVANT ###
        # If any constraint is violated, update initial values to ensure compliance
        # Ensure that the inequality constraint holds
        # for constraint in ineqConstraint
        #     while constraint(m) >= 0
        #         # Identify years where constraint is violated - CURRENTLY NOT ROBUST
        #         yearidx = timeperiods[m[:welfare, :Θᶠ] .- m[:welfare, :ftot] .>= 0]
        #         # Increase resources for food production in the violating years - AGAIN NOT ROBUST
        #         for share in [:ξᵏ, :ξˡ, :ξˣ]
        #             if share == :ξˣ
        #                 m[:allocation, share][yearidx, [2,3]] .+= m[:allocation, share][yearidx, 4]/4
        #                 m[:allocation, share][yearidx, 4] /= 2
        #             else
        #                 m[:allocation, share][yearidx, [2,3]] .+= m[:allocation, share][yearidx,1]/4
        #                 m[:allocation, share][yearidx, 1] /= 2
        #             end
        #         end
        #         paramUpdateDict = Dict([(:allocation, share) => m[:allocation, share] for share in [:ξᵏ, :ξˡ, :ξˣ]])
        #         update_params!(m, paramUpdateDict)
        #         update_params!(m_inst, paramUpdateDict)
        #         run(m)
        #     end
        # end
        
        # Ensure that food consumption is optimal
        # while any(abs.([localRootFuncVec[i](m[localRootFuncid...][i]) for i in timeperiods]) .>= 1e-11) # should perhaps allow for flexible tol at some point
        #     (comp, param) = localRootFuncid
        #     new_val = [NewtonRhapsonRoot(localRootFuncVec[i], m[comp, param][i], [0, 1], tol = 1e-11, maxiter=1e4) for i in timeperiods]
        #     robust_update_param!(m, comp, param, new_val)
        #     robust_update_param!(m_inst, comp, param, new_val)
        #     run(m)
        # end
        
        # run(m)
        # run(m_inst)

        # The updating scheme below is outdated, should be updated at some point
        # kept for reference on how to implement this feature
        # if t_max !== nothing && maximum(m[:climatedynamics, :TATM]) >= t_max
        #     while maximum(m[:climatedynamics, :TATM]) >= t_max
        #         update_param!(m, :MIU, m[:emissions, :MIU] + ([u < .99 for u in m[:emissions, :MIU]] .* 1/100))
        #         run(m)
        #     end
        # end

        outmat = Matrix{Float64}(undef, length(timeperiods), totalyearvars)  # Define an output matrix for allocation
        iter = 1

        # Populate the matrix with reshaped values
        for (comp, param) in zip(components, parameters)
            cols = prod(size(m[comp, param])[2:end])
            new_shape = (size(m[comp, param])[1], cols)
            outmat[:, iter:iter+cols-1] = reshape(m[comp, param], new_shape)
            iter += cols
        end

        return outmat
    end

    # Set up matrix of initial values and for holding optimal values
    initMat = init_gen()
    optparamMat = similar(initMat)

    # Adjust the indices for each variable - VERY AD HOC AND SHOULD BE REVISITED IN A FUTURE REVISION
    # local_varidx = [yearvaridx[1], yearvaridx[2], yearvaridx[3], yearvaridx[4][1:2], yearvaridx[5][1:2], yearvaridx[6][2:3]]

    # Small function to evaluate welfare in a model run
    function model_obj(model::Mimi.AbstractModel)
        return -(model[:welfare, :W])
    end
 
    # Backwards induction - The signature should be changed so the mutated input is first per Julia conventions
    function BIsol!(optparamMat, initMat, model, components, parameters, objective, timeperiods::Vector{<:Integer}, 
                    lower, upper, ineqConstraint, ineqConstraintid, yearvaridx; verbose=false)
        for year in reverse(timeperiods)
            BIsol!(optparamMat, initMat, model, components, parameters, objective, year, lower, upper, ineqConstraint, ineqConstraintid, yearvaridx, verbose=verbose)
        end
        return nothing
    end

    function BIsol!(optparamMat, initMat, model, components, parameters, objective, year::Integer, 
                    lower, upper, ineqConstraint, ineqConstraintid, yearvaridx; verbose=false)
        local_init = initMat[year, :]
        local_objective = baseobjective_year(model, components, parameters, objective, year)
        local_ineqcons = [x -> ineqConstraint[i](x, model, components, parameters, year) for i in eachindex(ineqConstraint)]
        local_lower = lower[year, :]
        local_upper = upper[year, :]

        optparamMat[year, :] = BoundedGradientDescent(local_objective, local_init, local_ineqcons, ineqConstraintid, yearvaridx, varFlags, bounds=[local_lower local_upper], maxiter=1e2, tol = [1e-6 for _ in eachindex(local_init)])

        robust_update_param_year!(model, components, parameters, year, optparamMat[year, :])
        run(model)

        return nothing
    end

    # Testing
    BIsol!(optparamMat, initMat, m_inst, components, parameters, model_obj, timeperiods, lower, upper, ineqConstraint, ineqConstraintid, yearvaridx)
    
    return optparamMat
end
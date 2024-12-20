#########################################################
# This file provides functions to set parameter values  #
# for the abatement functions in the GreenDICE model    #
#########################################################

# NOTICE: ALL CONTENTS OF THE FILE IS SUBJECT TO CHANGE
# THIS IS SIMPLY FOR INITIAL TESTING PURPOSES


"""
    abatement_calib_theta1_co2(;γ=fill(0.5, 188, 4), θ²=[2.6 2.6 2.6 2.6], backstop_price=558., init_decline=.01, late_decline=0.001)

Returns a matrix of calibrated values for θ¹, which is calibrated to match the marginal abatement costs determined by the `backstop_price`.

The `backstop_price` is assumed to be for 2050, decline `init_decline` percent per year before 2050 and by `late_decline` per year after 2050
"""
function abatement_calib_theta1_co2(years; γ=fill(0.5, length(years), 4), θ²=[2.6 2.6 2.6 2.6], backstop_price=558., init_decline=.01, late_decline=0.001)
    # First compute timepath for the backstop price - Note hardcoding of start and endpoints should be made dynamic in a future revision
    priceVec = [backstop_price * (n <= 0 ? (1 - init_decline)^n : (1 - late_decline)^n) for n in years .- 2050]

    # Then compute the associated time-varying component of the abatement cost function
    θ¹ = γ .* priceVec ./ θ² ./ 1000
    
    return θ¹
end

"""
    abatement_calib_theta_methane(;γ=fill(0.5, 188, 4), macdf = getharmsenmacdata())

Returns two matrices with calibrated values for θ₁ and θ₂ respectively for methane emissions.

The calibration uses the abatement data from Harmsen et al (2019) and fits the assumed abatement cost structure
to the data using a non-linear least squares approach.
"""
function abatement_calib_theta_methane(years; γ=fill(0.5, length(years), 4), θ²=[17., 5., 5.], macdf = getharmsenmacdata())
    macdf = macdf[:, [1, 2, 3, 5, 7]]   # Select only columnns with data for methane
    macdf."Cost" .*= 12/44 * 25     # 12/44 to go from tons of C to tons of CO2, 25 to go to tons of methane (GWP100)
    (theta1, theta2) = abatement_calib_estimation(macdf, γ, θ², years)

    init_decline = 1 .- (theta1[7, :] ./ theta1[1, :]).^(1/30)
    late_decline = 1 .- (theta1[end, :] ./ theta1[7, :]).^(1/50)

    θ₁ = permutedims(hcat([theta1[7, :] .* (n <= 0 ? (1 .- init_decline).^n : (1 .- late_decline).^n) for n in years .- 2050]...))

    θ₁ = hcat(θ₁, fill(0., size(θ₁)[1]))
    θ₂ = hcat(theta2..., 0.)
    
    return (θ₁, θ₂)
end

"""
    abatement_calib_theta_n2o(;γ=fill(0.5, 188, 4), macdf = getharmsenmacdata())

Returns two matrices with calibrated values for θ₁ and θ₂ respectively for nitrous oxide emissions.

The calibration uses the abatement data from Harmsen et al (2019) and fits the assumed abatement cost structure
to the data using a non-linear least squares approach.
"""
function abatement_calib_theta_n2o(years; γ=fill(0.5, length(years), 4), θ²=[60., 6., 6.], macdf = getharmsenmacdata())
    macdf = macdf[:, [1, 2, 4, 6, 8]]   # Select only columnns with data for nitrous oxide
    macdf."Cost" .*= 12/44 * 298    # 12/44 to go from tons of C to tons of CO2, 298 to go to tons of nitrous oxide (GWP100)
    (theta1, theta2) = abatement_calib_estimation(macdf, γ, θ², years, yearidx=[2025, 2020, 2020])  # NOTE - Drop 2020 manufacturing data as it makes the solution infeasible

    startidx = [2, 1, 1]    # Note that, because 2020 is dropped for manufacturing, theta1 values should be indexed differently

    init_decline = 1 .- [(theta1[7, n] ./ theta1[i, n]).^(1/((7-i)*5)) for (n, i) in enumerate(startidx)]
    late_decline = 1 .- (theta1[end, :] ./ theta1[7, :]).^(1/50)

    θ₁ = permutedims(hcat([theta1[7, :] .* (n <= 0 ? (1 .- init_decline).^n : (1 .- late_decline).^n) for n in years .- 2050]...))

    θ₁ = hcat(θ₁, fill(0., size(θ₁)[1]))
    θ₂ = hcat(theta2..., 0.)
    
    return (θ₁, θ₂)
end

"""
    abatement_calib_estimation(df, γ, theta2; yearidx=[2020, 2020, 2020])

Performs calibration of the θ₁ and θ₂ parameters respectively using the data in `df`

It is assumed that `theta2` contains the initial guesses for the θ₂ parameters.
These should be well-chosen, such that the 'true' parameters are close to these initial guesses.

The keyword argumetnt `yearidx` determines the initial data year for each of the sectors.
Since all abatement is assumed to be zero before 2020 per construction by Harmsen et el (2019),
the earliest year that can be feasibly chosen is 2020, which is assumed if nothing else is specified

Note that the emission intensities `γ` area assumed to be listed for the relevant gas
"""
function abatement_calib_estimation(df, γ, theta2, years; yearidx=[2020, 2020, 2020])
    costrange = eachindex(unique(df."Cost"))
    uniqueyears = unique(df[df."Year" .>= minimum(yearidx), "Year"])
    yearranges = [eachindex(uniqueyears[uniqueyears .>= t]) for t in yearidx]

    gammaidx = [n for n in eachindex(years)[years .∈ Ref(uniqueyears)]]   

    # Speaking of complete hacks, these values to correct for crop and livestock theta1 values are computed completely undocumented
    correctionVec = [1., 3.18, 4.21]    # Weighted price of crop-based and livestock-based foods respectively (in 2020)    

    sector_mats = [hcat(Matrix(df[df."Year" .>= yearidx[n], [2, n+2]]), [γ[gammaidx, n][t] for t in yearranges[n] for _ in costrange]) for n in 1:3]
    
    # This function computes the difference between the LHS and the RHS of the FOC for the minimum, and so should be zero at the optimum
    function exponentdiff(mat, val)
        gamma = unique(mat[:,3])
        T = 1:length(gamma)
        C = 1:Int(size(mat)[1]/length(gamma))
        cshift = length(C)
        MAC = mat[:,1]
        mu = mat[:,2]
        
        timeVec = [sum(MAC[rangeshift(C, (t - 1) * cshift)] .* mu[rangeshift(C, (t - 1) * cshift)].^(val - 1)) / sum(mu[rangeshift(C, (t - 1) * cshift)].^(2 * (val - 1))) for t in T]

        LHS = (timeVec).^2 .* [sum(mu[rangeshift(C, (t - 1) * cshift)].^(2 * (val - 1)) .+ val .* mu[rangeshift(C, (t - 1) * cshift)].^(2 * (val - 1)) .* log.(mu[rangeshift(C, (t - 1) * cshift)])) for t in T]
        
        RHS = timeVec .* [sum(MAC[rangeshift(C, (t - 1) * cshift)] .* (mu[rangeshift(C, (t - 1) * cshift)].^(val - 1) .+ val .* mu[rangeshift(C, (t - 1) * cshift)].^(val - 1) .* log.(mu[rangeshift(C, (t - 1) * cshift)]))) for t in T]

        res = (sum(LHS) - sum(RHS))

        return res
    end

    # This function computes the values of θ₁ given the data and a value of θ₂ based on the FOC for the minimum
    function calc_theta1(mat, theta2)
        gamma = unique(mat[:,3])
        T = 1:length(gamma)
        C = 1:Int(size(mat)[1]/length(gamma))
        cshift = length(C)
        MAC = mat[:,1]
        mu = mat[:,2]

        return [gamma[t] / (1e6 * theta2) * sum(MAC[rangeshift(C, (t - 1) * cshift)] .* mu[rangeshift(C, (t - 1) * cshift)].^(theta2 - 1)) / sum(mu[rangeshift(C, (t - 1) * cshift)].^(2 * (theta2 - 1))) for t in T]
    end

    # This loop goes through each sector and performs the estimation of the θ₁ and θ₂ values
    theta1 = Matrix{Float64}(undef, length(maximum(yearranges)), 3)
    for (i, mat) in enumerate(sector_mats)
        obj_func(val) = exponentdiff(mat, val) * 1e-4  # Define local objective function
        theta2[i] = NewtonRaphsonRoot(obj_func, theta2[i], [theta2[i] - 1, theta2[i] + 1], tol=1e-10)
        theta1range = rangeshift(yearranges[i], length(maximum(yearranges)) - length(yearranges[i]))
        theta1[theta1range,i] = calc_theta1(mat, theta2[i]) ./ correctionVec[i]
    end

    return (theta1, theta2)
end

"""
    abatement_calib_complete(years; <keyword arguments>)

NOTICE: TEMPORARY

Currently returns specified parameter values in suitable
dictionary

At some point this **should** be revisited to complete
a *proper* calibration routine
"""
function abatement_calib_complete(years; θᵐ¹=[0.67, 0., 0.], θᵐ²=[2.6, 17., 60.], gᶿᵐ=[-0.07, 0., 0.],    δᵐ=[-0.003, 0., 0.], γ=fill(0.5, length(years), 4, 3),
                                   θᶜ¹=[0., 1.1, 0.8], θᶜ²=[2.6, 5., 6.],   gᶿᶜ=[0., -0.03, -0.03], δᶜ=-[0., 0.008, 0.006],
                                   θˡ¹=[0., 1.1, 0.8], θˡ²=[2.6, 5., 6.],   gᶿˡ=[0., -0.03, -0.03], δˡ=-[0., 0.008, 0.006])

    macdf = getharmsenmacdata() # Read MAC data for non-CO2 gases                                
    θ₁ᶜᵒ² = abatement_calib_theta1_co2(years, γ=γ[:,:,1], θ²=[θᵐ²[1] θᶜ²[1] θˡ²[1] 2.6])   # Get calibrated values for θ¹ for CO2
    (θ₁ᶜʰ⁴, θ₂ᶜʰ⁴) = abatement_calib_theta_methane(years, γ=γ[:,:,2], θ²=[θᵐ²[2], θᶜ²[2], θˡ²[2]], macdf=macdf)    # Get calibrated θ values for methane
    (θ₁ⁿ²ᵒ, θ₂ⁿ²ᵒ) = abatement_calib_theta_n2o(years, γ=γ[:,:,3], θ²=[θᵐ²[3], θᶜ²[3], θˡ²[3]], macdf=macdf)    # Get calibrated θ values for nitrous oxide

    θ¹ = reshape([θ₁ᶜᵒ² θ₁ᶜʰ⁴ θ₁ⁿ²ᵒ], size(γ))  # Collect θ¹ values in a single matrix  (time, sector, ghg)
    θ² = [[θᵐ²[1], θᶜ²[1], θˡ²[1], 2.6] vec(θ₂ᶜʰ⁴) vec(θ₂ⁿ²ᵒ)]  # Collect θ² values in a single matrix (sector, ghg)

    θ  = Dict((:welfare, :θ¹) => θ¹, (:welfare, :θ²) => θ²) # Collect values in a dictionary which is returned
    return θ
end
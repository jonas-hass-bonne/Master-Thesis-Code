#######################################################
# This file provides functions to fetch data used for #
# calibrating various parameters in the model         #
#######################################################

using DataFrames
using CSV
using XLSX

######################################################################
### NOTICE: All the docstrings for the functions don't link to the ###
#### documentation for the other functions which a function will #####
##### implicitly call, such as finding the data directory. This ######
##### should be added to all the relevant docstrings in a future #####
#################### revisison of the repository #####################
######################################################################

"""
    find_datadir(maxiter::Int=5) -> String
Identify the folder called "data", which should contain the data for the model. 

The search is done by looking in the current directory, followed by each
directory above the current one in sequence until the "data"
folder is found or maximum iterations are reached
"""
function find_datadir(maxiter::Int=5)
    curdir = pwd()
    subdirs = readdir(curdir)
    datapresent = "data" in subdirs
    datapresent && return curdir * "/data/"
    iter = 1
    while !datapresent
        curdir *= "/.."
        iter += 1
        subdirs = readdir(curdir)
        datapresent = "data" in subdirs
        iter >= maxiter && error("the data folder was not found after looking through " * string(maxiter) * " directories")
    end
    return curdir * "/data/"
end

# For now, we just create a dictionary containing a mapping from IPCC categories to relevant model Sectors
# This should perhaps be changed to be more flexible and explicit in a future revision
const ipcc2sectormap = Dict(["Agriculture - Plants" => ["3.C.2", "3.C.3", "3.C.4", "3.C.5", "3.C.7", "5.A"], "Agriculture - Animals" => ["3.A.1", "3.A.2", "3.C.6"]])

"""
    mapfao2wbcountries(datadir::AbstractString=find_datadir())
Return a dictionary mapping from FAO countries to World Bank countries

The keys of the dictionary are the FAO countries and the values are the corresponding World Bank countries
"""
function mapfao2wbcountries(datadir::AbstractString=find_datadir())
    # Read CSV file with the data
    df = CSV.read(datadir * "FAOSTAT/FAOSTAT_Capital_Data.csv", DataFrame, select=[2, 5, 6])  # FAOSTAT capital data
    df2 = CSV.read(datadir * "FAOSTAT/FAOSTAT_Crop_Price_Data.csv", DataFrame, select=[2,3,4,5,7])
    df3 = CSV.read(datadir * "FAOSTAT/SUA/FAOSTAT_Crop_SUA_2010_Data.csv", DataFrame, select=[2, 3, 4, 5, 6])
    for year in 2011:2022
        df3 = vcat(df3, CSV.read(datadir * "FAOSTAT/SUA/FAOSTAT_Crop_SUA_" * string(year) * "_Data.csv", DataFrame, select=[2, 3, 4, 5, 6]))
    end
    wdidf = CSV.read(datadir * "World Bank/World_Bank_WDI_GDP_Data.csv", DataFrame, footerskip=5)

    # Create list of countries from the two data sources
    faocountries = sort(unique(vcat(unique(df."Area"), unique(df2."Area"), unique(df3."Area"))))
    wbcountries = unique(wdidf[:, "Country Name"])

    # Perform a first-pass simple name matching
    match = faocountries[faocountries .∈ Ref(wbcountries)]
    countrymap = Dict(match .=> match)

    # Register the countries not captured by the first match
    nonmatch = faocountries[.!(faocountries .∈ Ref(wbcountries))]
    # Perform cross-reference search for different names for the same country
    for n in nonmatch
        if !(n ∈ ["Belgium-Luxembourg", "China, Hong Kong SAR", "China, Macao SAR", "China, Taiwan Province of","Congo"])
            plaincheck = occursin.(wbcountries, Ref(n))    # Check if any non-matched countries occur in current country
            reversecheck = occursin.(Ref(n), wbcountries)  # Check if current country occurs in any non-matched countries
            check = plaincheck .| reversecheck
            if any(check)
                countrymap[n] = wbcountries[check][1]
            end
        end
    end

    # Perform manual mapping for the remaining countries
    nonmatch = nonmatch[.!(nonmatch .∈ Ref(keys(countrymap)))]
    # Anguilla is not recognized in the World Bank set of countries, 
    # so we assume that their values should be combined with St. Kitts and Nevis (Both use East Caribbean Dollars)
    countrymap[nonmatch[nonmatch .== "Anguilla"][1]] = wbcountries[wbcountries .== "St. Kitts and Nevis"][1]
    # Identifying Belgium-Luxembourg is nigh-on impossible, so we map it to Belgium 
    countrymap[nonmatch[nonmatch .== "Belgium-Luxembourg"][1]] = wbcountries[wbcountries .== "Belgium"][1]
    # China and the surrounding regions have... complicated relationships, so we'll perform manual assignment
    countrymap[nonmatch[nonmatch .== "China, Hong Kong SAR"][1]] = wbcountries[wbcountries .== "Hong Kong SAR, China"][1]
    countrymap[nonmatch[nonmatch .== "China, Macao SAR"][1]] = wbcountries[wbcountries .== "Macao SAR, China"][1]
    # The World Bank no longer recognizes Taiwan as an independent region, so we map them to China and note that they should be dropped in general
    countrymap[nonmatch[nonmatch .== "China, Taiwan Province of"][1]] = wbcountries[wbcountries .== "China"][1]
    # Congo Republic is just referred to as Congo in FAOSTAT, but abbreviated to Congo, Rep. in the World Bank
    countrymap[nonmatch[nonmatch .== "Congo"][1]] = wbcountries[wbcountries .== "Congo, Rep."][1]
    # Cook Islands are not recognized in the World Bank, we designate them under New Zealand (Both use New Zealand Dollars)
    countrymap[nonmatch[nonmatch .== "Cook Islands"][1]] = wbcountries[wbcountries .== "New Zealand"][1]
    # Cote d'Ivoire uses slightly different spelling in the two series
    countrymap[nonmatch[nonmatch .== "Côte d'Ivoire"][1]] = wbcountries[wbcountries .== "Cote d'Ivoire"][1]
    # Democratic People's Republic of Korea is spelled out in FAOSTAT but abbreviated in World Bank
    countrymap[nonmatch[nonmatch .== "Democratic People's Republic of Korea"][1]] = wbcountries[wbcountries .== "Korea, Dem. People's Rep."][1]
    # Democratic Republic of the Congo is spelled out in FAOSTAT but abbreviated in World Bank
    countrymap[nonmatch[nonmatch .== "Democratic Republic of the Congo"][1]] = wbcountries[wbcountries .== "Congo, Dem. Rep."][1]
    # Similar case for Iran
    countrymap[nonmatch[nonmatch .== "Iran (Islamic Republic of)"][1]] = wbcountries[wbcountries .== "Iran, Islamic Rep."][1]
    # Kyrgyzstan is registered as the Kyrgyz Republic in World Bank
    countrymap[nonmatch[nonmatch .== "Kyrgyzstan"][1]] = wbcountries[wbcountries .== "Kyrgyz Republic"][1]
    # Lao People's Democratic Republic is abbreviated in World Bank
    countrymap[nonmatch[nonmatch .== "Lao People's Democratic Republic"][1]] = wbcountries[wbcountries .== "Lao PDR"][1]
    # Similar for Micronesia
    countrymap[nonmatch[nonmatch .== "Micronesia (Federated States of)"][1]] = wbcountries[wbcountries .== "Micronesia, Fed. Sts."][1]
    # Palestine is referred to as West Bank and Gaza in World Bank
    countrymap[nonmatch[nonmatch .== "Palestine"][1]] = wbcountries[wbcountries .== "West Bank and Gaza"][1]
    # Repbulic of Korea is abbreviated in World Bank
    countrymap[nonmatch[nonmatch .== "Republic of Korea"][1]] = wbcountries[wbcountries .== "Korea, Rep."][1]
    # Reunion is not recognized in the World Bank, we designate them under France (Both use Euros)
    countrymap[nonmatch[nonmatch .== "Réunion"][1]] = wbcountries[wbcountries .== "France"][1]
    # St. Kitt and Nevis, St. Lucia and St. Vincent and the Grenadines are present in both sets
    countrymap[nonmatch[nonmatch .== "Saint Kitts and Nevis"][1]] = wbcountries[wbcountries .== "St. Kitts and Nevis"][1]
    countrymap[nonmatch[nonmatch .== "Saint Lucia"][1]] = wbcountries[wbcountries .== "St. Lucia"][1]
    countrymap[nonmatch[nonmatch .== "Saint Vincent and the Grenadines"][1]] = wbcountries[wbcountries .== "St. Vincent and the Grenadines"][1]
    # Slovakia is registered as the Slovak Republic in World Bank
    countrymap[nonmatch[nonmatch .== "Slovakia"][1]] = wbcountries[wbcountries .== "Slovak Republic"][1]
    # Turkiye is spelled differently between the two
    countrymap[nonmatch[nonmatch .== "Türkiye"][1]] = wbcountries[wbcountries .== "Turkiye"][1]
    # Bolivarian Republic of Venezuela is abbreviated in World Bank
    countrymap[nonmatch[nonmatch .== "Venezuela (Bolivarian Republic of)"][1]] = wbcountries[wbcountries .== "Venezuela, RB"][1]

    return countrymap
end

"""
    mapun2wbcountries(datadir::AbstractString=find_datadir())
Return a dictionary mapping from UN countries to World Bank countries

The keys of the dictionary are the UN countries and the values are the corresponding World Bank countries
"""
function mapun2wbcountries(datadir::AbstractString=find_datadir())
    # Read CSV file with the data
    df = CSV.read(datadir * "UNSD/GDP_shares.csv", DataFrame, missingstring="...")  # UNSD GDP share data
    wdidf = CSV.read(datadir * "World Bank/World_Bank_WDI_GDP_Data.csv", DataFrame, footerskip=5, missingstring="..")

    # Create list of countries from the two data sources
    uncountries = unique(df[:, "Country/Area"])
    wbcountries = unique(wdidf[:, "Country Name"])

    # Perform a first-pass simple name matching
    match = uncountries[uncountries .∈ Ref(wbcountries)]
    countrymap = Dict(match .=> match)

    # Register the countries not captured by the first match
    nonmatch = uncountries[.!(uncountries .∈ Ref(wbcountries))]

    # Perform cross-reference search for different names for the same country
    for n in nonmatch   # Loop through countries with no match
        plaincheck = occursin.(wbcountries, Ref(n))    # Check if any World Bank countries occur in current country
        reversecheck = occursin.(Ref(n), wbcountries)  # Check if current country occurs in any World Bank countries
        check = plaincheck .| reversecheck
        if any(check)
            countrymap[n] = wbcountries[check][1]
        end
    end

    # Correct for incorrect mapping of Hong Kong and Macao
    countrymap["China, Hong Kong SAR"] = "Hong Kong SAR, China"
    countrymap["China, Macao Special Administrative Region"] = "Macao SAR, China"
    # Correct for incorrect mapping of UK
    countrymap["United Kingdom of Great Britain and Northern Ireland"] = "United Kingdom"
    # Correct for incorrect mapping of the Republic of Congo
    countrymap["Congo"] = "Congo, Rep."

    # Perform manual mapping for the remaining countries
    nonmatch = nonmatch[.!(nonmatch .∈ Ref(keys(countrymap)))]
    # St. Kitts and Nevis, St. Lucia and St. Vincent and the Grenadines are present in both sets
    countrymap[nonmatch[nonmatch .== "Saint Kitts and Nevis"][1]] = wbcountries[wbcountries .== "St. Kitts and Nevis"][1]
    countrymap[nonmatch[nonmatch .== "Saint Lucia"][1]] = wbcountries[wbcountries .== "St. Lucia"][1]
    countrymap[nonmatch[nonmatch .== "Saint Vincent and the Grenadines"][1]] = wbcountries[wbcountries .== "St. Vincent and the Grenadines"][1]
    # Anguilla and Montserrat are not recognized in the World Bank set of countries, 
    # so we assume that their values should be combined with St. Kitts and Nevis (All use East Caribbean Dollars)
    countrymap[nonmatch[nonmatch .== "Anguilla"][1]] = wbcountries[wbcountries .== "St. Kitts and Nevis"][1]
    countrymap[nonmatch[nonmatch .== "Montserrat"][1]] = wbcountries[wbcountries .== "St. Kitts and Nevis"][1]
    # Cook Islands are similarly not recognized in the World Bank set of countries, we combine their values with New Zealand
    countrymap[nonmatch[nonmatch .== "Cook Islands"][1]] = wbcountries[wbcountries .== "New Zealand"][1]
    # Curacao uses slightly different spelling in the two series
    countrymap[nonmatch[nonmatch .== "Curaçao"][1]] = wbcountries[wbcountries .== "Curacao"][1]
    # Cote d'Ivoire uses slightly different spelling in the two series
    countrymap[nonmatch[4]] = wbcountries[wbcountries .== "Cote d'Ivoire"][1]
    # Democratic People's Republic of Korea is abbreviated in World Bank
    countrymap[nonmatch[5]] = wbcountries[wbcountries .== "Korea, Dem. People's Rep."][1]
    # Similar case for Democratic Republic of Congo
    countrymap[nonmatch[6]] = wbcountries[wbcountries .== "Congo, Dem. Rep."][1]
    # Similar case for Iran
    countrymap[nonmatch[10]] = wbcountries[wbcountries .== "Iran, Islamic Rep."][1]
    # Kyrgyzstan is registered as the Kyrgyz Republic in World Bank
    countrymap[nonmatch[11]] = wbcountries[wbcountries .== "Kyrgyz Republic"][1]
    # Lao People's Democratic Republic is abbreviated in World Bank
    countrymap[nonmatch[12]] = wbcountries[wbcountries .== "Lao PDR"][1]
    # Similar for Micronesia
    countrymap[nonmatch[13]] = wbcountries[wbcountries .== "Micronesia, Fed. Sts."][1]
    # Republic of Korea is shortened in the World Bank countries
    countrymap[nonmatch[15]] = wbcountries[wbcountries .== "Korea, Rep."][1]
    # Palestine is referred to as West Bank and Gaza in World Bank
    countrymap[nonmatch[nonmatch .== "State of Palestine"][1]] = wbcountries[wbcountries .== "West Bank and Gaza"][1]
    # Slovakia is registered as the Slovak Republic in World Bank
    countrymap[nonmatch[nonmatch .== "Slovakia"][1]] = wbcountries[wbcountries .== "Slovak Republic"][1]
    # Turkiye is spelled differently between the two
    countrymap[nonmatch[nonmatch .== "Türkiye"][1]] = wbcountries[wbcountries .== "Turkiye"][1]
    # Venezuela is abbreviated in World Bank
    countrymap[nonmatch[22]] = wbcountries[wbcountries .== "Venezuela, RB"][1]

    # Mapping former countries into current country constellations
    nonmatch = nonmatch[.!(nonmatch .∈ Ref(keys(countrymap)))]
    # Former Czechoslovakia is mapped to Slovakia
    countrymap[nonmatch[nonmatch .== "Former Czechoslovakia"][1]] = wbcountries[wbcountries .== "Slovak Republic"][1]
    # Former USSR is mapped to Russian Federation
    countrymap[nonmatch[nonmatch .== "Former USSR"][1]] = wbcountries[wbcountries .== "Russian Federation"][1]
    # The two previous Yemeni states are jointly mapped to the Yemen Republic
    countrymap[nonmatch[nonmatch .== "Yemen: Former Democratic Yemen"][1]] = wbcountries[wbcountries .== "Yemen, Rep."][1]
    countrymap[nonmatch[nonmatch .== "Yemen: Former Yemen Arab Republic"][1]] = wbcountries[wbcountries .== "Yemen, Rep."][1]
    # Former Yugoslavia is a tough match, for starters we will map everything to Serbia
    countrymap[nonmatch[nonmatch .== "Former Yugoslavia"][1]] = wbcountries[wbcountries .== "Serbia"][1]

    return countrymap
end

"""
    getwealthaccountsdata(datadir::AbstractString=find_datadir())

Obtain DataFrame with global capital stocks from the Wealth Accounts CSV file in the data folder
"""
function getwealthaccountsdata(datadir::AbstractString=find_datadir())
    # Read the CSV file with the data - Last 5 rows are skipped since they contain no data
    df = CSV.read(datadir * "World Bank/World_Bank_Produced_Capital_Data.csv", DataFrame, footerskip=5, missingstring="..")
    exchangedf = CSV.read(datadir * "World Bank/World_Bank_Exchange_Rate_Data.csv", DataFrame, footerskip=5, missingstring="..")
    wdidf = CSV.read(datadir * "World Bank/World_Bank_WDI_GDP_Data.csv", DataFrame, footerskip=5, missingstring="..")
    agcapdf = getagcapdata()

    # Zimbabwe changed to USD in 2009-2019 (suspension of own currency due to hyperinflation)
    exchangedf[exchangedf."Country Name" .== "Zimbabwe" .&& exchangedf."Time" .∈ Ref([2009:2019...]), 3] .= 1.

    # Euro countries don't have individual exchange rates, but use the euro exchange rate instead
    euro_countries = ["Austria", "Belgium", "Croatia", "Cyprus", "Estonia", "Finland", "France", "Germany", "Greece", "Ireland", 
                      "Italy", "Latvia", "Lithuania", "Luxembourg", "Malta", "Netherlands", "Portugal", "Slovak Republic", "Slovenia", "Spain"]
    missing_euro_idx = exchangedf."Country Name" .∈ Ref(euro_countries) .&& ismissing.(exchangedf[:, 3]) # Identify EU countries with missing exchange rates
    eugdf = groupby(exchangedf[missing_euro_idx, :], "Time")    # Group them by year
    refgdf = groupby(exchangedf[exchangedf."Country Name" .== "Euro area", :], "Time")  # Group euro area exchange rate by year
    years = unique(exchangedf."Time")
    for sheet in eugdf # For each year, set the exchange rate in EU countries to that of the Euro area 
        year = unique(sheet."Time")
        exchangerate = refgdf[years .== year][1][1,3]    
        sheet[:, 3] .= exchangerate
        exchangedf[missing_euro_idx .&& exchangedf."Time" .== year, 3] .= exchangerate
    end
    # Note: There is some more missing stuff about old East-bloc countries, but we plow ahead for now ignoring this

    # Strategy - Convert current US to LCU and then to international dollars at PPP, then correcting for inflation
    # Since some exchange rates appear to be quite unreasonable, we skip the exchange rate step for now
    # xchangecombine = innerjoin(df, exchangedf, on=["Time", "Country Name"]) # Note: Currently 17 missing values in this dataset
    # capdf = combine(groupby(xchangecombine, ["Time", "Country Name"]), [3, 4] => ByRow(*) => "Capital (Current LCU)")
    pppcombine = innerjoin(df, wdidf, on=["Time", "Country Name"])  # Note that it should combine capdf if correcting for exchange rates
    pppconvert(cap, constant, current, conv) = cap .* (constant./current) # .* conv # This last part should be added if converting from LCU
    pppcapdf = combine(groupby(pppcombine, ["Time", "Country Name"]), [3, 4, 5, 6] => pppconvert => "Capital (Constant 2021 international dollars)")

    # Sum the value across countries
    df_out = combine(groupby(pppcapdf, "Time"), 3 => (x -> sum(skipmissing(x)) * 1e-12) => "Capital (Constant 2021 International Dollars)")
    rename!(df_out, "Time" => "Year")

    # Correct for agricultural capital
    df_out[:,2] -= agcapdf."Total"[1:end-2] # Agricultural capital has 2 more years of data

    return df_out
end

"""
    getwdidata(datadir::AbstractString=find_datadir(), countrymap::AbstractDict=mapun2wbcountries())
Obtain DataFrame with GDP in constant 2021, PPP dollars from the World Development Indicators CSV file in the data folder
"""
function getwdidata(datadir::AbstractString=find_datadir(), countrymap::AbstractDict=mapun2wbcountries())
    # Read the CSV file with the data - Last 5 rows are skipped since they contain no data
    df = CSV.read(datadir * "World Bank/World_Bank_WDI_GDP_Data.csv", DataFrame, footerskip=5, missingstring="..")
    sharedf = CSV.read(datadir * "UNSD/GDP_shares.csv", DataFrame, missingstring="...")

    # Map between World Bank and United Nations country definitions
    gdf = groupby(sharedf, "Country/Area")
    mapfunc(country) = [countrymap[i] for i in country]
    mappedsharedf = transform(gdf, "Country/Area" => mapfunc => "Country Name")

    # Only keep countries for which a mapping exists and years present in both datasets
    df = df[df."Country Name" .∈ Ref(unique(mappedsharedf."Country Name")), :]
    df = df[df."Time" .∈ Ref(unique(mappedsharedf."Year")), :]
    mappedsharedf = mappedsharedf[mappedsharedf."Country Name" .∈ Ref(unique(df."Country Name")), :]
    mappedsharedf = mappedsharedf[mappedsharedf."Year" .∈ Ref(unique(df."Time")), :]

    # Drop the former countries since they are practically not present
    dropidx = mappedsharedf."Country/Area" .== "Former USSR" .||  
              mappedsharedf."Country/Area" .== "Former Czechoslovakia" .||
              mappedsharedf."Country/Area" .== "Former Yugoslavia" .||
              mappedsharedf."Country/Area" .== "Yemen: Former Democratic Yemen" .||
              mappedsharedf."Country/Area" .== "Yemen: Former Yemen Arab Republic" .||
              mappedsharedf."Country/Area" .== "Former Ethiopia" .||
              mappedsharedf."Country/Area" .== "Former Netherlands Antilles"
    # Drop the small island nations which are missing
    dropidx = dropidx .||
              mappedsharedf."Country/Area" .== "Anguilla" .||
              mappedsharedf."Country/Area" .== "Montserrat" .||
              mappedsharedf."Country/Area" .== "Cook Islands"

    # Drop some more small island nations
    dropidx = dropidx .||
              mappedsharedf."Country/Area" .== "United Republic of Tanzania: Zanzibar"

    mappedsharedf = mappedsharedf[.!(dropidx), :]

    # Combine the values for Former Sudan and Sudan
    mappedsharedf[mappedsharedf."Country/Area" .== "Sudan" .&& mappedsharedf."Year" .<= 2007, 3:end] = mappedsharedf[mappedsharedf."Country/Area" .== "Former Sudan" .&& mappedsharedf."Year" .<= 2007, 3:end]
    mappedsharedf = mappedsharedf[mappedsharedf."Country/Area" .!= "Former Sudan", :]   # Drop Former Sudan values

    # Join the relevant values together in one DataFrame

    dfcombined = innerjoin(df, mappedsharedf, on=["Country Name", "Time" => "Year"])

    gdf = groupby(dfcombined, "Time")

    # Column 3 is constant international dollars, 8 is share of agriculture in gdp
    aggregator(gdp, share) = sum(skipmissing(gdp .* (100 .- share)./100)) * 1e-12
    df_out = combine(gdf, [3, 8] => aggregator => "Industrial Output")
    rename!(df_out, "Time" => "Year")
    
    return df_out
end

"""
    getfaolanddata(datadir::AbstractString=find_datadir())
Obtain DataFrame with land usage from the United Nation Food and Agriculture Organisation
aggregated to the model sectors

Note that the aggregation procedure changes in 2001, as data for temporary meadows and pastures becomes available.

These are then removed from the plant-based sector and added to the animal-based sector,
which gives rise to a clear data-break in this year as a result of the changed definition.
"""
function getfaolanddata(datadir::AbstractString = find_datadir())
    # Read CSV files with the data
    df = CSV.read(datadir * "FAOSTAT/FAOSTAT_LU_Data.csv", DataFrame, header=1, select=[4,5,6])

    # Aggregation to model sectors - Generally cropland for plant-based agriculture and meadows and pastures for livestock-based agriculture
    # from 2001 onwards, we remove temporary meadows and pastures from cropland and add them to livestock-based agriculture
    # Ecosystem land is taken to be naturally regenerating forests
    # Change units from thousand to billion hectares as well
    
    df_out = DataFrame(:Year => unique(df.Year))
    df_out[!, "Plant-based agriculture"] = df[df.Item .== "Cropland", "Value"] .* 1e-6
    df_out[!, "Animal-based agriculture"] = df[df.Item .== "Permanent meadows and pastures", "Value"] .* 1e-6
    # For naturally regenerating forest, we only have values from 1990, so we insert missing values before then
    df_out[!, "Ecosystems"] = vcat(fill(missing, length(df_out.Year) - sum(df.Item .== "Naturally regenerating forest")), df[df.Item .== "Naturally regenerating forest", "Value"] .* 1e-6)
    # Then we correct for temporary meadows and pastures in years where we have data for this
    year_idx = df[df.Item .== "Temporary meadows and pastures", "Year"]
    df_out[df_out.Year .∈ Ref(year_idx), "Plant-based agriculture"] .-= df[df.Item .== "Temporary meadows and pastures", "Value"] .* 1e-6
    df_out[df_out.Year .∈ Ref(year_idx), "Animal-based agriculture"] .+= df[df.Item .== "Temporary meadows and pastures", "Value"] .* 1e-6
    
    return df_out
end

"""
    getilodata(datadir::AbstractString=find_datadir(), restrictmissing::Bool=false, startyear::Integer=1990)
Obtain DataFrame with employment from the International Labour Organization

`restrictmissing` is a boolean restricting the sample to countries with no missing values across all years

`startyear` is an integer restricting the sample to years equal to years equal to or later than `startyear`
"""
function getilodata(datadir::AbstractString = find_datadir(), restrictmissing::Bool=false, startyear::Integer=1990)
    # Read CSV file with the data
    df = CSV.read(datadir * "ILO/ILO_Employment_Data.csv", DataFrame, select=[1, 5, 6, 7])
    rename!(df, ["Country", "Variable", "Year", "Value"])   # Relabel the columns
    df[:,"Variable"] = SubString.(df[:,"Variable"], 35) # Only keep the useful (Aka the differing) part of the variable name
    select!(df, ["Year", "Country", "Variable", "Value"])   # Reorder the columns
    df = df[df[:, "Year"] .>= startyear, :] # Restrict sample time to later than or equal to startyear

    if restrictmissing  # Restrict sample to countries with data for all variables in all years
        # Check if all years are observed for each variable across countries
        gdf = groupby(df, ["Country", "Variable"])
        countryidx = combine(gdf, "Year" => (x -> all(unique(df[:, "Year"]) .∈ Ref(x))) => "Select")
        # Then register which countries have observations for all variables in all years
        gdf = groupby(countryidx, "Country")
        countryidx = combine(gdf, "Select" => all => "Select")
        countryidx = countryidx[countryidx[:, "Select"], "Country"] # Obtain list of countries with full observations
        df[df[:, "Country"] .∈ Ref(countryidx), :]  # Restrict sample to countries with full observations
    end

    gdf = groupby(df, ["Year", "Variable"])   # Group on years and variables
    df_transformed = combine(gdf, "Value" => sum => "Total")    # Compute totals across countries for each variable in each year

    # Reshape the DataFrame to be in the same style as other DataFrames
    gdf = groupby(df_transformed, "Variable")   # Group by variables
    # Join together the totals column for each group
    df_out = innerjoin([group[:, ["Year", "Total"]] for group in gdf]..., on="Year", makeunique=true)
    rename!(df_out, ["Year", "Total", "Agriculture", "Non-agriculture"])    # Rename the columns
    df_out[:, Not("Year")] .*= 1e-6 # Change unit to billions

    return df_out
end

"""
    getpopdata(datadir::AbstractString=find_datadir())
Obtain DataFrame with population from the World Bank
"""
function getpopdata(datadir::AbstractString = find_datadir(); aggregate=true)
    # Read CSV file with the data - Last 5 rows are skipped since they contain no data
    df = CSV.read(datadir * "World Bank/World_Bank_Population_Data.csv", DataFrame, footerskip=5, missingstring = "..")

    if aggregate
        gdf = groupby(df, "Time")   # Group data by year

        df_out = combine(gdf, names(df)[3:end] => ByRow((x...) -> sum(skipmissing(x))) => "Population") # Sum population each year
        rename!(df_out, "Time" => "Year")   # Rename year/time column
        df_out.Population .*= 1e-9  # Change units to billions
    else
        df_out = DataFrame(vcat([hcat(t, c, df[df."Time" .== t, c]) for t in df."Time" for c in names(df)[3:end]]...), ["Year", "Country", "Population"])
        df_out."Population" .*= 1e-6   # Change units to millions
    end

    return df_out
end

"""
    getpopprojections(datadir::AbstractString = find_datadir())

Obtain a DataFramw with population projections from the United Nations Population Division
"""
function getpopprojections(datadir::AbstractString = find_datadir(); variant="Medium")
    sheet = variant * " variant"
    basedf = DataFrame(XLSX.readdata(datadir * "UNSD/WPP2024_POP_F01_1_POPULATION_SINGLE_AGE_BOTH_SEXES.xlsx", sheet, "A17:DH94"), :auto)
    rename!(basedf, string.([values(basedf[1,:])...]))   # Name columns according to first row
    basedf = basedf[2:end, :]   # Drop the first row
    df = basedf[:,11:end]   # Drop unnecesary columns (i.e only keep year and data columns)
    df_out = transform(df, names(df)[2:end] => ByRow(+) => "Population")
    select!(df_out, ["Year", "Population"]) # Keep only total population column
    df_out."Population" .*= 1e-6    # Convert population to billions (original measurement is thousands)

    return df_out
end

"""
    getagcapdata(datadir::AbstractString=find_datadir(), countrymap::AbstractDict=mapfao2wbcountries(), restrictmissing::Bool=false)
Obtain DataFrame with agricultural capital stocks from the United Nation Food and Agriculture Organisation
"""
function getagcapdata(datadir::AbstractString = find_datadir(), countrymap::AbstractDict=mapfao2wbcountries(), restrictmissing::Bool=false)
    # Read CSV files with the data
    df = CSV.read(datadir * "FAOSTAT/FAOSTAT_Capital_Data.csv", DataFrame, header=1, select=[2, 5, 6])  # FAOSTAT capital data
    wdidf = CSV.read(datadir * "World Bank/World_Bank_WDI_GDP_Data.csv", DataFrame, footerskip=5, missingstring="..")
    
    # Group the FAOSTAT DataFrame by countries
    gdf = groupby(df, ["Area", "Year"])

    # Define a local function to convert LCU to constant 2021 international dollars measured at PPP
    function currency_convert(year, country, value)
        # Extract the country in question from the country column
        country = unique(country)[1]    # Assume that passed column is grouped on countries
        # Extract the year-specific conversion factors for the given country
        rowidx = (wdidf[:, "Country Name"] .== countrymap[country]) .& (wdidf[:, "Time"] .∈ Ref(year))
        convfactor = wdidf[rowidx, "PPP conversion factor, GDP (LCU per international \$)"]
        # Set the values for the years with missing conversion factors as missing, otherwise compute the value in current international dollars
        curval = wdidf[rowidx, "GDP, PPP (current international \$)"]
        constval = wdidf[rowidx, "GDP, PPP (constant 2021 international \$)"]
        value = ifelse.(.!(ismissing.(convfactor)), (value ./ convfactor) .* (constval ./ curval), missing)
        
        return value
    end
    
    # Use the function to convert LCU to constant international dollars for each country and each year
    transform!(gdf, ["Year", "Area", "Value"] => currency_convert => "Value")

    # Then sum values for all the countries together to get global agricultural capital stocks in trillion constant 2021 international dollars
    if restrictmissing  # Perform sample selection procedure if countries with missing values should be dropped
        gdf = groupby(df, "Area")   # Group by countries
        # For each country, check if there are no missing values across all years
        areaidx = combine(gdf, "Value" => (x -> !any(ismissing.(x))) => "Select")
        areaidx = areaidx[areaidx[:, "Select"], "Area"] # Get a list of countries with no missing data
        df = df[df[:, "Area"] .∈ Ref(areaidx), :]   # Keep only countries with no missing data
    end
    gdf = groupby(df, "Year")

    df_out = combine(gdf, "Value" => (x -> sum(skipmissing(x)) .* 1e-6) => "Total")

    return df_out
end

##################################################
# Add some documentation for these at some point #
##################################################

################################################
### FUNCTIONS FOR LOADING RCMIP RELATED DATA ###
################################################

"""
    getrcmipemissiondata(datadir::AbstractString = find_datadir())

Obtain a DataFrame with emission data from the RCMIP database
"""
function getrcmipemissiondata(datadir::AbstractString = find_datadir())
    # Read CSV file with the data
    df = CSV.read(datadir * "RCMIP/rcmip-emissions-annual-means-v5-1-0.csv", DataFrame, 
                    transpose=true, select=[1, 2480, 2464, 2547], header=5, skipto=8, limit=265)
    select!(df, 1, 3, 2, 4) # Reorder the columns 
    rename!(df, ["Year", "Gt CO2/year", "Mt CH4/year", "Mt N2O/year"])  # Rename the columns
 
    # Rescale emissions to Gt CO2/year and Mt N2O/year (model variable)
    df[!, [2, 4]] .*= 1e-3
    return df
end

"""
    getrcmipconcentrationdata(datadir::AbstractString = find_datadir())

Obtain a DataFrame with concentration data from the RCMIP database
"""
function getrcmipconcentrationdata(datadir::AbstractString = find_datadir())
    # Read CSV file with the data
    df = CSV.read(datadir * "RCMIP/rcmip-concentrations-annual-means-v5-1-0.csv", DataFrame,
                    transpose=true, select=[1, 2062, 2061, 2103], header=4, skipto=8, limit=315)
    select!(df, 1, 3, 2, 4) # Reorder the columns
    rename!(df, ["Year", "CO2 (ppm)", "CH4 (ppb)", "N2O (ppb)"])    # Rename the columns
    return df
end

################################################################################
### FUNCTIONS FOR LOADING DATA FROM FAOSTAT ON CROP AND LIVESTOCK PRODUCTION ###
################################################################################

# NOTES FOR BOTH THE CROP AND LIVESTOCK DATA FUNCTIONS
# At some point they should be altered to address the databreak in 2013
# and potentially be stitched together with the 2013 data or have
# a way of obtaining both datasets for further computations i.e. computing emission intensities
# estimating trends etc.

# Also, some extra documentation for the functions would likely not be entirely amiss

"""
    getfaocropproductiondata(datadir::AbstractString=find_datadir())
Obtain a DataFrame with some data on crop production
"""
function getfaocropproductiondata(datadir::AbstractString=find_datadir())
    # Read CSV file with the data
    df = CSV.read(datadir * "FAOSTAT/FAOSTAT_Crop_Production_Data.csv", DataFrame, select=[3, 4, 5, 6, 7])

    # In theory, there should probably be some smart catching mechanism here
    # For now, we make an ad-hoc hard-coded resolution, removing known non-food items
    idx_vec = .!("Cottonseed" .== df.Item .|| "Palm kernels" .== df.Item .|| "Alcohol, Non-Food" .== df.Item)
    df = df[idx_vec, :]

    # Remove honey from the dataset - This is a personal judgement that it does not belong here
    idx_vec = .!("Honey" .== df.Item)
    df = df[idx_vec, :]
    
    # Function to calculate the caloric density using the accurate per capita measurements
    # Note: While FAOSTAT claim that food supply is reported in Kcal, it's actually reported in Gcal
    function calc_caloric_density(idx, col)
        kcal_row = idx .== "Food supply (kcal)"
        kg_row = idx .== "Food"
        new_val = col[kcal_row] ./ (col[kg_row])    # This is Gcal divided by Gigagram (1000 tonnes)
        return DataFrame([:Element, :Unit, :Value] .=> ["Caloric density", "kcal/kg", new_val])
    end
    
    # Q&D mean function
    # mean(x) = sum(x)/length(x)

    # Q&D aggregator function
    function aggregator(element, unit, vals)
        return DataFrame([:Element, :Unit, :Value] .=> [unique(element), unique(unit), sum(vals)])
    end

    # Now apply some split-apply-combine techniques to transform the data
    gdf = groupby(df, [:Item, :Year])
    df_density = combine(gdf, [:Element, :Value] => calc_caloric_density => [:Element, :Unit, :Value])
    gdf_density = groupby(df_density, :Item)
    # Now a VERY ad-hoc solution since 2010 Sugar beet data is causing issues
    gdf_density[("Sugar beet",)][1, :Value] = mean(gdf_density[("Sugar beet",)][2:end, :Value])

    # Now we transform all elements of the dataset
    gdf = groupby(df, [:Item, :Year, :Unit])
    gdf_density = groupby(df_density, [:Item, :Year])
    for (item, year) in Base.Iterators.product(unique(df.Item), unique(df.Year))
        gdf[(item, year, "1000 t")].Value .*= gdf_density[(item, year)].Value[1]
        gdf[(item, year, "1000 t")].Unit .= "Gigacalories"
        # For now, we fix FAOSTAT unit error ourselves
        gdf[(item, year, "Kcal")].Unit .= "Gigacalories"
    end

    # Finally, we aggregate the data
    # Aggregate data into categories
    gdf = groupby(df, [:Element, :Year])
    df_aggregate = combine(gdf, [:Element, :Unit, :Value] => aggregator => [:Element, :Unit, :Value])
    gdf_aggregate = groupby(df_aggregate, :Element)


    # Note that selecting the first (and only) element works because data is grouped on the :Element column
    # so :Element column is necessarily unique by construction and because each :Element has a specific unit
    # associated with it, in this case the :Unit column is also unique 
    # As such, this strategy is HIGHLY SPECIFIC and DOES NOT GENERALISE
    df_out = DataFrame([gdfe.Element[1] * " - " * gdfe.Unit[1] => gdfe.Value for gdfe in gdf_aggregate])
    df_out.Year = unique(df.Year)
    select!(df_out, size(df_out, 2), [1:size(df_out, 2) - 1]...)    # Reorder the columns so year column is first

    return df_out
end


"""
    getfaolivestockproductiondata(datadir::AbstractString=find_datadir())
Obtain a DataFrame with some data on livestock production
"""
function getfaolivestockproductiondata(datadir::AbstractString=find_datadir())
    # Read CSV file with the data
    df = CSV.read(datadir * "FAOSTAT/FAOSTAT_Livestock_Production_Data.csv", DataFrame, select=[3, 4, 5, 6, 7])

    # We remove any aquatic items (eg. fish) since we only want to consider land-use intensive production
    idx_vec = .!(occursin.(Ref("Fish"), df.Item) .|| occursin.(Ref("Aquatic"), df.Item) 
                .|| occursin.(Ref("Crustaceans"), df.Item) .|| occursin.(Ref("Molluscs"), df.Item) .|| occursin.(Ref("Cephalopods"), df.Item))
    df = df[idx_vec, :]

    # For the rest of the function, the computations are shared with the associated function
    # for crop data, so they should likely be handed off to a common function to perform them
    # This is left as an exercise for a future version of the repository maintainer *smiley_face*
    function calc_caloric_density(idx, col)
        kcal_row = idx .== "Food supply (kcal)"
        kg_row = idx .== "Food"
        new_val = col[kcal_row] ./ (col[kg_row])    # This is Gcal divided by Gigagram (1000 tonnes)
        return DataFrame([:Element, :Unit, :Value] .=> ["Caloric density", "kcal/kg", new_val])
    end
    
    # Q&D mean function
    # mean(x) = sum(x)/length(x)

    # Q&D aggregator function
    function aggregator(element, unit, vals)
        return DataFrame([:Element, :Unit, :Value] .=> [unique(element), unique(unit), sum(vals)])
    end

    # Now apply some split-apply-combine techniques to transform the data
    gdf = groupby(df, [:Item, :Year])
    df_density = combine(gdf, [:Element, :Value] => calc_caloric_density => [:Element, :Unit, :Value])
    gdf_density = groupby(df_density, :Item)

    # Now we transform all elements of the dataset
    gdf = groupby(df, [:Item, :Year, :Unit])
    gdf_density = groupby(df_density, [:Item, :Year])
    for (item, year) in Base.Iterators.product(unique(df.Item), unique(df.Year))
        gdf[(item, year, "1000 t")].Value .*= gdf_density[(item, year)].Value[1]
        gdf[(item, year, "1000 t")].Unit .= "Gigacalories"
        # For now, we fix FAOSTAT unit error ourselves
        gdf[(item, year, "Kcal")].Unit .= "Gigacalories"
    end

    # Aggregate data into categories
    gdf = groupby(df, [:Element, :Year])
    df_aggregate = combine(gdf, [:Element, :Unit, :Value] => aggregator => [:Element, :Unit, :Value])
    gdf_aggregate = groupby(df_aggregate, :Element)


    # Note that selecting the first (and only) element works because data is grouped on the :Element column
    # so :Element column is necessarily unique by construction and because each :Element has a specific unit
    # associated with it, in this case the :Unit column is also unique 
    # As such, this strategy is HIGHLY SPECIFIC and DOES NOT GENERALISE
    df_out = DataFrame([gdfe.Element[1] * " - " * gdfe.Unit[1] => gdfe.Value for gdfe in gdf_aggregate])
    df_out.Year = unique(df.Year)
    select!(df_out, :Year, :)    # Reorder the columns so year column is first

    return df_out
end

"""
    getfaocroppricedata(;datadir::AbstractString=find_datadir(), countrymap::AbstractDict{<:AbstractString, <:AbstractString}=mapfao2wbcountries())
Obtain a DataFrame with some data on crop prices
"""
function getfaocroppricedata(;datadir::AbstractString=find_datadir(), countrymap::AbstractDict{<:AbstractString, <:AbstractString}=mapfao2wbcountries())
    df = CSV.read(datadir * "FAOSTAT/FAOSTAT_Crop_Price_Data.csv", DataFrame, select=[2, 3, 4, 5, 7])
    wdidf = CSV.read(datadir * "World Bank/World_Bank_WDI_GDP_Data.csv", DataFrame, footerskip=5, missingstring="..")
    cropdf = CSV.read(datadir * "FAOSTAT/SUA/FAOSTAT_Crop_SUA_2010_Data.csv", DataFrame, select=[2, 3, 4, 5, 6])
    for year in 2011:2022
        cropdf = vcat(cropdf, CSV.read(datadir * "FAOSTAT/SUA/FAOSTAT_Crop_SUA_" * string(year) * "_Data.csv", DataFrame, select=[2, 3, 4, 5, 6]))
    end

    # The Supply Utilization Accounts contains some ill-defined definition of China in addition to mainland China, which we remove for consistency
    cropdf = cropdf[cropdf."Area" .!= "China", :]
    # Additionally, we remove data for Taiwan since it does not figure in the World Bank Accounts
    cropdf = cropdf[cropdf."Area" .!= "China, Taiwan Province of", :]
    
    # Use the country mapping to go from FAO countries to World Bank countries
    df."Area" = map(x -> countrymap[x], df."Area")
    cropdf."Area" = map(x -> countrymap[x], cropdf."Area")

    # Restrict the crop selection to those present in both datasets
    suacrops = unique(cropdf."Item")
    pricecrops = unique(df."Item")
    commoncrops = suacrops[suacrops .∈ Ref(pricecrops)] # List of crops present in both datasets
    df = df[df."Item" .∈ Ref(commoncrops), :]
    cropdf = cropdf[cropdf."Item" .∈ Ref(commoncrops), :]

    # Save data for converting tonnes to exacalories
    gdf = groupby(cropdf, ["Year", "Item"])

    function calc_caloric_density(countries, labels, values)
        calcountries = countries[labels .== "Food supply (kcal/capita/day)"]
        weightcountries = countries[labels .== "Food supply quantity (g/capita/day)"]
        commoncountries = calcountries[calcountries .∈ Ref(weightcountries)]
        calories = values[labels .== "Food supply (kcal/capita/day)" .&& countries .∈ Ref(commoncountries)]
        weight = values[labels .== "Food supply quantity (g/capita/day)" .&& countries .∈ Ref(commoncountries)]
        nonzeroidx = .!(calories .<= 0. .|| weight .<= 0.)
        calories = calories[nonzeroidx]
        weight = weight[nonzeroidx]

        return mean(weight ./ calories) 
    end

    caldf = combine(gdf, ["Area", "Element", "Value"] => calc_caloric_density => "g/kcal")

    gdf = groupby(caldf, "Item")
    caldf = combine(gdf, "g/kcal" => mean => "g/kcal")
    caldf = caldf[.!(isnan.(caldf."g/kcal")), :]

    # Further restrict crops to those for which we obtain a caloric density estimate
    densitycrops = unique(caldf."Item")
    df = df[df."Item" .∈ Ref(densitycrops), :]
    cropdf = cropdf[cropdf."Item" .∈ Ref(densitycrops), :]

    # Clean up crop consumption data
    cropdf = cropdf[cropdf."Element" .== Ref("Production"), :]   # Select only production in tonnes
    select!(cropdf, Not("Element")) # Drop Element column
    rename!(cropdf, "Value" => "Production")

    # Prices in Belarus are EXTREMELY high prior to 2017 (for some reason), so we simply remove them from the sample for now
    df = df[df."Area" .!= "Belarus", :]
    cropdf = cropdf[cropdf."Area" .!= "Belarus", :]
    wdidf = wdidf[wdidf."Country Name" .!= "Belarus", :]

    # Additionally, prices in Sierra Leone are extremely high during the 2011-2018 period where they feature in the data, so we also remove them
    df = df[df."Area" .!= "Sierra Leone", :]
    cropdf = cropdf[cropdf."Area" .!= "Sierra Leone", :]
    wdidf = wdidf[wdidf."Country Name" .!= "Sierra Leone", :]

    # Furthermore, prices in Zambia are extremely high in the 2010-2012 period, and then drop sharply across all crops, so we remove the outlier years
    df = df[.!(df."Area" .== "Zambia" .&& df."Year" .∈ Ref(2010:2012)), :]
    cropdf = cropdf[.!(cropdf."Area" .== "Zambia" .&& cropdf."Year" .∈ Ref(2010:2012)), :]
    wdidf = wdidf[.!(wdidf."Country Name" .== "Zambia" .&& wdidf."Time" .∈ Ref(2010:2012)), :]

    # Combine price data with international income data (for currency conversion)
    dfcombined = innerjoin(df, wdidf, on=["Area" => "Country Name", "Year" => "Time"])

    # Define a local function to convert LCU to constant 2021 international dollars measured at PPP
    function currency_convert(value, constval, curval, convfactor)
        value = ifelse.(.!(ismissing.(convfactor)), (value ./ convfactor) .* (constval ./ curval), missing)
        return value
    end

    # Perform transformation of price to constant 2021 international dollars
    dfcombined = transform(dfcombined, names(dfcombined)[5:end] => currency_convert => "Price")
    select!(dfcombined, [4, 1, 3, 9])   # Drop all columns except price
    dropmissing!(dfcombined)    # Drop missing values

    # Combine modified price data and production data to compute shares for non-missing observations
    dfcombined = innerjoin(dfcombined, cropdf, on=["Year", "Area", "Item"])
    gdf = groupby(dfcombined, ["Year", "Item"])
    dfcombined = transform(gdf, "Production" => (x -> sum(x) > 0 ? x ./ sum(x) : fill(1/length(x), length(x))) => "Share")
    
    # Compute weighted price contributions across countries
    gdf = groupby(dfcombined, ["Year", "Item"])
    dftransformed = transform(gdf, ["Price", "Share"] => ByRow(*) => "Weighted Price")
    gdf = groupby(dftransformed, ["Year", "Item"])
    df_out = combine(gdf, "Weighted Price" => sum => "Price")

    # Transform to constant international dollars per kcal
    gdf = groupby(df_out, "Item")
    function price_transform(food, price; transform = caldf)
        return price * 1e-6 .* transform[transform."Item" .== unique(food), "g/kcal"]
    end
    df_out = transform(gdf, ["Item", "Price"] => price_transform => "Price" )
    
    return df_out
end

"""
    getfaolivestockpricedata(;datadir::AbstractString=find_datadir(), countrymap::AbstractDict{<:AbstractString, <:AbstractString}=mapfao2wbcountries())
Obtain a DataFrame with some data on livestock product prices
"""
function getfaolivestockpricedata(;datadir::AbstractString=find_datadir(), countrymap::AbstractDict{<:AbstractString, <:AbstractString}=mapfao2wbcountries())
    df = CSV.read(datadir * "FAOSTAT/FAOSTAT_Livestock_Price_Data.csv", DataFrame, select=[2, 3, 4, 5, 7])
    wdidf = CSV.read(datadir * "World Bank/World_Bank_WDI_GDP_Data.csv", DataFrame, footerskip=5, missingstring="..")
    livestockdf = CSV.read(datadir * "FAOSTAT/SUA/FAOSTAT_Livestock_SUA_Data.csv", DataFrame, select=[2, 3, 4, 5, 6])

    # The Supply Utilization Accounts contains some ill-defined definition of China in addition to mainland China, which we remove for consistency
    livestockdf = livestockdf[livestockdf."Area" .!= "China", :]
    # Additionally, we remove data for Taiwan since it does not figure in the World Bank Accounts
    livestockdf = livestockdf[livestockdf."Area" .!= "China, Taiwan Province of", :]
    
    # Use the country mapping to go from FAO countries to World Bank countries - Note that Chechoslovakia is currently missing
    df = df[df."Year" .>= minimum(livestockdf."Year"), :]   # temporary fix by restricting to shorter timeset
    df."Area" = map(x -> countrymap[x], df."Area")
    livestockdf."Area" = map(x -> countrymap[x], livestockdf."Area")

    # Restrict the food selection to those present in both datasets
    suafoods = unique(livestockdf."Item")
    pricefoods = unique(df."Item")
    commonfoods = suafoods[suafoods .∈ Ref(pricefoods)] # List of foods present in both datasets
    df = df[df."Item" .∈ Ref(commonfoods), :]
    livestockdf = livestockdf[livestockdf."Item" .∈ Ref(commonfoods), :]

    # Save data for converting tonnes to exacalories
    gdf = groupby(livestockdf, ["Year", "Item"])

    function calc_caloric_density(countries, labels, values)
        calcountries = countries[labels .== "Food supply (kcal/capita/day)"]
        weightcountries = countries[labels .== "Food supply quantity (g/capita/day)"]
        commoncountries = calcountries[calcountries .∈ Ref(weightcountries)]
        calories = values[labels .== "Food supply (kcal/capita/day)" .&& countries .∈ Ref(commoncountries)]
        weight = values[labels .== "Food supply quantity (g/capita/day)" .&& countries .∈ Ref(commoncountries)]
        nonzeroidx = .!(calories .<= 0. .|| weight .<= 0.)
        calories = calories[nonzeroidx]
        weight = weight[nonzeroidx]

        return mean(weight ./ calories) 
    end

    caldf = combine(gdf, ["Area", "Element", "Value"] => calc_caloric_density => "g/kcal")

    gdf = groupby(caldf, "Item")
    caldf = combine(gdf, "g/kcal" => mean => "g/kcal")
    caldf = caldf[.!(isnan.(caldf."g/kcal")), :]

    # Clean up livestock consumption data
    livestockdf = livestockdf[livestockdf."Element" .== Ref("Production"), :]   # Select only production in tonnes
    select!(livestockdf, [1, 3, 4, 5])
    rename!(livestockdf, "Value" => "Production")

    # Prices in Belarus are EXTREMELY high prior to 2017 (for some reason), so we simply remove them from the sample for now
    df = df[df."Area" .!= "Belarus", :]
    livestockdf = livestockdf[livestockdf."Area" .!= "Belarus", :]
    wdidf = wdidf[wdidf."Country Name" .!= "Belarus", :]

    # Additionally, prices in Sierra Leone are extremely high during the 2011-2018 period where they feature in the data, so we also remove them
    df = df[df."Area" .!= "Sierra Leone", :]
    livestockdf = livestockdf[livestockdf."Area" .!= "Sierra Leone", :]
    wdidf = wdidf[wdidf."Country Name" .!= "Sierra Leone", :]

    # Furthermore, prices in Zambia are extremely high in the 2010-2012 period, and then drop sharply across all crops, so we remove the outlier years
    df = df[.!(df."Area" .== "Zambia" .&& df."Year" .∈ Ref(2010:2012)), :]
    livestockdf = livestockdf[.!(livestockdf."Area" .== "Zambia" .&& livestockdf."Year" .∈ Ref(2010:2012)), :]
    wdidf = wdidf[.!(wdidf."Country Name" .== "Zambia" .&& wdidf."Time" .∈ Ref(2010:2012)), :]

    # Combine price data with international income data (for currency conversion)
    dfcombined = innerjoin(df, wdidf, on=["Area" => "Country Name", "Year" => "Time"])

    # Define a local function to convert LCU to constant 2021 international dollars measured at PPP
    function currency_convert(value, constval, curval, convfactor)
        value = ifelse.(.!(ismissing.(convfactor)), (value ./ convfactor) .* (constval ./ curval), missing)
        return value
    end

    # Perform transformation of price to constant 2021 international dollars
    dfcombined = transform(dfcombined, names(dfcombined)[5:end] => currency_convert => "Price")
    select!(dfcombined, [4, 1, 3, 9])   # Drop all columns except price
    dropmissing!(dfcombined)    # Drop missing values

    # Combine modified price data and production data to compute shares for non-missing observations
    dfcombined = innerjoin(dfcombined, livestockdf, on=["Year", "Area", "Item"])
    gdf = groupby(dfcombined, ["Year", "Item"])
    dfcombined = transform(gdf, "Production" => (x -> x ./ sum(x)) => "Share")
    
    # Compute weighted price contributions across countries
    gdf = groupby(dfcombined, ["Year", "Item"])
    dftransformed = transform(gdf, ["Price", "Share"] => ByRow(*) => "Weighted Price")
    gdf = groupby(dftransformed, ["Year", "Item"])
    df_out = combine(gdf, "Weighted Price" => sum => "Price")

    # Transform to constant international dollars per kcal
    gdf = groupby(df_out, "Item")
    function price_transform(food, price; transform = caldf)
        return price * 1e-6 .* transform[transform."Item" .== unique(food), "g/kcal"]
    end
    df_out = transform(gdf, ["Item", "Price"] => price_transform => "Price" )
    
    return df_out
end

""" 
    getfaocropconsumptiondata(;datadir::AbstractString=find_datadir())
Obtain a DataFrame with data on consumption of crop-based foods
"""
function getfaocropconsumptiondata(;datadir::AbstractString=find_datadir())
    cropdf = CSV.read(datadir * "FAOSTAT/SUA/FAOSTAT_Crop_SUA_2010_Data.csv", DataFrame, select=[2, 3, 4, 5, 6])
    for year in 2011:2022
        cropdf = vcat(cropdf, CSV.read(datadir * "FAOSTAT/SUA/FAOSTAT_Crop_SUA_" * string(year) * "_Data.csv", DataFrame, select=[2, 3, 4, 5, 6]))
    end

    df_out = cropdf[cropdf."Element" .== "Food supply (kcal/capita/day)", ["Year", "Area", "Item", "Value"]]
    df_out."Value" .*= 365   # Change to yearly caloric intake per capita

    return df_out
end

""" 
    getfaolivestockconsumptiondata(;datadir::AbstractString=find_datadir())
Obtain a DataFrame with data on consumption of livestock-based foods
"""
function getfaolivestockconsumptiondata(;datadir::AbstractString=find_datadir())
    livestockdf = CSV.read(datadir * "FAOSTAT/SUA/FAOSTAT_Livestock_SUA_Data.csv", DataFrame, select=[2, 3, 4, 5, 6])

    df_out = livestockdf[livestockdf."Element" .== "Food supply (kcal/capita/day)", ["Year", "Area", "Item", "Value"]]
    df_out."Value" .*= 365   # Change to yearly caloric intake per capita

    return df_out
end


###########################################################################
### FUNCTIONS FOR LOADING DATA FROM THE JRC EDGAR DATABASE ON EMISSIONS ###
###########################################################################

"""
    edgaremissiongrouping(df::DataFrame; mapping=ipcc2sectormap)

Using a DataFrame with the raw emissions data from the EDGAR database, 
compute total emissions from each registered activity in the frame
and assign those to their respective sectors according to the supplied
activity to sector mapping (It's assumed that any activities not specified
in the mapping are to be assigned to the manufacturing (non-agricultural) sector)
"""
function edgaremissiongrouping(df::AbstractDataFrame; mapping=ipcc2sectormap)
    # Group emissions according to activities to compute total emissions from each activity
    gdf = groupby(df, 5)    # Fifth column contains IPCC activity codes
    totals_df = combine(gdf, [names(df)[9:end]...] .=> (x -> sum(skipmissing(x), init=0.)))
    totals_df = permutedims(totals_df)  # Flip the frame so years are along rows and categories along columns
    rename!(totals_df, [values(totals_df[1,:])...])    # Rename columns according to first row
    totals_df = totals_df[2:end, :]   # Drop first row
    totals_df.Year = convert(Vector{String}, SubString.(names(df)[9:end], Ref(3:6)))  # Add a year column
    select!(totals_df, :Year, :)   # Reorder columns so Year is first column

    # Map activites into their respective sectors
    out_df = DataFrame("Year" => parse.(Ref(Int), totals_df.Year))  # Create new DataFrame with duplicate Year column
    for (key, val) in mapping
        col_idx = names(totals_df) .∈ Ref(val)
        out_df[:, key] = any(col_idx) ? vec(sum(Matrix(totals_df[:, col_idx]), dims=2)) : fill(0., size(out_df)[1])
    end
    # Note that agricultural waste burning (3.C.1b) is ignored in BOTH agricultural and non-agricultural sector 
    out_df[:, "Manufacturing"] = vec(sum(Matrix(totals_df[:, Not(names(totals_df) .∈ Ref(vcat("Year", "3.C.1", values(mapping)...)))]), dims=2))
    return out_df
end

"""
    getedgarmethaneemissions(;datadir::AbstractString=find_datadir(), mapping=ipcc2sectormap)

Obtain a DataFrame with methane emissions from the EDGAR database from JRC
"""
function getedgarmethaneemissions(;datadir::AbstractString=find_datadir(), mapping=ipcc2sectormap)
    # Load the dataset
    df = DataFrame(XLSX.readdata(datadir * "JRC EDGAR/EDGAR_CH4_1970_2022.xlsx", "IPCC 2006", "A10:BI4751"), :auto)
    rename!(df, [values(df[1,:])...])   # Name columns according to first row
    df = df[2:end, :]   # Drop the first row

    # Group emissions according to activites to compute total emissions from each activity
    # and map the activites to their respective sectors
    out_df = edgaremissiongrouping(df, mapping=mapping)
    out_df[:, 2:end] .*= 1e-3   # Adjust units to Mt
    return out_df
end

"""
    getedgarco2emissions(;datadir::AbstractString=find_datadir(), mapping=ipcc2sectormap)

Obtain a DataFrame with CO2 emissions from the EDGAR databse from JRC
"""
function getedgarco2emissions(;datadir::AbstractString=find_datadir(), mapping=ipcc2sectormap)
    # Load the dataset
    df = DataFrame(XLSX.readdata(datadir * "JRC EDGAR/IEA_EDGAR_CO2_1970_2022.xlsx", "IPCC 2006", "A10:BI3516"), :auto)
    rename!(df, [values(df[1, :])...])    # Name columns according to first row
    df = df[2:end, :] # Drop the first row
    df_bio = DataFrame(XLSX.readdata(datadir * "JRC EDGAR/EDGAR_CO2bio_1970_2022.xlsx", "IPCC 2006", "A10:BI1123"), :auto)
    rename!(df_bio, [values(df_bio[1, :])...])  # Name columns according to first row
    df_bio = df_bio[2:end, :]   # Drop the first row
    df = vcat(df, df_bio)    # Concatenate DataFrames to gather all data in one frame

    # Group emissions according to activites to compute total emissions from each activity
    # and map the activites to their respective sectors
    out_df = edgaremissiongrouping(df, mapping=mapping)
    out_df[:, 2:end] .*= 1e-6   # Adjust units to Gt
    return out_df
end

"""
    getedgarnitrousoxideemissions(;datadir::AbstractString=find_datadir(), mapping=ipcc2sectormap)

Obtain a DataFrame with nitrous oxide emissions from the EDGAR database from JRC
"""
function getedgarnitrousoxideemissions(;datadir::AbstractString=find_datadir(), mapping=ipcc2sectormap)
    df = DataFrame(XLSX.readdata(datadir * "JRC EDGAR/EDGAR_N2O_1970_2022.xlsx", "IPCC 2006", "A10:BI4822"), :auto)
    rename!(df, [values(df[1, :])...])  # Name columns according to first row
    df = df[2:end, :]   # Drop the first row

    # Group emissions according to activites to compute total emissions from each activity
    # and map the activities to their respective sectors
    out_df = edgaremissiongrouping(df, mapping=mapping)
    out_df[:, 2:end] .*= 1e-3   # Adjust units to Mt
    return out_df
end

######################################################
### FUNCTIONS FOR LOADING HADCRUT TEMPERATURE DATA ###
######################################################

"""
    gethadcruttemperatures(;datadir::AbstractString=find_datadir())

Obtain a DataFrame with temperature data from the HadCRUT dataset, rescaled to
measuring anomalies from mena 1850-1900 (pre-industrial) temperature.
"""
function gethadcruttemperatures(;datadir::AbstractString=find_datadir())
    df = CSV.read(datadir * "Met Office/HadCRUT.5.0.2.0.analysis.summary_series.global.annual.csv", DataFrame, select=[1,2])
    # The data is measured as anomalies from 1961-1990 temperature, so we change it to make it anomalies from 1850-1900 temperature
    df[:,2] .-= mean(df[df.Time .<= 1900, 2])
    rename!(df, [:Year, :Temperature])
    return df
end

#########################################################
### FUNCTIONS FOR LOADING NON-CO2 ABATEMENT COST DATA ###
#########################################################

"""
    getharmsenmacdata(;datadir::AbstractString=find_datadir())

Obtain a DataFrame with marginal abatement cost data from the
Harmsen et al (2019) paper, split by sector
"""
function getharmsenmacdata(;datadir::AbstractString=find_datadir())
    basedf = DataFrame(XLSX.readdata(datadir * "HARMSEN/MAC_Data.xlsx", "SSP2 CH4 N2O baseline emissions", "A1:P495"), :auto)
    rename!(basedf, [values(basedf[1,:])...])   # Name columns according to first row
    basedf = basedf[2:end, :]   # Drop the first row
    wdidf = CSV.read(datadir * "World Bank/World_Bank_WDI_GDP_Data.csv", DataFrame, footerskip=5, missingstring="..")
    popdf = CSV.read(datadir * "World Bank/World_Bank_Population_Data.csv", DataFrame, footerskip=5, missingstring="..")
    
    function dataframeflatten(df)
        # Construct the reshaped DataFrame to return
        idxMat = permutedims(hcat([[year, country] for (country, year) in Iterators.product(names(df)[3:end], unique(df."Time"))]...))
        df_out = DataFrame(idxMat, ["Year", "Country Name"])  # Initiate the output DataFrame with the index matrix
        df_out."Population" = fill(0., nrow(df_out))  # Add column for storing population

        # Populate with data from the columns
        gdf = groupby(df_out, "Country Name")
        for (group, col) in zip(gdf, eachcol(df[:,3:end]))
            group."Population" = col
        end    

        return df_out
    end

    # Perform currency conversion using 2021 population as weights
    popdf = dataframeflatten(popdf) # Flatten dataframe
    popdf = dropmissing(popdf[popdf."Year" .== 2021, :2:end])    # Restrict to 2010 and drop missing
    convdf = dropmissing(wdidf[wdidf."Time" .== 2010, 2:4])  # Restrict to 2010 and drop missing
    
    popdf."Population" ./= sum(popdf."Population")
    combinedconvdf = innerjoin(convdf, popdf, on="Country Name")
    convfactor = combine(combinedconvdf, names(combinedconvdf)[2:end] => ((cons, curr, w) -> sum(cons ./ curr .* w)))[1,1]
    
    # Compute share of emissions for each source and region in each year
    gdf = groupby(basedf, "Year")
    
    function share_transform(basecol, cols...)
        
        df_out = DataFrame(fill(0., (length(basecol),length(cols)+1)), :auto)
        
        df_out[:,1] = basecol ./ sum(basecol)
        for (i, col) in enumerate(cols)
            df_out[:,i+1] = col ./ sum(col)
        end
        
        return df_out
    end 
    
    sharedf = transform(gdf, names(basedf)[3:end] => share_transform => names(basedf)[3:end])
    
    # Compute share of each source for total emissions from each sector
    sectormap = [[1, 2, 3, 4, 5, 9, 10, 11, 14], [6, 12], [7, 8, 13]]   # A hacky way of constructing a sector map
    
    function sector_combine(cols...; sectormap=sectormap)
        manufacturingTot = sum(hcat(cols[sectormap[1]]...))
        cropTot = sum(hcat(cols[sectormap[2]]...))
        livestockTot = sum(hcat(cols[sectormap[3]]...))

        manufacturingMat = sum(hcat(cols[sectormap[1]]...), dims=1)
        cropMat = sum(hcat(cols[sectormap[2]]...), dims=1)
        livestockMat = sum(hcat(cols[sectormap[3]]...), dims=1)

        manufacturingShare = manufacturingMat ./ manufacturingTot
        cropShare = cropMat ./ cropTot
        livestockShare = livestockMat ./ livestockTot

        orderingDict = Dict(vcat(sectormap...) .=> 1:length(cols))
        orderingVec = [orderingDict[n] for n in 1:length(cols)]
        outMat = hcat(manufacturingShare..., cropShare..., livestockShare...)[:, orderingVec]

        return outMat
    end
    
    sectordf = combine(gdf, names(basedf)[3:end] => sector_combine => names(basedf)[3:end])

    # For each sector and gas type, obtain abatement rates at various cost levels each year

    function assignment_loop(name, sheet, range; df_out=nothing)
        df = getharmsenmacsheet(datadir=datadir, sheet_name=sheet, sheet_range=range)
        dfcombined = innerjoin(df, sharedf[:, ["Year", "Region", name]], on=["Year", "Region"])
        gdf = groupby(dfcombined, ["Year", "Cost"])
        resdf = combine(gdf, ["Rate", name] => ((r, s) -> sum(r .* s)) => name)
        df_out = typeof(df_out) == DataFrame ? innerjoin(df_out, resdf, on=["Year", "Cost"]) : resdf 
    end
    
    manufacturingCH4Iter = (names(sectordf)[2:end][sectormap[1][begin:end-4]], 
                            ["SSP2 CH4_coal", "SSP2 CH4_oilp", "SSP2 CH4_ngas", "SSP2 CH4_landfills", "SSP2 CH4_sewage"],
                            ["A2:AB5429" for _ in sectormap[1][begin:end-4]])

    manufacturingN2OIter = (names(sectordf)[2:end][sectormap[1][end-3:end]],
                            ["SSP2 N2O_transport", "SSP2 N2O_adip acid", "SSP2 N2O_nitr acid", "SSP2 N2O_sewage"],
                            ["A2:AB5429" for _ in sectormap[1][end-3:end]])

    cropsCH4Iter = (names(sectordf)[2:end][sectormap[2][begin:begin]], ["SSP2 CH4_rice"], ["A2:AB5429"])
    cropsN2OIter = (names(sectordf)[2:end][sectormap[2][end:end]], ["SSP2 N2O_fertilizer"], ["A2:AB5429"])
    
    livestockCH4Iter = (names(sectordf)[2:end][sectormap[3][begin:end-1]], ["SSP2 CH4_ent fermentation", "SSP2 CH4_manure"], ["A2:AB5429", "A2:AB5429"])
    livestockN2OIter = (names(sectordf)[2:end][sectormap[3][end:end]], ["SSP2 N2O_manure"], ["A2:AB5429"])
    
    manufacturingCH4df_out = nothing
    for (name, sheet, range) in zip(manufacturingCH4Iter...)
        manufacturingCH4df_out = assignment_loop(name, sheet, range, df_out=manufacturingCH4df_out)
    end

    manufacturingN2Odf_out = nothing
    for (name, sheet, range) in zip(manufacturingN2OIter...)
        manufacturingN2Odf_out = assignment_loop(name, sheet, range, df_out=manufacturingN2Odf_out)
    end

    cropsCH4df_out = nothing
    for (name, sheet, range) in zip(cropsCH4Iter...)
        cropsCH4df_out = assignment_loop(name, sheet, range, df_out=cropsCH4df_out)
    end

    cropsN2Odf_out = nothing
    for (name, sheet, range) in zip(cropsN2OIter...)
        cropsN2Odf_out = assignment_loop(name, sheet, range, df_out=cropsN2Odf_out)
    end

    livestockCH4df_out = nothing
    for (name, sheet, range) in zip(livestockCH4Iter...)
        livestockCH4df_out = assignment_loop(name, sheet, range, df_out=livestockCH4df_out)
    end

    livestockN2Odf_out = nothing
    for (name, sheet, range) in zip(livestockN2OIter...)
        livestockN2Odf_out = assignment_loop(name, sheet, range, df_out=livestockN2Odf_out)
    end

    # Combine abatement rates across sources within industries according to their shares
    combineIter = ([manufacturingCH4df_out,  manufacturingN2Odf_out,  cropsCH4df_out,  cropsN2Odf_out,  livestockCH4df_out,  livestockN2Odf_out],
                   [manufacturingCH4Iter[1], manufacturingN2OIter[1], cropsCH4Iter[1], cropsN2OIter[1], livestockCH4Iter[1], livestockN2OIter[1]],
                   ["Manufacturing - CH4",   "Manufacturing - N2O",   "Crops - CH4",   "Crops - N2O",   "Livestock - CH4",   "Livestock - N2O"])

    function weighted_mac(year, cols...; colnames, weights=sectordf)
        weights = weights[weights."Year" .== year, colnames] # Select desired weights
        
        return sum(hcat(cols...) .* Matrix(weights))
    end

    df_out = DataFrame("Year" => manufacturingCH4df_out."Year", "Cost" => manufacturingCH4df_out."Cost")
    
    for (df, cols, sector) in zip(combineIter...)
        gdf = groupby(df, ["Year", "Cost"])
        local_weighted_mac(y, c...) = weighted_mac(y, c..., colnames=cols)
        df_out = innerjoin(df_out, combine(gdf, ["Year", cols...] => local_weighted_mac => sector), on=["Year", "Cost"])
    end

    df_out."Cost" .*= convfactor    # Convert to constant 2021 international dollars (population weighted mean)

    return df_out
end

"""
    getharmsenmacsheet(;datadir::AbstractString=find_datadir(), sheet_name::AbstractString="", sheet_range::AbstractString="")

Helper function to retrieve a sheet from the Harmsen excel data-set rearranged to fit with other data formats
"""
function getharmsenmacsheet(;datadir::AbstractString=find_datadir(), sheet_name::AbstractString="", sheet_range::AbstractString="")
    df = DataFrame(XLSX.readdata(datadir * "HARMSEN/MAC_Data.xlsx", sheet_name, sheet_range), :auto)
    rename!(df, [values(df[1,:])...])   # Name columns according to first row
    df = df[2:end,:]    # Drop the first row

    # Construct the reshaped DataFrame to return
    idxMat = permutedims(hcat([[year, cost, region] for (region, cost, year) in Iterators.product(names(df)[3:end], unique(df[:,2]), unique(df."t"))]...))
    df_out = DataFrame(idxMat, ["Year", "Cost", "Region"])  # Initiate the output DataFrame with the index matrix
    df_out."Rate" = fill(0., nrow(df_out))  # Add column for storing abatement rates

    # Populate with data from the columns
    gdf = groupby(df_out, "Region")
    for (group, col) in zip(gdf, eachcol(df[:,3:end]))
        group."Rate" = col
    end

    return df_out
end


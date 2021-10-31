module Currencies

export Currency

using ..TrueBalance: getwith, filterunique

import Downloads
using Requires
using XMLDict


## Currency

struct Currency
    code::String   # e.g. "EUR"
    name::String   # e.g. "Euro"
    symbol::String # e.g. "€"
    number::Int
    minorunit::Int # decimal places, -1 if N.A.
end

include("currencies_generated.jl")

# e.g. "€" => EUR, "EUR" => EUR
# symbols not included if ambiguity, except for "$" associated to USD
const SYMBOLS = let
    uniquesymbols = Set(filterunique([c.symbol for c in CURRENCIES]))
    symbols = Dict{String, Currency}()
    for c in CURRENCIES
        symbols[c.code] = c
        if c.symbol != "" && c.symbol ∈ uniquesymbols
            symbols[c.symbol] = c
        end
    end
    symbols["\$"] = USD
    symbols
end

function __init__()
    # loading CSV is too slow and it's currently almost never needed
    @require CSV="336ed68f-0bac-5ca0-87d4-7b16caf5d00b" import .CSV
end


# generate currencies_generated.jl
# requires that CSV is loaded
# if "list_one.xml" is already downloaded in a file, it can be passed as an argument
function gencurrencies(list_one::AbstractString=nothing)
    symbolstable = CSV.read(joinpath(@__DIR__, "currencies_symbols.tsv"), NamedTuple,
                            comment="#")
    symbols = Dict(symbolstable[1] .=> symbolstable[3])

    if list_one === nothing
        list_one = IOBuffer()
        Downloads.download("https://www.six-group.com/dam/download/financial-information/data-center/iso-currrency/amendments/lists/list_one.xml",
                           list_one)
        list_one = String(take!(list_one))
    else
        list_one = read(list_one, String)
    end
    currsdict = xml_dict(list_one)
    currs = currsdict["ISO_4217"]["CcyTbl"]["CcyNtry"]
    currencies = Currency[]
    countries = Dict{String, Vector{Currency}}()

    for curr in currs
        if !haskey(curr, "Ccy")
            countries[curr["CtryNm"]] = Currency[]
            continue
        end
        cold = getwith(currencies; code=curr["Ccy"])
        currname = curr["CcyNm"]
        if currname isa AbstractDict
            @assert collect(keys(currname)) == [:IsFund, ""]
            currname = currname[""]
        end
        cnew = Currency(curr["Ccy"], currname, get(symbols, curr["Ccy"], ""),
                        parse(Int, curr["CcyNbr"]),
                        let u = curr["CcyMnrUnts"]
                            u == "N.A." ? -1 : parse(Int, u)
                        end)
        if cold === nothing
            push!(currencies, cnew)
        else
            @assert cold == cnew
        end
        push!(get!(countries, curr["CtryNm"], Currency[]), cnew)
    end
    sort!(currencies, by=x->x.code)
    countrieskeys = sort!(collect(keys(countries)))

    open(joinpath(@__DIR__, "currencies_generated.jl"), "w") do gen
        write(gen, "# do not edit: auto-generated file, via `gencurrencies()`\n\n")
        for curr in currencies
            write(gen, "const ", curr.code, " = Currency(",
                  repr(curr.code), ", ", repr(curr.name), ", ",repr(curr.symbol),
                  ", ", string(curr.number, ", ", curr.minorunit, ")\n"))
        end
        write(gen, "\nconst CURRENCIES = Currency[")
        for (ii, curr) in enumerate(currencies)
            mod1(ii, 18) == 1 && write(gen, "\n    ")
            write(gen, curr.code, ", ")
        end
        write(gen, "]\n\n")
        write(gen, "const COUNTRIES = Dict(\n")

        for ckey in countrieskeys
            write(gen, "    ", repr(ckey), " => [",)
            pre = ""
            for c in countries[ckey]
                write(gen, pre, c.code)
                pre = ", "
            end
            write(gen, "],\n")
        end
        write(gen, ")\n")
        nothing
    end
end

end # Currencies

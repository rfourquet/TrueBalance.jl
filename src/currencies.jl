module Currencies

export Currency

import Downloads
using XMLDict
using ..TrueBalance: getwith


## Currency

struct Currency
    code::String   # e.g. "EUR"
    name::String   # e.g. "Euro"
    symbol::String # e.g. "€"
    number::Int
    minorunit::Int # decimal places, -1 if N.A.
end

include("currencies_generated.jl")

# generate currencies_generated.jl
function gencurrencies()
    list_one = IOBuffer()
    Downloads.download("https://www.six-group.com/dam/download/financial-information/data-center/iso-currrency/amendments/lists/list_one.xml",
                       list_one)
    list_one = String(take!(list_one))
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
        cnew = Currency(curr["Ccy"], currname, "", parse(Int, curr["CcyNbr"]),
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

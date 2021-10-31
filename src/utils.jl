filterwith(src; fields...) =
    filter(src) do xx
        all(pairs(fields)) do (k, v)
            getfield(xx, k) == v
        end
    end

function getwith(src; fields...)
    res = filterwith(src; fields...)
    isempty(res) ? nothing : only(res)
end

@testset "getwith" begin
    a = [(x=1, y=2), (x=1, y=3)]
    @test filterwith(a, x=1) == a
    @test_throws Exception getwith(a, x=1)
    @test filterwith(a, y=2) == [(x=1, y=2)]
    @test getwith(a, y=2) == (x=1, y=2)
    @test isempty(filterwith(a, y=0))
    @test getwith(a, y=0) === nothing

    b = [1=>2, 3=>4, 1=>6]
    @test filterwith(b, first=1) == [1=>2, 1=>6]
    @test filterwith(b, first=3) == [3=>4]
    @test getwith(b, first=3) == (3=>4)
    @test isempty(filterwith(b, second=3) )
    @test getwith(b, second=2) == (1=>2)

    # unknown fields are errors
    @test_throws ErrorException filterwith(b, unknown=0)
    @test_throws ErrorException getwith(b, unknown=0)
end

function filterunique(xs)
    cs = Dict{eltype(xs), Int}()
    for xx in xs
        cs[xx] = 1 + get(cs, xx, 0)
    end
    eltype(xs)[xx for xx in xs if cs[xx] == 1]
end

module TrueBalance

export entity!

using Base: @kwdef
using Random
using UUIDs

using InlineTest

include("utils.jl")


## Entity

@kwdef mutable struct Entity
    id::UUID
    name::String
    description::String
end

function entity!(name::AbstractString, description="")
    ent = getwith(ENTITIES; name)
    if ent === nothing
        ent = Entity(; name, description, id=uuid4())
        push!(ENTITIES, ent)
    else
        if !isempty(description)
            ent.description = description
        end
    end
    ent
end

@testset "Entity" begin
    name = "TestEntity-" * randstring(RandomDevice())
    @test getwith(ENTITIES; name) === nothing
    ent = entity!(name)
    @test getwith(ENTITIES; name) === ent
    @test ent.description == ""
    @test ent === entity!(name, "an entity")
    @test ent.description == "an entity"
    @test ent === entity!(name, "overwritten")
    @test ent.description == "overwritten"

    name = "TestEntity2=" * randstring(RandomDevice())
    @test getwith(ENTITIES; name) === nothing
    ent2 = entity!(name, "a second entity")
    @test ent2.description == "a second entity"

    filter!(ENTITIES) do entity
        entity.name ∉ (ent.name, ent2.name)
    end
end

const ENTITIES = Entity[]

end # module

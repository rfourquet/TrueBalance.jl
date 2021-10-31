module TrueBalance

export entity!

using Base: @kwdef
using Random
using UUIDs

using InlineTest

include("utils.jl")


## Entity

@kwdef mutable struct Entity
    id::UUID = uuid4()
    name::String
    description::String
end

function entity!(name::AbstractString, description="")
    ent = getwith(ENTITIES; name)
    if ent === nothing
        ent = Entity(; name, description)
        push!(ENTITIES, ent)
    else
        if !isempty(description)
            ent.description = description
        end
    end
    ent
end

const ENTITIES = Entity[]

defaultowner() = ENTITIES[1]

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


## Account

@kwdef mutable struct Account
    id::UUID = uuid4()
    owner::UUID
    name::String        # (owner, name) should be unique
    description::String # user facing, one line
end

function account!(spec::AbstractString, description="")
    owner_acc = split(spec, '@', limit=2)
    if length(owner_acc) == 2
        owner = entity!(owner_acc[1]).id
        name = owner_acc[2]
    else
        owner = defaultowner().id
        name = only(owner_acc)
    end
    isempty(name) && error("account name can't be empty")
    acc = getwith(ACCOUNTS; name, owner)

    if acc === nothing
        acc = Account(; owner, name, description)
        push!(ACCOUNTS, acc)
    else
        if !isempty(description)
            acc.description = description
        end
    end
    acc
end

const ACCOUNTS = Account[]

@testset "Account" begin
    saved_accounts = copy(ACCOUNTS)
    saved_entities = copy(ENTITIES)
    try
        empty!(ACCOUNTS)

        ## implicit owner errors
        name = "TestAccount-" * randstring(RandomDevice())
        @test getwith(ACCOUNTS; name) === nothing
        @test_throws Exception account!(name) # no owner set

        ## create an entity on the fly
        spec1 = "Ent@" * name
        acc1 = account!(spec1)
        owner = defaultowner()
        @test owner.name == "Ent"
        @test acc1.owner == owner.id
        @test acc1.name == name
        @test getwith(ACCOUNTS; name) === acc1
        @test acc1.description == ""
        @test acc1 === account!(name, "an account")
        @test acc1.description == "an account"

        ## implicit owner
        name2 = "TestAccount-" * randstring(RandomDevice())
        @test getwith(ACCOUNTS; name=name2) === nothing
        acc2 = account!(name2, "a second account")
        @test acc2.owner == owner.id
        @test acc2.name == name2
        @test acc2.description == "a second account"

        ## create another entity on the fly
        spec3 = "Another@Test"
        acc3 = account!(spec3, "another")
        another = getwith(ENTITIES, name="Another")::Entity
        @test acc3.owner == another.id
        @test acc3.name == "Test"
        @test acc3.description == "another"

        ## create a new account on the fly for existing owner
        spec4 = "Another@Test2"
        acc4 = account!(spec4)
        @test acc4.owner == another.id
        @test acc4.name == "Test2"

        ## new account with default owner
        name5 = "Test5"
        @test getwith(ACCOUNTS; name=name5) === nothing
        acc5 = account!(name5)
        @test acc5.owner == owner.id
        @test acc5.name == "Test5"

        ## empty name
        @test_throws Exception account!("")
        @test_throws Exception account!("Ent@")
        @test_throws Exception account!("NewEnt@")
        # whether the last one should create "NewEnt" before throwing is
        # currently left undefined, although it actually does
    finally
        copy!(ACCOUNTS, saved_accounts)
        copy!(ENTITIES, saved_entities)
    end
end


end # module

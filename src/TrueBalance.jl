module TrueBalance

export entity!

using Base: @kwdef
using Random
using UUIDs

using InlineTest

include("utils.jl")


## Entity

@kwdef mutable struct Entity
    id::UUID = uuid(Entity)
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
    @test idis(ent.id, Entity)

    name = "TestEntity2=" * randstring(RandomDevice())
    @test getwith(ENTITIES; name) === nothing
    ent2 = entity!(name, "a second entity")
    @test ent2.description == "a second entity"
    @test idis(ent2.id, Entity)

    filter!(ENTITIES) do entity
        entity.name ∉ (ent.name, ent2.name)
    end
end


## Account

@kwdef mutable struct Account
    id::UUID = uuid(Account)
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
        @test idis(acc1.id, Account)
        @test idis(owner.id, Entity)

        ## implicit owner
        name2 = "TestAccount-" * randstring(RandomDevice())
        @test getwith(ACCOUNTS; name=name2) === nothing
        acc2 = account!(name2, "a second account")
        @test acc2.owner == owner.id
        @test acc2.name == name2
        @test acc2.description == "a second account"
        @test idis(acc2.id, Account)

        ## create another entity on the fly
        spec3 = "Another@Test"
        acc3 = account!(spec3, "another")
        another = getwith(ENTITIES, name="Another")::Entity
        @test acc3.owner == another.id
        @test acc3.name == "Test"
        @test acc3.description == "another"
        @test idis(acc3.id, Account)

        ## create a new account on the fly for existing owner
        spec4 = "Another@Test2"
        acc4 = account!(spec4)
        @test acc4.owner == another.id
        @test acc4.name == "Test2"
        @test idis(acc4.id, Account)

        ## new account with default owner
        name5 = "Test5"
        @test getwith(ACCOUNTS; name=name5) === nothing
        acc5 = account!(name5)
        @test acc5.owner == owner.id
        @test acc5.name == "Test5"
        @test idis(acc5.id, Account)

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


## uuid

uuidsig(::Type{Entity}) = 1
uuidsig(::Type{Account}) = 2

# the first (leftmost) hex digit of the first group of 4 digits in the UUID is used
# to tag the type of object, e.g. for Entity:
# UUID("aebb7978-1bd9-4a5a-b0b4-6f8b0c4f87dd")
#                ^--- 1 denotes Entity, 2 Account, etc.
function uuid(::Type{X}) where X
    uid = uuid4()
    xuid = uid.value
    mask = UInt128(15) << 92
    xuid &= ~mask
    xuid |= UInt128(uuidsig(X)) << 92
    UUID(xuid)
end

function idis(id::UUID, ::Type{X}) where X
    x = 15 & (id.value >> 92)
    x == uuidsig(X)
end

@testset "uuid" begin
    allids = Set{UUID}()
    for _=1:50
        ent = uuid(Entity)::UUID
        entstr = split(string(ent), '-')[2]
        @test entstr[1] == '1'
        @test length(entstr) == 4
        push!(allids, ent)

        acc = uuid(Account)::UUID
        accstr = split(string(acc), '-')[2]
        @test accstr[1] == '2'
        @test length(accstr) == 4
        @test idis(acc, Account)
        push!(allids, acc)
    end
    @test length(allids) == 100 # check there are no collisions, a proxy for randomness
end

end # module

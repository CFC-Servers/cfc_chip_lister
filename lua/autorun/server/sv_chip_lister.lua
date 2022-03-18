AddCSLuaFile( "cfc_chip_lister/shared/sh_chip_lister.lua" )
AddCSLuaFile( "cfc_chip_lister/client/cl_hud.lua" )
include( "cfc_chip_lister/shared/sh_chip_lister.lua" )

local CPU_MULT = 1000000
local PLAYER_LENGTH_MAX = 20
local CHIP_LENGTH_MAX = 25
local ID_WORLD = "[WORLD]"
local TIMER_NAME = "CFC_ChipLister_UpdateListData"
local CHIP_SHORTHANDS = { -- Must all be unique two-character strings
    gmod_wire_expression2 = "E2",
    starfall_processor = "SF",
}

local listUsers = {}
local chips = {}
local listUserCount = 0
local chipCount = 0
local convarFlags = { FCVAR_ARCHIVE, FCVAR_REPLICATED }

local isValid = IsValid
local rawset = rawset
local rawget = rawget
local mRound = math.Round
local tableInsert = table.insert
local tableRemove = table.remove
local tableKeyFromValue = table.KeyFromValue
local tableRemoveByValue = table.RemoveByValue
local stringLen = string.len
local stringSub = string.sub
local stringReplace = string.Replace
local stringTrim = string.Trim
local getClass
local getOwner
local getNick

do
    local entityMeta = FindMetaTable( "Entity" )

    getClass = entityMeta.GetClass
    
    local _getOwner = entityMeta.GetOwner
    local cppiGetOwner = entityMeta.CPPIGetOwner

    getOwner = function( ent )
        local owner = cppiGetOwner and cppiGetOwner( ent )

        if not isValid( owner ) then
            owner = _getOwner( ent )
        end

        return owner
    end


    local playerMeta = FindMetaTable( "Player" )

    getNick = playerMeta.Nick
end

local LISTER_INTERVAL = CreateConVar( "cfc_chiplister_interval", 1, convarFlags, "How often (in seconds) the chip lister will update and send info to players.", 0.05, 10 )

util.AddNetworkString( "CFC_ChipLister_SetEnabled" )
util.AddNetworkString( "CFC_ChipLister_UpdateListData" )


local function getChipName( ent )
    return ent.GetGateName and ent:GetGateName() or "[UNKNOWN]"
end

local function getCPUs( ent, class )
    if ent.Starfall then
        local instance = ent.instance

        return instance and instance:movingCPUAverage() or 0
    end

    if ( class or getClass( ent ) ) == "gmod_wire_expression2" then
        local context = ent.context

        return context and context.timebench or 0
    end

    return 0
end

local function normalizeCPUs( cpus )
    return mRound( ( cpus or 0 ) * CPU_MULT )
end

local function prepareName( str, maxLength )
    str = stringTrim( stringReplace( str or "", "\n", " " ) )
    
    if stringLen( str ) > maxLength then
        str = stringSub( str, 1, maxLength - 3 ) .. "..."
    end

    return str
end

local function preparePlyName( str )
    return prepareName( str, PLAYER_LENGTH_MAX )
end

local function prepareChipName( str )
    return prepareName( str, CHIP_LENGTH_MAX )
end

local function updateChipLister()
    if listUserCount == 0 then return end

    local perPlyData = {}
    local idLookup = {}
    local globalUsage = 0
    local idCount = 0

    for i = 1, chipCount do
        local chip = rawget( chips, i )

        if isValid( chip ) then
            local chipName = prepareChipName( " -" .. getChipName( chip ) )
            local chipClass = getClass( chip )
            local chipUsage = normalizeCPUs( getCPUs( chip, chipClass ) )
            local owner = getOwner( chip )
            local ownerName

            globalUsage = globalUsage + chipUsage

            -- For some reason, :IsPlayer() always returns false if obtained locally from entityMeta, it HAS to be called this way
            if isValid( owner ) and owner:IsPlayer() then
                ownerName = preparePlyName( getNick( owner ) )
            else
                owner = ID_WORLD
                ownerName = ID_WORLD
            end
            
            local id = rawget( idLookup, owner )

            if not id then
                idCount = idCount + 1
                id = idCount
                rawset( idLookup, owner, id )
            end

            local data = rawget( perPlyData, id )
            local dataCount

            if data then
                dataCount = rawget( data, "Count" )
                rawset( data, "OwnerUsage", rawget( data, "OwnerUsage" ) + chipUsage )
            else
                data = {
                    Count = 0,
                    Owner = owner,
                    OwnerName = ownerName,
                    OwnerUsage = chipUsage,
                }

                rawset( perPlyData, id, data )
                dataCount = 0
            end

            dataCount = dataCount + 1
            rawset( data, dataCount, chipName )
            dataCount = dataCount + 1
            rawset( data, dataCount, CHIP_SHORTHANDS[chipClass] )
            dataCount = dataCount + 1
            rawset( data, dataCount, chipUsage )

            rawset( data, "Count", dataCount )
        end
    end

    rawset( perPlyData, "Count", idCount )

    net.Start( "CFC_ChipLister_UpdateListData" )
    net.WriteTable( perPlyData ) -- I would use TableToJSON, Compress, and WriteData, but player and chip names could easily break the formatting
    net.WriteUInt( globalUsage, 20 )
    net.Send( listUsers )
end

cvars.AddChangeCallback( "cfc_chiplister_interval", function( _, old, new )
    timer.Create( TIMER_NAME, tonumber( new ) or 1, 0, updateChipLister )
end )


hook.Add( "OnEntityCreated", "CFC_ChipLister_ChipCreated", function( ent )
    if not isValid( ent ) then return end

    local class = getClass( ent )

    if not CHIP_SHORTHANDS[class] then return end

    chipCount = chipCount + 1
    chips[chipCount] = ent
end )

hook.Add( "OnEntityRemoved", "CFC_ChipLister_ChipRemoved", function( ent )
    if not isValid( ent ) then return end

    local class = getClass( ent )

    if not CHIP_SHORTHANDS[class] then return end

    chipCount = chipCount - 1
    tableRemoveByValue( chips, ent )
end )

hook.Add( "PlayerDisconnected", "CFC_ChipLister_UpdateListUserCount", function( ply )
    if not ( ply or {} ).cfcChipLister_usesLister then return end

    local ind = tableKeyFromValue( listUsers, ply )

    if ind then
        tableRemove( listUsers, ind )
        listUserCount = listUserCount - 1
        ply.cfcChipLister_usesLister = nil
    end
end )


net.Receive( "CFC_ChipLister_SetEnabled", function( _, ply )
    local state = net.ReadBool()

    if state then
        tableInsert( listUsers, ply )
        listUserCount = listUserCount + 1
        ply.cfcChipLister_usesLister = true
    else
        local ind = tableKeyFromValue( listUsers, ply )

        if ind then
            tableRemove( listUsers, ind )
            listUserCount = listUserCount - 1
            ply.cfcChipLister_usesLister = nil
        end
    end
end )

timer.Create( TIMER_NAME, LISTER_INTERVAL:GetFloat(), 0, updateChipLister )

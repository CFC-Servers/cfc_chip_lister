AddCSLuaFile( "cfc_chip_lister/shared/sh_chip_lister.lua" )
AddCSLuaFile( "cfc_chip_lister/client/cl_hud.lua" )
include( "cfc_chip_lister/shared/sh_chip_lister.lua" )

local CPU_MULT = 1000000
local PLAYER_LENGTH_MAX = 20
local CHIP_LENGTH_MAX = 25
local MAX_TOTAL_ELEMENTS = 30 * 2
local ID_WORLD = "[WORLD]"
local TIMER_NAME = "CFC_ChipLister_UpdateListData"
local TOGGLE_HUD_COMMAND = "!chiplister"
local CHIP_CLASSES = {
    gmod_wire_expression2 = true,
    starfall_processor = true,
}

CFC_ChipLister = CFC_ChipLister or {}
CFC_ChipLister.ListUsers = CFC_ChipLister.ListUsers or {}
CFC_ChipLister.ListUserCount = CFC_ChipLister.ListUserCount or 0
CFC_ChipLister.Chips = CFC_ChipLister.Chips or {}

local listUsers = CFC_ChipLister.ListUsers
local chips = CFC_ChipLister.Chips
local listUserRatelimits = {}
local listUserRatelimitDesStates = {}
local convarFlags = { FCVAR_ARCHIVE, FCVAR_REPLICATED }
local cornerCache = {}

local IsValid = IsValid
local rawset = rawset
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

    local _getOwner = entityMeta.GetOwner
    local cppiGetOwner = entityMeta.CPPIGetOwner
    getClass = entityMeta.GetClass

    getOwner = function( ent )
        local owner = cppiGetOwner and cppiGetOwner( ent )

        return IsValid( owner ) and owner or _getOwner( ent )
    end


    local playerMeta = FindMetaTable( "Player" )

    getNick = playerMeta.Nick
end

local LISTER_INTERVAL = CreateConVar( "cfc_chiplister_interval", 1, convarFlags, "How often (in seconds) the chip lister will update and send info to players.", 0.05, 10 )

util.AddNetworkString( "CFC_ChipLister_SetEnabled" )
util.AddNetworkString( "CFC_ChipLister_UpdateListData" )
util.AddNetworkString( "CFC_ChipLister_ToggleHUD" )


-- Get the four corners of a thin, flat plate.
local function getPlateCorners( ent )
    local corners = cornerCache[ent]
    if corners then return corners end

    local obbSizeHalf = ( ent:OBBMaxs() - ent:OBBMins() ) / 2
    local forward = ent:GetForward() * obbSizeHalf[1]
    local right = ent:GetRight() * obbSizeHalf[2]
    local entPos = ent:GetPos()

    corners = {
        entPos + forward + right,
        entPos + forward - right,
        entPos - forward + right,
        entPos - forward - right,
    }

    cornerCache[ent] = corners

    return corners
end

-- Rough visibility check for a thin, flat plate.
local function isPlateVisible( ent, ply )
    if not ply:TestPVS( ent ) then return false end

    local eyePos = ply:GetShootPos()
    local eyeDir = ply:GetAimVector()
    local fov = ply:GetFOV() + 20 -- Actual effective visbility is ~20 degrees more than the stated FOV
    local dotLimit = math.cos( math.rad( math.Clamp( fov / 2, 0, 90 ) ) )

    for _, point in ipairs( getPlateCorners( ent ) ) do
        local eyeToPoint = point - eyePos
        local eyeToPointLength = eyeToPoint:Length()

        if eyeToPointLength == 0 then return true end

        local eyeToPointDir = eyeToPoint / eyeToPointLength

        if eyeDir:Dot( eyeToPointDir ) >= dotLimit then return true end
    end

    return false
end

-- Can a player see at least one chip lister?
-- Give listers as false to only check for the HUD setting (i.e. no lister entities exist).
local function canSeeALister( ply, listers )
    if not IsValid( ply ) then return false end
    if ply:GetInfoNum( "cfc_chiplister_hud_persist", 0 ) == 1 then return true end
    if not listers then return false end

    local aimEnt = ply:GetEyeTrace().Entity
    if IsValid( aimEnt ) and aimEnt:GetClass() == "cfc_chip_lister" then return true end

    for _, lister in ipairs( listers ) do
        if isPlateVisible( lister, ply ) then return true end
    end

    return false
end

-- Get all list users who can see at least one chip lister.
local function getVisibleListUsers()
    if CFC_ChipLister.ListUserCount == 0 then return {}, 0 end

    local listers = ents.FindByClass( "cfc_chip_lister" )

    if #listers == 0 then
        listers = false
    end

    local visibleUsers = {}
    local visibleUserCount = 0
    cornerCache = {} -- Reset corner cache

    for _, ply in ipairs( listUsers ) do
        if canSeeALister( ply, listers ) then
            visibleUserCount = visibleUserCount + 1
            rawset( visibleUsers, visibleUserCount, ply )
        end
    end

    return visibleUsers, visibleUserCount
end

local function getChipName( ent )
    return ent.GetGateName and ent:GetGateName() or "[UNKNOWN]"
end

local function getCPUs( ent )
    if ent.Starfall then
        local instance = ent.instance
        if not instance then return false end
        if instance.error then return false end

        return instance:movingCPUAverage()
    end

    if getClass( ent ) == "gmod_wire_expression2" then
        if ent.error then return false end

        local context = ent.context
        if not context then return 0 end

        return context.timebench or 0
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

local maxplayers_bits = math.ceil( math.log( 1 + game.MaxPlayers() ) / math.log( 2 ) )
local function updateListerData()
    local visibleUsers, visibleUserCount = getVisibleListUsers()
    if visibleUserCount == 0 then return end

    local playerData = {}
    local globalUsage = 0
    local lineCount = 0

    for _, chip in ipairs( chips ) do
        local isE2 = getClass( chip ) == "gmod_wire_expression2"
        local chipUsage = getCPUs( chip )
        local chipNormalizedUsage = normalizeCPUs( chipUsage or 0 )
        local owner = getOwner( chip )

        globalUsage = globalUsage + chipNormalizedUsage

        if lineCount >= MAX_TOTAL_ELEMENTS then
            continue
        end

        local plyData = playerData[owner]
        if not plyData then
            plyData = {
                Count = 0,
                OwnerIndex = owner == ID_WORLD and 0 or owner:EntIndex(),
                OwnerName = owner == ID_WORLD and ID_WORLD or preparePlyName( getNick( owner ) ),
                OwnerTotalUsage = 0,
                ChipInfo = {},
            }
            playerData[owner] = plyData
            lineCount = lineCount + 1
        end

        table.insert( plyData.ChipInfo, {
            Name = prepareChipName( getChipName( chip ) ),
            IsE2 = isE2,
            CPUUsage = chipUsage == false and -1 or chipNormalizedUsage,
        } )
        plyData.Count = plyData.Count + 1
        if chipUsage ~= false then
            plyData.OwnerTotalUsage = plyData.OwnerTotalUsage + chipNormalizedUsage
        end
        lineCount = lineCount + 1
    end

    for _, data in pairs( playerData ) do
        table.sort( data.ChipInfo, function( a, b )
            return a.CPUUsage > b.CPUUsage
        end )
    end

    local sortedPlayerData = {}
    for _, data in pairs( playerData ) do
        table.insert( sortedPlayerData, data )
    end
    table.sort( sortedPlayerData, function( a, b )
        return a.OwnerTotalUsage > b.OwnerTotalUsage
    end )

    local hasChips = #chips > 0
    if not hasChips then
        net.Start( "CFC_ChipLister_UpdateListData" )
        net.WriteBool( false )
        net.Send( visibleUsers )
        return
    end

    net.Start( "CFC_ChipLister_UpdateListData" )
    net.WriteBool( true )
    net.WriteUInt( globalUsage, 16 )
    net.WriteUInt( #sortedPlayerData, 5 )
    for _, data in ipairs( sortedPlayerData ) do
        net.WriteUInt( data.Count, 6 )
        net.WriteString( data.OwnerName )
        net.WriteUInt( data.OwnerIndex, maxplayers_bits )
        net.WriteUInt( data.OwnerTotalUsage, 15 )

        for _, chip in ipairs( data.ChipInfo ) do
            net.WriteString( chip.Name )
            net.WriteBool( chip.IsE2 )
            net.WriteInt( chip.CPUUsage, 15 )
        end
    end
    net.Send( visibleUsers )
end

local function setListUserState( ply, state )
    if state then
        tableInsert( listUsers, ply )
        CFC_ChipLister.ListUserCount = CFC_ChipLister.ListUserCount + 1
        ply.cfcChipLister_usesLister = true
    else
        local ind = tableKeyFromValue( listUsers, ply )

        if ind then
            tableRemove( listUsers, ind )
            CFC_ChipLister.ListUserCount = CFC_ChipLister.ListUserCount - 1
            ply.cfcChipLister_usesLister = nil
        end
    end
end

cvars.AddChangeCallback( "cfc_chiplister_interval", function( _, _, new )
    timer.Create( TIMER_NAME, tonumber( new ) or 1, 0, updateListerData )
end )


hook.Add( "OnEntityCreated", "CFC_ChipLister_ChipCreated", function( ent )
    local class = getClass( ent )
    if not CHIP_CLASSES[class] then return end

    table.insert( chips, ent )
end )

hook.Add( "EntityRemoved", "CFC_ChipLister_ChipRemoved", function( ent )
    local class = getClass( ent )
    if not CHIP_CLASSES[class] then return end

    tableRemoveByValue( chips, ent )
end )

hook.Add( "PlayerDisconnected", "CFC_ChipLister_UpdateListUserCount", function( ply )
    if not ply or not ply.cfcChipLister_usesLister then return end

    local ind = tableKeyFromValue( listUsers, ply )

    if ind then
        tableRemove( listUsers, ind )
        CFC_ChipLister.ListUserCount = CFC_ChipLister.ListUserCount - 1
        ply.cfcChipLister_usesLister = nil
    end
end )

hook.Add( "PlayerSay", "CFC_ChipLister_ToggleHUD", function( ply, msg )
    if msg ~= TOGGLE_HUD_COMMAND then return end

    net.Start( "CFC_ChipLister_ToggleHUD" )
    net.Send( ply )

    return ""
end )


net.Receive( "CFC_ChipLister_SetEnabled", function( _, ply )
    local state = net.ReadBool()
    local ratelimit = listUserRatelimits[ply]

    listUserRatelimitDesStates[ply] = state

    if ratelimit then
        if ratelimit == 2 then return end

        listUserRatelimits[ply] = 2

        timer.Create( "CFC_ChipLister_NeedlesslyOverkillRatelimit_SetUserEnabled_" .. ply:SteamID(), 1, 1, function()
            if not IsValid( ply ) then return end

            listUserRatelimits[ply] = nil
            setListUserState( ply, listUserRatelimitDesStates[ply] )
        end )

        return
    end

    timer.Create( "CFC_ChipLister_NeedlesslyOverkillRatelimit_SetUserEnabled_" .. ply:SteamID(), 1, 1, function()
        if not IsValid( ply ) then return end

        listUserRatelimits[ply] = nil
    end )

    listUserRatelimits[ply] = 1
    setListUserState( ply, state )
end )

timer.Create( TIMER_NAME, LISTER_INTERVAL:GetFloat(), 0, updateListerData )

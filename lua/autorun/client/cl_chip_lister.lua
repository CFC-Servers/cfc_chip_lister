include( "cfc_chip_lister/shared/sh_chip_lister.lua" )

local TOGGLE_DIST = 1500
local MAX_ELEMENTS = 30
local SCREEN_SIZE = 1024
local SCREEN_SIZE_HALF = SCREEN_SIZE / 2

local FONT_NAME = "CFC_ChipLister_Font"
local FONT_SIZE = 30

local STR_GLOBAL = "Overall Total CPUs: "
local STR_TOTAL = "Total: "
local STR_MICROSECONDS = utf8.char( 181 ) .. "s"
local STR_TITLE = "-----E2/SF Lister-----"
local STR_TOGGLE = "(Press " .. string.upper( input.LookupBinding( "+use" ) or "e" ) .. "/use to toggle)"
local STR_ENABLE = "Press " .. string.upper( input.LookupBinding( "+use" ) or "e" ) .. "/use to turn on"
local STR_WAITING = "Waiting for next update from the server..."

local COLOR_BACKGROUND = Color( 0, 0, 0, 255 )
local COLOR_DIVIDER = Color( 255, 255, 255, 255 )
local COLOR_TEXT = Color( 255, 255, 255, 255 )
local COLOR_WORLD = Color( 150, 120, 120, 255 )
local CHIP_COLORS = {
    E2 = Color( 216, 34, 45, 255 ),
    SF = Color( 55, 100, 252, 255 ),
}
local HSV_FADE_OFFSET = Vector( 0, 0, -0.65 )
local HSV_FADE_MICROS_OFFSET = Vector( 0, 0, -0.25 )

local ID_WORLD = "[WORLD]"
local CPUS_FORMAT = "%05d"
local RENDER_TARGET_NAME = "cfc_chiplister_rt"


local rtChipLister = GetRenderTarget( RENDER_TARGET_NAME, SCREEN_SIZE, SCREEN_SIZE )
local INFO_OFFSET_OWNER = 0
local INFO_OFFSET_CHIP = 0
local TOGGLE_DIST_SQR = TOGGLE_DIST ^ 2
local COLOR_TEXT_FADED
local COLOR_MICROS

local IsValid = IsValid
local getPlayerByUID = Player
local rawget = rawget
local colorToHSV = ColorToHSV
local hsvToColor = HSVToColor
local utilJSONToTable = util.JSONToTable
local utilDecompress = util.Decompress
local stringLen = string.len
local stringSub = string.sub
local stringFormat = string.format
local teamGetColor = team.GetColor
local getClass
local getTeam

local FONT_DATA = {
    font = "Roboto Mono",
    extended = false,
    size = FONT_SIZE,
    weight = 500,
    blursize = 0,
    scanlines = 0,
    antialias = true,
    underline = false,
    italic = false,
    strikeout = false,
    symbol = false,
    rotary = false,
    shadow = false,
    Additive = false,
    outline = false,
}

do
    local entityMeta = FindMetaTable( "Entity" )
    getClass = entityMeta.GetClass

    local playerMeta = FindMetaTable( "Player" )
    getTeam = playerMeta.Team


    if not file.Exists( "resource/fonts/RobotoMono.ttf", "MOD" ) then
        local files = file.Find( "resource/fonts/*", "THIRDPARTY" )
        local robotoExists = false

        for _, v in ipairs( files ) do
            if v == "RobotoMono.ttf" then
                robotoExists = true

                break
            end
        end

        if not robotoExists then
            FONT_DATA.font = "Arial"
        end
    end

    surface.CreateFont( FONT_NAME, FONT_DATA )

    surface.SetFont( FONT_NAME )
    INFO_OFFSET_OWNER = -surface.GetTextSize( STR_TOTAL .. stringFormat( CPUS_FORMAT, 0 ) .. STR_MICROSECONDS )
    INFO_OFFSET_CHIP = -surface.GetTextSize( table.GetKeys( CHIP_COLORS )[1] .. " " .. stringFormat( CPUS_FORMAT, 0 ) .. STR_MICROSECONDS )
end

local LISTER_ENABLED = CreateClientConVar( "cfc_chiplister_enabled", 1, true, false, "Enables the Expression2/Starfall chip lister." )

local listerEnabled = LISTER_ENABLED:GetBool()


include( "cfc_chip_lister/client/cl_hud.lua" )


local function formatCPUs( num )
    local usageStr = stringFormat( CPUS_FORMAT, num or 0 )
    local leadStr = ""
    local leadCount = 0

    for i = 1, stringLen( usageStr ) do
        if stringSub( usageStr, i, i ) == "0" then
            leadStr = leadStr .. "0"
            leadCount = leadCount + 1
        else
            return leadStr, stringSub( usageStr, leadCount + 1 )
        end
    end

    return leadStr, ""
end

local function getTeamColor( ply )
    if ply == ID_WOLRD or not IsValid( ply ) then
        return COLOR_WORLD
    end

    return teamGetColor( getTeam( ply ) )
end

local function fadeColor( color, fadeOverride )
    local h, s, v = colorToHSV( color )
    local offset = fadeOverride or HSV_FADE_OFFSET

    return hsvToColor( h + offset[1], s + offset[2], v + offset[3] )
end

COLOR_TEXT_FADED = fadeColor( COLOR_TEXT )
COLOR_MICROS = fadeColor( COLOR_TEXT, HSV_FADE_MICROS_OFFSET )


-- Draws the Chip List data for a single chip
local function drawChipRow( data, i, ownerColor, elemCount, x, xEnd, y )
    local baseInd = i * 3 - 2
    local chipShorthand = rawget( data, baseInd + 1 )
    local chipUsageStrLead, chipUsageStr = formatCPUs( rawget( data, baseInd + 2 ) )

    surface.SetTextPos( x, y )
    surface.SetTextColor( ownerColor )
    surface.DrawText( rawget( data, baseInd ) ) -- chipName

    surface.SetTextPos( xEnd + INFO_OFFSET_CHIP, y )
    surface.SetTextColor( rawget( CHIP_COLORS, chipShorthand ) )
    surface.DrawText( chipShorthand .. " " )
    surface.SetTextColor( COLOR_TEXT_FADED )
    surface.DrawText( chipUsageStrLead )
    surface.SetTextColor( COLOR_TEXT )
    surface.DrawText( chipUsageStr )
    surface.SetTextColor( COLOR_MICROS )
    surface.DrawText( STR_MICROSECONDS )
    y = y + FONT_SIZE
    elemCount = elemCount + 1

    if elemCount == MAX_ELEMENTS then
        x = SCREEN_SIZE_HALF
        xEnd = xEnd + SCREEN_SIZE_HALF
        y = FONT_SIZE * 4
    end

    return elemCount, x, xEnd, y -- These should persist between calls
end

-- Draws the Chip List data of a particular chip owner
local function drawPlayersChipData( data, elemCount, x, xEnd, y )
    local dataCount = rawget( data, "Count" )
    local ownerUID = rawget( data, "OwnerUID" )
    local ownerUsage = rawget( data, "OwnerUsage" )

    local owner = ownerUID == ID_WORLD and ID_WORLD or getPlayerByUID( ownerUID )
    local ownerColor = getTeamColor( owner)
    local ownerColorFaded = fadeColor( ownerColor )
    local ownerUsageStrLead, ownerUsageStr = formatCPUs( ownerUsage )

    surface.SetTextPos( x, y )
    surface.SetTextColor( ownerColor )
    surface.DrawText( rawget( data, "OwnerName" ) )

    surface.SetTextPos( xEnd + INFO_OFFSET_OWNER, y )
    surface.DrawText( STR_TOTAL )
    surface.SetTextColor( ownerColorFaded )
    surface.DrawText( ownerUsageStrLead )
    surface.SetTextColor( ownerColor )
    surface.DrawText( ownerUsageStr )
    surface.SetTextColor( COLOR_MICROS )
    surface.DrawText( STR_MICROSECONDS )
    y = y + FONT_SIZE
    elemCount = elemCount + 1

    if elemCount == MAX_ELEMENTS then
        x = SCREEN_SIZE_HALF
        xEnd = xEnd + SCREEN_SIZE_HALF
        y = FONT_SIZE * 4
    end

    for i = 1, dataCount / 3 do
        elemCount, x, xEnd, y = drawChipRow( data, i, ownerColor, elemCount, x, xEnd, y )
    end

    return elemCount, x, xEnd, y -- These should persist between calls
end

-- Updates the Chip List material by drawing onto it once per update
local function updateListDraw( plyCount, globalUsage, perPlyData )
    local elemCount = 0
    local x = 0
    local xEnd = SCREEN_SIZE_HALF
    local y = 0

    globalUsageStrLead, globalUsageStr = formatCPUs( globalUsage )

    render.PushRenderTarget( rtChipLister )
    cam.Start2D()

    surface.SetDrawColor( COLOR_BACKGROUND )
    surface.SetFont( FONT_NAME )
    surface.SetTextColor( COLOR_TEXT )
    surface.DrawRect( 0, 0, SCREEN_SIZE, SCREEN_SIZE )

    draw.SimpleText( STR_TITLE, FONT_NAME, SCREEN_SIZE_HALF, 0, COLOR_TEXT, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP )
    y = y + FONT_SIZE
    draw.SimpleText( STR_TOGGLE, FONT_NAME, SCREEN_SIZE_HALF, y, COLOR_TEXT, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP )
    y = y + FONT_SIZE * 2

    surface.SetTextPos( x, y )
    surface.DrawText( STR_GLOBAL )
    surface.SetTextColor( COLOR_TEXT_FADED )
    surface.DrawText( globalUsageStrLead )
    surface.SetTextColor( COLOR_TEXT )
    surface.DrawText( globalUsageStr )
    surface.SetTextColor( COLOR_MICROS )
    surface.DrawText( STR_MICROSECONDS )
    y = y + FONT_SIZE

    for i = 1, plyCount do -- Draw the info of each owner and their chips
        local data = rawget( perPlyData, i )

        elemCount, x, xEnd, y = drawPlayersChipData( data, elemCount, x, xEnd, y )
    end

    surface.SetDrawColor( COLOR_DIVIDER )
    surface.DrawLine( SCREEN_SIZE_HALF, FONT_SIZE * 3, SCREEN_SIZE_HALF, SCREEN_SIZE )

    cam.End2D()
    render.PopRenderTarget()
end


cvars.AddChangeCallback( "cfc_chiplister_enabled", function( _, old, new )
    local state = new ~= "0"

    if state == listerEnabled then return end

    listerEnabled = state

    net.Start( "CFC_ChipLister_SetEnabled" )
    net.WriteBool( listerEnabled )
    net.SendToServer()

    if listerEnabled then
        render.PushRenderTarget( rtChipLister )
        cam.Start2D()

            surface.SetDrawColor( COLOR_BACKGROUND )
            surface.DrawRect( 0, 0, SCREEN_SIZE, SCREEN_SIZE )

            draw.SimpleText( STR_WAITING, FONT_NAME, SCREEN_SIZE_HALF, SCREEN_SIZE_HALF, COLOR_TEXT, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER )

        cam.End2D()
        render.PopRenderTarget()
    else
        render.PushRenderTarget( rtChipLister )
        cam.Start2D()

            surface.SetDrawColor( COLOR_BACKGROUND )
            surface.DrawRect( 0, 0, SCREEN_SIZE, SCREEN_SIZE )

            draw.SimpleText( STR_ENABLE, FONT_NAME, SCREEN_SIZE_HALF, SCREEN_SIZE_HALF, COLOR_TEXT, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER )

        cam.End2D()
        render.PopRenderTarget()
    end
end )


hook.Add( "InitPostEntity", "CFC_ChipLister_InformServerOfPlayerChoice", function()
    timer.Simple( 10, function()
        net.Start( "CFC_ChipLister_SetEnabled" )
        net.WriteBool( LISTER_ENABLED:GetBool() )
        net.SendToServer()
    end )
end )

hook.Add( "KeyPress", "CFC_ChipLister_ToggleScreen", function( ply, key ) -- ply is always LocalPlayer() on client
    if key ~= IN_USE then return end

    local tr = ply:GetEyeTrace()
    local ent = tr.Entity

    if not IsValid( ent ) or getClass( ent ) ~= "cfc_chip_lister" then return end
    if tr.StartPos:DistToSqr( tr.HitPos ) > TOGGLE_DIST_SQR then return end

    ply:ConCommand( "cfc_chiplister_enabled " .. ( listerEnabled and "0" or "1" ) )
end )


net.Receive( "CFC_ChipLister_UpdateListData", function()
    if not listerEnabled then return end

    local plyCount = net.ReadUInt( 8 )
    local globalUsage = net.ReadUInt( 20 )
    local compLength = net.ReadUInt( 32 )
    local compressed = net.ReadData( compLength )
    local perPlyData = utilJSONToTable( utilDecompress( compressed ) )

    updateListDraw( plyCount, globalUsage, perPlyData )
end )

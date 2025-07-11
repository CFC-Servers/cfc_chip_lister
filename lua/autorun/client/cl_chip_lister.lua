include( "cfc_chip_lister/shared/sh_chip_lister.lua" )

list.Set( "ContentCategoryIcons", "Chip Lister", "icon16/application_xp_terminal.png" )

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
local COLOR_ERR = Color( 150, 40, 0, 255 )
local CHIP_COLORS = {
    E2 = Color( 216, 34, 45, 255 ),
    SF = Color( 55, 100, 252, 255 ),
}
local HSV_FADE_ADJUST = Vector( 0, 1, 0.35 )
local HSV_FADE_MICROS_ADJUST = Vector( 0, 1, 0.75 )

local ID_WORLD = 0
local CPUS_FORMAT = "%05d"
local CPUS_FORMAT_ERR_LEAD = "err "
local CPUS_FORMAT_ERR_TRAIL = "0"


local rtChipLister = GetRenderTarget( "cfc_chiplister_rt", SCREEN_SIZE, SCREEN_SIZE )
local INFO_OFFSET_OWNER = 0
local INFO_OFFSET_CHIP = 0
local TOGGLE_DIST_SQR = TOGGLE_DIST ^ 2
local COLOR_TEXT_FADED
local COLOR_MICROS

local IsValid = IsValid
local rawget = rawget
local colorToHSV = ColorToHSV
local hsvToColor = HSVToColor
local stringLen = string.len
local stringSub = string.sub
local stringFormat = string.format
local mathClamp = math.Clamp
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
    if num == -1 then return CPUS_FORMAT_ERR_LEAD, CPUS_FORMAT_ERR_TRAIL, COLOR_ERR, COLOR_TEXT_FADED end

    local usageStr = stringFormat( CPUS_FORMAT, num or 0 )
    local leadStr = ""
    local leadCount = 0

    for i = 1, stringLen( usageStr ) do
        if stringSub( usageStr, i, i ) == "0" then
            leadStr = leadStr .. "0"
            leadCount = leadCount + 1
        else
            return leadStr, stringSub( usageStr, leadCount + 1 ), COLOR_TEXT_FADED, COLOR_TEXT
        end
    end

    return leadStr, "", COLOR_TEXT_FADED, COLOR_TEXT
end

local function getTeamColor( ply )
    if ply == ID_WORLD or not IsValid( ply ) then
        return COLOR_WORLD
    end

    return teamGetColor( getTeam( ply ) )
end

-- fadeOverride:  Vector( hueOffset, saturationMult, valueMult )
local function fadeColor( color, fadeOverride )
    local h, s, v = colorToHSV( color )
    local adjustment = fadeOverride or HSV_FADE_ADJUST

    return hsvToColor(
        mathClamp( h + adjustment[1], 0, 360 ),
        mathClamp( s * adjustment[2], 0, 1 ),
        mathClamp( v * adjustment[3], 0, 1 )
    )
end

COLOR_TEXT_FADED = fadeColor( COLOR_TEXT )
COLOR_MICROS = fadeColor( COLOR_TEXT, HSV_FADE_MICROS_ADJUST )


-- Draws the Chip List data for a single chip
local function drawChipRow( data, elemCount, ownerColor, x, xEnd, y )
    local chipShorthand = data.IsE2 and "E2" or "SF"
    local chipUsageStrLead, chipUsageStr, usageLeadColor, usageTrailColor = formatCPUs( data.CPUUsage )

    surface.SetTextPos( x, y )
    surface.SetTextColor( ownerColor )
    surface.DrawText( data.Name ) -- chipName

    surface.SetTextPos( xEnd + INFO_OFFSET_CHIP, y )
    surface.SetTextColor( rawget( CHIP_COLORS, chipShorthand ) )
    surface.DrawText( chipShorthand .. " " )
    surface.SetTextColor( usageLeadColor )
    surface.DrawText( chipUsageStrLead )
    surface.SetTextColor( usageTrailColor )
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
    local ownerIndex = data.OwnerIndex
    local ownerUsage = data.OwnerTotalUsage

    local owner = ownerIndex == ID_WORLD and ID_WORLD or Entity( ownerIndex )
    local ownerColor = getTeamColor( owner )
    local ownerColorFaded = fadeColor( ownerColor )
    local ownerUsageStrLead, ownerUsageStr = formatCPUs( ownerUsage )

    surface.SetTextPos( x, y )
    surface.SetTextColor( ownerColor )
    surface.DrawText( data.OwnerName or ownerUID )

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

    for _, chipInfo in ipairs( data.ChipInfo ) do
        elemCount, x, xEnd, y = drawChipRow( chipInfo, elemCount, ownerColor, x, xEnd, y )
    end

    return elemCount, x, xEnd, y -- These should persist between calls
end

-- Updates the Chip List material by drawing onto it once per update
local function updateListDraw( globalUsage, playerData )
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

    for _, data in ipairs( playerData ) do -- Draw the info of each owner and their chips
        elemCount, x, xEnd, y = drawPlayersChipData( data, elemCount, x, xEnd, y )
    end

    surface.SetDrawColor( COLOR_DIVIDER )
    surface.DrawLine( SCREEN_SIZE_HALF, FONT_SIZE * 3, SCREEN_SIZE_HALF, SCREEN_SIZE )

    cam.End2D()
    render.PopRenderTarget()
end

local function displayWaitingMessage()
    render.PushRenderTarget( rtChipLister )
    cam.Start2D()

        surface.SetDrawColor( COLOR_BACKGROUND )
        surface.DrawRect( 0, 0, SCREEN_SIZE, SCREEN_SIZE )

        draw.SimpleText( STR_WAITING, FONT_NAME, SCREEN_SIZE_HALF, SCREEN_SIZE_HALF, COLOR_TEXT, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER )

    cam.End2D()
    render.PopRenderTarget()
end

local function displayDisabledMessage()
    render.PushRenderTarget( rtChipLister )
    cam.Start2D()

        surface.SetDrawColor( COLOR_BACKGROUND )
        surface.DrawRect( 0, 0, SCREEN_SIZE, SCREEN_SIZE )

        draw.SimpleText( STR_ENABLE, FONT_NAME, SCREEN_SIZE_HALF, SCREEN_SIZE_HALF, COLOR_TEXT, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER )

    cam.End2D()
    render.PopRenderTarget()
end

local function setListerEnabled( state )
    listerEnabled = state

    net.Start( "CFC_ChipLister_SetEnabled" )
    net.WriteBool( listerEnabled )
    net.SendToServer()

    if listerEnabled then
        displayWaitingMessage()
    else
        displayDisabledMessage()
    end
end


cvars.AddChangeCallback( "cfc_chiplister_enabled", function( _, _, new )
    local state = new ~= "0"

    if state == listerEnabled then return end

    setListerEnabled( state )
end )


hook.Add( "InitPostEntity", "CFC_ChipLister_InformServerOfPlayerChoice", function()
    timer.Simple( 10, function()
        -- Initialize on join
        setListerEnabled( LISTER_ENABLED:GetBool() )
    end )
end )

hook.Add( "KeyPress", "CFC_ChipLister_ToggleScreen", function( ply, key ) -- ply is always LocalPlayer() on client
    if key ~= IN_USE then return end
    if not IsFirstTimePredicted() then return end

    local tr = ply:GetEyeTrace()
    local ent = tr.Entity

    if not IsValid( ent ) or getClass( ent ) ~= "cfc_chip_lister" then return end
    if tr.StartPos:DistToSqr( tr.HitPos ) > TOGGLE_DIST_SQR then return end

    ply:ConCommand( "cfc_chiplister_enabled " .. ( listerEnabled and "0" or "1" ) )
end )

local maxplayers_bits = math.ceil( math.log( 1 + game.MaxPlayers() ) / math.log( 2 ) )
net.Receive( "CFC_ChipLister_UpdateListData", function()
    if not listerEnabled then return end

    local hasChips = net.ReadBool()
    if not hasChips then
        updateListDraw( 0, {} )
        return
    end

    local globalUsage = net.ReadUInt( 16 )
    local playerData = {}
    local playerDataCount = net.ReadUInt( 5 )
    for _ = 1, playerDataCount do
        local data = {
            Count = net.ReadUInt( 6 ),
            OwnerName = net.ReadString(),
            OwnerIndex = net.ReadUInt( maxplayers_bits ),
            OwnerTotalUsage = net.ReadUInt( 15 ),
            ChipInfo = {}
        }

        for _ = 1, data.Count do
            local chip = {
                Name = "-" .. net.ReadString(),
                IsE2 = net.ReadBool(),
                CPUUsage = net.ReadInt( 15 ),
            }
            table.insert( data.ChipInfo, chip )
        end

        table.insert( playerData, data )
    end

    updateListDraw( globalUsage, playerData )
end )

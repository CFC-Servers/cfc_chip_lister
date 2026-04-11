local listerPanel
local ignoringPosConvars = false

local PANEL_MIN_SIZE_FRAC = 300 / 1080
local PANEL_DEFAULT_SIZE_FRAC = 400 / 1080

local PANEL_PERSIST = CreateClientConVar( "cfc_chiplister_hud_persist", 0, true, true, "Causes the chiplister HUD element to persist across sessions." )
local PANEL_POS_X = CreateClientConVar( "cfc_chiplister_hud_pos_x", 50, true, false, "X-Position of the chiplister HUD element." )
local PANEL_POS_Y = CreateClientConVar( "cfc_chiplister_hud_pos_y", 25, true, false, "Y-Position of the chiplister HUD element." )
local PANEL_SIZE_FRAC = CreateClientConVar( "cfc_chiplister_hud_size_frac", -1, true, false, "Fractional size of the chiplister HUD element. -1 For the addon default.", -1, 1 )

local LISTER_ENABLED = GetConVar( "cfc_chiplister_enabled" )


local function clampSize( size )
    return math.max( size, ScrH() * PANEL_MIN_SIZE_FRAC )
end

local function getSizeFromConvar()
    local frac = PANEL_SIZE_FRAC:GetFloat()
    if frac < 0 then frac = PANEL_DEFAULT_SIZE_FRAC end

    return clampSize( frac * ScrH() )
end

local function openListerPanel()
    if IsValid( listerPanel ) then
        listerPanel:Show()
        listerPanel:MoveToFront()

        return
    end

    listerPanel = vgui.Create( "DFrame" )
    listerPanel:SetSize( getSizeFromConvar(), getSizeFromConvar() )
    listerPanel:SetPos( PANEL_POS_X:GetInt(), PANEL_POS_Y:GetInt() )
    listerPanel:SetSizable( true )
    listerPanel:SetScreenLock( true )
    listerPanel:SetTitle( "E2/SF Lister    (Open chat for cursor)" )

    local imagePanel = vgui.Create( "DImage", listerPanel )
    imagePanel:SetPos( 10, 35 )
    imagePanel:Dock( FILL )
    imagePanel:SetImage( "!cfc_chiplister_screen" )

    local _imagePaint = imagePanel.Paint
    function imagePanel:Paint( w, h )
        if LISTER_ENABLED:GetBool() then
            _imagePaint( self, w, h )
            return
        end

        -- If lister is disabled, draw a custom message mentioning it.
        -- Otherwise, the "Press E to toggle" text will show up from the RT, which only applies to placed listers.
        surface.SetDrawColor( 0, 0, 0, 255 )
        surface.DrawRect( 0, 0, w, h )
        draw.SimpleText( "Chip Lister not enabled!", "CloseCaption_Bold", w / 2, h / 2, nil, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER )
    end


    function listerPanel:OnClose()
        LocalPlayer():ConCommand( "cfc_chiplister_hud_persist 0" )
    end

    local _SetPos = listerPanel.SetPos
    function listerPanel:SetPos( x, y, noConvar )
        _SetPos( self, x, y )

        if not noConvar then
            local oldState = ignoringPosConvars
            ignoringPosConvars = true
            PANEL_POS_X:SetInt( x )
            PANEL_POS_Y:SetInt( y )
            ignoringPosConvars = oldState
        end
    end

    local _SetSize = listerPanel.SetSize
    function listerPanel:SetSize( w, h )
        local size = clampSize( math.min( w, h ) ) -- Keep it as a square

        _SetSize( self, size, size )
        PANEL_SIZE_FRAC:SetFloat( size / 1080 )
    end

    LocalPlayer():ConCommand( "cfc_chiplister_hud_persist 1" )
end

local function closeListerPanel()
    if not IsValid( listerPanel ) then return end

    listerPanel:Close()
end

local function toggleListerPanel()
    if IsValid( listerPanel ) and listerPanel:IsVisible() then
        closeListerPanel()
    else
        openListerPanel()
    end
end

local function setPosFromConvar( x, y )
    if ignoringPosConvars then return end
    if not IsValid( listerPanel ) then return end

    x = x or PANEL_POS_X:GetInt()
    y = y or PANEL_POS_Y:GetInt()
    listerPanel:SetPos( x, y, true )
end


CreateMaterial( "cfc_chiplister_screen", "UnlitGeneric", {
    ["$basetexture"] = "cfc_chiplister_rt",
    ["$model"] = 1,
} )

concommand.Add( "cfc_chiplister_open_hud", openListerPanel, nil, "Opens the Chip Lister as a HUD element." )
concommand.Add( "cfc_chiplister_close_hud", closeListerPanel, nil, "Closes the Chip Lister HUD element." )
concommand.Add( "cfc_chiplister_toggle_hud", toggleListerPanel, nil, "Toggles the Chip Lister HUD element." )
net.Receive( "CFC_ChipLister_ToggleHUD", toggleListerPanel )


cvars.AddChangeCallback( "cfc_chiplister_hud_pos_x", function( _, _, new )
    setPosFromConvar( tonumber( new ), nil )
end, "CFC_ShipLister_MoveHUD" )

cvars.AddChangeCallback( "cfc_chiplister_hud_pos_y", function( _, _, new )
    setPosFromConvar( nil, tonumber( new ) )
end, "CFC_ShipLister_MoveHUD" )


hook.Add( "AddToolMenuCategories", "CFC_ChipLister_AddToolMenuCategories", function()
    spawnmenu.AddToolCategory( "Options", "CFC", "#CFC" )
end )

hook.Add( "PopulateToolMenu", "CFC_ChipLister_PopulateToolMenu", function()
    spawnmenu.AddToolMenuOption( "Options", "CFC", "cfc_chiplister", "#Chip Lister", "", "", function( panel )
        panel:CheckBox( "Enable E2/SF Lister", "cfc_chiplister_enabled" )
        panel:Button( "Toggle Chip Lister on HUD", "cfc_chiplister_toggle_hud" )

        local btnReset = panel:Button( "Reset HUD Position" )

        function btnReset:DoClick()
            PANEL_POS_X:Revert()
            PANEL_POS_Y:Revert()
        end
    end )
end )

hook.Add( "InitPostEntity", "CFC_ChipLister_OpenHUD", function()
    if not PANEL_PERSIST:GetBool() then return end

    timer.Simple( 5, openListerPanel )
end )

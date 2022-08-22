local clConVars = {}
local convarPrefix = "cfc_chiplister"

local function createChipListerClientConVar( name, default, save, userinfo, text, min, max )
    local convar = CreateClientConVar( convarPrefix .. "_" .. name, default, save, userinfo, text, min, max )
    clConVars[name] = convar

    return convar
end

local matChipLister = CreateMaterial( "cfc_chiplister_screen", "UnlitGeneric", {
    ["$basetexture"] = "cfc_chiplister_rt",
    ["$model"] = 1,
} )

local HUD_ENABLED = createChipListerClientConVar( "hud_enabled", 0, true, false, "Whether or not to display the chip lister on your screen at all times.", 0, 1 )
local HUD_SCALE = createChipListerClientConVar( "hud_scale", 0.2, true, false, "The size of the chip lister on your HUD, scaled by your screen width.", 0, 1 )
local HUD_POS_X = createChipListerClientConVar( "hud_pos_x", 0.8, true, false, "The x-position of the chip lister on your HUD, scaled by your screen width.", 0, 1 )
local HUD_POS_Y = createChipListerClientConVar( "hud_pos_y", 0.2, true, false, "The y-position of the chip lister on your HUD, scaled by your screen height.", 0, 1 )

clConVars.cfc_chiplister_enabled = GetConVar( "cfc_chiplister_enabled" )

local hudEnabled = HUD_ENABLED:GetBool()
local hudScale = HUD_SCALE:GetFloat()
local hudPosX = HUD_POS_X:GetFloat()
local hudPosY = HUD_POS_Y:GetFloat()


local function applyOrRemoveHUDLister()
    if not hudEnabled then
        hook.Remove( "HUDPaint", "CFC_ChipLister_DrawHUD" )

        return
    end

    hook.Add( "HUDPaint", "CFC_ChipLister_DrawHUD", function()
        local scrW = ScrW()
        local scrH = ScrH()
        local size = hudScale * scrW

        surface.SetMaterial( matChipLister )
        surface.SetDrawColor( 255, 255, 255, 255 )
        surface.DrawTexturedRect( hudPosX * scrW, hudPosY * scrH, size, size )
    end )
end


hook.Add( "AddToolMenuCategories", "CFC_ChipLister_AddToolMenuCategories", function()
    spawnmenu.AddToolCategory( "Options", "CFC", "#CFC" )
end )

hook.Add( "PopulateToolMenu", "CFC_ChipLister_PopulateToolMenu", function()
    spawnmenu.AddToolMenuOption( "Options", "CFC", "cfc_chiplister", "#Chip Lister", "", "", function( panel )
        ProtectedCall( function() -- ControlPresets only exists in certain gamemodes
            local presetControl = vgui.Create( "ControlPresets", panel )
            local defaults = {}

            for cvName, cv in pairs( clConVars ) do
                presetControl:AddConVar( cvName )
                defaults[cvName] = cv:GetDefault()
            end

            presets.Add( "cfc_chiplister", "Default", defaults )
            presetControl:SetPreset( "cfc_chiplister" )

            panel:AddItem( presetControl )
        end )

        panel:CheckBox( "Enable E2/SF Lister", "cfc_chiplister_enabled" )
        panel:CheckBox( "Enable Chip Lister on HUD", "cfc_chiplister_hud_enabled" )

        panel:NumSlider( "Lister HUD Size", "cfc_chiplister_hud_scale", 0, 1, 2 )
        panel:NumSlider( "Lister HUD x-pos", "cfc_chiplister_hud_pos_x", 0, 1, 2 )
        panel:NumSlider( "Lister HUD y-pos", "cfc_chiplister_hud_pos_y", 0, 1, 2 )
    end )
end )


cvars.AddChangeCallback( "cfc_chiplister_hud_enabled", function( _, old, new )
    hudEnabled = new ~= "0"
    applyOrRemoveHUDLister()
end )

cvars.AddChangeCallback( "cfc_chiplister_hud_scale", function( _, old, new )
    hudScale = tonumber( new ) or 0.2
end )

cvars.AddChangeCallback( "cfc_chiplister_hud_pos_x", function( _, old, new )
    hudPosX = tonumber( new ) or 0.8
end )

cvars.AddChangeCallback( "cfc_chiplister_hud_pos_y", function( _, old, new )
    hudPosY = tonumber( new ) or 0.1
end )


applyOrRemoveHUDLister()

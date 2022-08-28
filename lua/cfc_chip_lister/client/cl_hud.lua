local listerPanel

local function createListerPanel()
    if IsValid( listerPanel ) then
        listerPanel:Show()
        listerPanel:MoveToFront()

        return
    end

    listerPanel = vgui.Create( "DFrame" )
    listerPanel:SetSize( 480, 480 )
    listerPanel:Center()
    listerPanel:SetSizable( true )
    listerPanel:SetScreenLock( true )
    listerPanel:SetTitle( "E2/SF Lister" )

    local imagePanel = vgui.Create( "DImage", listerPanel )
    imagePanel:SetPos( 10, 35 )
    imagePanel:Dock( FILL )
    imagePanel:SetImage( "!cfc_chiplister_screen" )
end


CreateMaterial( "cfc_chiplister_screen", "UnlitGeneric", {
    ["$basetexture"] = "cfc_chiplister_rt",
    ["$model"] = 1,
} )

concommand.Add( "cfc_chiplister_open_hud", createListerPanel, nil, "Opens the Chip Lister as a HUD element." )
net.Receive( "CFC_ChipLister_OpenHUD", createListerPanel )


hook.Add( "AddToolMenuCategories", "CFC_ChipLister_AddToolMenuCategories", function()
    spawnmenu.AddToolCategory( "Options", "CFC", "#CFC" )
end )

hook.Add( "PopulateToolMenu", "CFC_ChipLister_PopulateToolMenu", function()
    spawnmenu.AddToolMenuOption( "Options", "CFC", "cfc_chiplister", "#Chip Lister", "", "", function( panel )
        panel:CheckBox( "Enable E2/SF Lister", "cfc_chiplister_enabled" )
        panel:Button( "Open Chip Lister on HUD", "cfc_chiplister_open_hud" )
    end )
end )

hook.Add( "Think", "CFC_ChipLister_ResizeHUD", function()
    if not IsValid( listerPanel ) then return end

    local w, h = listerPanel:GetSize()

    if w == h then return end

    local size = math.min( w, h )
    listerPanel:SetSize( size, size )
end )

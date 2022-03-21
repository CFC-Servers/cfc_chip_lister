include( "shared.lua" )

ENT.RenderGroup = RENDERGROUP_BOTH

local render = render
local matChipLister = Material( "!cfc_chiplister_screen" )
local matWritez = Material( "engine/writez" )

-- Code taken from Starfall screen rendering. Most likely could be improved.

function ENT:Initialize()
    self.BaseClass.Initialize( self )

    local info = self.ListScreenOffsets[self:GetModel()]

    if not info then
        local mins = self:OBBMins()
        local maxs = self:OBBMaxs()
        local size = maxs - mins

        info = {
            Name       = "",
            RS         = ( size.y - 1 ) / 512,
            RatioX     = size.y / size.x,
            offset     = self:OBBCenter() + Vector( 0, 0, maxs.z - 0.24 ),
            rot        = Angle( 0, 0, 180 ),
            x1         = 0,
            x2         = 0,
            y1         = 0,
            y2         = 0,
            z          = 0,
        }
    end

    self.ScreenInfo = info
    self:SetScreenMatrix( info )
end

function ENT:SetScreenMatrix( info )
    local rotation, translation, translation2, scale = Matrix(), Matrix(), Matrix(), Matrix()
    rotation:SetAngles( info.rot )
    translation:SetTranslation( info.offset )
    translation2:SetTranslation( Vector( -256 / info.RatioX, -256, 0 ) )
    scale:SetScale( Vector( info.RS, info.RS, info.RS ) )

    self.ScreenMatrix = translation * rotation * scale * translation2
    self.Aspect = info.RatioX
    self.Scale = info.RS
    self.Origin = info.offset
    self.Transform = self:GetWorldTransformMatrix() * self.ScreenMatrix

    local w, h = 512 / self.Aspect, 512
    self.ScreenQuad = { Vector( 0, 0, 0 ), Vector( w, 0, 0 ), Vector( w, h, 0 ), Vector( 0, h, 0 ), Color( 0, 0, 0, 255 ) }
end

function ENT:RenderScreen()
    if not matChipLister or matChipLister:IsError() then
        matChipLister = Material( "!cfc_chiplister_screen" )
    end

    surface.SetDrawColor( 255, 255, 255, 255 )
    surface.SetMaterial( matChipLister )
    surface.DrawTexturedRect( 0, 0, 512, 512 )
end

function ENT:Draw()
    self:DrawModel()
end

function ENT:DrawTranslucent()
    self:DrawModel()

    if halo.RenderedEntity() == self then return end
    
    local entityMatrix = self:GetWorldTransformMatrix()

    -- Draw screen here
    local transform = entityMatrix * self.ScreenMatrix
    self.Transform = transform

    cam.PushModelMatrix( transform )
        render.ClearStencil()
        render.SetStencilEnable( true )
        render.SetStencilFailOperation( STENCILOPERATION_KEEP )
        render.SetStencilZFailOperation( STENCILOPERATION_KEEP )
        render.SetStencilPassOperation( STENCILOPERATION_REPLACE )
        render.SetStencilCompareFunction( STENCILCOMPARISONFUNCTION_ALWAYS )
        render.SetStencilWriteMask( 1)
        render.SetStencilReferenceValue( 1 )

        -- First draw a quad that defines the visible area
        render.SetColorMaterial()
        render.DrawQuad( unpack( self.ScreenQuad ) )

        render.SetStencilCompareFunction( STENCILCOMPARISONFUNCTION_EQUAL )
        render.SetStencilTestMask( 1 )

        -- Clear it to the clear color and clear depth as well
        local color = self.ScreenQuad[5]
        if color.a == 255 then
            render.ClearBuffersObeyStencil( color.r, color.g, color.b, color.a, true )
        end

        -- Render the lister
        render.PushFilterMag( TEXFILTER.ANISOTROPIC )
        render.PushFilterMin( TEXFILTER.ANISOTROPIC )

        self:RenderScreen()

        render.PopFilterMag()
        render.PopFilterMin()

        render.SetStencilEnable( false )

        -- Give the screen back its depth
        render.SetMaterial( matWritez )
        render.DrawQuad( unpack( self.ScreenQuad ) )

    cam.PopModelMatrix()
end

ENT.ListScreenOffsets = {
    ["models/hunter/plates/plate1x1.mdl"] = {
        Name      =    "Panel 1x1",
        RS        =    0.09,
        RatioX    =    1,
        offset    =    Vector( 0, 0, 2 ),
        rot       =    Angle( 0, 90, 180 ),
        x1        =    -48,
        x2        =    48,
        y1        =    -48,
        y2        =    48,
        z         =    0,
    },
    ["models/hunter/plates/plate2x2.mdl"] = {
        Name      =    "Panel 2x2",
        RS        =    0.182,
        RatioX    =    1,
        offset    =    Vector( 0, 0, 2 ),
        rot       =    Angle( 0, 90, 180 ),
        x1        =    -48,
        x2        =    48,
        y1        =    -48,
        y2        =    48,
        z         =    0,
    },
    ["models/hunter/plates/plate4x4.mdl"] = {
        Name      =    "plate4x4.mdl",
        RS        =    0.3707,
        RatioX    =    1,
        offset    =    Vector( 0, 0, 2 ),
        rot       =    Angle( 0, 90, 180 ),
        x1        =    -94.9,
        x2        =    94.9,
        y1        =    -94.9,
        y2        =    94.9,
        z         =    1.7,
    },
    ["models/hunter/plates/plate8x8.mdl"] = {
        Name      =    "plate8x8.mdl",
        RS        =    0.741,
        RatioX    =    1,
        offset    =    Vector( 0, 0, 2 ),
        rot       =    Angle( 0, 90, 180 ),
        x1        =    -189.8,
        x2        =    189.8,
        y1        =    -189.8,
        y2        =    189.8,
        z         =    1.7,
    },
    ["models/hunter/plates/plate16x16.mdl"] = {
        Name      =    "plate16x16.mdl",
        RS        =    1.482,
        RatioX    =    1,
        offset    =    Vector( 0, 0, 2 ),
        rot       =    Angle( 0, 90, 180 ),
        x1        =    -379.6,
        x2        =    379.6,
        y1        =    -379.6,
        y2        =    379.6,
        z         =    1.7,
    },
}

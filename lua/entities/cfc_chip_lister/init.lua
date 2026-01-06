AddCSLuaFile( "cl_init.lua" )
AddCSLuaFile( "shared.lua" )
include( "shared.lua" )


local MODEL_ERROR = "models/error.mdl"

local makeChiplister


function ENT:Initialize()
    self.BaseClass.Initialize( self )

    if self:GetModel() == MODEL_ERROR then
        self:SetModel( self.Model )
    end

    self:PhysicsInit( SOLID_VPHYSICS )
    self:SetMoveType( MOVETYPE_VPHYSICS )
    self:SetSolid( SOLID_VPHYSICS )
    self:SetUseType( SIMPLE_USE )

    self:AddEFlags( EFL_FORCE_CHECK_TRANSMIT )

    self:SetMaterial( "models/debug/debugwhite" )
    self:SetColor( Color( 36, 36, 36, 255 ) )
end

function ENT:SpawnFunction( ply, tr )
    if not tr.Hit then return end

    local normal = tr.HitNormal
    local pos = tr.HitPos + normal * 1.5
    local ang = normal:Angle()
    ang:RotateAroundAxis( ang:Right(), -90 )

    local ent = makeChiplister( ply, {
        Pos = pos,
        Angle = ang,
        Model = self.Model,
    } )

    return ent
end

function ENT:UpdateTransmitState()
    return TRANSMIT_ALWAYS
end


makeChiplister = function( ply, data )
    local validPly = IsValid( ply )
    if validPly and not ply:CheckLimit( "cfc_chip_lister" ) then return end

    local ent = ents.Create( "cfc_chip_lister" )
    if not ent:IsValid() then return end

    duplicator.DoGeneric( ent, data )
    ent:Spawn()
    ent:Activate()

    duplicator.DoGenericPhysics( ent, ply, data )

    if validPly then
        ply:AddCount( "cfc_chip_lister", ent )
        ply:AddCleanup( "cfc_chip_lister", ent )
    end

    return ent
end


duplicator.RegisterEntityClass( "cfc_chip_lister", makeChiplister, "Data" )

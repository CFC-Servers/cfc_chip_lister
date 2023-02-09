AddCSLuaFile( "cl_init.lua" )
AddCSLuaFile( "shared.lua" )
include( "shared.lua" )


local ErrorModel = "models/error.mdl"

function ENT:KeyValue( key, value )
    if key == "model" then
        self.Model = value
    end
end

function ENT:Initialize()
    self.BaseClass.Initialize( self )

    if self:GetModel() == ErrorModel then
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

function ENT:UpdateTransmitState()
    return TRANSMIT_ALWAYS
end

ENT.Type            = "anim"
ENT.Base            = "base_gmodentity"

ENT.PrintName       = "Huge Chip Lister"
ENT.Author          = "legokidlogan"
ENT.Contact         = "https://cfcservers.org/discord"
ENT.Purpose         = "Displays E2 and Starfall chips"
ENT.Instructions    = ""
ENT.Category        = "Chip Lister"

ENT.Spawnable       = true
ENT.Model           = "models/hunter/plates/plate16x16.mdl"
ENT.IconOverride    = "spawnicons/models/hunter/plates/plate16x16.png"


CreateConVar( "sbox_maxcfc_chip_lister", 16, { FCVAR_ARCHIVE, FCVAR_REPLICATED }, "The max number of cfc chip listers per player.", 0, 1000 )

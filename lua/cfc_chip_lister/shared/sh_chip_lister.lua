CreateConVar( "sbox_maxcfc_chip_lister", 20, { FCVAR_ARCHIVE, FCVAR_REPLICATED }, "The max number of chip listers per player.", 0, 1000 )

if cleanup then
    cleanup.Register( "cfc_chip_lister" )
end

local function addChipListerModel( spawnName, name, model )
    local modelNoExtension = string.StripExtension( model )
    list.Set( "SpawnableEntities", spawnName, {
        PrintName = name,
        ClassName = "cfc_chip_lister",
        IconOverride = "spawnicons/" .. modelNoExtension .. ".png",
        Category = "Chip Lister",
        KeyValues = {
            model = model
        }
    } )
end

addChipListerModel(
    "cfc_chip_lister_tiny",
    "Tiny Chip Lister",
    "models/hunter/plates/plate1x1.mdl"
)

addChipListerModel(
    "cfc_chip_lister_small",
    "Small Chip Lister",
    "models/hunter/plates/plate2x2.mdl"
)

addChipListerModel(
    "cfc_chip_lister_medium",
    "Medium Chip Lister",
    "models/hunter/plates/plate4x4.mdl"
)

addChipListerModel(
    "cfc_chip_lister_large",
    "Large Chip Lister",
    "models/hunter/plates/plate8x8.mdl"
)

local function addChipListerModel( spawnName, name, model )
    list.Set( "SpawnableEntities", spawnName, {
        PrintName = name,
        ClassName = "cfc_chip_lister",
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

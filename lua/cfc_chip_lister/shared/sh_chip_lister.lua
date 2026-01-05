local function addChipListerModel( className, name, model )
    local modelNoExtension = string.StripExtension( model )
    local ENT = scripted_ents.Get( "cfc_chip_lister" )

    ENT.PrintName = name
    ENT.Model = model
    ENT.IconOverride = "spawnicons/" .. modelNoExtension .. ".png"

    scripted_ents.Register( ENT, className )
end


hook.Add( "Initialize", "CFC_ChipLister_RegisterAdditionalModels", function()
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
end )

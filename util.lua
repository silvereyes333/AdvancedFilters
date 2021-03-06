local AF = AdvancedFilters
AF.util = {}
AF.util.LibFilters = LibStub("LibFilters-2.0")
AF.util.LibMotifCategories = LibStub("LibMotifCategories-1.0")

function AF.util.ApplyFilter(button, filterTag, requestUpdate)
    local LibFilters = AF.util.LibFilters
    local callback = button.filterCallback
    local filterType

    if AF.currentInventoryType == 6 then
        filterType = LF_VENDOR_BUY
    else
        filterType = LibFilters:GetCurrentFilterTypeForInventory(AF.currentInventoryType)
    end

    --d("Apply " .. button.name .. " from " .. filterTag .. " for filterType " .. filterType .. " and inventoryType " .. AF.currentInventoryType)

    --if something isn't right, abort
    if callback == nil then
        d("callback was nil for " .. filterTag)
        return
    end
    if filterType == nil then
        d("filterType was nil for " .. filterTag)
        return
    end

    --first, clear current filters without an update
    LibFilters:UnregisterFilter(filterTag)
    --then register new one and hand off update parameter
    LibFilters:RegisterFilter(filterTag, filterType, callback)
    if requestUpdate == true then LibFilters:RequestUpdate(filterType) end
end

function AF.util.RemoveAllFilters()
    local LibFilters = AF.util.LibFilters
    local filterType

    if AF.currentInventoryType == 6 then
        filterType = LF_VENDOR_BUY
    else
        filterType = LibFilters:GetCurrentFilterTypeForInventory(AF.currentInventoryType)
    end

    LibFilters:UnregisterFilter("AF_ButtonFilter")
    LibFilters:UnregisterFilter("AF_DropdownFilter")

    if filterType ~= nil then LibFilters:RequestUpdate(filterType) end
end

function AF.util.RefreshSubfilterBar(subfilterBar)
    if not subfilterBar then return end

    local inventoryType = subfilterBar.inventoryType
    local inventory, inventorySlots

    --disable buttons
    for _, button in pairs(subfilterBar.subfilterButtons) do
        button.texture:SetColor(.3, .3, .3, .9)
        button:SetEnabled(false)
        button.clickable = false
    end

    if inventoryType == 6 then
        inventory = STORE_WINDOW
        inventorySlots = inventory.items
    else
        inventory = PLAYER_INVENTORY.inventories[inventoryType]
        inventorySlots = inventory.slots
    end

    --check buttons for availability
    for _, itemData in pairs(inventorySlots) do
        for _, button in pairs(subfilterBar.subfilterButtons) do
            if button.filterCallback(itemData) and (not button.clickable)
              and (itemData.filterData[1] == inventory.currentFilter
              or itemData.filterData[2] == inventory.currentFilter) then
                button.texture:SetColor(1, 1, 1, 1)
                button:SetEnabled(true)
                button.clickable = true
            end
        end
    end
end

function AF.util.BuildDropdownCallbacks(groupName, subfilterName)
    if subfilterName == "Heavy" or subfilterName == "Medium"
      or subfilterName == "Light" or subfilterName == "Clothing" then
        subfilterName = "Body"
    end

    local callbackTable = {}
    local keys = {
        ["Weapons"] = {
            "All", "OneHand", "TwoHand", "Bow", "DestructionStaff", "HealStaff",
        },
        ["Armor"] = {
            "All", "Body", "Shield", "Jewelry", "Vanity",
        },
        ["Consumables"] = {
            "All", "Crown", "Food", "Drink", "Recipe", "Potion", "Poison",
            "Motif", "Container", "Repair", "Trophy",
        },
        ["Crafting"] = {
            "All", "Blacksmithing", "Clothier", "Woodworking", "Alchemy",
            "Enchanting", "Provisioning", "Style", "WeaponTrait", "ArmorTrait",
        },
        ["Miscellaneous"] = {
            "All", "Glyphs", "SoulGem", "Siege", "Bait", "Tool", "Trophy",
            "Fence", "Trash",
        },
        ["Junk"] = {
            "All", "Weapon", "Apparel", "Consumable", "Materials",
            "Miscellaneous"
        },
        ["Blacksmithing"] = {
            "All", "RawMaterial", "RefinedMaterial", "Temper",
        },
        ["Clothing"] = {
            "All", "RawMaterial", "RefinedMaterial", "Resin",
        },
        ["Woodworking"] = {
            "All", "RawMaterial", "RefinedMaterial", "Tannin",
        },
        ["Alchemy"] = {
            "All", "Reagent", "Water", "Oil",
        },
        ["Enchanting"] = {
            "All", "Aspect", "Essence", "Potency",
        },
        ["Provisioning"] = {
            "All", "FoodIngredient", "DrinkIngredient", "OldIngredient", "Bait",
        },
        ["Style"] = {
            "All", "NormalStyle", "RareStyle", "AllianceStyle",
            "ExoticStyle", "CrownStyle",
        },
        ["Traits"] = {
            "All", "ArmorTrait", "WeaponTrait",
        },
    }

    -- insert global "All" filters
    for _, callbackEntry in ipairs(AF.subfilterCallbacks["All"].dropdownCallbacks) do
        table.insert(callbackTable, callbackEntry)
    end

    if subfilterName == "All" then
        --insert all default filters for each subfilter
        for _, subfilterName in ipairs(keys[groupName]) do
            local currentSubfilterTable = AF.subfilterCallbacks[groupName][subfilterName]

            for _, callbackEntry in ipairs(currentSubfilterTable.dropdownCallbacks) do
                table.insert(callbackTable, callbackEntry)
            end
        end

        --insert all filters provided by addons
        for _, addonTable in ipairs(AF.subfilterCallbacks[groupName].addonDropdownCallbacks) do
            --check to see if addon is set up for a submenu
            if addonTable.submenuName then
                --insert whole package
                table.insert(callbackTable, addonTable)
            else
                --insert all callbackTable entries
                local currentAddonTable = addonTable.callbackTable

                for _, callbackEntry in ipairs(currentAddonTable) do
                    table.insert(callbackTable, callbackEntry)
                end
            end
        end
    else
        --insert filters for provided subfilter
        local currentSubfilterTable = AF.subfilterCallbacks[groupName][subfilterName]
        for _, callbackEntry in ipairs(currentSubfilterTable.dropdownCallbacks) do
            table.insert(callbackTable, callbackEntry)
        end

        --insert filters provided by addons for this subfilter
        for _, addonTable in ipairs(AF.subfilterCallbacks[groupName].addonDropdownCallbacks) do
            --scan addon to see if it applies to given subfilter
            for _, subfilter in ipairs(addonTable.subfilters) do
                if subfilter == subfilterName or subfilter == "All" then
                    --add addon filters
                    --check to see if addon is set up for a submenu
                    if addonTable.submenuName then
                        --insert whole package
                        table.insert(callbackTable, addonTable)
                    else
                        --insert all callbackTable entries
                        local currentAddonTable = addonTable.callbackTable

                        for _, callbackEntry in ipairs(currentAddonTable) do
                            table.insert(callbackTable, callbackEntry)
                        end
                    end
                end
            end
        end
    end

    return callbackTable
end

function AF.util.GetLanguage()
    local lang = GetCVar("language.2")
    local supported = {
        de = 1,
        en = 2,
        es = 3,
        fr = 4,
        ru = 5,
        jp = 6,
    }

    --check for supported languages
    if(supported[lang] ~= nil) then return lang end

    --return english if not supported
    return "en"
end

--thanks ckaotik
function AF.util.Localize(text)
    if type(text) == 'number' then
        -- get the string from this constant
        text = GetString(text)
    end
    -- clean up suffixes such as ^F or ^S
    return zo_strformat(SI_TOOLTIP_ITEM_NAME, text) or " "
end

function AF.util.ThrottledUpdate(callbackName, timer, callback, ...)
    local args = {...}
    local function Update()
        EVENT_MANAGER:UnregisterForUpdate(callbackName)
        callback(unpack(args))
    end

    EVENT_MANAGER:UnregisterForUpdate(callbackName)
    EVENT_MANAGER:RegisterForUpdate(callbackName, timer, Update)
end

function AF.util.GetItemLink(slot)
    if slot.bagId then
        return GetItemLink(slot.bagId, slot.slotIndex)
    else
        return GetStoreItemLink(slot.slotIndex)
    end
end
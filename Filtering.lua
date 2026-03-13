local _, BrannFilterBag = ...

-------------------------------------------------------------------------------
-- BrannFilterBag – Filtering
-- Strukturiertes Regel-Evaluierungs-System
-- Jede Regel: { field, op, value }
-- op: "AND" | "OR" | "NOT"
-------------------------------------------------------------------------------

BrannFilterBag.Filtering = {}
local F = BrannFilterBag.Filtering

-- Spaltennamen für Quality
BrannFilterBag.QualityNames = {
    [0] = "poor",       -- Grau / Wertlos
    [1] = "common",     -- Weiß / Gewöhnlich
    [2] = "uncommon",   -- Grün / Ungewöhnlich
    [3] = "rare",       -- Blau / Selten
    [4] = "epic",       -- Lila / Episch
    [5] = "legendary",  -- Orange / Legendär
    [6] = "artifact",   -- Gold / Artefakt
    [7] = "heirloom",   -- Hellblau / Erbstück
}

-- Locale-Qualitätsnamen aus WoW-Strings
BrannFilterBag.QualityLabels = {
    [0] = ITEM_QUALITY0_DESC or "Wertlos",
    [1] = ITEM_QUALITY1_DESC or "Gewöhnlich",
    [2] = ITEM_QUALITY2_DESC or "Ungewöhnlich",
    [3] = ITEM_QUALITY3_DESC or "Selten",
    [4] = ITEM_QUALITY4_DESC or "Episch",
    [5] = ITEM_QUALITY5_DESC or "Legendär",
    [6] = ITEM_QUALITY6_DESC or "Artefakt",
    [7] = ITEM_QUALITY7_DESC or "Erbstück",
}

-- Equipslot-Anzeigenamen
BrannFilterBag.SlotLabels = {
    INVTYPE_HEAD         = "Kopf",
    INVTYPE_NECK         = "Hals",
    INVTYPE_SHOULDER     = "Schultern",
    INVTYPE_CLOAK        = "Umhang",
    INVTYPE_CHEST        = "Brust",
    INVTYPE_WRIST        = "Handgelenke",
    INVTYPE_HAND         = "Hände",
    INVTYPE_WAIST        = "Taille",
    INVTYPE_LEGS         = "Beine",
    INVTYPE_FEET         = "Füße",
    INVTYPE_FINGER       = "Ring",
    INVTYPE_TRINKET      = "Schmuckstück",
    INVTYPE_WEAPONMAINHAND = "Haupthand",
    INVTYPE_WEAPONOFFHAND  = "Nebenhand",
    INVTYPE_RANGED       = "Fernkampf",
    INVTYPE_2HWEAPON     = "2H Waffe",
    INVTYPE_WEAPON       = "Ein-Hand",
    INVTYPE_SHIELD       = "Schild",
    INVTYPE_HOLDABLE     = "Gehaltener Gegenstand",
    INVTYPE_THROWN       = "Wurfwaffe",
    INVTYPE_BAG          = "Tasche",
    INVTYPE_BODY         = "Hemd",
    INVTYPE_TABARD       = "Wappenrock",
    INVTYPE_NON_EQUIP    = "Nicht ausrüstbar",
}

-------------------------------------------------------------------------------
-- Einzelne Regel prüfen
-------------------------------------------------------------------------------
local function CheckRule(rule, item, bindCache)
    local field = rule.field
    local value = rule.value

    if field == "name" then
        if not value or value == "" then return true end
        return item.name and item.name:lower():find(value:lower(), 1, true) and true or false

    elseif field == "quality" then
        -- value = Qualitätsstufe 0-7
        return item.quality == tonumber(value)

    elseif field == "quality_min" then
        return (item.quality or 0) >= tonumber(value)

    elseif field == "quality_max" then
        return (item.quality or 0) <= tonumber(value)

    elseif field == "ilvl_min" then
        local ilvl = C_Item.GetDetailedItemLevelInfo and select(1, C_Item.GetDetailedItemLevelInfo(item.link)) or 0
        return ilvl >= tonumber(value or 0)

    elseif field == "ilvl_max" then
        local ilvl = C_Item.GetDetailedItemLevelInfo and select(1, C_Item.GetDetailedItemLevelInfo(item.link)) or 0
        return ilvl <= tonumber(value or 0)

    elseif field == "equipable" then
        local isEquip = item.equipLoc and item.equipLoc ~= "" and item.equipLoc ~= "INVTYPE_NON_EQUIP"
        if rule.value == false then return not isEquip end
        return isEquip

    elseif field == "slot" then
        -- value = INVTYPE_* string
        return item.equipLoc == value

    elseif field == "type" then
        if not value or value == "" then return true end
        return item.itemType and item.itemType:lower():find(value:lower(), 1, true) and true or false

    elseif field == "bind" then
        -- value = "soulbound" | "boe" | "warband" | "none"
        local bt = bindCache[item.bag .. "_" .. item.slot]
        if not bt then
            bt = BrannFilterBag:GetBindTypeFromScan(item.bag, item.slot)
            bindCache[item.bag .. "_" .. item.slot] = bt
        end
        return bt == value

    elseif field == "housing" then
        local result = BrannFilterBag:IsHousingItem(item.itemSubType, item.itemType, item.classID, item.subClassID)
        if rule.value == false then return not result end
        return result

    elseif field == "loadout" then
        -- rule.value: false/"false" = in keinem Set, "any" = beliebiges Set, <number> = spezifisches Set
        if rule.value == false or rule.value == "false" then
            -- "In keinem Set" → true wenn NICHT in irgendeinem Set
            return not BrannFilterBag:IsInGearLoadout(item.bag, item.slot, "any")
        elseif rule.value == "any" or rule.value == true or rule.value == "true" then
            return BrannFilterBag:IsInGearLoadout(item.bag, item.slot, "any")
        else
            -- Spezifisches Set (numerische ID)
            return BrannFilterBag:IsInGearLoadout(item.bag, item.slot, rule.value)
        end

    elseif field == "already_filtered" then
        -- Prüfe ob dieses Item bereits von einem vorherigen Filter erfasst wurde
        local key = item.bag .. "_" .. item.slot
        local isMatched = item._matchedSet and item._matchedSet[key] or false
        if rule.value == false then return not isMatched end
        return isMatched

    elseif field == "expansion" then
        return (item.expacID or 0) == tonumber(value)

    elseif field == "upgrade" then
        -- Kann der Gegenstand angelegt werden?
        local isEquip = item.equipLoc and item.equipLoc ~= "" and item.equipLoc ~= "INVTYPE_NON_EQUIP"
        if not isEquip then
            -- Wenn kein Ausrüstungsteil, ist es per Definition kein Upgrade (oder nach Konfiguration)
            return rule.value == false
        end

        local itemLink = item.link
        if not itemLink then return rule.value == false end

        local itemIlvl = C_Item.GetDetailedItemLevelInfo and select(1, C_Item.GetDetailedItemLevelInfo(itemLink)) or 0
        if itemIlvl <= 0 then return rule.value == false end

        -- WoW Slots basierend auf equipLoc
        -- Ein Item kann in mehrere Slots passen (z.B. Ring, Schmuckstück, 1H-Waffen)
        local slotsToCheck = {}
        
        if item.equipLoc == "INVTYPE_HEAD" then table.insert(slotsToCheck, 1)
        elseif item.equipLoc == "INVTYPE_NECK" then table.insert(slotsToCheck, 2)
        elseif item.equipLoc == "INVTYPE_SHOULDER" then table.insert(slotsToCheck, 3)
        elseif item.equipLoc == "INVTYPE_BODY" then table.insert(slotsToCheck, 4) -- Hemd
        elseif item.equipLoc == "INVTYPE_CHEST" or item.equipLoc == "INVTYPE_ROBE" then table.insert(slotsToCheck, 5)
        elseif item.equipLoc == "INVTYPE_WAIST" then table.insert(slotsToCheck, 6)
        elseif item.equipLoc == "INVTYPE_LEGS" then table.insert(slotsToCheck, 7)
        elseif item.equipLoc == "INVTYPE_FEET" then table.insert(slotsToCheck, 8)
        elseif item.equipLoc == "INVTYPE_WRIST" then table.insert(slotsToCheck, 9)
        elseif item.equipLoc == "INVTYPE_HAND" then table.insert(slotsToCheck, 10)
        elseif item.equipLoc == "INVTYPE_FINGER" then 
            table.insert(slotsToCheck, 11)
            table.insert(slotsToCheck, 12)
        elseif item.equipLoc == "INVTYPE_TRINKET" then 
            table.insert(slotsToCheck, 13)
            table.insert(slotsToCheck, 14)
        elseif item.equipLoc == "INVTYPE_CLOAK" then table.insert(slotsToCheck, 15)
        elseif item.equipLoc == "INVTYPE_WEAPON" or item.equipLoc == "INVTYPE_WEAPONMAINHAND" or item.equipLoc == "INVTYPE_2HWEAPON" then 
            table.insert(slotsToCheck, 16) -- Main Hand
            if item.equipLoc == "INVTYPE_WEAPON" then
                table.insert(slotsToCheck, 17) -- Off Hand (falls dual wield)
            end
        elseif item.equipLoc == "INVTYPE_WEAPONOFFHAND" or item.equipLoc == "INVTYPE_SHIELD" or item.equipLoc == "INVTYPE_HOLDABLE" then 
            table.insert(slotsToCheck, 17)
        end

        if #slotsToCheck == 0 then return rule.value == false end

        -- Ist das Item-Level höher als *einer* der überprüften Slots?
        -- Für Ringe/Trinkets: Upgrade, wenn höher als der niedrigste angelegte Ring/Trinket.
        local lowestEquippedIlvl = 9999
        local emptySlot = false

        for _, invSlot in ipairs(slotsToCheck) do
            local equippedLink = GetInventoryItemLink("player", invSlot)
            if equippedLink then
                local eqIlvl = C_Item.GetDetailedItemLevelInfo and select(1, C_Item.GetDetailedItemLevelInfo(equippedLink)) or 0
                if eqIlvl < lowestEquippedIlvl then
                    lowestEquippedIlvl = eqIlvl
                end
            else
                emptySlot = true
                lowestEquippedIlvl = 0
            end
        end

        local isUpgrade = false
        if emptySlot then 
            isUpgrade = true -- Wenn ein Slot leer ist, ist alles ein Upgrade
        elseif itemIlvl > lowestEquippedIlvl then
            isUpgrade = true
        end

        if rule.value == false then
            return not isUpgrade
        else
            return isUpgrade
        end

    end
    return false
end

-------------------------------------------------------------------------------
-- Regelset evaluieren mit AND / OR + unabhängigem NOT
-- Regeln werden in Reihenfolge ausgewertet (links nach rechts):
-- op bestimmt die Verknüpfung mit dem bisherigen Ergebnis (AND/OR)
-- negate (NOT-Checkbox) invertiert die jeweilige Regel unabhängig vom Operator
--
-- Beispiel: (Expansion=DF OR Expansion=TWW) AND NOT Expansion=Midnight
-- → Regel 1: Expansion=DF                   (Basis)
-- → Regel 2: OR  Expansion=TWW              (result OR check)
-- → Regel 3: AND Expansion=Midnight [NOT]   (result AND (NOT check))
-------------------------------------------------------------------------------
function F:EvaluateRules(rules, item, bindCache)
    -- Keine Regeln → kein Match (keine Items ohne aktiven Filter)
    if not rules or #rules == 0 then return false end

    local result = nil

    for i, rule in ipairs(rules) do
        local check = CheckRule(rule, item, bindCache)

        -- NOT: negate-Flag ODER Legacy-Kompatibilität (op == "NOT")
        if rule.negate or rule.op == "NOT" then
            check = not check
        end

        if i == 1 or result == nil then
            result = check
        elseif rule.op == "OR" then
            result = result or check
        else
            -- AND (oder Legacy-NOT, das ebenfalls als AND verknüpft wird)
            result = result and check
        end
    end

    return result == true
end

-------------------------------------------------------------------------------
-- Alle passenden Items aus Inventar holen
-------------------------------------------------------------------------------
function F:GetMatchingItems(rules, matchedSet)
    local items = {}

    -- Bind-Cache für diesen Scan (teuer → cachen)
    local bindCache = {}

    -- Feststellen ob bind-Regeln vorhanden sind (teurer Tooltip-Scan nur bei Bedarf)
    local needsBind = false
    if rules then
        for _, rule in ipairs(rules) do
            if rule.field == "bind" then needsBind = true; break end
        end
    end

    for bag = 0, 4 do
        local numSlots = C_Container.GetContainerNumSlots(bag)
        for slot = 1, numSlots do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info and info.hyperlink then
                local itemName, _, itemQuality, _, _, itemType, itemSubType, _, equipLoc,
                      _, sellPrice, classID, subClassID, bindType, expacID =
                    C_Item.GetItemInfo(info.hyperlink)

                if itemName then
                    local item = {
                        bag        = bag,
                        slot       = slot,
                        link       = info.hyperlink,
                        texture    = info.iconFileID,
                        stackCount = info.stackCount or 1,
                        isLocked   = info.isLocked,
                        quality    = itemQuality or info.quality or 0,
                        name       = itemName,
                        itemType   = itemType,
                        itemSubType= itemSubType,
                        equipLoc   = equipLoc,
                        classID    = classID,
                        subClassID = subClassID,
                        expacID    = expacID,
                        _matchedSet = matchedSet,
                    }

                    local matches = self:EvaluateRules(rules, item, bindCache)
                    if matches then
                        table.insert(items, item)
                    end
                end
            end
        end
    end

    table.sort(items, function(a, b) return a.name < b.name end)
    return items
end

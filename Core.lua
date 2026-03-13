local AddonName, BrannFilterBag = ...

-------------------------------------------------------------------------------
-- BrannFilterBag – Core
-------------------------------------------------------------------------------

_G["BrannFilterBag"] = BrannFilterBag
BrannFilterBag.VERSION = "2.0.0"

BrannFilterBag.Defaults = {
    virtualBags = {},
    reagentBags = {},
    nextID      = 1,
    masterBag = {
        cols = 5,
        visible = true,
        reagentOpen = false,
    },
}

-- Bind-Type Erkennung via Hidden Tooltip
local scanTT = CreateFrame("GameTooltip", "BrannFilterBag_ScanTT", nil, "GameTooltipTemplate")
scanTT:SetOwner(WorldFrame, "ANCHOR_NONE")

function BrannFilterBag:GetBindTypeFromScan(bag, slot)
    scanTT:ClearLines()
    scanTT:SetBagItem(bag, slot)
    for i = 2, scanTT:NumLines() do
        local left = _G["BrannFilterBag_ScanTTTextLeft" .. i]
        if left then
            local t = left:GetText() or ""
            if t:find("Seelenge") or t:find("Soulbound") or t:find("Soul-bound") then return "soulbound" end
            if t:find("Ausrüst") or t:find("Equip") then
                if t:find("Schaden") or t:find("Bind on") then end
                return "boe"
            end
            if t:find("Gebunden wenn") or t:find("Binds when") then return "boe" end
            if t:find("Kriegsbeute") or t:find("Warband") then return "warband" end
        end
    end
    return "none"
end

function BrannFilterBag:IsHousingItem(itemSubType, itemType, classID, subClassID)
    -- Methode 1: classID/subClassID (zuverlässigster Weg)
    -- Housing Items in TWW: classID 19 (Professional), diverse subClassIDs
    -- Oder: classID 17 (Miscellaneous), subClassID für Housing
    if classID == 17 and subClassID == 0 then
        -- Prüfe über Namen
    end

    -- Methode 2: itemType / itemSubType String-Check
    if itemType then
        local t = itemType:lower()
        if t:find("housing") then return true end
    end
    if itemSubType then
        local sub = itemSubType:lower()
        if sub:find("house") or sub:find("furniture") or sub:find("housing")
            or sub:find("möbel") or sub:find("einrichtung") or sub:find("decor") then
            return true
        end
    end

    return false
end

-- Equipment-Set Location Unpacker (kompatibel mit allen WoW-Versionen)
local function UnpackEquipLocation(location)
    if not location or location <= 0 then return nil, nil end

    -- Methode 1: Midnight 12.0+ (EquipmentManager_GetLocationData)
    if EquipmentManager_GetLocationData then
        local data = EquipmentManager_GetLocationData(location)
        if data and (data.isBags or data.isBank) and data.bag and data.slot then
            return data.bag, data.slot
        end
        return nil, nil
    end

    -- Methode 2: Pre-Midnight (EquipmentManager_UnpackLocation)
    if EquipmentManager_UnpackLocation then
        local _, bank, bags, _, slot, bag = EquipmentManager_UnpackLocation(location)
        if (bank or bags) and bag and slot then
            return bag, slot
        end
        return nil, nil
    end

    -- Methode 3: Manuelles Bitfeld-Unpacking (ultimativer Fallback)
    -- Bit 20 = onPlayer, Bit 21 = inBank, Bit 22 = inBags
    -- Bits 8-15 = bag, Bits 0-7 = slot
    local PLAYER_FLAG = 0x100000
    local BANK_FLAG   = 0x200000
    local BAGS_FLAG   = 0x400000

    local inBags = bit.band(location, BAGS_FLAG) ~= 0
    local inBank = bit.band(location, BANK_FLAG) ~= 0
    if inBags or inBank then
        local bag  = bit.band(bit.rshift(location, 8), 0xFF)
        local slot = bit.band(location, 0xFF)
        return bag, slot
    end
    return nil, nil
end

function BrannFilterBag:IsInGearLoadout(bag, slot, targetSet)
    local function CheckSet(setID)
        local locations = C_EquipmentSet.GetItemLocations(setID)
        if not locations then return false end
        for _, loc in pairs(locations) do
            if type(loc) == "number" and loc > 0 then
                local locBag, locSlot = UnpackEquipLocation(loc)
                if locBag == bag and locSlot == slot then
                    return true
                end
            end
        end
        return false
    end

    -- Nur spezifisches Set prüfen
    if targetSet and targetSet ~= "any" then
        local numericID = tonumber(targetSet)
        if not numericID then return false end
        return CheckSet(numericID)
    end

    -- Alle Sets prüfen (any)
    local setIDs = C_EquipmentSet.GetEquipmentSetIDs()
    if setIDs then
        for _, setID in ipairs(setIDs) do
            if CheckSet(setID) then return true end
        end
    end
    return false
end

function BrannFilterBag:NewID()
    local id = self.db.nextID
    self.db.nextID = id + 1
    return id
end

function BrannFilterBag:Print(msg)
    print("|cff00ccff[Brann FilterBag]|r " .. tostring(msg))
end

function BrannFilterBag:DeepCopy(orig)
    local copy = {}
    for k, v in pairs(orig) do
        copy[k] = type(v) == "table" and self:DeepCopy(v) or v
    end
    return copy
end

-------------------------------------------------------------------------------
-- Events
-------------------------------------------------------------------------------
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == AddonName then
        if not BrannFilterBagDB then
            BrannFilterBagDB = BrannFilterBag:DeepCopy(BrannFilterBag.Defaults)
        end
        for k, v in pairs(BrannFilterBag.Defaults) do
            if BrannFilterBagDB[k] == nil then
                BrannFilterBagDB[k] = BrannFilterBag:DeepCopy(v)
            end
        end
        BrannFilterBag.db = BrannFilterBagDB
        BrannFilterBag:Print("v" .. BrannFilterBag.VERSION .. " geladen.")
        self:UnregisterEvent("ADDON_LOADED")
    elseif event == "PLAYER_LOGIN" then
        if BrannFilterBag.UI then BrannFilterBag.UI:Initialize() end
    end
end)

-------------------------------------------------------------------------------
-- Slash Commands
-------------------------------------------------------------------------------
SlashCmdList["BRANNFILTERBAG"] = function(msg)
    msg = (msg or ""):trim():lower()
    if msg == "reset" then
        BrannFilterBagDB = nil
        ReloadUI()
    else
        BrannFilterBag:Print("Befehle: /bbf reset")
    end
end
SLASH_BRANNFILTERBAG1 = "/bbf"
SLASH_BRANNFILTERBAG2 = "/bfb"

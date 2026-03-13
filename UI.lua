local _, BrannFilterBag = ...

-------------------------------------------------------------------------------
-- BrannFilterBag – UI v3
-- Fixes:
--   • UseContainerItem ADDON_ACTION_FORBIDDEN → HookScript statt SetScript
--   • Header overhaul: full-width title bar, no quicksearch
--   • Icon top-left, Gear + Close top-right
--   • + Button oben links am Original-Bag
--   • Icon-Picker mit allen Macro-Icons (scrollbar)
-------------------------------------------------------------------------------

BrannFilterBag.UI = {}
local UI = BrannFilterBag.UI

local SLOT_SIZE    = 37
local SLOT_PAD     = 4
local COLS_DEFAULT = 5
local HEADER_H     = 36   -- Nur Titelzeile Master Bag (Icon + Name + Buttons)
local FOOTER_H     = 16   -- Zähler
local SECTION_H    = 16   -- Minimalistic section text header

local combinedBagsHooked = false

local function CalcFrameWidth(cols)
    return cols * (SLOT_SIZE + SLOT_PAD) + SLOT_PAD + 24
end

-------------------------------------------------------------------------------
-- Initialisierung
-------------------------------------------------------------------------------
function UI:Initialize()
    self:HookBagVisibility()
    
    if not BrannFilterBag.db.masterBag then
        BrannFilterBag.db.masterBag = { cols = COLS_DEFAULT, visible = true }
    end
    
    self:CreateMasterFrame()

    local updater = CreateFrame("Frame")
    updater:RegisterEvent("BAG_UPDATE_DELAYED")
    updater:RegisterEvent("MERCHANT_SHOW")
    updater:RegisterEvent("MERCHANT_CLOSED")
    updater:SetScript("OnEvent", function(self, event)
        if event == "MERCHANT_SHOW" then
            UI.isAtMerchant = true
        elseif event == "MERCHANT_CLOSED" then
            UI.isAtMerchant = false
        end
        if UI.masterFrame and UI.masterFrame:IsShown() then
            UI:RefreshMasterBag()
        end
    end)
end

local NukeFrame = CreateFrame("Frame", "BrannFilterBagSneakyFrame")
NukeFrame:Hide()

function UI:HookBagVisibility()
    if combinedBagsHooked then return end
    if not ContainerFrameCombinedBags then return end
    combinedBagsHooked = true
    print("|cff00ff00[BBF DEBUG]|r Verstecke native Taschen...")
    
    -- Native Taschen verdammen: komplett in ein verstecktes Parent umleiten (wie BetterBags)
    ContainerFrameCombinedBags:SetParent(NukeFrame)
    for i = 1, 13 do
        local f = _G["ContainerFrame" .. i]
        if f then f:SetParent(NukeFrame) end
    end

    -- Zusätzlich das original Reagenz-Fenster hart verstecken
    if ContainerFrame6 then ContainerFrame6:SetParent(NukeFrame) end

    -- Statt Hook auf OnShow von CombinedBags (da es nun geparentet ist und evt nicht feuert),
    -- übernehmen wir lieber direkt ToggleAllBags/OpenAllBags wenn möglich, 
    -- aber belassen es mal beim OnShow hook für Kompatibilität, falls es doch aufgerufen wird:
    ContainerFrameCombinedBags:HookScript("OnShow", function(self)
        if BrannFilterBag.db.masterBag.visible ~= false and self.masterFrame then 
            self.masterFrame:Show()
            self:RefreshMasterBag()
        end
    end)
    ContainerFrameCombinedBags:HookScript("OnHide", function(self)
        if self.masterFrame then self.masterFrame:Hide() end
    end)

    -- =========================================================================
    -- GLOBALE TOGGLE-FUNKTION (aufgerufen von Bindings.xml)
    -- =========================================================================
    function BrannFilterBag_ToggleBags()
        local ui = BrannFilterBag.UI
        if not ui then return end
        if not ui.masterFrame then return end
        
        if ui.masterFrame:IsShown() then
            ui.masterFrame:Hide()
        else
            ui.masterFrame:Show()
            ui:RefreshMasterBag()
        end
    end

    -- =========================================================================
    -- KEYBINDING OVERRIDES (wie BetterBags: SetOverrideBinding)
    -- Wir führen ALLE natürlichen Bag-Keybinds auf unser eigenes
    -- BRANNFILTERBAG_TOGGLEBAGS Binding um.
    -- =========================================================================
    local bindFrame = CreateFrame("Frame", "BrannFilterBag_BindingFrame")
    bindFrame:RegisterEvent("PLAYER_LOGIN")
    bindFrame:RegisterEvent("UPDATE_BINDINGS")

    local function UpdateBindings()
        if InCombatLockdown() then
            bindFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
            return
        end
        bindFrame:UnregisterEvent("PLAYER_REGEN_ENABLED")
        ClearOverrideBindings(bindFrame)

        local bindings = {
            "TOGGLEBACKPACK",
            "TOGGLEREAGENTBAG",
            "TOGGLEBAG1",
            "TOGGLEBAG2",
            "TOGGLEBAG3",
            "TOGGLEBAG4",
            "OPENALLBAGS",
        }
        local boundCount = 0
        for _, binding in ipairs(bindings) do
            local key1, key2 = GetBindingKey(binding)
            if key1 then
                SetOverrideBinding(bindFrame, true, key1, "BRANNFILTERBAG_TOGGLEBAGS")
                print("|cff00ff00[BBF DEBUG]|r Binding "..binding.." -> Key1: "..key1.." -> BRANNFILTERBAG_TOGGLEBAGS")
                boundCount = boundCount + 1
            end
            if key2 then
                SetOverrideBinding(bindFrame, true, key2, "BRANNFILTERBAG_TOGGLEBAGS")
                boundCount = boundCount + 1
            end
        end
    end

    bindFrame:SetScript("OnEvent", UpdateBindings)

    -- =========================================================================
    -- HOOK: ToggleAllBags / CloseAllBags (Sicherheit für andere Auslöser)
    -- =========================================================================
    hooksecurefunc("ToggleAllBags", function()
        BrannFilterBag_ToggleBags()
    end)

    hooksecurefunc("OpenAllBags", function()
        local ui = BrannFilterBag.UI
        if not ui or not ui.masterFrame then return end
        if BrannFilterBag.db.masterBag.visible ~= false then
            ui.masterFrame:Show()
            ui:RefreshMasterBag()
        end
    end)

    hooksecurefunc("CloseAllBags", function()
        local ui = BrannFilterBag.UI
        if ui and ui.masterFrame then ui.masterFrame:Hide() end
    end)

    -- =========================================================================
    -- BUTTON HOOKS (Taschenleiste unten)
    -- =========================================================================
    local bagButtons = {
        MainMenuBarBackpackButton,
        CharacterBag0Slot, CharacterBag1Slot, CharacterBag2Slot, CharacterBag3Slot,
    }
    if CharacterReagentBag0Slot then
        table.insert(bagButtons, CharacterReagentBag0Slot)
    end
    if KeyRingButton then
        table.insert(bagButtons, KeyRingButton)
    end

    for _, btn in pairs(bagButtons) do
        if btn then
            btn:HookScript("OnClick", function()
                BrannFilterBag_ToggleBags()
            end)
        end
    end
end



-------------------------------------------------------------------------------
-- Layout: Master Bag links neben dem Bag-UI platzieren
-------------------------------------------------------------------------------
function UI:LayoutMasterBag()
    if not ContainerFrameCombinedBags or not self.masterFrame or self.masterFrame.data.customPos then return end
    self.masterFrame:ClearAllPoints()
    self.masterFrame:SetPoint("RIGHT", ContainerFrameCombinedBags, "LEFT", -8, 0)
end

-------------------------------------------------------------------------------
-- Master Bag Frame erstellen
-------------------------------------------------------------------------------
function UI:CreateMasterFrame()
    if self.masterFrame then return end

    local db = BrannFilterBag.db.masterBag
    local cols = db.cols or COLS_DEFAULT
    local frameW = CalcFrameWidth(cols)

    -- Verwende das native WoW Template für Menüfenster
    local frame = CreateFrame("Frame", "BrannFilterBag_MasterBag", UIParent, "ButtonFrameTemplate")
    frame:SetFrameStrata("HIGH")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        db.customPos = true
        local point, _, relativePoint, xOfs, yOfs = self:GetPoint()
        db.pos = { point, relativePoint, xOfs, yOfs }
    end)

    frame.data = db

    if db.customPos and db.pos then
        frame:SetPoint(db.pos[1], UIParent, db.pos[2], db.pos[3], db.pos[4])
    else
        self.masterFrame = frame
        self:LayoutMasterBag()
    end

    -- Native WoW Header befüllen
    frame:SetTitle("Brann FilterBag")
    if frame.SetPortraitToAsset then
        frame:SetPortraitToAsset("Interface\\Icons\\INV_Misc_Bag_07")
    end

    -- Portrait-Button: Rechtsklick → Taschenzuordnungs-Menü (wie Blizzard Combined Bags)
    if frame.PortraitContainer then
        local portraitBtn = CreateFrame("Button", nil, frame.PortraitContainer)
        portraitBtn:SetAllPoints(frame.PortraitContainer)
        portraitBtn:SetFrameLevel(frame.PortraitContainer:GetFrameLevel() + 2)
        portraitBtn:RegisterForClicks("RightButtonUp")
        portraitBtn:SetScript("OnClick", function(btn, mouseBtn)
            if mouseBtn == "RightButton" then
                MenuUtil.CreateContextMenu(btn, function(_, rootDescription)
                    rootDescription:SetTag("MENU_BBF_BAG_FILTERS")
                    for bagID = 0, 4 do
                        local numSlots = C_Container.GetContainerNumSlots(bagID)
                        if numSlots > 0 then
                            local bName = C_Container.GetBagName(bagID) or ("Tasche " .. bagID)
                            -- Only bags 1-4 support filter flags (not backpack, not profession bags)
                            local isProfBag = bagID > 0 and IsInventoryItemProfessionBag and IsInventoryItemProfessionBag("player", C_Container.ContainerIDToInventoryID(bagID))
                            if bagID > 0 and not isProfBag then
                                local submenu = rootDescription:CreateButton(bName)
                                submenu:CreateTitle(BAG_FILTER_ASSIGN_TO or "Zuweisen zu:")
                                local filterFlags = {
                                    { flag = Enum.BagSlotFlags.ClassEquipment, name = BAG_FILTER_EQUIPMENT or "Ausrüstung" },
                                    { flag = Enum.BagSlotFlags.ClassConsumables, name = BAG_FILTER_CONSUMABLES or "Verbrauchsgüter" },
                                    { flag = Enum.BagSlotFlags.ClassProfessionGoods, name = BAG_FILTER_PROFESSION_GOODS or "Handelswaren" },
                                    { flag = Enum.BagSlotFlags.ClassJunk, name = BAG_FILTER_JUNK or "Plunder" },
                                    { flag = Enum.BagSlotFlags.ClassQuestItems, name = BAG_FILTER_QUEST_ITEMS or "Questgegenstände" },
                                    { flag = Enum.BagSlotFlags.ClassReagents, name = BAG_FILTER_REAGENTS or "Reagenzien" },
                                }
                                for _, f in ipairs(filterFlags) do
                                    submenu:CreateCheckbox(f.name,
                                        function() return C_Container.GetBagSlotFlag(bagID, f.flag) end,
                                        function()
                                            local cur = C_Container.GetBagSlotFlag(bagID, f.flag)
                                            C_Container.SetBagSlotFlag(bagID, f.flag, not cur)
                                        end
                                    )
                                end
                                submenu:CreateTitle(BAG_FILTER_IGNORE or "Ignorieren:")
                                submenu:CreateCheckbox(BAG_FILTER_CLEANUP or "Aufräumen ignorieren",
                                    function() return C_Container.GetBagSlotFlag(bagID, Enum.BagSlotFlags.DisableAutoSort) end,
                                    function()
                                        local cur = C_Container.GetBagSlotFlag(bagID, Enum.BagSlotFlags.DisableAutoSort)
                                        C_Container.SetBagSlotFlag(bagID, Enum.BagSlotFlags.DisableAutoSort, not cur)
                                    end
                                )
                                submenu:CreateCheckbox(SELL_ALL_JUNK_ITEMS_EXCLUDE_FLAG or "Plunderverkauf ausschließen",
                                    function() return C_Container.GetBagSlotFlag(bagID, Enum.BagSlotFlags.ExcludeJunkSell) end,
                                    function()
                                        local cur = C_Container.GetBagSlotFlag(bagID, Enum.BagSlotFlags.ExcludeJunkSell)
                                        C_Container.SetBagSlotFlag(bagID, Enum.BagSlotFlags.ExcludeJunkSell, not cur)
                                    end
                                )
                            else
                                -- Backpack/Profession bag: nur Cleanup-Optionen
                                local submenu = rootDescription:CreateButton(bName)
                                if bagID == 0 then
                                    submenu:CreateCheckbox(BAG_FILTER_CLEANUP or "Aufräumen ignorieren",
                                        function() return C_Container.GetBackpackAutosortDisabled() end,
                                        function()
                                            local cur = C_Container.GetBackpackAutosortDisabled()
                                            C_Container.SetBackpackAutosortDisabled(not cur)
                                        end
                                    )
                                    submenu:CreateCheckbox(SELL_ALL_JUNK_ITEMS_EXCLUDE_FLAG or "Plunderverkauf ausschließen",
                                        function() return C_Container.GetBackpackSellJunkDisabled() end,
                                        function()
                                            local cur = C_Container.GetBackpackSellJunkDisabled()
                                            C_Container.SetBackpackSellJunkDisabled(not cur)
                                        end
                                    )
                                end
                            end
                        end
                    end
                end)
            end
        end)
        portraitBtn:SetScript("OnEnter", function(btn)
            GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
            GameTooltip:SetText("Brann FilterBag", 1, 1, 1)
            GameTooltip:AddLine("Rechtsklick: Taschenzuordnung", 0.5, 0.8, 1)
            GameTooltip:Show()
        end)
        portraitBtn:SetScript("OnLeave", GameTooltip_Hide)
    end

    if frame.CloseButton then
        frame.CloseButton:HookScript("OnClick", function()
            db.visible = false
        end)
    end

    frame:SetShown(
        ContainerFrameCombinedBags and
        ContainerFrameCombinedBags:IsShown() and
        db.visible ~= false
    )
    self.masterFrame = frame

    -- Content-Bereich sicher ans native Inset koppeln
    local contentFrame = CreateFrame("Frame", nil, frame.Inset or frame)
    if frame.Inset then
        contentFrame:SetPoint("TOPLEFT", frame.Inset, "TOPLEFT", 6, -6)
        contentFrame:SetPoint("TOPRIGHT", frame.Inset, "TOPRIGHT", -6, -6)
    else
        contentFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -64)
        contentFrame:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -12, -64)
    end
    contentFrame:SetHeight(1)
    frame.contentFrame = contentFrame

    -- Reagent Bag Toggle Button am linken Rand
    local reagentToggleBtn = CreateFrame("Button", nil, frame)
    reagentToggleBtn:SetSize(32, 32)
    reagentToggleBtn:SetPoint("RIGHT", frame, "LEFT", 4, 0)
    reagentToggleBtn:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Up")
    reagentToggleBtn:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Down")
    reagentToggleBtn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight")
    reagentToggleBtn:SetScript("OnClick", function()
        db.reagentOpen = not db.reagentOpen
        UI:RefreshMasterBag()
    end)
    frame.reagentToggleBtn = reagentToggleBtn

    -- Resize-Handle
    local resizeH = CreateFrame("Button", nil, frame.Inset or frame)
    resizeH:SetSize(16, 16)
    resizeH:SetPoint("BOTTOMRIGHT", frame.Inset or frame, "BOTTOMRIGHT", -2, 2)
    resizeH:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    resizeH:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    resizeH:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")

    local startX, startCols
    resizeH:SetScript("OnMouseDown", function(self, btn)
        if btn ~= "LeftButton" then return end
        startX    = GetCursorPosition()
        startCols = db.cols or COLS_DEFAULT
        self:SetScript("OnUpdate", function()
            local cx = GetCursorPosition()
            local dx = (cx - startX) / UIParent:GetEffectiveScale()
            local newCols = math.max(1, math.min(10,
                math.floor(startCols + dx / (SLOT_SIZE + SLOT_PAD) + 0.5)))
            if newCols ~= db.cols then
                db.cols = newCols
                local newW = CalcFrameWidth(newCols)
                frame:SetWidth(newW)
                UI:RefreshMasterBag()
            end
        end)
    end)
    resizeH:SetScript("OnMouseUp", function(self)
        self:SetScript("OnUpdate", nil)
    end)

    -- Item-Zähler Gesamt
    local countText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    countText:SetPoint("BOTTOMLEFT", frame.Inset or frame, "BOTTOMLEFT", 6, 6)
    countText:SetTextColor(0.55, 0.55, 0.55)
    frame.countText = countText

    -- Settings-Button (Zahnrad) für Master
    local gearBtn = CreateFrame("Button", nil, frame)
    gearBtn:SetSize(20, 20)
    if frame.CloseButton then
        gearBtn:SetPoint("RIGHT", frame.CloseButton, "LEFT", -4, 0)
    else
        gearBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -24, -4)
    end
    
    local gearTex = gearBtn:CreateTexture(nil, "ARTWORK")
    gearTex:SetAllPoints()
    gearTex:SetTexture("Interface\\GossipFrame\\BinderGossipIcon")
    gearTex:SetVertexColor(0.8, 0.8, 0.8)
    
    local gearHL = gearBtn:CreateTexture(nil, "HIGHLIGHT")
    gearHL:SetAllPoints()
    gearHL:SetColorTexture(1, 1, 1, 0.2)
    
    -- Fix: Ensure the icon overlays the border
    gearBtn:SetFrameLevel(frame.CloseButton and (frame.CloseButton:GetFrameLevel() + 1) or (frame:GetFrameLevel() + 5))
    
    gearBtn:SetScript("OnClick", function()
        BrannFilterBag.FilterSettings:OpenGlobal(self.masterFrame)
    end)

    gearBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("Filter-Einstellungen verwalten", 1, 1, 1)
        GameTooltip:Show()
    end)
    gearBtn:SetScript("OnLeave", GameTooltip_Hide)

    -- Sortier-Button (Besen-Icon)
    local sortBtn = CreateFrame("Button", nil, frame)
    sortBtn:SetSize(20, 20)
    sortBtn:SetPoint("RIGHT", gearBtn, "LEFT", -4, 0)
    
    local sortTex = sortBtn:CreateTexture(nil, "ARTWORK")
    sortTex:SetAllPoints()
    sortTex:SetTexture("Interface\\Icons\\INV_Pet_Broom")
    sortTex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    sortTex:SetVertexColor(0.8, 0.8, 0.8)
    
    local sortHL = sortBtn:CreateTexture(nil, "HIGHLIGHT")
    sortHL:SetAllPoints()
    sortHL:SetColorTexture(1, 1, 1, 0.2)
    
    sortBtn:SetFrameLevel(gearBtn:GetFrameLevel())
    
    sortBtn:SetScript("OnClick", function()
        if C_Container and C_Container.SortBags then
            C_Container.SortBags()
        elseif SortBags then
            SortBags()
        end
    end)
    
    sortBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("Taschen sortieren", 1, 1, 1)
        GameTooltip:Show()
    end)
    sortBtn:SetScript("OnLeave", GameTooltip_Hide)

    -- Suchleiste
    local searchBox = CreateFrame("EditBox", "BrannFilterBag_SearchBox", frame, "BagSearchBoxTemplate")
    searchBox:SetSize(260, 20)
    searchBox:SetPoint("TOP", frame, "TOP", 0, -32)
    searchBox:SetScript("OnTextChanged", function(self)
        SearchBoxTemplate_OnTextChanged(self)
        UI.currentSearch = self:GetText():lower()
        if UI.currentSearch == "" then UI.currentSearch = nil end
        UI:RefreshMasterBag()
    end)
    frame.searchBox = searchBox
    if BrannFilterBag.db.global then
        frame.searchBox:SetShown(BrannFilterBag.db.global.showSearch ~= false)
    end

    -- Versuch, Money/Token Frame vom Combined Backpack zu klauen
    local bottomBar = CreateFrame("Frame", nil, frame)
    bottomBar:SetHeight(24)
    bottomBar:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 6, 4)
    bottomBar:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -6, 4)

    local bottomBg = bottomBar:CreateTexture(nil, "BACKGROUND")
    bottomBg:SetAllPoints()
    bottomBg:SetTexture("Interface\\ChatFrame\\ChatFrameBackground")
    bottomBg:SetVertexColor(0, 0, 0, 0.4)

    if ContainerFrameCombinedBags then
        local moneyH = 0
        
        if ContainerFrameCombinedBags.MoneyFrame then
            local mf = ContainerFrameCombinedBags.MoneyFrame
            mf:SetParent(bottomBar)
            mf:SetFrameLevel(bottomBar:GetFrameLevel() + 5)
            mf:ClearAllPoints()
            mf:SetPoint("RIGHT", bottomBar, "RIGHT", -4, 0)
            hooksecurefunc(mf, "SetPoint", function(self, _, parent)
                if parent ~= bottomBar then
                    self:ClearAllPoints()
                    self:SetPoint("RIGHT", bottomBar, "RIGHT", -4, 0)
                end
            end)
            moneyH = 26
        end

        local tf = BackpackTokenFrame
        if not tf and ContainerFrameCombinedBags.TokenFrame then tf = ContainerFrameCombinedBags.TokenFrame end
        if tf then
            tf:SetParent(bottomBar)
            tf:SetFrameLevel(bottomBar:GetFrameLevel() + 5)
            tf:ClearAllPoints()
            tf:SetPoint("LEFT", bottomBar, "LEFT", 4, 0)
            hooksecurefunc(tf, "SetPoint", function(self, _, parent)
                if parent ~= bottomBar then
                    self:ClearAllPoints()
                    self:SetPoint("LEFT", bottomBar, "LEFT", 4, 0)
                end
            end)
            moneyH = 26
        end
        frame.extraBottomSpace = moneyH
    else
        frame.extraBottomSpace = 0
    end

    self.sectionHeaders = self.sectionHeaders or {}
    self.itemButtons = self.itemButtons or {}
    self.itemPoolCounter = 1
    
    if BrannFilterBag.db.global then
        local alpha = BrannFilterBag.db.global.opacity or 0.8
        if frame.Bg then frame.Bg:SetAlpha(alpha) end
        if frame.Inset then
            local insetBg = frame.Inset:GetRegions()
            if insetBg then insetBg:SetAlpha(alpha) end
            frame.Inset.Bg = frame.Inset.Bg or insetBg
        end
    end

    self:RefreshMasterBag()
    return frame
end

-------------------------------------------------------------------------------
-- Hilfsfunktion: Original-ContainerFrame-Slot-Button finden
-------------------------------------------------------------------------------
local function GetOriginalSlotButton(bag, slot)
    -- Konvention bei Einzeltaschen: ContainerFrame(bag+1)Item(slot)
    local direct = _G["ContainerFrame" .. (bag + 1) .. "Item" .. slot]
    if direct then return direct end

    -- Combined Bags: Kinder von ContainerFrameCombinedBags durchsuchen
    if ContainerFrameCombinedBags then
        for _, child in ipairs({ ContainerFrameCombinedBags:GetChildren() }) do
            if child.bagID == bag and child.GetID and child:GetID() == slot then
                return child
            end
        end
    end
    return nil
end

-- Alle aktuell gedimmten Slots merken
local dimmedSlots = {}  -- key = "bag_slot", value = { btn, overlay }

local function RestoreAllDimmed()
    for _, data in pairs(dimmedSlots) do
        if data.btn then data.btn:SetAlpha(1.0) end
        if data.overlay then data.overlay:Hide() end
    end
    wipe(dimmedSlots)
end

local function DimOriginalSlot(bag, slot)
    local key = bag .. "_" .. slot
    if dimmedSlots[key] then return end

    local btn = GetOriginalSlotButton(bag, slot)
    if not btn then return end

    btn:SetAlpha(0.2)

    local overlay = btn.bbfDimOverlay
    if not overlay then
        overlay = btn:CreateTexture(nil, "OVERLAY", nil, 7)
        overlay:SetAllPoints(btn)
        overlay:SetColorTexture(0, 0, 0, 0.6)
        btn.bbfDimOverlay = overlay
    end
    overlay:Show()

    dimmedSlots[key] = { btn = btn, overlay = overlay }
end

-- Globalen Dimm-Zustand neu berechnen anhand der Liste
function UI:UpdateDimmingFromList(newDimmedSlots)
    RestoreAllDimmed()
    
    if not newDimmedSlots then return end

    for _, data in ipairs(newDimmedSlots) do
        DimOriginalSlot(data.bag, data.slot)
    end
end

-------------------------------------------------------------------------------
-- Dynamischen Section-Header erstellen/abrufen (Minimalistisch)
-------------------------------------------------------------------------------
function UI:GetOrCreateSectionHeader(index, data)
    if self.sectionHeaders[index] then
        local hdr = self.sectionHeaders[index]
        hdr.data = data
        hdr.nameText:SetText(data.name or ("Filter " .. data.id))
        return hdr
    end

    local hdr = CreateFrame("Frame", nil, self.masterFrame.contentFrame)
    hdr:SetHeight(SECTION_H)
    hdr.data = data

    local nameText = hdr:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    nameText:SetPoint("TOPLEFT", 0, 0)
    nameText:SetPoint("BOTTOMRIGHT", 0, 0)
    nameText:SetJustifyH("LEFT")
    nameText:SetText(data.name or ("Filter " .. data.id))
    nameText:SetTextColor(1, 0.82, 0)
    nameText:SetWordWrap(false)
    hdr.nameText = nameText

    hdr:EnableMouse(true)
    hdr:SetMovable(true)
    hdr:RegisterForDrag("LeftButton")

    hdr:SetScript("OnDragStart", function(self)
        if self.data and self.data.id == "sonstige" then return end
        self.isDragging = true
        self:StartMoving()
        self:SetFrameStrata("TOOLTIP") -- In den Vordergrund bringen
    end)

    hdr:SetScript("OnDragStop", function(self)
        if not self.isDragging then return end
        self.isDragging = false
        self:StopMovingOrSizing()
        self:SetFrameStrata("MEDIUM")

        local _, cy = self:GetCenter()
        if not cy then
            UI:RefreshMasterBag()
            return
        end

        local oldDbIndex = self.dbIndex
        local closestHdr = nil
        local closestDist = math.huge

        -- Determine which bag list we are working with
        local isReagent = self.sectionIndex and self.sectionIndex >= 1000
        local targetDbArray = isReagent and BrannFilterBag.db.reagentBags or BrannFilterBag.db.virtualBags

        for _, otherHdr in pairs(UI.sectionHeaders) do
            if otherHdr:IsShown() and otherHdr ~= self then
                -- Only compare headers from the same bag
                local otherIsReagent = otherHdr.sectionIndex and otherHdr.sectionIndex >= 1000
                if isReagent == otherIsReagent then
                    local _, otherCy = otherHdr:GetCenter()
                    if otherCy then
                        local dist = math.abs(cy - otherCy)
                        if dist < closestDist then
                            closestDist = dist
                            closestHdr = otherHdr
                        end
                    end
                end
            end
        end

        if closestHdr then
            local _, otherCy = closestHdr:GetCenter()
            
            -- Remove item from old position
            local item = table.remove(targetDbArray, oldDbIndex)
            
            -- Find the target's new position in the array
            local currentTargetIdx = nil
            for i, bd in ipairs(targetDbArray) do
                if bd.id == closestHdr.data.id then
                    currentTargetIdx = i
                    break
                end
            end
            
            if currentTargetIdx then
                -- WoW Y coordinates: larger Y is higher up on screen
                if cy > otherCy then
                    -- Dropped ABOVE target -> insert at target index
                    table.insert(targetDbArray, currentTargetIdx, item)
                else
                    -- Dropped BELOW target -> insert after target
                    table.insert(targetDbArray, currentTargetIdx + 1, item)
                end
            else
                -- Fallback
                table.insert(targetDbArray, oldDbIndex, item)
            end
        end
        
        UI:RefreshMasterBag()
    end)

    local sellBtn = CreateFrame("Button", nil, hdr)
    sellBtn:SetSize(16, 16)
    sellBtn:SetPoint("RIGHT", hdr, "RIGHT", -2, 0)
    sellBtn:SetNormalTexture("Interface\\Icons\\INV_Misc_Coin_01")
    
    local highlight = sellBtn:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetColorTexture(1, 1, 1, 0.3)
    
    sellBtn:SetScript("OnClick", function()
        if not UI.isAtMerchant then return end
        local items = hdr.visibleItems or {}
        for _, item in ipairs(items) do
            if not item.isLocked then
                if C_Container and C_Container.UseContainerItem then
                    C_Container.UseContainerItem(item.bag, item.slot)
                else
                    UseContainerItem(item.bag, item.slot)
                end
            end
        end
    end)
    sellBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("Alle Items verkaufen", 1, 1, 1)
        GameTooltip:Show()
    end)
    sellBtn:SetScript("OnLeave", GameTooltip_Hide)
    sellBtn:Hide()
    hdr.sellBtn = sellBtn

    self.sectionHeaders[index] = hdr
    return hdr
end

-------------------------------------------------------------------------------
-- Einen itemspezifischen Button holen (verhindert SetID-Taint!)
-------------------------------------------------------------------------------
function UI:GetBagSlotButton(bag, slot)
    self.slotButtons = self.slotButtons or {}
    self.slotWrappers = self.slotWrappers or {}
    
    self.slotButtons[bag] = self.slotButtons[bag] or {}
    self.slotWrappers[bag] = self.slotWrappers[bag] or {}
    
    local btn = self.slotButtons[bag][slot]
    if not btn then
        local parentFrame = self.masterFrame.contentFrame
        if bag == 5 and self.reagentFrame then
            parentFrame = self.reagentFrame.contentFrame
        end

        local wrapper = CreateFrame("Frame", nil, parentFrame, nil, bag)
        wrapper:SetSize(SLOT_SIZE, SLOT_SIZE)
        
        btn = self:CreateItemButton(wrapper, slot)
        btn:SetAllPoints(wrapper)
        btn.bbfWrapper = wrapper
        
        self.slotButtons[bag][slot] = btn
        self.slotWrappers[bag][slot] = wrapper
    end
    
    return btn
end

-------------------------------------------------------------------------------
-- Reagent Bag Frame erstellen
-------------------------------------------------------------------------------
function UI:CreateReagentFrame()
    if self.reagentFrame then return end

    local db = BrannFilterBag.db.masterBag
    local cols = db.cols or COLS_DEFAULT
    local frameW = CalcFrameWidth(cols)

    local frame = CreateFrame("Frame", "BrannFilterBag_ReagentBag", self.masterFrame, "ButtonFrameTemplate")
    frame:SetFrameStrata("HIGH")
    frame:SetPoint("TOPRIGHT", self.masterFrame, "TOPLEFT", -2, 0)
    frame:SetWidth(frameW)

    frame:SetTitle("Reagenzien")
    if frame.SetPortraitToAsset then
        frame:SetPortraitToAsset("Interface\\Icons\\INV_Misc_Bag_10_Red")
    end

    if frame.CloseButton then
        frame.CloseButton:HookScript("OnClick", function()
            db.reagentOpen = false
            self:RefreshMasterBag()
        end)
    end

    local contentFrame = CreateFrame("Frame", nil, frame.Inset or frame)
    if frame.Inset then
        contentFrame:SetPoint("TOPLEFT", frame.Inset, "TOPLEFT", 6, -6)
        contentFrame:SetPoint("TOPRIGHT", frame.Inset, "TOPRIGHT", -6, -6)
    else
        contentFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -64)
        contentFrame:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -12, -64)
    end
    contentFrame:SetHeight(1)
    frame.contentFrame = contentFrame

    -- Zähler
    local countText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    countText:SetPoint("BOTTOMLEFT", frame.Inset or frame, "BOTTOMLEFT", 6, 6)
    countText:SetTextColor(0.55, 0.55, 0.55)
    frame.countText = countText

    -- Settings-Button (Zahnrad) für Reagent Bag
    local gearBtn = CreateFrame("Button", nil, frame)
    gearBtn:SetSize(20, 20)
    if frame.CloseButton then
        gearBtn:SetPoint("RIGHT", frame.CloseButton, "LEFT", -4, 0)
    else
        gearBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -24, -4)
    end
    
    local gearTex = gearBtn:CreateTexture(nil, "ARTWORK")
    gearTex:SetAllPoints()
    gearTex:SetTexture("Interface\\GossipFrame\\BinderGossipIcon")
    gearTex:SetVertexColor(0.8, 0.8, 0.8)
    
    local gearHL = gearBtn:CreateTexture(nil, "HIGHLIGHT")
    gearHL:SetAllPoints()
    gearHL:SetColorTexture(1, 1, 1, 0.2)
    
    gearBtn:SetFrameLevel(frame.CloseButton and (frame.CloseButton:GetFrameLevel() + 1) or (frame:GetFrameLevel() + 5))
    
    gearBtn:SetScript("OnClick", function()
        BrannFilterBag.FilterSettings:OpenGlobal(self.reagentFrame, true)
    end)

    gearBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("Reagenzien-Filter verwalten", 1, 1, 1)
        GameTooltip:Show()
    end)
    gearBtn:SetScript("OnLeave", GameTooltip_Hide)

    self.reagentFrame = frame
    return frame
end

-------------------------------------------------------------------------------
-- Master Bag aktualisieren
-------------------------------------------------------------------------------
function UI:RefreshMasterBag()
    if not self.masterFrame or not self.masterFrame:IsShown() then return end

    self.itemButtons = self.itemButtons or {}
    self.sectionHeaders = self.sectionHeaders or {}

    local db = BrannFilterBag.db.masterBag
    local cols = db.cols or COLS_DEFAULT
    local frameW = CalcFrameWidth(cols)
    self.masterFrame:SetWidth(frameW)

    -- Alle bisherigen Items verstecken
    for bag, slots in pairs(self.slotButtons or {}) do
        for slot, btn in pairs(slots) do
            btn:Hide()
            btn.bbfPerBagSlot = nil
            btn.bbfPerBagIcon = nil
            if btn.bbfWrapper then btn.bbfWrapper:Hide() end
        end
    end
    -- Alle Clone-Buttons verstecken
    for _, clone in ipairs(self.clonePool or {}) do
        clone:Hide()
        if clone.bbfWrapper then clone.bbfWrapper:Hide() end
    end
    for _, hdr in pairs(self.sectionHeaders) do
        hdr:Hide()
    end

    self.itemPoolCounter = 1
    self.clonePoolIndex = 1
    self.clonePool = self.clonePool or {}
    local renderedSlots = {} -- Track which bag_slot are already rendered (need clone for 2nd+)

    local currentX = 0
    local currentY = 0
    local maxRowH = 0
    local currentCol = 0

    local totalItems = 0
    local matchedItemsLookup = {} -- Track items added to filters string "bag_slot"

    local function NewLine()
        if currentCol > 0 then
            currentCol = 0
            currentY = currentY + maxRowH + 6 -- spacing between rows of sections
            maxRowH = 0
        end
    end

    -- Alle freien Plätze in der Master-Tasche sammeln
    local emptySlotsMaster = {}
    for bag = 0, 4 do
        local numSlots = C_Container.GetContainerNumSlots(bag)
        for slot = 1, numSlots do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if not info or not info.hyperlink then
                table.insert(emptySlotsMaster, { bag = bag, slot = slot })
            end
        end
    end
    local totalFreeMaster = #emptySlotsMaster
    local showPerBag = BrannFilterBag.db.global and BrannFilterBag.db.global.showPerBagSlots

    local sectionIndex = 1

    -- Clone-Button für Items die in mehreren Sections erscheinen
    local function GetOrCreateClone(item, parentFrame)
        local idx = self.clonePoolIndex
        local clone = self.clonePool[idx]
        if not clone then
            local wrapper = CreateFrame("Frame", nil, parentFrame)
            wrapper:SetSize(SLOT_SIZE, SLOT_SIZE)
            clone = CreateFrame("Button", nil, wrapper)
            clone:SetSize(SLOT_SIZE, SLOT_SIZE)
            clone:SetAllPoints(wrapper)
            clone.bbfWrapper = wrapper

            local icon = clone:CreateTexture(nil, "ARTWORK")
            icon:SetAllPoints()
            clone.icon = icon

            clone:RegisterForClicks("LeftButtonUp", "RightButtonUp")
            clone:RegisterForDrag("LeftButton")
            clone:SetScript("OnEnter", function(self)
                if not self.bbfItem then return end
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetBagItem(self.bbfItem.bag, self.bbfItem.slot)
                GameTooltip:Show()
                GameTooltip_ShowCompareItem(GameTooltip)
                CursorUpdate(self)
            end)
            clone:SetScript("OnLeave", function(self)
                GameTooltip:Hide()
                ResetCursor()
            end)
            clone:SetScript("OnClick", function(self, mouseBtn)
                if not self.bbfItem then return end
                if IsShiftKeyDown() and self.bbfItem.link then
                    if ChatEdit_GetActiveWindow() then
                        ChatEdit_InsertLink(self.bbfItem.link)
                    else
                        ChatFrame_OpenChat("")
                        ChatEdit_InsertLink(self.bbfItem.link)
                    end
                elseif mouseBtn == "RightButton" then
                    C_Container.UseContainerItem(self.bbfItem.bag, self.bbfItem.slot)
                end
            end)
            clone:SetScript("OnDragStart", function(self)
                if self.bbfItem then
                    C_Container.PickupContainerItem(self.bbfItem.bag, self.bbfItem.slot)
                end
            end)

            self.clonePool[idx] = clone
        end
        self.clonePoolIndex = idx + 1
        clone.bbfWrapper:SetParent(parentFrame)
        clone.bbfItem = item
        return clone
    end

    local function RenderSection(bagData, items, availableEmptySlots)
        local itemCount = #items
        if itemCount == 0 then
            if not bagData.showEmpty then return end
            if availableEmptySlots and #availableEmptySlots > 0 then
                local e = table.remove(availableEmptySlots, 1)
                table.insert(items, {
                    bag = e.bag, slot = e.slot,
                    isLocked = false, quality = -1, isPseudoEmpty = true, texture = nil, stackCount = 1
                })
                itemCount = 1
            else
                return -- cannot render empty if we have no slots to bind to
            end
        end
        
        -- Floating Responsive Logic: width of section is at least 2 columns to fit text, or itemCount columns.
        local desiredCols = math.min(math.max(itemCount, 2), cols)
        if desiredCols > cols then desiredCols = cols end
        
        -- Line break if it exceeds max columns
        if currentCol > 0 and (currentCol + desiredCols > cols) then
            NewLine()
        end
        
        local startX = currentCol * (SLOT_SIZE + SLOT_PAD)
        local startY = currentY
        
        -- Section Header
        local hdr = self:GetOrCreateSectionHeader(sectionIndex, bagData)
        hdr.dbIndex = bagData.dbIndex
        hdr.sectionIndex = sectionIndex
        hdr:SetParent(self.masterFrame.contentFrame)
        hdr:ClearAllPoints()
        hdr:SetPoint("TOPLEFT", self.masterFrame.contentFrame, "TOPLEFT", startX, -startY)
        hdr:SetWidth(desiredCols * (SLOT_SIZE + SLOT_PAD) - SLOT_PAD)
        hdr.visibleItems = items
        hdr:Show()

        if UI.isAtMerchant and bagData.id ~= "sonstige" then
            hdr.sellBtn:Show()
        else
            hdr.sellBtn:Hide()
        end
        
        local itemsStartY = startY + SECTION_H + 2

        -- Items platzieren
        for j, item in ipairs(items) do
            totalItems = totalItems + 1
            local key = item.bag .. "_" .. item.slot
            local isClone = renderedSlots[key]
            local btn, wrapper

            if isClone then
                -- Dieser Slot ist bereits in einer anderen Section gerendert → Clone verwenden
                btn = GetOrCreateClone(item, self.masterFrame.contentFrame)
                wrapper = btn.bbfWrapper
            else
                btn = self:GetBagSlotButton(item.bag, item.slot)
                wrapper = btn.bbfWrapper
                if item.bag ~= 5 then
                    wrapper:SetParent(self.masterFrame.contentFrame)
                end
                renderedSlots[key] = true
            end
            
            wrapper:ClearAllPoints()
            local slotId = j - 1
            local cx = startX + (slotId % desiredCols) * (SLOT_SIZE + SLOT_PAD)
            local cy = itemsStartY + math.floor(slotId / desiredCols) * (SLOT_SIZE + SLOT_PAD)
            
            wrapper:SetPoint("TOPLEFT", self.masterFrame.contentFrame, "TOPLEFT", cx, -cy)
            wrapper:Show()
            
            btn.bbfItem = item

            if isClone then
                -- Clone: manuelles Rendering
                if item.isPseudoEmpty then
                    if item.isBagSlot then
                        btn.icon:SetTexture(item.texture)
                        btn.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
                        if item.stackCount and item.stackCount > 0 then
                            if not btn.bbfCountText then
                                btn.bbfCountText = btn:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
                                btn.bbfCountText:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -2, 2)
                                btn.bbfCountText:SetJustifyH("RIGHT")
                            end
                            btn.bbfCountText:SetText(item.stackCount)
                            btn.bbfCountText:Show()
                        else
                            if btn.bbfCountText then btn.bbfCountText:Hide() end
                        end
                    else
                        btn.icon:SetTexture(nil)
                        if btn.bbfCountText then btn.bbfCountText:Hide() end
                    end
                    if btn.bbfBorder then btn.bbfBorder:Hide() end
                    if btn.bbfIlvlText then btn.bbfIlvlText:Hide() end
                else
                    btn.icon:SetTexture(item.texture)
                    btn.icon:SetDesaturated(item.isLocked and true or false)
                    -- Stack-Count
                    if item.stackCount and item.stackCount > 1 then
                        if not btn.bbfCountText then
                            btn.bbfCountText = btn:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
                            btn.bbfCountText:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -2, 2)
                            btn.bbfCountText:SetJustifyH("RIGHT")
                        end
                        btn.bbfCountText:SetText(item.stackCount)
                        btn.bbfCountText:Show()
                    else
                        if btn.bbfCountText then btn.bbfCountText:Hide() end
                    end
                    -- Quality border
                    if item.quality and item.quality >= 1 then
                        local r, g, b = GetItemQualityColor(item.quality)
                        if not btn.bbfBorder then
                            btn.bbfBorder = btn:CreateTexture(nil, "OVERLAY")
                            btn.bbfBorder:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
                            btn.bbfBorder:SetBlendMode("ADD")
                            btn.bbfBorder:SetTexCoord(14/64, 49/64, 15/64, 50/64)
                            btn.bbfBorder:SetPoint("CENTER")
                            btn.bbfBorder:SetSize(SLOT_SIZE * 1.1, SLOT_SIZE * 1.1)
                        end
                        btn.bbfBorder:SetVertexColor(r, g, b, 0.5)
                        btn.bbfBorder:Show()
                    else
                        if btn.bbfBorder then btn.bbfBorder:Hide() end
                    end
                    -- Item-Level
                    local gearCheck = (item.classID == 2 or item.classID == 4)
                    local isEquip = gearCheck and item.equipLoc and item.equipLoc ~= "" and item.equipLoc ~= "INVTYPE_NON_EQUIP"
                    local ilvl = isEquip and C_Item.GetDetailedItemLevelInfo and select(1, C_Item.GetDetailedItemLevelInfo(item.link))
                    if not btn.bbfIlvlText then
                        btn.bbfIlvlText = btn:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
                        btn.bbfIlvlText:SetPoint("TOPRIGHT", btn, "TOPRIGHT", -1, -1)
                        btn.bbfIlvlText:SetJustifyH("RIGHT")
                    end
                    if isEquip and ilvl and ilvl > 0 then
                        local r, g, b = 1, 1, 1
                        if item.quality and item.quality >= 0 then r, g, b = GetItemQualityColor(item.quality) end
                        btn.bbfIlvlText:SetText(ilvl)
                        btn.bbfIlvlText:SetTextColor(r, g, b)
                        btn.bbfIlvlText:Show()
                    else
                        btn.bbfIlvlText:Hide()
                    end
                end
                btn:Show()
            else
                -- Original-Button: volle WoW-API
                SetItemButtonCount(btn, item.stackCount)
                SetItemButtonDesaturated(btn, item.isLocked and true or false)

                if item.isPseudoEmpty then
                    if item.isBagSlot then
                        SetItemButtonTexture(btn, item.texture)
                        SetItemButtonCount(btn, item.stackCount)
                    else
                        SetItemButtonTexture(btn, nil)
                    end
                    if btn.bbfBorder then btn.bbfBorder:Hide() end
                    if btn.bbfIlvlText then btn.bbfIlvlText:Hide() end
                else
                    SetItemButtonTexture(btn, item.texture)
                    -- Qualitäts-Rand (bbfBorder) – ersetzt das gekillete IconBorder
                    if item.quality and item.quality >= 1 then
                        local r, g, b = GetItemQualityColor(item.quality)
                        if not btn.bbfBorder then
                            btn.bbfBorder = btn:CreateTexture(nil, "OVERLAY")
                            btn.bbfBorder:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
                            btn.bbfBorder:SetBlendMode("ADD")
                            btn.bbfBorder:SetTexCoord(14/64, 49/64, 15/64, 50/64)
                            btn.bbfBorder:SetPoint("CENTER")
                            btn.bbfBorder:SetSize(SLOT_SIZE * 1.1, SLOT_SIZE * 1.1)
                        end
                        btn.bbfBorder:SetVertexColor(r, g, b, 0.5)
                        btn.bbfBorder:Show()
                    else
                        if btn.bbfBorder then btn.bbfBorder:Hide() end
                    end

                    -- Item-Level
                    local gearCheck = (item.classID == 2 or item.classID == 4)
                    local isEquip = gearCheck and item.equipLoc and item.equipLoc ~= "" and item.equipLoc ~= "INVTYPE_NON_EQUIP"
                    local ilvl = isEquip and C_Item.GetDetailedItemLevelInfo and select(1, C_Item.GetDetailedItemLevelInfo(item.link))
                    if not btn.bbfIlvlText then
                        btn.bbfIlvlText = btn:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
                        btn.bbfIlvlText:SetPoint("TOPRIGHT", btn, "TOPRIGHT", -1, -1)
                        btn.bbfIlvlText:SetJustifyH("RIGHT")
                    end
                    if isEquip and ilvl and ilvl > 0 then
                        local r, g, b = 1, 1, 1
                        if item.quality and item.quality >= 0 then r, g, b = GetItemQualityColor(item.quality) end
                        btn.bbfIlvlText:SetText(ilvl)
                        btn.bbfIlvlText:SetTextColor(r, g, b)
                        btn.bbfIlvlText:Show()
                    else
                        btn.bbfIlvlText:Hide()
                    end
                end

                btn:Show()

                if not item.isPseudoEmpty and C_NewItems then
                    if C_NewItems.RemoveNewItem then C_NewItems.RemoveNewItem(item.bag, item.slot) end
                end
                if btn.ClearNewItem then btn:ClearNewItem() end
            end
        end
        
        -- Row height tracking
        local rowsUsed = math.ceil(itemCount / desiredCols)
        if rowsUsed == 0 then rowsUsed = 0 end -- empty filter doesn't take item vertical space
        local sectionH = SECTION_H + 2 + rowsUsed * (SLOT_SIZE + SLOT_PAD)
        if rowsUsed > 0 then sectionH = sectionH + 2 end -- small buffer beneath items
        
        maxRowH = math.max(maxRowH, sectionH)
        currentCol = currentCol + desiredCols
        sectionIndex = sectionIndex + 1
    end

    local function ItemMatchesSearch(item)
        if not UI.currentSearch then return true end
        if item.name and item.name:lower():find(UI.currentSearch, 1, true) then return true end
        if item.itemType and item.itemType:lower():find(UI.currentSearch, 1, true) then return true end
        if item.itemSubType and item.itemSubType:lower():find(UI.currentSearch, 1, true) then return true end
        return false
    end

    if not showPerBag and totalFreeMaster > 0 then
        local firstE = table.remove(emptySlotsMaster, 1)
        local freeItem = {
            bag = firstE.bag, slot = firstE.slot,
            stackCount = totalFreeMaster, isLocked = false, quality = -1, isPseudoEmpty = true, texture = nil
        }
        RenderSection({ id = "free_space", name = "Freie Plätze", visible = true, showEmpty = false }, { freeItem }, nil)
    end

    -- Erste Runde: Alle Filter auswerten, exclusiveOnly-Keys sammeln
    local exclusiveKeys = {} -- key -> true, wenn mindestens eine exclusiveOnly-Gruppe das Item matched
    local filterResults = {} -- { bagData, items (raw) }
    for i, bagData in ipairs(BrannFilterBag.db.virtualBags) do
        if bagData.visible ~= false then
            local itemsRaw = BrannFilterBag.Filtering:GetMatchingItems(bagData.rules, matchedItemsLookup)
            local items = {}
            for _, item in ipairs(itemsRaw) do
                local key = item.bag .. "_" .. item.slot
                if ItemMatchesSearch(item) then
                    table.insert(items, item)
                end
                matchedItemsLookup[key] = true
                if bagData.exclusiveOnly then
                    exclusiveKeys[key] = true
                end
            end
            bagData.dbIndex = i
            table.insert(filterResults, { bagData = bagData, items = items })
        end
    end

    -- Zweite Runde: Rendern, exklusive Items nur in Gruppen mit exclusiveOnly
    for _, entry in ipairs(filterResults) do
        local bagData = entry.bagData
        local filteredItems = {}
        for _, item in ipairs(entry.items) do
            local key = item.bag .. "_" .. item.slot
            -- Wenn das Item exklusiv ist, nur in exclusiveOnly-Gruppen anzeigen
            if exclusiveKeys[key] then
                if bagData.exclusiveOnly then
                    table.insert(filteredItems, item)
                end
            else
                table.insert(filteredItems, item)
            end
        end
        RenderSection(bagData, filteredItems, emptySlotsMaster)
    end
    
    -- Sonstige (Unmatched Items) erfassen und als letzte Section rendern
    local sonstigeItems = {}
    if not BrannFilterBag.db.global or BrannFilterBag.db.global.showSonstige ~= false then
        for bag = 0, 4 do
            local numSlots = C_Container.GetContainerNumSlots(bag)
            for slot = 1, numSlots do
                local key = bag .. "_" .. slot
                if not matchedItemsLookup[key] then
                    local info = C_Container.GetContainerItemInfo(bag, slot)
                    if info and info.hyperlink then
                        local itemName, _, itemQuality, _, _, itemType, itemSubType, _, equipLoc = C_Item.GetItemInfo(info.hyperlink)
                        if itemName then
                            local itemObj = {
                                bag = bag,
                                slot = slot,
                                link = info.hyperlink,
                                texture = info.iconFileID,
                                stackCount = info.stackCount or 1,
                                isLocked = info.isLocked,
                                quality = itemQuality or info.quality or 0,
                                equipLoc = equipLoc,
                                name = itemName,
                                itemType = itemType,
                                itemSubType = itemSubType,
                                classID = info.classID or select(12, C_Item.GetItemInfo(info.hyperlink)),
                                subClassID = info.subclassID or select(13, C_Item.GetItemInfo(info.hyperlink))
                            }
                            if ItemMatchesSearch(itemObj) then
                                table.insert(sonstigeItems, itemObj)
                            end
                        end
                    end
                end
            end
        end

        if #sonstigeItems > 0 then
            RenderSection({ id = "sonstige", name = "|cff888888Sonstige|r", visible = true }, sonstigeItems)
        end
    end

    -- Per-Bag freie Plätze (nach Sonstige, ganz unten)
    if showPerBag then
        local perBagCount = {}
        for _, e in ipairs(emptySlotsMaster) do
            perBagCount[e.bag] = (perBagCount[e.bag] or 0) + 1
        end
        local bagSlots = {}
        for bag = 0, 4 do
            local numSlots = C_Container.GetContainerNumSlots(bag)
            if numSlots > 0 then
                local freeCount = perBagCount[bag] or 0
                local bagIcon
                if bag == 0 then
                    bagIcon = 133633 -- INV_Misc_Bag_08 (Backpack)
                else
                    local invID = C_Container.ContainerIDToInventoryID(bag)
                    bagIcon = invID and GetInventoryItemTexture("player", invID) or 133633
                end
                -- Use a fake slot (numSlots+1) so we don't conflict with real bag slots
                local fakeSlot = numSlots + 1
                table.insert(bagSlots, {
                    bag = bag, slot = fakeSlot,
                    stackCount = freeCount, isLocked = false, quality = -1,
                    isPseudoEmpty = true, isBagSlot = true,
                    texture = bagIcon, bagIndex = bag
                })
            end
        end
        if #bagSlots > 0 then
            RenderSection({
                id = "free_bags", name = "Freie Plätze",
                visible = true, showEmpty = false
            }, bagSlots, nil)
            -- Mark rendered buttons for per-bag tooltip
            for _, bs in ipairs(bagSlots) do
                local slotBtn = self.slotButtons[bs.bag] and self.slotButtons[bs.bag][bs.slot]
                if slotBtn then
                    slotBtn.bbfPerBagSlot = bs.bag
                    slotBtn.bbfPerBagIcon = bs.texture
                end
            end
        end
    end

    NewLine() -- apply last row height to currentY

    -- Gesamthöhe anpassen
    local contentH = math.max(currentY, 10)
    self.masterFrame.contentFrame:SetHeight(contentH)
    -- ButtonFrameTemplate standard header is roughly 60px tall, plus ~24px bottom buffer (plus money space if any)
    local moneyAdd = self.masterFrame.extraBottomSpace or 0
    self.masterFrame:SetHeight(contentH + 86 + 24 + moneyAdd) -- added 24 for the searchbox
    
    if self.masterFrame.countText then
        self.masterFrame.countText:SetPoint("BOTTOMLEFT", self.masterFrame.Inset or self.masterFrame, "BOTTOMLEFT", 6, 6 + moneyAdd)
        self.masterFrame.countText:SetText(totalItems .. " Item" .. (totalItems == 1 and "" or "s") .. " gesamt")
    end

    -- =========================================================================
    -- CREST DISPLAY (Im Stil des Gold-Frames unten links)
    -- Midnight 12.0.1 Dawncrests: 3383 (Adventurer), 3341 (Veteran), 3343 (Champion), 3345 (Hero), 3347 (Myth)
    -- =========================================================================
    if not self.masterFrame.bbfCrestsFrame then
        self.masterFrame.bbfCrestsFrame = CreateFrame("Frame", nil, self.masterFrame)
        self.masterFrame.bbfCrestsFrame:SetSize(250, 20)
        self.masterFrame.bbfCrestsFrame.crestStrings = {}
        for i = 1, 5 do
            -- Font wie beim MoneyFrame (GameFontHighlight)
            local fs = self.masterFrame.bbfCrestsFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            self.masterFrame.bbfCrestsFrame.crestStrings[i] = fs
        end
    end
    -- Ganz unten links im Taschenfenster positionieren (Spiegelverkehrt zum Gold)
    self.masterFrame.bbfCrestsFrame:SetPoint("BOTTOMLEFT", self.masterFrame, "BOTTOMLEFT", 12, 8)

    local crestIDs = { 3383, 3341, 3343, 3345, 3347 }
    local cAnchor = self.masterFrame.bbfCrestsFrame
    local cIndex = 1

    for _, cID in ipairs(crestIDs) do
        local cInfo = C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo(cID)
        if cInfo and cInfo.quantity and cInfo.quantity > 0 then
            local fs = self.masterFrame.bbfCrestsFrame.crestStrings[cIndex]
            if fs then
                local iconStr = cInfo.iconFileID and ("|T" .. cInfo.iconFileID .. ":14:14:0:0|t") or ""
                fs:SetText(iconStr .. " " .. cInfo.quantity)
                fs:ClearAllPoints()
                if cIndex == 1 then
                    fs:SetPoint("LEFT", cAnchor, "LEFT", 0, 0)
                else
                    fs:SetPoint("LEFT", self.masterFrame.bbfCrestsFrame.crestStrings[cIndex-1], "RIGHT", 8, 0)
                end
                fs:Show()
                cIndex = cIndex + 1
            end
        end
    end
    -- Die restlichen (nicht genutzten) FontStrings verstecken
    for i = cIndex, 5 do
        if self.masterFrame.bbfCrestsFrame.crestStrings[i] then
            self.masterFrame.bbfCrestsFrame.crestStrings[i]:Hide()
        end
    end

    if self.masterFrame.reagentToggleBtn then
        if db.reagentOpen then
            self.masterFrame.reagentToggleBtn:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up")
            self.masterFrame.reagentToggleBtn:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Down")
        else
            self.masterFrame.reagentToggleBtn:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Up")
            self.masterFrame.reagentToggleBtn:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Down")
        end
    end

    if C_NewItems and C_NewItems.ClearAll then
        C_NewItems.ClearAll()
    end
    
    -- Reagent Bag Render Logic
    if db.reagentOpen then
        if not self.reagentFrame then self:CreateReagentFrame() end
        self.reagentFrame:SetWidth(frameW)
        self.reagentFrame:Show()
        
        local rx = 0
        local ry = 0
        local maxRy = 0
        local rCol = 0
        local rCount = 0
        local rIndex = 1000 -- offset for section headers to not collide with master bag
        
        local emptySlotsReagent = {}
        local rNumSlots = C_Container.GetContainerNumSlots(5)
        for slot = 1, rNumSlots do
            local info = C_Container.GetContainerItemInfo(5, slot)
            if not info or not info.hyperlink then
                table.insert(emptySlotsReagent, { bag = 5, slot = slot })
            end
        end
        local totalFreeReagent = #emptySlotsReagent
        local renderedReagentSlots = {}

        local function rLine()
            if rCol > 0 then
                rCol = 0
                ry = ry + maxRy + 6
                maxRy = 0
            end
        end
        
        local function rSection(bagData, items, availableEmptySlots)
            local itemCount = #items
            if itemCount == 0 then
                if not bagData.showEmpty then return end
                if availableEmptySlots and #availableEmptySlots > 0 then
                    local e = table.remove(availableEmptySlots, 1)
                    table.insert(items, {
                        bag = e.bag, slot = e.slot,
                        isLocked = false, quality = -1, isPseudoEmpty = true, texture = nil, stackCount = 1
                    })
                    itemCount = 1
                else
                    return
                end
            end
            
            local desiredCols = math.min(math.max(itemCount, 2), cols)
            if desiredCols > cols then desiredCols = cols end
            
            if rCol > 0 and (rCol + desiredCols > cols) then rLine() end
            
            local startX = rCol * (SLOT_SIZE + SLOT_PAD)
            local startY = ry
            
            -- Section header in reagent bag
            local hdr = self:GetOrCreateSectionHeader(rIndex, bagData)
            hdr.dbIndex = bagData.dbIndex
            hdr.sectionIndex = rIndex
            hdr:SetParent(self.reagentFrame.contentFrame)
            hdr:ClearAllPoints()
            hdr:SetPoint("TOPLEFT", self.reagentFrame.contentFrame, "TOPLEFT", startX, -startY)
            hdr:SetWidth(desiredCols * (SLOT_SIZE + SLOT_PAD) - SLOT_PAD)
            hdr:Show()
            
            if UI.isAtMerchant and bagData.id ~= "sonstige_reagent" then
                hdr.sellBtn:Show()
            else
                hdr.sellBtn:Hide()
            end
            
            local itemsStartY = startY + SECTION_H + 2
            
            for j, item in ipairs(items) do
                rCount = rCount + 1
                local key = item.bag .. "_" .. item.slot
                local isClone = renderedReagentSlots[key]
                local btn, wrapper

                if isClone then
                    btn = GetOrCreateClone(item, self.reagentFrame.contentFrame)
                    wrapper = btn.bbfWrapper
                else
                    btn = self:GetBagSlotButton(item.bag, item.slot)
                    wrapper = btn.bbfWrapper
                    wrapper:SetParent(self.reagentFrame.contentFrame)
                    renderedReagentSlots[key] = true
                end
                
                wrapper:ClearAllPoints()
                local slotId = j - 1
                local cx = startX + (slotId % desiredCols) * (SLOT_SIZE + SLOT_PAD)
                local cy = itemsStartY + math.floor(slotId / desiredCols) * (SLOT_SIZE + SLOT_PAD)
                
                wrapper:SetPoint("TOPLEFT", self.reagentFrame.contentFrame, "TOPLEFT", cx, -cy)
                wrapper:Show()
                
                btn.bbfItem = item
                
                if isClone then
                    if item.isPseudoEmpty then
                        btn.icon:SetTexture(nil)
                        if btn.bbfBorder then btn.bbfBorder:Hide() end
                        if btn.bbfCountText then btn.bbfCountText:Hide() end
                    else
                        btn.icon:SetTexture(item.texture)
                        btn.icon:SetDesaturated(item.isLocked and true or false)
                        if item.stackCount and item.stackCount > 1 then
                            if not btn.bbfCountText then
                                btn.bbfCountText = btn:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
                                btn.bbfCountText:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -2, 2)
                                btn.bbfCountText:SetJustifyH("RIGHT")
                            end
                            btn.bbfCountText:SetText(item.stackCount)
                            btn.bbfCountText:Show()
                        else
                            if btn.bbfCountText then btn.bbfCountText:Hide() end
                        end
                        if item.quality and item.quality >= 1 then
                            local r, g, b = GetItemQualityColor(item.quality)
                            if not btn.bbfBorder then
                                btn.bbfBorder = btn:CreateTexture(nil, "OVERLAY")
                                btn.bbfBorder:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
                                btn.bbfBorder:SetBlendMode("ADD")
                                btn.bbfBorder:SetTexCoord(14/64, 49/64, 15/64, 50/64)
                                btn.bbfBorder:SetPoint("CENTER")
                                btn.bbfBorder:SetSize(SLOT_SIZE * 1.1, SLOT_SIZE * 1.1)
                            end
                            btn.bbfBorder:SetVertexColor(r, g, b, 0.5)
                            btn.bbfBorder:Show()
                        else
                            if btn.bbfBorder then btn.bbfBorder:Hide() end
                        end
                    end
                    if btn.bbfIlvlText then btn.bbfIlvlText:Hide() end
                    btn:Show()
                else
                    SetItemButtonCount(btn, item.stackCount)
                    SetItemButtonDesaturated(btn, item.isLocked and true or false)
                    
                    if item.isPseudoEmpty then
                        SetItemButtonTexture(btn, nil)
                        if btn.bbfBorder then btn.bbfBorder:Hide() end
                    else
                        SetItemButtonTexture(btn, item.texture)
                        if item.quality and item.quality >= 1 then
                            local r, g, b = GetItemQualityColor(item.quality)
                            if not btn.bbfBorder then
                                btn.bbfBorder = btn:CreateTexture(nil, "OVERLAY")
                                btn.bbfBorder:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
                                btn.bbfBorder:SetBlendMode("ADD")
                                btn.bbfBorder:SetTexCoord(14/64, 49/64, 15/64, 50/64)
                                btn.bbfBorder:SetPoint("CENTER")
                                btn.bbfBorder:SetSize(SLOT_SIZE * 1.1, SLOT_SIZE * 1.1)
                            end
                            btn.bbfBorder:SetVertexColor(r, g, b, 0.5)
                            btn.bbfBorder:Show()
                        else
                            if btn.bbfBorder then btn.bbfBorder:Hide() end
                        end
                    end
                    
                    if btn.bbfIlvlText then btn.bbfIlvlText:Hide() end
                    btn:Show()

                    if not item.isPseudoEmpty and C_NewItems then
                        if C_NewItems.RemoveNewItem then C_NewItems.RemoveNewItem(item.bag, item.slot) end
                    end
                    if btn.ClearNewItem then btn:ClearNewItem() end
                end
            end
            
            local rowsUsed = math.ceil(itemCount / desiredCols)
            local sectionH = SECTION_H + 2 + rowsUsed * (SLOT_SIZE + SLOT_PAD)
            if rowsUsed > 0 then sectionH = sectionH + 2 end
            
            maxRy = math.max(maxRy, sectionH)
            rCol = rCol + desiredCols
            rIndex = rIndex + 1
        end

        if totalFreeReagent > 0 then
            local firstE = table.remove(emptySlotsReagent, 1)
            local freeItem = {
                bag = firstE.bag, slot = firstE.slot,
                stackCount = totalFreeReagent, isLocked = false, quality = -1, isPseudoEmpty = true, texture = nil
            }
            rSection({ id = "free_space_reagent", name = "Freie Plätze", visible = true, showEmpty = false }, { freeItem }, nil)
        end

        BrannFilterBag.db.reagentBags = BrannFilterBag.db.reagentBags or {}
        local rMatched = {}
        for i, bagData in ipairs(BrannFilterBag.db.reagentBags) do
            if bagData.visible ~= false then
                -- Override bag limit inside GetMatchingItems logic temporarily for reagent bag (Enum.BagIndex.ReagentBag == 5)
                local itemsRaw = {}
                local numSlots = C_Container.GetContainerNumSlots(5)
                for slot = 1, numSlots do
                    local info = C_Container.GetContainerItemInfo(5, slot)
                    if info and info.hyperlink then
                        local itemName, _, itemQuality, _, _, itemType, itemSubType, _, equipLoc, _, _, classID, subClassID = C_Item.GetItemInfo(info.hyperlink)
                        if itemName then
                            local itemObj = {
                                bag = 5, slot = slot, link = info.hyperlink, texture = info.iconFileID, stackCount = info.stackCount or 1, isLocked = info.isLocked, quality = itemQuality or info.quality or 0, equipLoc = equipLoc, name = itemName, itemType = itemType, itemSubType = itemSubType, classID = classID, subClassID = subClassID,
                                _matchedSet = rMatched,
                            }
                            if BrannFilterBag.Filtering:EvaluateRules(bagData.rules, itemObj, {}) then
                                table.insert(itemsRaw, itemObj)
                            end
                        end
                    end
                end

                local items = {}
                for _, item in ipairs(itemsRaw) do
                    local key = "5_" .. item.slot
                    if ItemMatchesSearch(item) then
                        table.insert(items, item)
                    end
                    rMatched[key] = true
                end
                bagData.dbIndex = i
                rSection(bagData, items, emptySlotsReagent)
            end
        end
        
        local rSonstige = {}
        local numSlots = C_Container.GetContainerNumSlots(5)
        for slot = 1, numSlots do
            local key = "5_" .. slot
            if not rMatched[key] then
                local info = C_Container.GetContainerItemInfo(5, slot)
                if info and info.hyperlink then
                    local itemName, _, itemQuality, _, _, itemType, itemSubType, _, equipLoc = C_Item.GetItemInfo(info.hyperlink)
                    if itemName then
                        local itemObj = { bag = 5, slot = slot, link = info.hyperlink, texture = info.iconFileID, stackCount = info.stackCount or 1, isLocked = info.isLocked, quality = itemQuality or info.quality or 0, equipLoc = equipLoc, name = itemName, itemType = itemType, itemSubType = itemSubType }
                        if ItemMatchesSearch(itemObj) then table.insert(rSonstige, itemObj) end
                    end
                end
            end
        end
        
        if #rSonstige > 0 then
            rSection({ id = "sonstige_reagent", name = "|cff888888Sonstige Reagenzien|r", visible = true }, rSonstige)
        end
        
        rLine()
        
        local rContentH = math.max(ry, 10)
        self.reagentFrame.contentFrame:SetHeight(rContentH)
        self.reagentFrame:SetHeight(rContentH + 86)
        
        if self.reagentFrame.countText then
            self.reagentFrame.countText:SetText(rCount .. " Reagenzien")
        end
        
        if not self.reagentFrame.gearBtn then
            local rGearBtn = CreateFrame("Button", nil, self.reagentFrame)
            rGearBtn:SetSize(20, 20)
            if self.reagentFrame.CloseButton then
                rGearBtn:SetPoint("RIGHT", self.reagentFrame.CloseButton, "LEFT", -4, 0)
            else
                rGearBtn:SetPoint("TOPRIGHT", self.reagentFrame, "TOPRIGHT", -24, -4)
            end
            
            local gearTex = rGearBtn:CreateTexture(nil, "ARTWORK")
            gearTex:SetAllPoints()
            gearTex:SetTexture("Interface\\GossipFrame\\BinderGossipIcon")
            gearTex:SetVertexColor(0.8, 0.8, 0.8)
            
            local gearHL = rGearBtn:CreateTexture(nil, "HIGHLIGHT")
            gearHL:SetAllPoints()
            gearHL:SetColorTexture(1, 1, 1, 0.2)
            
            rGearBtn:SetFrameLevel(self.reagentFrame.CloseButton and (self.reagentFrame.CloseButton:GetFrameLevel() + 1) or (self.reagentFrame:GetFrameLevel() + 5))
            
            rGearBtn:SetScript("OnClick", function()
                BrannFilterBag.FilterSettings:OpenGlobal(self.reagentFrame, true)
            end)

            rGearBtn:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_LEFT")
                GameTooltip:SetText("Reagenzien-Filter verwalten", 1, 1, 1)
                GameTooltip:Show()
            end)
            rGearBtn:SetScript("OnLeave", GameTooltip_Hide)
            self.reagentFrame.gearBtn = rGearBtn
        end
        
    elseif self.reagentFrame then
        self.reagentFrame:Hide()
    end
end

-------------------------------------------------------------------------------
-- Item-Button erstellen
-- WICHTIG: SetScript(OnClick) NICHT verwenden → protected function!
-- ContainerFrameItemButtonTemplate hat eigenen sicheren Click-Handler.
-- Wir hooken nur für Shift+Click (Chat-Link = erlaubt).
-- UM DEN BLAUEN GLOW ZU VERHINDERN verbergen wir alle Standard-Texturen
-- wie bei BetterBags.
-------------------------------------------------------------------------------
function UI:CreateItemButton(parent, slotID)
    local btn = CreateFrame("ItemButton", nil, parent, "ContainerFrameItemButtonTemplate", slotID)

    -- BetterBags Taktik: Nativ Texturen leeren/verstecken um Taint & Glows zu verhindern
    if btn:GetPushedTexture() then btn:GetPushedTexture():SetTexture("") end
    
    local function KillTexture(tex)
        if tex then
            tex:SetAlpha(0)
            tex:Hide()
            if tex.SetVertexColor then tex:SetVertexColor(0,0,0,0) end
            hooksecurefunc(tex, "Show", function(self) self:Hide() end)
            hooksecurefunc(tex, "SetAlpha", function(self, a) if a > 0 then self:SetAlpha(0) end end)
        end
    end

    if btn:GetNormalTexture() then KillTexture(btn:GetNormalTexture()) end

    KillTexture(btn.NewItemTexture)
    KillTexture(btn.BattlepayItemTexture)
    KillTexture(btn.BattlepayItemNewItemTexture)
    KillTexture(btn.flash)
    KillTexture(btn.ItemContextOverlay)
    KillTexture(btn.IconOverlay)
    KillTexture(btn.IconOverlay2)
    KillTexture(btn.IconBorder) -- Wir nutzen nun bbfBorder für Quality!
    
    if btn.newitemglowAnim then
        btn.newitemglowAnim:Stop()
        hooksecurefunc(btn.newitemglowAnim, "Play", function(self) self:Stop() end)
    end
    
    if btn.flashAnim then
        btn.flashAnim:Stop()
        hooksecurefunc(btn.flashAnim, "Play", function(self) self:Stop() end)
    end

    -- OnEnter: nativer Tooltip via SetBagItem (bleibt stehen!)
    btn:SetScript("OnEnter", function(self)
        if not self.bbfItem then return end
        if self.bbfItem.isPseudoEmpty and self.bbfPerBagSlot ~= nil then
            local bagIdx = self.bbfPerBagSlot
            local bName = C_Container.GetBagName(bagIdx) or (bagIdx == 0 and "Rucksack" or ("Tasche " .. bagIdx))
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(bName, 1, 1, 1)
            GameTooltip:AddLine(self.bbfItem.stackCount .. " freie Plätze", 0.5, 0.8, 1)
            GameTooltip:Show()
            return
        end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetBagItem(self.bbfItem.bag, self.bbfItem.slot)
        GameTooltip:Show()
        GameTooltip_ShowCompareItem(GameTooltip)
        CursorUpdate(self)
    end)

    btn:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
        ResetCursor()
    end)

    -- HookScript → hängt sich hinters Template, OHNE es zu ersetzen
    -- Nur Shift+Click für Chat-Link; normaler Klick → Template-Handler ist sicher
    btn:HookScript("OnClick", function(self, mouseBtn)
        if IsShiftKeyDown() and self.bbfItem and self.bbfItem.link then
            if ChatEdit_GetActiveWindow() then
                ChatEdit_InsertLink(self.bbfItem.link)
            else
                ChatFrame_OpenChat("")
                ChatEdit_InsertLink(self.bbfItem.link)
            end
        end
    end)

    -- Drag: Template-Handler übernimmt (kein SetScript!)
    -- Nur Registrierung für Drag muss explizit gesetzt werden wenn template es nicht hat
    btn:RegisterForDrag("LeftButton")

    -- OnReceiveDrag: Für Per-Bag-Slots (Fake-Slot) den echten freien Slot finden
    btn:SetScript("OnReceiveDrag", function(self)
        if self.bbfPerBagSlot ~= nil then
            local bag = self.bbfPerBagSlot
            local numSlots = C_Container.GetContainerNumSlots(bag)
            for slot = 1, numSlots do
                local info = C_Container.GetContainerItemInfo(bag, slot)
                if not info or not info.hyperlink then
                    C_Container.PickupContainerItem(bag, slot)
                    return
                end
            end
        elseif self.bbfItem then
            C_Container.PickupContainerItem(self.bbfItem.bag, self.bbfItem.slot)
        end
    end)

    return btn
end

-------------------------------------------------------------------------------
-- Icon-Picker (alle Macro-Icons, FauxScrollFrame + Suchfeld)
-------------------------------------------------------------------------------
-- Globaler Icon-Cache (wird einmal geladen, bleibt im Speicher)
local allIconsCache = nil

local function LoadAllIcons()
    if allIconsCache then return allIconsCache end
    allIconsCache = {}
    local seen = {}

    -- Methode 1: GetLooseMacroIcons / GetLooseMacroItemIcons (Retail)
    local ok1, spellIcons = pcall(function() return GetLooseMacroIcons() end)
    if ok1 and spellIcons then
        for _, fid in ipairs(spellIcons) do
            if not seen[fid] then seen[fid] = true; table.insert(allIconsCache, fid) end
        end
    end
    local ok2, itemIcons = pcall(function() return GetLooseMacroItemIcons() end)
    if ok2 and itemIcons then
        for _, fid in ipairs(itemIcons) do
            if not seen[fid] then seen[fid] = true; table.insert(allIconsCache, fid) end
        end
    end

    -- Methode 2: GetNumMacroIcons / GetMacroIconInfo (Fallback)
    if #allIconsCache == 0 then
        local numIcons = GetNumMacroIcons and GetNumMacroIcons() or 0
        for i = 1, numIcons do
            local fid = GetMacroIconInfo(i)
            if fid and not seen[fid] then seen[fid] = true; table.insert(allIconsCache, fid) end
        end
    end

    -- Methode 3: Statische Fallback-Liste (absolut letzte Option)
    if #allIconsCache == 0 then
        local fallback = {
            132594, 132596, 132599, 132601, 132603, 132605, -- Bags
            133784, 133785, 133786, 133787, -- Boxes
            132763, 132764, 132765, 132766, -- Herbs
            134400, 134401, 134402, 134403, -- Potions
            135131, 135132, 135135, 135136, -- Holy spells
            136012, 136032, 136058, 136075, -- Warrior abilities
            237274, 237280, 237283, 237286, -- Misc items
            134056, 134058, 134059, 134060, -- Misc gems
            133566, 133567, 133568, 133569, -- Keys
            134227, 134228, 134229, 134230, -- Trade skills
            237381, 237382, 237383, 237384, -- Nature spells
            236396, 236397, 236398, 236399, -- Shadow spells
            132834, 132836, 132838, 132840, -- Swords
            132940, 132941, 132942, 132943, -- Shields
            135030, 135033, 135034, 135036, -- Trinkets
            134940, 134941, 134942, 134943, -- Rings
            133071, 133073, 133074, 133076, -- Armor
        }
        for _, fid in ipairs(fallback) do
            if not seen[fid] then seen[fid] = true; table.insert(allIconsCache, fid) end
        end
    end

    return allIconsCache
end

function UI:ShowIconPicker(anchor, data, callback)
    if self.iconPicker then self.iconPicker:Hide() end

    -- Icons laden
    local allIcons = LoadAllIcons()
    local filteredIcons = allIcons -- Wird bei Suche gefiltert

    -- Layout-Konstanten
    local PCOLS  = 10
    local PBTN   = 30
    local PPAD   = 2
    local VISIBLE_ROWS = 8
    local PW     = PCOLS * (PBTN + PPAD) + 40
    local PH_VIS = VISIBLE_ROWS * (PBTN + PPAD)
    local SEARCH_H = 28

    local picker = CreateFrame("Frame", "BrannFilterBag_IconPicker", UIParent, "BackdropTemplate")
    picker:SetSize(PW, PH_VIS + SEARCH_H + 50)
    picker:SetFrameStrata("DIALOG")
    picker:SetClampedToScreen(true)
    picker:SetMovable(true)
    picker:EnableMouse(true)
    picker:RegisterForDrag("LeftButton")
    picker:SetScript("OnDragStart", picker.StartMoving)
    picker:SetScript("OnDragStop", picker.StopMovingOrSizing)
    picker:SetPoint("BOTTOM", anchor, "TOP", 0, 4)
    picker:SetBackdrop({
        bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 28,
        insets = { left = 8, right = 8, top = 8, bottom = 8 }
    })

    -- Titel
    local title = picker:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOP", 0, -8)
    title:SetText("Icon wählen  |cff888888(" .. #allIcons .. " Icons)|r")

    -- Close Button
    local closeBtn = CreateFrame("Button", nil, picker, "UIPanelCloseButton")
    closeBtn:SetSize(22, 22)
    closeBtn:SetPoint("TOPRIGHT", -2, -2)
    closeBtn:SetScript("OnClick", function() picker:Hide() end)

    -- Suchfeld
    local searchBox = CreateFrame("EditBox", nil, picker, "InputBoxTemplate")
    searchBox:SetSize(PW - 30, 18)
    searchBox:SetPoint("TOPLEFT", picker, "TOPLEFT", 14, -26)
    searchBox:SetAutoFocus(false)

    local searchPlaceholder = searchBox:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    searchPlaceholder:SetPoint("LEFT", 4, 0)
    searchPlaceholder:SetText("Suche (z.B. Bag, Sword, Fire...)")
    searchBox:SetScript("OnEditFocusGained", function() searchPlaceholder:Hide() end)
    searchBox:SetScript("OnEditFocusLost", function()
        if searchBox:GetText() == "" then searchPlaceholder:Show() end
    end)

    -- Grid-Offset (unterhalb Suche)
    local gridTop = -(26 + SEARCH_H)

    -- Faux ScrollFrame
    local scrollFrame = CreateFrame("ScrollFrame", "BrannFilterBag_IconScroll", picker, "FauxScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", picker, "TOPLEFT", 10, gridTop)
    scrollFrame:SetPoint("BOTTOMRIGHT", picker, "BOTTOMRIGHT", -32, 10)

    -- Buttons generieren (nur die sichtbaren)
    local buttons = {}
    for row = 0, VISIBLE_ROWS - 1 do
        for col = 0, PCOLS - 1 do
            local idx = row * PCOLS + col + 1
            local ib = CreateFrame("Button", nil, picker)
            ib:SetSize(PBTN, PBTN)
            ib:SetPoint("TOPLEFT", picker, "TOPLEFT", 10 + col * (PBTN + PPAD), gridTop - row * (PBTN + PPAD))

            local tex = ib:CreateTexture(nil, "ARTWORK")
            tex:SetAllPoints()
            ib.tex = tex

            local hl = ib:CreateTexture(nil, "HIGHLIGHT")
            hl:SetAllPoints()
            hl:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
            hl:SetBlendMode("ADD")

            ib:SetScript("OnClick", function(self)
                if self.iconID then
                    callback(self.iconID)
                    picker:Hide()
                end
            end)

            ib:SetScript("OnEnter", function(self)
                if self.iconID then
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    GameTooltip:SetText("Icon ID: " .. tostring(self.iconID), 1, 1, 1)
                    GameTooltip:Show()
                end
            end)
            ib:SetScript("OnLeave", GameTooltip_Hide)

            buttons[idx] = ib
        end
    end

    local function UpdateScrollFrame()
        local totalRows = math.ceil(#filteredIcons / PCOLS)
        FauxScrollFrame_Update(scrollFrame, totalRows, VISIBLE_ROWS, PBTN + PPAD)
        local offset = FauxScrollFrame_GetOffset(scrollFrame)

        for row = 0, VISIBLE_ROWS - 1 do
            for col = 0, PCOLS - 1 do
                local btnIdx = row * PCOLS + col + 1
                local iconIdx = (offset + row) * PCOLS + col + 1

                local btn = buttons[btnIdx]
                if iconIdx <= #filteredIcons then
                    btn.iconID = filteredIcons[iconIdx]
                    btn.tex:SetTexture(filteredIcons[iconIdx])
                    btn:Show()
                else
                    btn.iconID = nil
                    btn:Hide()
                end
            end
        end
    end

    scrollFrame:SetScript("OnVerticalScroll", function(self, offset)
        FauxScrollFrame_OnVerticalScroll(self, offset, PBTN + PPAD, UpdateScrollFrame)
    end)

    -- Suche: FileID → Name ist in WoW nicht wirklich möglich,
    -- aber wir können GetMacroIconInfo nutzen, das auch den Pfad zurückgibt.
    -- Da Retail nur fileIDs liefert, bauen wir einen Reverse-Lookup beim ersten Suchvorgang.
    local iconNameCache = nil
    local function BuildIconNameCache()
        if iconNameCache then return end
        iconNameCache = {}
        local numIcons = GetNumMacroIcons and GetNumMacroIcons() or 0
        for i = 1, numIcons do
            local fid, name = GetMacroIconInfo(i)
            if fid and name then
                iconNameCache[fid] = name:lower()
            end
        end
    end

    searchBox:SetScript("OnTextChanged", function(self)
        local query = self:GetText():lower():trim()
        if query == "" then
            filteredIcons = allIcons
        else
            BuildIconNameCache()
            filteredIcons = {}
            for _, fid in ipairs(allIcons) do
                local name = iconNameCache and iconNameCache[fid]
                if name and name:find(query, 1, true) then
                    table.insert(filteredIcons, fid)
                end
            end
            -- Wenn keine Namen-Matches, einfach alle behalten (Fallback)
            if #filteredIcons == 0 and #allIcons > 0 then
                -- Versuche die Zahl selbst als FileID zu parsen
                local numQuery = tonumber(query)
                if numQuery then
                    for _, fid in ipairs(allIcons) do
                        if fid == numQuery then
                            table.insert(filteredIcons, fid)
                        end
                    end
                end
            end
        end
        title:SetText("Icon wählen  |cff888888(" .. #filteredIcons .. " Icons)|r")
        FauxScrollFrame_SetOffset(scrollFrame, 0)
        UpdateScrollFrame()
    end)

    UpdateScrollFrame()
    self.iconPicker = picker

    -- Click-Away schließt Picker
    local sf = CreateFrame("Frame", nil, UIParent)
    sf:SetAllPoints()
    sf:SetFrameStrata("DIALOG")
    sf:SetFrameLevel(picker:GetFrameLevel() - 1)
    sf:EnableMouse(true)
    sf:SetScript("OnMouseDown", function() picker:Hide() end)
    picker:HookScript("OnHide", function() sf:Hide() end)
end

-------------------------------------------------------------------------------
-- SavedVars wiederherstellen
-------------------------------------------------------------------------------
function UI:RestoreVirtualBags()
    if not BrannFilterBag.db or not BrannFilterBag.db.virtualBags then return end
    for _, bagData in ipairs(BrannFilterBag.db.virtualBags) do
        self:CreateVirtualBagFrame(bagData)
    end
    self:LayoutVirtualBags()
end

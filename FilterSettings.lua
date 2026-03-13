local _, BrannFilterBag = ...

-------------------------------------------------------------------------------
-- BrannFilterBag – FilterSettings v2
-- Einstellungs-Panel: Name, Icon, AND/OR/NOT Regeleditor
-- Kein Reihefolge-Management (Drag & Drop reicht)
-------------------------------------------------------------------------------

BrannFilterBag.FilterSettings = {}
local FS = BrannFilterBag.FilterSettings
FS.currentFrame = nil

-------------------------------------------------------------------------------
-- Feld-Definitionen
-------------------------------------------------------------------------------
local FIELDS = {
    { id = "name",        label = "Itemname"              },
    { id = "quality",     label = "Qualität (exakt)"      },
    { id = "quality_min", label = "Qualität (mindestens)" },
    { id = "quality_max", label = "Qualität (maximal)"    },
    { id = "ilvl_min",    label = "Item-Level (min)"      },
    { id = "ilvl_max",    label = "Item-Level (max)"      },
    { id = "equipable",   label = "Ausrüstbar (Gear)"     },
    { id = "slot",        label = "Slot"                  },
    { id = "type",        label = "Typ / Klasse"          },
    { id = "bind",        label = "Bindung"               },
    { id = "housing",     label = "Housing-Item"          },
    { id = "loadout",     label = "Im Gear-Loadout"       },
    { id = "expansion",   label = "Erweiterung (Addon)"   },
    { id = "upgrade",     label = "Ist Item-Upgrade"      },
    { id = "already_filtered", label = "Bereits gefiltert"  },
}

local OP_OPTIONS = { "AND", "OR" }

local QUALITY_OPTIONS = {}
for i = 0, 7 do
    table.insert(QUALITY_OPTIONS, {
        id    = tostring(i),
        label = (BrannFilterBag.QualityLabels and BrannFilterBag.QualityLabels[i]) or tostring(i)
    })
end

local SLOT_OPTIONS = {}
for k, v in pairs(BrannFilterBag.SlotLabels or {}) do
    table.insert(SLOT_OPTIONS, { id = k, label = v })
end
table.sort(SLOT_OPTIONS, function(a, b) return a.label < b.label end)

local BIND_OPTIONS = {
    { id = "soulbound", label = "Seelengebunden"              },
    { id = "boe",       label = "Beim Anlegen gebunden (BOE)" },
    { id = "warband",   label = "Kriegsbeute (Warband)"       },
    { id = "none",      label = "Nicht gebunden"              },
}

local BOOL_OPTIONS = {
    { id = "true",  label = "Ja"   },
    { id = "false", label = "Nein" },
}

local EXPANSION_OPTIONS = {
    { id = "0",  label = "Classic"           },
    { id = "1",  label = "Burning Crusade"   },
    { id = "2",  label = "Wrath of the Lich King" },
    { id = "3",  label = "Cataclysm"         },
    { id = "4",  label = "Mists of Pandaria" },
    { id = "5",  label = "Warlords of Draenor" },
    { id = "6",  label = "Legion"            },
    { id = "7",  label = "Battle for Azeroth" },
    { id = "8",  label = "Shadowlands"       },
    { id = "9",  label = "Dragonflight"      },
    { id = "10", label = "The War Within"    },
    { id = "11", label = "Midnight"          },
}

-------------------------------------------------------------------------------
-- Simples Dropdown (mit globalem Popup-Tracking für Auto-Close)
-------------------------------------------------------------------------------
local activeDropdownPopup = nil
local activeDropdownSF = nil

local function CloseActiveDropdown()
    if activeDropdownPopup then activeDropdownPopup:Hide() end
    if activeDropdownSF then activeDropdownSF:Hide() end
    activeDropdownPopup = nil
    activeDropdownSF = nil
end

local function CreateSimpleDropdown(parent, options, currentValue, onChange)
    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn:SetSize(140, 22)
    btn:SetBackdrop({
        bgFile   = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 10,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    btn:SetBackdropColor(0.1, 0.1, 0.1, 0.9)
    btn:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)

    local label = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("LEFT", 6, 0)
    label:SetPoint("RIGHT", -20, 0)
    label:SetJustifyH("LEFT")
    label:SetWordWrap(false)

    local arrow = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    arrow:SetPoint("RIGHT", -4, 0)
    arrow:SetText("▾")
    arrow:SetTextColor(0.8, 0.8, 0.8)

    -- Aktuellen Wert anzeigen
    local currentLabel = tostring(currentValue or "")
    for _, opt in ipairs(options) do
        if opt.id == tostring(currentValue or "") then
            currentLabel = opt.label; break
        end
    end
    label:SetText(currentLabel)
    btn.value = currentValue

    btn:SetScript("OnClick", function(self)
        -- Vorheriges Dropdown schließen
        CloseActiveDropdown()

        local MAX_VISIBLE = 18
        local ROW_H = 22
        local numVisible = math.min(#options, MAX_VISIBLE)
        local needsScroll = #options > MAX_VISIBLE
        local popupH = numVisible * ROW_H + 8
        local popupW = 150

        local popup = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
        popup:SetFrameStrata("TOOLTIP")
        popup:SetSize(popupW, popupH)
        popup:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 0, -2)
        popup:SetBackdrop({
            bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 12,
            insets = { left = 4, right = 4, top = 4, bottom = 4 }
        })
        popup:SetClampedToScreen(true)
        popup:EnableMouse(true)

        local scrollParent = popup
        if needsScroll then
            local scrollFrame = CreateFrame("ScrollFrame", nil, popup, "UIPanelScrollFrameTemplate")
            scrollFrame:SetPoint("TOPLEFT", 4, -4)
            scrollFrame:SetPoint("BOTTOMRIGHT", -24, 4)
            local scrollChild = CreateFrame("Frame", nil, scrollFrame)
            scrollChild:SetSize(popupW - 30, #options * ROW_H)
            scrollFrame:SetScrollChild(scrollChild)
            scrollParent = scrollChild
        end

        for i, opt in ipairs(options) do
            local row = CreateFrame("Button", nil, scrollParent)
            if needsScroll then
                row:SetSize(popupW - 34, 20)
                row:SetPoint("TOPLEFT", scrollParent, "TOPLEFT", 0, -(i - 1) * ROW_H)
            else
                row:SetSize(popupW - 8, 20)
                row:SetPoint("TOPLEFT", popup, "TOPLEFT", 4, -4 - (i - 1) * ROW_H)
            end
            local hl = row:CreateTexture(nil, "HIGHLIGHT")
            hl:SetAllPoints()
            hl:SetColorTexture(0, 0.5, 0.8, 0.4)
            local txt = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            txt:SetPoint("LEFT", 4, 0)
            txt:SetText(opt.label)
            row:SetScript("OnClick", function()
                btn.value = opt.id
                label:SetText(opt.label)
                popup:Hide()
                if onChange then onChange(opt.id) end
            end)
        end

        -- Screen-Capture Frame zum Schließen bei Klick außerhalb
        local sf = CreateFrame("Frame", nil, UIParent)
        sf:SetAllPoints(UIParent)
        sf:SetFrameStrata("TOOLTIP")
        sf:SetFrameLevel(popup:GetFrameLevel() - 1)
        sf:EnableMouse(true)
        sf:SetScript("OnMouseDown", function()
            popup:Hide()
            sf:Hide()
            activeDropdownPopup = nil
            activeDropdownSF = nil
        end)
        popup:HookScript("OnHide", function()
            sf:Hide()
            activeDropdownPopup = nil
            activeDropdownSF = nil
        end)

        activeDropdownPopup = popup
        activeDropdownSF = sf
    end)

    return btn
end

-------------------------------------------------------------------------------
-- Regel-Zeile
-------------------------------------------------------------------------------
local function CreateRuleLine(parent, rule, index, y, onRemove, onChange)
    local line = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    line:SetSize(parent:GetWidth() - 20, 28)
    line:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, y)
    line:SetBackdrop({ bgFile = "Interface\\ChatFrame\\ChatFrameBackground" })
    line:SetBackdropColor(0.07, 0.07, 0.1, 0.6)

    local xOff = 4

    -- Operator-Dropdown (erste Regel: nur Dash)
    if index == 1 then
        local dash = line:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        dash:SetPoint("LEFT", xOff, 0)
        dash:SetSize(52, 22)
        dash:SetText("|cff888888—|r")
        dash:SetJustifyH("CENTER")
        xOff = xOff + 56
    else
        local opOpts = {}
        for _, op in ipairs(OP_OPTIONS) do
            table.insert(opOpts, { id = op, label = op })
        end
        local opDD = CreateSimpleDropdown(line, opOpts, rule.op or "AND", function(val)
            rule.op = val; onChange()
        end)
        opDD:SetSize(56, 22)
        opDD:SetPoint("LEFT", line, "LEFT", xOff, 0)
        xOff = xOff + 60
    end

    -- NOT-Checkbox (unabhängig vom Operator, für jede Regel verfügbar)
    local notCB = CreateFrame("CheckButton", nil, line, "UICheckButtonTemplate")
    notCB:SetSize(22, 22)
    notCB:SetPoint("LEFT", line, "LEFT", xOff, 0)
    notCB:SetChecked(rule.negate == true)
    if notCB.Text then
        notCB.Text:SetText("")
    end
    local notLabel = line:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    notLabel:SetPoint("LEFT", notCB, "RIGHT", -2, 0)
    notLabel:SetText("|cffff6666\194\172|r")  -- unicode NOT sign ¬
    notCB:SetScript("OnClick", function(self)
        rule.negate = self:GetChecked()
        onChange()
    end)
    notCB:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("NOT – Bedingung invertieren", 1, 1, 1)
        GameTooltip:Show()
    end)
    notCB:SetScript("OnLeave", GameTooltip_Hide)
    xOff = xOff + 34

    -- Forward-declare UpdateValueWidget
    local UpdateValueWidget

    -- Feld-Dropdown
    local fieldDD = CreateSimpleDropdown(line, FIELDS, rule.field, function(val)
        rule.field = val
        rule.value = ""
        if UpdateValueWidget then UpdateValueWidget() end
        onChange()
    end)
    fieldDD:SetSize(140, 22)
    fieldDD:SetPoint("LEFT", line, "LEFT", xOff, 0)
    xOff = xOff + 144

    -- Wert-Widget
    UpdateValueWidget = function()
        if line.valueWidget then line.valueWidget:Hide(); line.valueWidget = nil end

        local field = rule.field
        local wgt

        if field == "quality" or field == "quality_min" or field == "quality_max" then
            wgt = CreateSimpleDropdown(line, QUALITY_OPTIONS, tostring(rule.value or 2), function(val)
                rule.value = tonumber(val); onChange()
            end)
            wgt:SetSize(130, 22)
        elseif field == "slot" then
            wgt = CreateSimpleDropdown(line, SLOT_OPTIONS, rule.value, function(val)
                rule.value = val; onChange()
            end)
            wgt:SetSize(130, 22)
        elseif field == "bind" then
            wgt = CreateSimpleDropdown(line, BIND_OPTIONS, rule.value, function(val)
                rule.value = val; onChange()
            end)
            wgt:SetSize(130, 22)
        elseif field == "housing" or field == "equipable" or field == "upgrade" or field == "already_filtered" then
            wgt = CreateSimpleDropdown(line, BOOL_OPTIONS, tostring(rule.value ~= false), function(val)
                rule.value = (val == "true"); onChange()
            end)
            wgt:SetSize(130, 22)
        elseif field == "loadout" then
            local loadoutOpts = {
                { id = "any",   label = "In irgendeinem Set" },
                { id = "false", label = "In KEINEM Set"      }
            }
            local setIDs = C_EquipmentSet.GetEquipmentSetIDs()
            for _, sid in ipairs(setIDs) do
                local name = C_EquipmentSet.GetEquipmentSetInfo(sid)
                if name then
                    table.insert(loadoutOpts, { id = tostring(sid), label = name })
                end
            end
            
            local currentValStr
            if rule.value == false then currentValStr = "false"
            elseif rule.value == nil or rule.value == "any" then currentValStr = "any"
            else currentValStr = tostring(rule.value) end
            
            wgt = CreateSimpleDropdown(line, loadoutOpts, currentValStr, function(val)
                if val == "false" then rule.value = false
                elseif val == "any" then rule.value = "any"
                else rule.value = tonumber(val) end
                onChange()
            end)
            wgt:SetSize(130, 22)
        elseif field == "expansion" then
            wgt = CreateSimpleDropdown(line, EXPANSION_OPTIONS, tostring(rule.value or 10), function(val)
                rule.value = tonumber(val); onChange()
            end)
            wgt:SetSize(160, 22)
        else
            local eb = CreateFrame("EditBox", nil, line, "InputBoxTemplate")
            eb:SetSize(130, 20)
            eb:SetAutoFocus(false)
            eb:SetText(tostring(rule.value or ""))
            eb:SetScript("OnEnterPressed", function(self)
                self:ClearFocus(); rule.value = self:GetText(); onChange()
            end)
            eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
            eb:SetScript("OnTextChanged", function(self) rule.value = self:GetText() end)
            wgt = eb
        end

        if wgt then
            wgt:SetPoint("LEFT", line, "LEFT", xOff, 0)
            line.valueWidget = wgt
        end
    end

    UpdateValueWidget()

    -- × Entfernen-Button
    local removeBtn = CreateFrame("Button", nil, line)
    removeBtn:SetSize(18, 18)
    removeBtn:SetPoint("RIGHT", line, "RIGHT", -4, 0)
    removeBtn:SetNormalTexture("Interface\\Buttons\\UI-StopButton")
    removeBtn:GetNormalTexture():SetVertexColor(0.9, 0.3, 0.3)
    removeBtn:SetHighlightTexture("Interface\\Buttons\\UI-StopButton")
    removeBtn:SetScript("OnClick", function() onRemove(index) end)

    return line
end

-------------------------------------------------------------------------------
-- Filter-Panel (Globales Management)
-------------------------------------------------------------------------------
function FS:OpenGlobal(parentVBagFrame)
    if self.currentFrame then
        self.currentFrame:Hide()
        self.currentFrame = nil
    end

    local PANEL_W = 740
    local PANEL_H = 500
    local LEFT_W  = 200

    local panel = CreateFrame("Frame", "BrannFilterBag_GlobalSettings", UIParent, "BackdropTemplate")
    panel:SetSize(PANEL_W, PANEL_H)
    panel:SetFrameStrata("DIALOG")
    panel:SetClampedToScreen(true)
    panel:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    panel:SetMovable(true)
    panel:EnableMouse(true)
    panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart", panel.StartMoving)
    panel:SetScript("OnDragStop", panel.StopMovingOrSizing)
    panel:SetBackdrop({
        bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })

    -- Titel
    local titleTex = panel:CreateTexture(nil, "ARTWORK")
    titleTex:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
    titleTex:SetSize(256, 64)
    titleTex:SetPoint("TOP", 0, 12)

    local titleText = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    titleText:SetPoint("TOP", 0, -2)
    titleText:SetText("|cff00ccffFilter-Verwaltung|r")

    local closeBtn = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -4, -4)
    closeBtn:SetScript("OnClick", function() panel:Hide() end)

    -- -------------------------------------------------------------------------
    -- Tab-Navigation
    -- -------------------------------------------------------------------------
    local tabGeneral = CreateFrame("Button", "BrannFilterBag_TabGeneral", panel, "UIPanelButtonTemplate")
    tabGeneral:SetPoint("TOPLEFT", panel, "BOTTOMLEFT", 15, -4)
    tabGeneral:SetSize(120, 26)
    tabGeneral:SetText("Einstellungen")

    local tabFilters = CreateFrame("Button", "BrannFilterBag_TabFilters", panel, "UIPanelButtonTemplate")
    tabFilters:SetPoint("LEFT", tabGeneral, "RIGHT", 4, 0)
    tabFilters:SetSize(120, 26)
    tabFilters:SetText("Filter")

    -- Container für Tab-Inhalte
    local contentGeneral = CreateFrame("Frame", nil, panel)
    contentGeneral:SetPoint("TOPLEFT", panel, "TOPLEFT", 14, -34)
    contentGeneral:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -14, 14)

    local contentFilters = CreateFrame("Frame", nil, panel)
    contentFilters:SetPoint("TOPLEFT", panel, "TOPLEFT", 14, -34)
    contentFilters:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -14, 14)
    contentFilters:Hide()

    -- Tab-Logik
    local function SelectTab(tabID)
        if tabID == 1 then
            tabGeneral:Disable()
            tabFilters:Enable()
            contentGeneral:Show()
            contentFilters:Hide()
        else
            tabFilters:Disable()
            tabGeneral:Enable()
            contentGeneral:Hide()
            contentFilters:Show()
        end
    end

    tabGeneral:SetScript("OnClick", function() SelectTab(1) end)
    tabFilters:SetScript("OnClick", function() SelectTab(2) end)

    -- -------------------------------------------------------------------------
    -- Tab 1: Allgemeine Einstellungen
    -- -------------------------------------------------------------------------
    -- Transparenz Taschenfenster
    local opacityLabel = contentGeneral:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    opacityLabel:SetPoint("TOPLEFT", contentGeneral, "TOPLEFT", 10, -10)
    opacityLabel:SetText("Transparenz Taschenfenster (Hintergrund)")

    local opacitySlider = CreateFrame("Slider", "BrannFilterBag_OpacitySlider", contentGeneral, "OptionsSliderTemplate")
    opacitySlider:SetPoint("TOPLEFT", opacityLabel, "BOTTOMLEFT", 0, -15)
    opacitySlider:SetWidth(200)
    opacitySlider:SetMinMaxValues(0, 1)
    opacitySlider:SetValueStep(0.05)
    opacitySlider:SetObeyStepOnDrag(true)
    _G[opacitySlider:GetName().."Low"]:SetText("0%")
    _G[opacitySlider:GetName().."High"]:SetText("100%")

    -- Initialisiere globale settings, falls nicht vorhanden
    BrannFilterBag.db.global = BrannFilterBag.db.global or {
        opacity = 0.8,
        showSearch = true,
        showSonstige = true,
        showPerBagSlots = false,
    }

    opacitySlider:SetValue(BrannFilterBag.db.global.opacity)
    _G[opacitySlider:GetName().."Text"]:SetText(string.format("%.0f%%", BrannFilterBag.db.global.opacity * 100))

    opacitySlider:SetScript("OnValueChanged", function(self, value)
        BrannFilterBag.db.global.opacity = value
        _G[self:GetName().."Text"]:SetText(string.format("%.0f%%", value * 100))
        if BrannFilterBag.UI then
            if BrannFilterBag.UI.masterFrame then
                if BrannFilterBag.UI.masterFrame.Bg then BrannFilterBag.UI.masterFrame.Bg:SetAlpha(value) end
                if BrannFilterBag.UI.masterFrame.Inset then
                    for _, region in pairs({BrannFilterBag.UI.masterFrame.Inset:GetRegions()}) do
                        if region and region.SetAlpha then region:SetAlpha(value) end
                    end
                end
            end
            if BrannFilterBag.UI.reagentFrame then
                if BrannFilterBag.UI.reagentFrame.Bg then BrannFilterBag.UI.reagentFrame.Bg:SetAlpha(value) end
                if BrannFilterBag.UI.reagentFrame.Inset then
                    for _, region in pairs({BrannFilterBag.UI.reagentFrame.Inset:GetRegions()}) do
                        if region and region.SetAlpha then region:SetAlpha(value) end
                    end
                end
            end
        end
    end)

    -- Suchleiste anzeigen (Globale Option)
    local searchCB = CreateFrame("CheckButton", "BrannFilterBag_GlobalSearchCB", contentGeneral, "UICheckButtonTemplate")
    searchCB:SetPoint("TOPLEFT", opacitySlider, "BOTTOMLEFT", 0, -20)
    searchCB:SetSize(24, 24)
    if searchCB.Text then
        searchCB.Text:SetText("Suchleiste im Taschenfenster anzeigen")
        searchCB.Text:SetFontObject("GameFontNormal")
    end
    searchCB:SetChecked(BrannFilterBag.db.global.showSearch)

    searchCB:SetScript("OnClick", function(self)
        BrannFilterBag.db.global.showSearch = self:GetChecked()
        if BrannFilterBag.UI and BrannFilterBag.UI.masterFrame then
            BrannFilterBag.UI.masterFrame.searchBox:SetShown(BrannFilterBag.db.global.showSearch)
            BrannFilterBag.UI:RefreshMasterBag()
        end
    end)

    -- "Sonstige" Gruppe anzeigen (Globale Option)
    local sonstigeCB = CreateFrame("CheckButton", "BrannFilterBag_GlobalSonstigeCB", contentGeneral, "UICheckButtonTemplate")
    sonstigeCB:SetPoint("TOPLEFT", searchCB, "BOTTOMLEFT", 0, -10)
    sonstigeCB:SetSize(24, 24)
    if sonstigeCB.Text then
        sonstigeCB.Text:SetText("Automatische 'Sonstige'-Gruppe anzeigen")
        sonstigeCB.Text:SetFontObject("GameFontNormal")
    end
    sonstigeCB:SetChecked(BrannFilterBag.db.global.showSonstige)

    sonstigeCB:SetScript("OnClick", function(self)
        BrannFilterBag.db.global.showSonstige = self:GetChecked()
        if BrannFilterBag.UI then
            BrannFilterBag.UI:RefreshMasterBag()
        end
    end)

    -- Freie Plätze je Tasche anzeigen (Globale Option)
    local perBagCB = CreateFrame("CheckButton", "BrannFilterBag_GlobalPerBagCB", contentGeneral, "UICheckButtonTemplate")
    perBagCB:SetPoint("TOPLEFT", sonstigeCB, "BOTTOMLEFT", 0, -10)
    perBagCB:SetSize(24, 24)
    if perBagCB.Text then
        perBagCB.Text:SetText("Freie Plätze je Tasche anzeigen (Rechtsklick: Zuordnung)")
        perBagCB.Text:SetFontObject("GameFontNormal")
    end
    perBagCB:SetChecked(BrannFilterBag.db.global.showPerBagSlots or false)

    perBagCB:SetScript("OnClick", function(self)
        BrannFilterBag.db.global.showPerBagSlots = self:GetChecked()
        if BrannFilterBag.UI then
            BrannFilterBag.UI:RefreshMasterBag()
        end
    end)

    -- -------------------------------------------------------------------------
    -- Tab 2: Filter-Verwaltung 
    -- -------------------------------------------------------------------------
    -- Linke Spalte (Filterliste)
    local leftPane = CreateFrame("Frame", nil, contentFilters, "BackdropTemplate")
    leftPane:SetPoint("TOPLEFT", contentFilters, "TOPLEFT", 0, -24) -- Platz für Tabs oben
    leftPane:SetPoint("BOTTOMLEFT", contentFilters, "BOTTOMLEFT", 0, 0)
    leftPane:SetWidth(LEFT_W)
    leftPane:SetBackdrop({
        bgFile   = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 8,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })
    leftPane:SetBackdropColor(0.05, 0.05, 0.05, 0.8)

    -- Sub-Tabs für Filter-Gruppen (Haupttasche vs Reagenzien)
    local tabMainBag = CreateFrame("Button", nil, contentFilters, "UIPanelButtonTemplate")
    tabMainBag:SetPoint("BOTTOMLEFT", leftPane, "TOPLEFT", 4, 0)
    tabMainBag:SetSize(110, 22)
    tabMainBag:SetText("Haupttasche")
    
    local tabReagent = CreateFrame("Button", nil, contentFilters, "UIPanelButtonTemplate")
    tabReagent:SetPoint("LEFT", tabMainBag, "RIGHT", 4, 0)
    tabReagent:SetSize(110, 22)
    tabReagent:SetText("Reagenzien")

    local listScroll = CreateFrame("ScrollFrame", nil, leftPane, "UIPanelScrollFrameTemplate")
    listScroll:SetPoint("TOPLEFT", leftPane, "TOPLEFT", 4, -4)
    listScroll:SetPoint("BOTTOMRIGHT", leftPane, "BOTTOMRIGHT", -26, 36)

    local listContent = CreateFrame("Frame", nil, listScroll)
    listContent:SetSize(LEFT_W - 30, 1)
    listScroll:SetScrollChild(listContent)

    local addBagBtn = CreateFrame("Button", nil, leftPane, "UIPanelButtonTemplate")
    addBagBtn:SetSize(LEFT_W - 12, 24)
    addBagBtn:SetPoint("BOTTOM", leftPane, "BOTTOM", 0, 6)
    addBagBtn:SetText("+ Neuen Filter erstellen")

    -- Rechte Spalte (Regel-Editor & Optionen)
    local rightPane = CreateFrame("Frame", nil, contentFilters)
    rightPane:SetPoint("TOPLEFT", leftPane, "TOPRIGHT", 10, 0)
    rightPane:SetPoint("BOTTOMRIGHT", contentFilters, "BOTTOMRIGHT", 0, 0)

    local noSelText = rightPane:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    noSelText:SetPoint("CENTER", 0, 0)
    noSelText:SetText("|cff888888Wähle links einen Filter aus|r")

    local editorContainer = CreateFrame("Frame", nil, rightPane)
    editorContainer:SetAllPoints()
    editorContainer:Hide()

    -- Name/Dimmen Header im Editor
    local nameLabel = editorContainer:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    nameLabel:SetPoint("TOPLEFT", 4, -10)
    nameLabel:SetText("Filter-Name:")

    local nameEB = CreateFrame("EditBox", nil, editorContainer, "InputBoxTemplate")
    nameEB:SetSize(200, 20)
    nameEB:SetPoint("LEFT", nameLabel, "RIGHT", 8, 0)
    nameEB:SetAutoFocus(false)

    local dimCB = CreateFrame("CheckButton", "BrannFilterBag_Settings_GlobalDimCB", editorContainer, "UICheckButtonTemplate")
    dimCB:SetPoint("TOPLEFT", nameLabel, "BOTTOMLEFT", -4, -6)
    dimCB:SetSize(24, 24)
    if dimCB.Text then
        dimCB.Text:SetText("Nur in dieser Gruppe")
        dimCB.Text:SetFontObject("GameFontNormalSmall")
    end
    dimCB:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Wenn aktiviert, werden Items dieser Gruppe nicht als Clones in anderen Gruppen angezeigt.\nIst es in mehreren Gruppen aktiv, erscheinen Items nur in diesen Gruppen.", 1, 1, 1)
        GameTooltip:Show()
    end)
    dimCB:SetScript("OnLeave", GameTooltip_Hide)

    local showEmptyCB = CreateFrame("CheckButton", "BrannFilterBag_Settings_GlobalShowEmptyCB", editorContainer, "UICheckButtonTemplate")
    showEmptyCB:SetPoint("LEFT", dimCB, "RIGHT", 140, 0)
    showEmptyCB:SetSize(24, 24)
    if showEmptyCB.Text then
        showEmptyCB.Text:SetText("Mit leerem Slot anzeigen")
        showEmptyCB.Text:SetFontObject("GameFontNormalSmall")
    end
    
    showEmptyCB:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Leere Filtergruppen werden standardmäßig ausgeblendet.\nAktiviere dies, um den Filter mit einem leeren Taschenplatzhalter anzuzeigen, wenn keine Items darin sind.", 1, 1, 1)
        GameTooltip:Show()
    end)
    showEmptyCB:SetScript("OnLeave", GameTooltip_Hide)

    local deleteFilterBtn = CreateFrame("Button", nil, editorContainer, "UIPanelButtonTemplate")
    deleteFilterBtn:SetSize(110, 22)
    deleteFilterBtn:SetPoint("TOPRIGHT", editorContainer, "TOPRIGHT", -4, -8)
    deleteFilterBtn:SetText("|cffff4444Filter löschen|r")

    -- Spalten Bezeichner für Regeln
    local colHeader = editorContainer:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    colHeader:SetPoint("TOPLEFT", dimCB, "BOTTOMLEFT", 8, -8)
    colHeader:SetText("|cff00ccffVerknüpf.  NOT  Feld                       Wert|r")

    local sep = editorContainer:CreateTexture(nil, "ARTWORK")
    sep:SetHeight(1)
    sep:SetPoint("TOPLEFT", colHeader, "BOTTOMLEFT", -8, -4)
    sep:SetPoint("RIGHT", editorContainer, "RIGHT", 0, 0)
    sep:SetColorTexture(0.3, 0.3, 0.3, 0.8)

    -- Regel Scroll Frame
    local ruleScroll = CreateFrame("ScrollFrame", nil, editorContainer, "UIPanelScrollFrameTemplate")
    ruleScroll:SetPoint("TOPLEFT", sep, "BOTTOMLEFT", 0, -4)
    ruleScroll:SetPoint("BOTTOMRIGHT", editorContainer, "BOTTOMRIGHT", -26, 40)

    local ruleContent = CreateFrame("Frame", nil, ruleScroll)
    ruleContent:SetSize(rightPane:GetWidth() - 26, 1)
    ruleScroll:SetScrollChild(ruleContent)

    local addRuleBtn = CreateFrame("Button", nil, editorContainer, "UIPanelButtonTemplate")
    addRuleBtn:SetSize(160, 26)
    addRuleBtn:SetText("+ Regel hinzufügen")
    addRuleBtn:SetPoint("BOTTOMLEFT", editorContainer, "BOTTOMLEFT", 0, 4)

    local clearRulesBtn = CreateFrame("Button", nil, editorContainer, "UIPanelButtonTemplate")
    clearRulesBtn:SetSize(110, 26)
    clearRulesBtn:SetText("Alle löschen")
    clearRulesBtn:SetPoint("LEFT", addRuleBtn, "RIGHT", 8, 0)

    local hint = editorContainer:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hint:SetPoint("BOTTOMRIGHT", editorContainer, "BOTTOMRIGHT", -4, 10)
    hint:SetText("|cff666666Änderungen werden sofort übernommen|r")

    -- STATE 
    local activeBagData = nil
    local ruleLines = {}
    local filterButtons = {}

    local function RefreshRuleList()
        if not activeBagData then return end
        
        for _, line in ipairs(ruleLines) do
            line:Hide()
            line:SetParent(nil)
        end
        wipe(ruleLines)

        local rules = activeBagData.rules
        local ROW_H = 32
        local totalH = 0

        for i, rule in ipairs(rules) do
            local line = CreateRuleLine(
                ruleContent, rule, i, -totalH,
                function(ri)
                    table.remove(rules, ri)
                    RefreshRuleList()
                    if BrannFilterBag.UI then BrannFilterBag.UI:RefreshMasterBag() end
                end,
                function()
                    if BrannFilterBag.UI then BrannFilterBag.UI:RefreshMasterBag() end
                end
            )
            table.insert(ruleLines, line)
            totalH = totalH + ROW_H
        end

        ruleContent:SetHeight(math.max(totalH, 10))
    end

    local function SelectFilter(bagData)
        activeBagData = bagData
        
        for _, btn in ipairs(filterButtons) do
            if btn.bagData == bagData then
                btn.highlight:SetColorTexture(0.2, 0.6, 1.0, 0.4)
            else
                btn.highlight:SetColorTexture(1, 1, 1, 0.1)
            end
        end

        if bagData then
            noSelText:Hide()
            editorContainer:Show()
            
            nameEB:SetText(bagData.name or "Filter")
            dimCB:SetChecked(bagData.exclusiveOnly == true)
            showEmptyCB:SetChecked(bagData.showEmpty == true)
            
            RefreshRuleList()
        else
            noSelText:Show()
            editorContainer:Hide()
        end
    end

    local function RefreshFilterList()
        -- Tab-Button-Status visuell updaten
        if FS.isEditingReagents then
            tabMainBag:Enable()
            tabReagent:Disable()
        else
            tabMainBag:Disable()
            tabReagent:Enable()
        end
        
        for _, btn in ipairs(filterButtons) do
            btn:Hide()
            btn:SetParent(nil)
        end
        wipe(filterButtons)

        local y = 0
        local vBags = FS.isEditingReagents and BrannFilterBag.db.reagentBags or BrannFilterBag.db.virtualBags
        for i, bd in ipairs(vBags) do
            local btn = CreateFrame("Button", nil, listContent)
            btn:SetSize(LEFT_W - 30, 24)
            btn:SetPoint("TOPLEFT", listContent, "TOPLEFT", 0, -y)
            
            local hl = btn:CreateTexture(nil, "BACKGROUND")
            hl:SetAllPoints()
            hl:SetColorTexture(1, 1, 1, 0.1)
            btn.highlight = hl
            
            btn:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
            btn:GetHighlightTexture():SetBlendMode("ADD")
            
            local txt = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            txt:SetPoint("LEFT", 4, 0)
            txt:SetPoint("RIGHT", -4, 0)
            txt:SetJustifyH("LEFT")
            txt:SetWordWrap(false)
            txt:SetText(bd.name)
            
            btn.bagData = bd
            btn:SetScript("OnClick", function()
                SelectFilter(bd)
            end)
            
            -- Sort Up Button
            local upBtn = CreateFrame("Button", nil, btn)
            upBtn:SetSize(16, 16)
            upBtn:SetPoint("RIGHT", btn, "RIGHT", -20, 0)
            upBtn:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollUp-Up")
            upBtn:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollUp-Down")
            upBtn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight")
            upBtn:SetScript("OnClick", function(self)
                if i > 1 then
                    local temp = vBags[i]
                    vBags[i] = vBags[i-1]
                    vBags[i-1] = temp
                    RefreshFilterList()
                    if BrannFilterBag.UI then BrannFilterBag.UI:RefreshMasterBag() end
                end
            end)

            -- Sort Down Button
            local downBtn = CreateFrame("Button", nil, btn)
            downBtn:SetSize(16, 16)
            downBtn:SetPoint("RIGHT", btn, "RIGHT", -2, 0)
            downBtn:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up")
            downBtn:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Down")
            downBtn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight")
            downBtn:SetScript("OnClick", function(self)
                if i < #vBags then
                    local temp = vBags[i]
                    vBags[i] = vBags[i+1]
                    vBags[i+1] = temp
                    RefreshFilterList()
                    if BrannFilterBag.UI then BrannFilterBag.UI:RefreshMasterBag() end
                end
            end)

            -- Drag and Drop Funktionalität
            btn:RegisterForDrag("LeftButton")
            btn:SetScript("OnDragStart", function(self)
                self.isDragging = true
                self.dragStartIdx = i
                SetCursor("BUY_CURSOR") -- Einfacher visueller Indikator "ich greife etwas"
            end)
            btn:SetScript("OnDragStop", function(self)
                if not self.isDragging then return end
                self.isDragging = false
                ResetCursor()
                
                -- Finde Ziel-Button anhand der Maus-Y-Koordinate
                local cx, cy = GetCursorPosition()
                local scale = btn:GetEffectiveScale()
                cy = cy / scale
                
                local targetIdx = nil
                local closestDist = math.huge
                
                for j, otherBtn in ipairs(filterButtons) do
                    if otherBtn:IsShown() and otherBtn ~= self then
                        local _, ocy = otherBtn:GetCenter()
                        if ocy then
                            local dist = math.abs(cy - ocy)
                            if dist < closestDist then
                                closestDist = dist
                                targetIdx = j
                            end
                        end
                    end
                end
                
                if targetIdx then
                    local item = table.remove(vBags, self.dragStartIdx)
                    table.insert(vBags, targetIdx, item)
                    RefreshFilterList()
                    if BrannFilterBag.UI then BrannFilterBag.UI:RefreshMasterBag() end
                end
            end)

            table.insert(filterButtons, btn)
            y = y + 26
        end
        listContent:SetHeight(math.max(y, 10))

        -- Reselect if active still exists, else nil
        local found = false
        if activeBagData then
            for _, bd in ipairs(vBags) do
                if bd == activeBagData then found = true; break end
            end
        end
        
        if found then SelectFilter(activeBagData) else SelectFilter(nil) end
    end

    -- Callbacks
    addBagBtn:SetScript("OnClick", function()
        local id = BrannFilterBag:NewID()
        local bd = {
            id      = id,
            name    = "Filter " .. id,
            icon    = "Interface\\Icons\\INV_Misc_Bag_07",
            rules   = {},
            visible = true,
            expanded = true,
        }
        
        if FS.isEditingReagents then
            table.insert(BrannFilterBag.db.reagentBags, bd)
            BrannFilterBag.db.masterBag.reagentOpen = true
        else
            table.insert(BrannFilterBag.db.virtualBags, bd)
            BrannFilterBag.db.masterBag.visible = true
        end
        
        if BrannFilterBag.UI then
            BrannFilterBag.UI.masterFrame:Show()
            BrannFilterBag.UI:RefreshMasterBag()
        end
        RefreshFilterList()
        SelectFilter(bd)
    end)

    deleteFilterBtn:SetScript("OnClick", function()
        if not activeBagData then return end
        local vBags = FS.isEditingReagents and BrannFilterBag.db.reagentBags or BrannFilterBag.db.virtualBags
        for i, bd in ipairs(vBags) do
            if bd == activeBagData then
                table.remove(vBags, i)
                break
            end
        end
        if BrannFilterBag.UI then BrannFilterBag.UI:RefreshMasterBag() end
        RefreshFilterList()
    end)

    nameEB:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
        if activeBagData then
            activeBagData.name = self:GetText()
            RefreshFilterList() -- updates left pane button text
            if BrannFilterBag.UI then BrannFilterBag.UI:RefreshMasterBag() end
        end
    end)
    nameEB:SetScript("OnEscapePressed", function(self)
        self:SetText(activeBagData.name or "Filter")
        self:ClearFocus()
    end)

    dimCB:SetScript("OnClick", function(self)
        if activeBagData then
            activeBagData.exclusiveOnly = self:GetChecked()
            if BrannFilterBag.UI then BrannFilterBag.UI:RefreshMasterBag() end
        end
    end)

    showEmptyCB:SetScript("OnClick", function(self)
        if activeBagData then
            activeBagData.showEmpty = self:GetChecked()
            if BrannFilterBag.UI then BrannFilterBag.UI:RefreshMasterBag() end
        end
    end)

    addRuleBtn:SetScript("OnClick", function()
        if not activeBagData then return end
        table.insert(activeBagData.rules, { field = "name", op = "AND", negate = false, value = "" })
        RefreshRuleList()
        if BrannFilterBag.UI then BrannFilterBag.UI:RefreshMasterBag() end
    end)

    clearRulesBtn:SetScript("OnClick", function()
        if not activeBagData then return end
        wipe(activeBagData.rules)
        RefreshRuleList()
        if BrannFilterBag.UI then BrannFilterBag.UI:RefreshMasterBag() end
    end)

    tabMainBag:SetScript("OnClick", function()
        FS.isEditingReagents = false
        SelectFilter(nil)
        RefreshFilterList()
    end)

    tabReagent:SetScript("OnClick", function()
        FS.isEditingReagents = true
        SelectFilter(nil)
        RefreshFilterList()
    end)

    -- Initialer Zustand
    FS.isEditingReagents = false
    RefreshFilterList()
    SelectTab(1) -- Defaulte auf Einstellungen

    self.currentFrame = panel
    return panel
end

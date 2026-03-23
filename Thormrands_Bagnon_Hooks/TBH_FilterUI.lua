---@diagnostic disable: undefined-global, undefined-field
TBH_FilterUI = {}
TBH_FilterUI.frame = nil

local function ReduceFontSize(fontString, multiplier)
    -- Deprecated: The 0.75 modifier is inherently too small.
end

local function GetCheckbox(parent)
    parent.activeCbs = (parent.activeCbs or 0) + 1
    local cb = parent.cbPool[parent.activeCbs]
    if not cb then
        cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
        cb:SetSize(20, 20)
        local text = cb:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        text:SetPoint("LEFT", cb, "RIGHT", 4, 0)
        cb.text = text
        table.insert(parent.cbPool, cb)
    end
    cb:Show()
    return cb
end

local function GetLabel(parent)
    parent.activeLbls = (parent.activeLbls or 0) + 1
    local lbl = parent.lblPool[parent.activeLbls]
    if not lbl then
        lbl = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        table.insert(parent.lblPool, lbl)
    end
    lbl:Show()
    return lbl
end

local function CreateCheckbox(parent, labelText, onClick, isSubItem)
    local cb = GetCheckbox(parent)
    cb.text:SetText(labelText)

    if isSubItem then
        cb.text:SetFontObject("GameFontHighlightSmall")
    else
        cb.text:SetFontObject("GameFontNormal")
    end

    cb:SetScript("OnClick", function(self)
        onClick(self:GetChecked())
    end)
    return cb
end

local function RebuildUI(f, sourceConfig, targetConfig)
    if not f.container then
        local c = CreateFrame("Frame", nil, f)
        c:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -16)
        c:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -16, 16)
        c.cbPool = {}
        c.lblPool = {}

        c.sLbl = c:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        c.sLbl:SetText("Search text:")

        c.ilvlLbl = c:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        c.ilvlLbl:SetText("iLvl Range (Min-Max):")

        -- Helper to create clean flat editboxes
        local function CreateCleanEditBox(parent)
            local eb = CreateFrame("EditBox", nil, parent)
            eb:SetBackdrop({
                bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
                edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                edgeSize = 8,
                insets = { left = 2, right = 2, top = 2, bottom = 2 }
            })
            eb:SetBackdropColor(0, 0, 0, 0.5)
            eb:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
            eb:SetFontObject("ChatFontNormal")
            eb:SetTextInsets(6, 6, 0, 0)
            return eb
        end

        c.minIlvlBox = CreateCleanEditBox(c)
        c.minIlvlBox:SetSize(45, 20)
        c.minIlvlBox:SetAutoFocus(false)
        c.minIlvlBox:SetNumeric(true)
        c.minIlvlBox:EnableMouseWheel(true)

        c.maxIlvlBox = CreateCleanEditBox(c)
        c.maxIlvlBox:SetSize(45, 20)
        c.maxIlvlBox:SetAutoFocus(false)
        c.maxIlvlBox:SetNumeric(true)
        c.maxIlvlBox:EnableMouseWheel(true)

        c.btnClear = CreateFrame("Button", nil, c)
        c.btnClear:SetSize(100, 24)
        local cTxt = c.btnClear:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        cTxt:SetText("Clear Filter")
        cTxt:SetPoint("CENTER")
        c.btnClear:SetFontString(cTxt)
        c.btnClear.text = cTxt
        c.btnClear:SetScript("OnEnter", function(self)
            self.text:SetTextColor(1, 1, 1)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText("Clear Filter")
            GameTooltip:AddLine("Clears all active filters to default.", 1, 1, 1)
            GameTooltip:Show()
        end)
        c.btnClear:SetScript("OnLeave", function(self)
            self.text:SetTextColor(1, 0.82, 0)
            GameTooltip:Hide()
        end)

        c.btnTransfer = CreateFrame("Button", nil, c)
        c.btnTransfer:SetSize(100, 24)
        local tTxt = c.btnTransfer:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        tTxt:SetText("Transfer")
        tTxt:SetPoint("CENTER")
        c.btnTransfer:SetFontString(tTxt)
        c.btnTransfer.text = tTxt
        c.btnTransfer:SetScript("OnEnter", function(self)
            self.text:SetTextColor(1, 1, 1)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText("Execute Transfer")
            GameTooltip:AddLine("Moves all currently matching items into the opposing open container.", 1, 1, 1)
            GameTooltip:Show()
        end)
        c.btnTransfer:SetScript("OnLeave", function(self)
            self.text:SetTextColor(1, 0.82, 0)
            GameTooltip:Hide()
        end)

        -- Separator Lines
        c.sep1 = c:CreateTexture(nil, "ARTWORK")
        c.sep1:SetTexture(1, 1, 1, 0.15)
        c.sep1:SetSize(188, 1)

        c.sep2 = c:CreateTexture(nil, "ARTWORK")
        c.sep2:SetTexture(1, 1, 1, 0.15)
        c.sep2:SetSize(188, 1)

        f.container = c
    end

    local container = f.container
    container.activeCbs = 0
    container.activeLbls = 0

    -- Hide pooled elements
    for _, cb in ipairs(container.cbPool) do
        cb:Hide(); cb:ClearAllPoints()
    end
    for _, lbl in ipairs(container.lblPool) do
        lbl:Hide(); lbl:ClearAllPoints()
    end

    local items = TBH_FilterUI.cachedItems or {}
    local m = TBH_FilterLogic.Manifest
    local filters = TBH_GlobalState.PersistedFilters

    -- Count Types for debug
    local typeCount = 0
    for k, v in pairs(m.Types) do typeCount = typeCount + 1 end
    TBH_GlobalState.DebugPrint("|cFFFFFF00[TBH Debug] Scanned items: " ..
        tostring(items and #items or 0) .. ", Unique Categories: " .. tostring(typeCount) .. "|r")

    local yOffset = 0
    local SPACING = -24

    local function AddLine(element, height)
        element:SetPoint("TOPLEFT", container, "TOPLEFT", 0, yOffset)
        yOffset = yOffset - height
    end

    local activeCategory = filters.category

    if activeCategory and activeCategory ~= "Armor" and activeCategory ~= "Weapon" then
        filters.bloodforged = false
        filters.mythic = false
        filters.raid = false
        filters.minIlvl = nil
        filters.maxIlvl = nil
    end

    -- Categories
    for catName, catData in pairs(m.Types) do
        local isAdvAllowed = (catName == "Armor" or catName == "Weapon")
        if not (filters.bloodforged or filters.mythic or filters.raid) or isAdvAllowed then
            if activeCategory == nil or activeCategory == catName then
                local cb = CreateCheckbox(container, catName, function(checked)
                    if checked then
                        filters.category = catName
                        filters.subCategory = nil
                        filters.equipLoc = nil
                        if catName ~= "Armor" and catName ~= "Weapon" then
                            filters.bloodforged = false
                            filters.mythic = false
                            filters.raid = false
                            filters.minIlvl = nil
                            filters.maxIlvl = nil
                        end
                    else
                        filters.category = nil
                        filters.subCategory = nil
                        filters.equipLoc = nil
                    end
                    RebuildUI(f, sourceConfig, targetConfig)
                end, false)
                cb:SetChecked(filters.category == catName)
                AddLine(cb, 24)

                if filters.category == catName then
                    local activeSub = filters.subCategory
                    for subName, subData in pairs(catData.SubTypes) do
                        if activeSub == nil or activeSub == subName then
                            local subCb = CreateCheckbox(container, subName, function(checked)
                                if checked then
                                    filters.subCategory = subName
                                    filters.equipLoc = nil
                                else
                                    filters.subCategory = nil
                                    filters.equipLoc = nil
                                end
                                RebuildUI(f, sourceConfig, targetConfig)
                            end, true)
                            subCb:SetPoint("TOPLEFT", container, "TOPLEFT", 20, yOffset)
                            yOffset = yOffset - 24
                            subCb:SetChecked(filters.subCategory == subName)

                            if filters.subCategory == subName then
                                if next(subData.EquipLocs) then
                                    for eqName, _ in pairs(subData.EquipLocs) do
                                        local activeEq = filters.equipLoc
                                        if activeEq == nil or activeEq == eqName then
                                            local eqCb = CreateCheckbox(container, _G[eqName] or eqName,
                                                function(checked)
                                                    if checked then filters.equipLoc = eqName else filters.equipLoc = nil end
                                                    RebuildUI(f, sourceConfig, targetConfig)
                                                end, true)
                                            eqCb:SetPoint("TOPLEFT", container, "TOPLEFT", 40, yOffset)
                                            yOffset = yOffset - 24
                                            eqCb:SetChecked(filters.equipLoc == eqName)
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    -- Separator 1 (Categories -> Advanced Filters)
    yOffset = yOffset - 4
    container.sep1:SetPoint("TOPLEFT", container, "TOPLEFT", 0, yOffset)
    yOffset = yOffset - 12

    -- Advanced Filters Section
    local showAdvFilters = (not activeCategory or activeCategory == "Armor" or activeCategory == "Weapon")

    if showAdvFilters then
        if m.HasBloodforged and not (filters.mythic or filters.raid) then
            local bfCb = CreateCheckbox(container, "Bloodforged Only", function(checked)
                filters.bloodforged = checked
                if checked then
                    filters.mythic = false; filters.raid = false
                end
                RebuildUI(f, sourceConfig, targetConfig)
            end, false)
            bfCb:SetChecked(filters.bloodforged)
            AddLine(bfCb, 20)
        end
        if m.HasMythic and not (filters.bloodforged or filters.raid) then
            local mtCb = CreateCheckbox(container, "Mythic Only", function(checked)
                filters.mythic = checked
                if checked then
                    filters.bloodforged = false; filters.raid = false
                end
                RebuildUI(f, sourceConfig, targetConfig)
            end, false)
            mtCb:SetChecked(filters.mythic)
            AddLine(mtCb, 20)
        end
        if m.HasRaid and not (filters.bloodforged or filters.mythic) then
            local rdCb = CreateCheckbox(container, "Raid Only", function(checked)
                filters.raid = checked
                if checked then
                    filters.bloodforged = false; filters.mythic = false
                end
                RebuildUI(f, sourceConfig, targetConfig)
            end, false)
            rdCb:SetChecked(filters.raid)
            AddLine(rdCb, 20)
        end

        yOffset = yOffset - 8
        container.ilvlLbl:SetPoint("TOPLEFT", container, "TOPLEFT", 0, yOffset)
        container.ilvlLbl:Show()
        yOffset = yOffset - 16

        local validIlvls = {}
        local validHash = {}
        for _, item in ipairs(items) do
            local pass = true
            if filters.category and item.itemType ~= filters.category then pass = false end
            local cSub = (item.subType and item.subType ~= "") and item.subType or "None"
            if pass and filters.subCategory and cSub ~= filters.subCategory then pass = false end
            if pass and filters.equipLoc and item.equipLoc ~= filters.equipLoc then pass = false end
            if pass and filters.bloodforged and not item.isBloodforged then pass = false end
            if pass and filters.mythic and not item.isMythic then pass = false end
            if pass and filters.raid and not item.isRaid then pass = false end

            if pass and item.itemLevel and item.itemLevel > 0 then
                if not validHash[item.itemLevel] then
                    validHash[item.itemLevel] = true
                    table.insert(validIlvls, item.itemLevel)
                end
            end
        end
        table.sort(validIlvls)

        local function GetAdj(cur, delta)
            if #validIlvls == 0 then return cur end
            local c = tonumber(cur) or validIlvls[1]
            local idx = 1
            for i, v in ipairs(validIlvls) do
                if v <= c then idx = i end
                if v >= c then break end
            end
            local nx = idx + (delta > 0 and 1 or -1)
            if nx < 1 then nx = 1 end
            if nx > #validIlvls then nx = #validIlvls end
            return validIlvls[nx]
        end

        local defMin = #validIlvls > 0 and validIlvls[1] or (m.MinIlvl or "")
        local defMax = #validIlvls > 0 and validIlvls[#validIlvls] or (m.MaxIlvl or "")

        container.minIlvlBox:SetText(filters.minIlvl and tostring(filters.minIlvl) or tostring(defMin))
        container.minIlvlBox:SetPoint("TOPLEFT", container, "TOPLEFT", 6, yOffset)
        container.minIlvlBox:SetScript("OnTextChanged", nil)
        container.minIlvlBox:SetScript("OnEditFocusLost", function(self)
            local val = tonumber(self:GetText() or "")
            if filters.minIlvl ~= val then
                filters.minIlvl = val
                RebuildUI(f, sourceConfig, targetConfig)
            end
        end)
        container.minIlvlBox:SetScript("OnEnterPressed", function(self)
            self:ClearFocus()
        end)
        container.minIlvlBox:SetScript("OnMouseWheel", function(self, delta)
            local nx = GetAdj(self:GetText(), delta)
            self:SetText(tostring(nx))
            filters.minIlvl = nx
            RebuildUI(f, sourceConfig, targetConfig)
        end)
        container.minIlvlBox:Show()

        container.maxIlvlBox:SetText(filters.maxIlvl and tostring(filters.maxIlvl) or tostring(defMax))
        container.maxIlvlBox:SetPoint("TOPLEFT", container, "TOPLEFT", 56, yOffset)
        container.maxIlvlBox:SetScript("OnTextChanged", nil)
        container.maxIlvlBox:SetScript("OnEditFocusLost", function(self)
            local val = tonumber(self:GetText() or "")
            if filters.maxIlvl ~= val then
                filters.maxIlvl = val
                RebuildUI(f, sourceConfig, targetConfig)
            end
        end)
        container.maxIlvlBox:SetScript("OnEnterPressed", function(self)
            self:ClearFocus()
        end)
        container.maxIlvlBox:SetScript("OnMouseWheel", function(self, delta)
            local nx = GetAdj(self:GetText(), delta)
            self:SetText(tostring(nx))
            filters.maxIlvl = nx
            RebuildUI(f, sourceConfig, targetConfig)
        end)
        container.maxIlvlBox:Show()
        yOffset = yOffset - 28
    else
        container.ilvlLbl:Hide()
        container.minIlvlBox:Hide()
        container.maxIlvlBox:Hide()
    end

    -- Separator 2 (Advanced Filters -> Execution Buttons)
    if showAdvFilters then
        container.sep2:SetPoint("TOPLEFT", container, "TOPLEFT", 0, yOffset)
        container.sep2:Show()
        yOffset = yOffset - 12
    else
        container.sep2:Hide()
        yOffset = yOffset - 4
    end

    local matchCount = 0
    local matchedBags = {}
    local matchedTabs = {}

    for _, item in ipairs(items) do
        local pass = true
        if filters.category and item.itemType ~= filters.category then pass = false end
        local cSub = (item.subType and item.subType ~= "") and item.subType or "None"
        if pass and filters.subCategory and cSub ~= filters.subCategory then pass = false end
        if pass and filters.equipLoc and item.equipLoc ~= filters.equipLoc then pass = false end
        if pass and filters.bloodforged and not item.isBloodforged then pass = false end
        if pass and filters.mythic and not item.isMythic then pass = false end
        if pass and filters.raid and not item.isRaid then pass = false end
        if pass and filters.minIlvl and item.itemLevel < filters.minIlvl then pass = false end
        if pass and filters.maxIlvl and item.itemLevel > filters.maxIlvl then pass = false end

        if pass then
            matchCount = matchCount + 1
            if item.type == "bag" or item.type == "bank" then
                matchedBags[item.bag] = true
            elseif item.type == "guild" then
                matchedTabs[item.tab] = true
            end
        end
    end

    if not container.resultLbl then
        container.resultLbl = container:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
        container.resultLbl:SetPoint("BOTTOM", container, "BOTTOM", 0, 0)
    end

    container.resultLbl:SetText("Results: " .. matchCount)
    if matchCount == 0 then
        container.resultLbl:SetTextColor(1, 0.4, 0.4)
    elseif matchCount <= 50 then
        container.resultLbl:SetTextColor(0.4, 1, 0.4)
    else
        if not container.pulseFrame then
            container.pulseFrame = CreateFrame("Frame", nil, container)
        end
        container.pulseFrame.timer = 0
        container.pulseFrame:SetScript("OnUpdate", function(self, elapsed)
            self.timer = (self.timer + elapsed) % 10
            local pulse = (math.sin(self.timer * 8) + 1) / 2
            container.resultLbl:SetTextColor(1, 0.5 + pulse * 0.5, pulse * 0.2)
        end)
    end
    if matchCount <= 50 and container.pulseFrame then
        container.pulseFrame:SetScript("OnUpdate", nil)
    end

    local LCG = LibStub("LibCustomGlow-1.0", true)
    if not container.activeLCGFrames then container.activeLCGFrames = {} end
    if LCG then
        for tf, _ in pairs(container.activeLCGFrames) do
            LCG.PixelGlow_Stop(tf, "TBHFilter")
        end
    end
    table.wipe(container.activeLCGFrames)

    local glowR, glowG, glowB = 0, 1, 0
    if f.bagnonFrame then
        local settings = f.bagnonFrame:GetSettings()
        if settings then
            local cr, cg, cb = settings:GetColor()
            if cr then glowR, glowG, glowB = cr, cg, cb end
        end
    end
    local glowColor = { glowR, glowG, glowB, 1 }

    local function ApplyGlow(targetFrame)
        if not targetFrame then return end
        if LCG then
            LCG.PixelGlow_Start(targetFrame, glowColor, 8, 0.25, 8, 3, 0, 0, false, "TBHFilter")
        end
        container.activeLCGFrames[targetFrame] = true
    end

    if sourceConfig.type == "guild" then
        for tabId, _ in pairs(matchedTabs) do
            for i = 1, 30 do
                local tf = _G["BagnonGuildTab" .. i]
                if tf and tf:GetID() == tabId then ApplyGlow(tf) end
            end
        end
    else
        for bagId, _ in pairs(matchedBags) do
            for i = 1, 30 do
                local bf = _G["BagnonBag" .. i]
                if bf and bf:GetID() == bagId then ApplyGlow(bf) end
            end
        end
    end

    local matchedItemsSet = {}
    for _, item in ipairs(items) do
        local pass = true
        if filters.category and item.itemType ~= filters.category then pass = false end
        local cSub = (item.subType and item.subType ~= "") and item.subType or "None"
        if pass and filters.subCategory and cSub ~= filters.subCategory then pass = false end
        if pass and filters.equipLoc and item.equipLoc ~= filters.equipLoc then pass = false end
        if pass and filters.bloodforged and not item.isBloodforged then pass = false end
        if pass and filters.mythic and not item.isMythic then pass = false end
        if pass and filters.raid and not item.isRaid then pass = false end
        if pass and filters.minIlvl and item.itemLevel < filters.minIlvl then pass = false end
        if pass and filters.maxIlvl and item.itemLevel > filters.maxIlvl then pass = false end

        if pass then
            local key = (item.type == "guild" and item.tab or item.bag) .. "_" .. item.slot
            matchedItemsSet[key] = true
        end
    end

    TBH_FilterUI.matchedItemsSet = matchedItemsSet
    TBH_FilterUI.glowColor = glowColor

    if f.bagnonFrame and f.bagnonFrame.itemFrame and type(f.bagnonFrame.itemFrame.GetAllItemSlots) == "function" then
        for _, itemSlot in f.bagnonFrame.itemFrame:GetAllItemSlots() do
            if itemSlot:IsVisible() then
                local bTab, bSlot
                if type(itemSlot.GetSlot) == "function" then
                    bTab, bSlot = itemSlot:GetSlot()
                elseif type(itemSlot.GetBag) == "function" then
                    bTab, bSlot = itemSlot:GetBag(), itemSlot:GetID()
                end

                if bTab and bSlot and matchedItemsSet[bTab .. "_" .. bSlot] then
                    ApplyGlow(itemSlot)
                end
            end
        end
    end

    if not TBH_FilterUI.hooksInitialized then
        TBH_FilterUI.hooksInitialized = true
        local function HookBagnonItemUpdate(itemSlot)
            local uiF = TBH_FilterUI.frame
            if uiF and uiF:IsVisible() and TBH_FilterUI.matchedItemsSet then
                local LCGv = LibStub("LibCustomGlow-1.0", true)
                if not LCGv then return end

                local bTab, bSlot
                if type(itemSlot.GetSlot) == "function" then
                    bTab, bSlot = itemSlot:GetSlot()
                elseif type(itemSlot.GetBag) == "function" then
                    bTab, bSlot = itemSlot:GetBag(), itemSlot:GetID()
                end

                if bTab and bSlot then
                    local key = bTab .. "_" .. bSlot
                    if TBH_FilterUI.matchedItemsSet[key] then
                        if not container.activeLCGFrames[itemSlot] then
                            LCGv.PixelGlow_Start(itemSlot, TBH_FilterUI.glowColor, 8, 0.25, 8, 3, 0, 0, false,
                                "TBHFilter")
                            container.activeLCGFrames[itemSlot] = true
                        end
                    else
                        if container.activeLCGFrames[itemSlot] then
                            LCGv.PixelGlow_Stop(itemSlot, "TBHFilter")
                            container.activeLCGFrames[itemSlot] = nil
                        end
                    end
                end
            end
        end

        if Bagnon and Bagnon.ItemSlot and Bagnon.ItemSlot.Update then
            hooksecurefunc(Bagnon.ItemSlot, "Update", HookBagnonItemUpdate)
        end
        if Bagnon and Bagnon.GuildItemSlot and Bagnon.GuildItemSlot.Update then
            hooksecurefunc(Bagnon.GuildItemSlot, "Update", HookBagnonItemUpdate)
        end
    end

    -- Action Links at bottom
    container.btnClear:SetPoint("BOTTOMLEFT", container, "BOTTOMLEFT", 0, 24)
    container.btnClear:SetScript("OnClick", function()
        TBH_FilterLogic.ClearFilters()
        RebuildUI(f, sourceConfig, targetConfig)
    end)

    container.btnTransfer:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", 0, 24)
    container.btnTransfer:SetScript("OnClick", function()
        TBH_FilterLogic.ExecuteFilteredTransfer(sourceConfig, targetConfig)
        f:Hide()
    end)

    f:SetScript("OnHide", function()
        if container.activeLCGFrames then
            local LCG = LibStub("LibCustomGlow-1.0", true)
            if LCG then
                for g, _ in pairs(container.activeLCGFrames) do
                    LCG.PixelGlow_Stop(g, "TBHFilter")
                end
            end
        end
    end)

    -- Adjust frame height to nicely fit contents
    f:SetHeight(math.max(200, math.abs(yOffset) + 78))
end

function TBH_FilterUI.Toggle(bagnonFrame)
    local fid = bagnonFrame:GetFrameID()

    local oppositeID = TBH_TransferLogic.GetOpposingFrame(fid)
    if not oppositeID then
        print("|cFFFF0000[TBH] Open another container (e.g. Bank or Guild Bank) to use filters.|r")
        return
    end

    if TBH_FilterUI.frame and TBH_FilterUI.frame:IsShown() and TBH_FilterUI.frame.bagnonFrameID == fid then
        TBH_FilterUI.frame:Hide()
        return
    end

    if not TBH_FilterUI.frame then
        local f = CreateFrame("Frame", "TBH_FilterUIFrame", UIParent)
        f:SetSize(220, 300)
        f:SetFrameStrata("BACKGROUND")
        tinsert(UISpecialFrames, f:GetName())

        f:SetBackdrop({
            bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 16,
            tile = true,
            tileSize = 16,
            insets = { left = 4, right = 4, top = 4, bottom = 4 }
        })

        f:SetScript("OnUpdate", function(self)
            if self.bagnonFrame and not self.bagnonFrame:IsVisible() then
                self:Hide()
            end
            if self.oppositeID and not TBH_TransferLogic.GetOpposingFrame(self.bagnonFrameID) then
                self:Hide()
            end
        end)

        TBH_FilterUI.frame = f
    end

    local f = TBH_FilterUI.frame
    f.bagnonFrameID = fid
    f.bagnonFrame = bagnonFrame
    f.oppositeID = oppositeID

    -- Anchor it natively to the Bagnon frame TOPRIGHT
    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", bagnonFrame, "TOPRIGHT", -5, 0)

    -- Mirror Colors
    local settings = bagnonFrame:GetSettings()
    if settings then
        local r, g, b, a = settings:GetColor()
        if r then f:SetBackdropColor(r * 0.75, g * 0.75, b * 0.75, 0.90) end
        local br, bg, bb, ba = settings:GetBorderColor()
        if br then f:SetBackdropBorderColor(br, bg, bb, ba) end
    end

    -- Determine SourceConfig (Scanning Clicked Container to push to Opposite Container)
    local sourceConfig = {}
    local targetConfig = {}
    local inventoryBags = { 0, 1, 2, 3, 4 }
    local bankBags = { -1, 5, 6, 7, 8, 9, 10, 11 }

    local fidStr = tostring(fid):lower()
    if fidStr == "inventory" then
        sourceConfig.type = "bag"
        sourceConfig.bags = inventoryBags
    elseif fidStr == "bank" then
        sourceConfig.type = "bag"
        sourceConfig.bags = bankBags
    elseif fidStr:find("guild") then
        sourceConfig.type = "guild"
        sourceConfig.tab = GetCurrentGuildBankTab()
    end

    local oppStr = tostring(oppositeID):lower()
    if oppStr == "inventory" then
        targetConfig.type = "bag"
        targetConfig.bags = inventoryBags
    elseif oppStr == "bank" then
        targetConfig.type = "bag"
        targetConfig.bags = bankBags
    elseif oppStr:find("guild") then
        targetConfig.type = "guild"
        targetConfig.tab = GetCurrentGuildBankTab()
    end

    if sourceConfig.type == "guild" and not sourceConfig.tab then
        print("|cFFFF0000[TBH] Valid Guild Bank tab not selected.|r")
        return
    end

    -- Heaviest function block execution. Cache snapshot to prevent stuttering.
    TBH_FilterUI.cachedItems = TBH_FilterLogic.ScanContainer(sourceConfig)

    RebuildUI(f, sourceConfig, targetConfig)
    f:Show()
end

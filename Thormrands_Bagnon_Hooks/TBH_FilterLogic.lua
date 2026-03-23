---@diagnostic disable: undefined-global, undefined-field
TBH_FilterLogic = {}
TBH_FilterLogic.Manifest = {}

TBH_GlobalState.BloodforgedCaches = TBH_GlobalState.BloodforgedCaches or {}
TBH_GlobalState.MythicCaches = TBH_GlobalState.MythicCaches or {}
TBH_GlobalState.RaidCaches = TBH_GlobalState.RaidCaches or {}

TBH_GlobalState.PersistedFilters = TBH_GlobalState.PersistedFilters or {
    category = nil,
    subCategory = nil,
    equipLoc = nil,
    quality = {},
    bloodforged = false,
    mythic = false,
    raid = false,
    minIlvl = nil,
    maxIlvl = nil,
    searchText = ""
}

local function GetItemAttributes(itemLink)
    if not itemLink then return false, false, false end

    local bfCache = TBH_GlobalState.BloodforgedCaches[itemLink]
    local mtCache = TBH_GlobalState.MythicCaches[itemLink]
    local rdCache = TBH_GlobalState.RaidCaches[itemLink]

    if bfCache ~= nil and mtCache ~= nil and rdCache ~= nil then
        return bfCache, mtCache, rdCache
    end

    if not _G.TBH_HiddenScannerTooltip then
        local tooltip = CreateFrame("GameTooltip", "TBH_HiddenScannerTooltip", UIParent, "GameTooltipTemplate")
        tooltip:SetOwner(UIParent, "ANCHOR_NONE")
    end

    _G.TBH_HiddenScannerTooltip:ClearLines()
    _G.TBH_HiddenScannerTooltip:SetHyperlink(itemLink)

    local isBF, isMT, isRD = false, false, false
    for i = 1, math.min(10, _G.TBH_HiddenScannerTooltip:NumLines()) do
        local leftText = _G["TBH_HiddenScannerTooltipTextLeft" .. i]
        if leftText and leftText:GetText() then
            local text = leftText:GetText()
            if text:find("^Bloodforged") or text == "Bloodforged" then isBF = true end
            if text:find("Mythic") then isMT = true end
            if text:find("Raid") then isRD = true end
        end
    end

    TBH_GlobalState.BloodforgedCaches[itemLink] = isBF
    TBH_GlobalState.MythicCaches[itemLink] = isMT
    TBH_GlobalState.RaidCaches[itemLink] = isRD

    return isBF, isMT, isRD
end

function TBH_FilterLogic.ClearFilters()
    table.wipe(TBH_GlobalState.PersistedFilters.quality)
    TBH_GlobalState.PersistedFilters.category = nil
    TBH_GlobalState.PersistedFilters.subCategory = nil
    TBH_GlobalState.PersistedFilters.equipLoc = nil
    TBH_GlobalState.PersistedFilters.bloodforged = false
    TBH_GlobalState.PersistedFilters.mythic = false
    TBH_GlobalState.PersistedFilters.raid = false
    TBH_GlobalState.PersistedFilters.minIlvl = nil
    TBH_GlobalState.PersistedFilters.maxIlvl = nil
end

function TBH_FilterLogic.ScanContainer(sourceConfig)
    local items = {}
    local manifest = {
        Types = {},
        Qualities = {},
        HasBloodforged = false,
        HasMythic = false,
        HasRaid = false,
        MinIlvl = nil,
        MaxIlvl = nil
    }

    local function processItemEntry(bagOrTab, slot, link, isGuild)
        if not link then return end
        local itemName, _, itemRarity, itemLevel, _, itemType, itemSubType, _, itemEquipLoc = GetItemInfo(link)
        if not itemName then return end

        local isBF, isMT, isRD = false, false, false
        if itemType == "Armor" or itemType == "Weapon" then
            isBF, isMT, isRD = GetItemAttributes(link)
            if itemLevel and itemLevel > 0 then
                if not manifest.MinIlvl or itemLevel < manifest.MinIlvl then manifest.MinIlvl = itemLevel end
                if not manifest.MaxIlvl or itemLevel > manifest.MaxIlvl then manifest.MaxIlvl = itemLevel end
            end
        end

        local itemData = {
            link = link,
            name = itemName,
            quality = itemRarity,
            itemLevel = itemLevel,
            itemType = itemType,
            subType = itemSubType,
            equipLoc = itemEquipLoc,
            isBloodforged = isBF,
            isMythic = isMT,
            isRaid = isRD,
            bag = isGuild and nil or bagOrTab,
            tab = isGuild and bagOrTab or nil,
            slot = slot,
            type = isGuild and "guild" or "bag"
        }
        table.insert(items, itemData)

        -- Build Manifest
        if not manifest.Types[itemType] then
            manifest.Types[itemType] = { SubTypes = {} }
        end

        local stName = (itemSubType and itemSubType ~= "") and itemSubType or "None"
        if not manifest.Types[itemType].SubTypes[stName] then
            manifest.Types[itemType].SubTypes[stName] = { EquipLocs = {} }
        end

        if itemEquipLoc and itemEquipLoc ~= "" then
            manifest.Types[itemType].SubTypes[stName].EquipLocs[itemEquipLoc] = true
        end

        manifest.Qualities[itemRarity or 0] = true
        if isBF then manifest.HasBloodforged = true end
        if isMT then manifest.HasMythic = true end
        if isRD then manifest.HasRaid = true end
    end

    if sourceConfig.type == "bag" then
        for _, bag in ipairs(sourceConfig.bags) do
            local numSlots = GetContainerNumSlots(bag)
            for slot = 1, numSlots do
                local link = GetContainerItemLink(bag, slot)
                processItemEntry(bag, slot, link, false)
            end
        end
    elseif sourceConfig.type == "guild" then
        local numTabs = math.min(6, GetNumGuildBankTabs() or 0)
        for tab = 1, numTabs do
            for slot = 1, 98 do
                local link = GetGuildBankItemLink(tab, slot)
                processItemEntry(tab, slot, link, true)
            end
        end
    end

    TBH_FilterLogic.Manifest = manifest
    return items
end

function TBH_FilterLogic.ExecuteFilteredTransfer(sourceConfig, targetConfig)
    if TBH_GlobalState.isTransferring then
        print("|cFFFF0000[TBH] Already transferring! Please wait.|r")
        return
    end

    local items = TBH_FilterLogic.ScanContainer(sourceConfig)
    local filters = TBH_GlobalState.PersistedFilters
    local matchCount = 0

    TBH_GlobalState.transferTargetConfig = targetConfig
    table.wipe(TBH_GlobalState.queue)

    for _, item in ipairs(items) do
        local pass = true

        if filters.category and item.itemType ~= filters.category then
            pass = false
        end

        local checkSub = (item.subType and item.subType ~= "") and item.subType or "None"
        if pass and filters.subCategory and checkSub ~= filters.subCategory then
            pass = false
        end

        if pass and filters.equipLoc and item.equipLoc ~= filters.equipLoc then
            pass = false
        end

        -- Quality check
        if pass then
            local hasAnyQualityFilter = false
            local qualityPassed = false
            for k, v in pairs(filters.quality) do
                if v then
                    hasAnyQualityFilter = true
                    if item.quality == k then
                        qualityPassed = true
                    end
                end
            end
            if hasAnyQualityFilter and not qualityPassed then
                pass = false
            end
        end

        if pass and filters.bloodforged and not item.isBloodforged then
            pass = false
        end

        if pass and filters.mythic and not item.isMythic then
            pass = false
        end

        if pass and filters.raid and not item.isRaid then
            pass = false
        end

        if pass and item.itemType and (item.itemType == "Armor" or item.itemType == "Weapon") then
            if filters.minIlvl and item.itemLevel < filters.minIlvl then pass = false end
            if filters.maxIlvl and item.itemLevel > filters.maxIlvl then pass = false end
        end

        if pass and filters.searchText and filters.searchText ~= "" then
            if not item.name:lower():find(filters.searchText:lower(), 1, true) then
                pass = false
            end
        end

        if pass then
            table.insert(TBH_GlobalState.queue, { type = item.type, bag = item.bag, tab = item.tab, slot = item.slot })
            matchCount = matchCount + 1
        end
    end

    if matchCount > 0 then
        if matchCount > 50 and not TBH_SavedSettings.SkipMassTransferWarning then
            local dialog = StaticPopup_Show("TBH_CONFIRM_MASS_TRANSFER", matchCount)
            if dialog then dialog.data = matchCount end
            return
        end
        print("|cFFFFFF00[TBH] Queueing " .. matchCount .. " filtered transfers...|r")
        TBH_GlobalState.isTransferring = true
    else
        print("|cFFFF0000[TBH] No items matched the current active filters!|r")
    end
end

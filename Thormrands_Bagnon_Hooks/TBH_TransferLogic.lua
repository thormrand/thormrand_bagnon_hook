TBH_TransferLogic = {}

local updateFrame = CreateFrame("Frame")
local TIME_BETWEEN_TRANSFERS = 0.05
local timer = 0

updateFrame:SetScript("OnUpdate", function(self, elapsed)
    if not TBH_GlobalState.isTransferring then return end

    timer = timer + elapsed
    if timer >= TIME_BETWEEN_TRANSFERS then
        timer = 0
        local job = table.remove(TBH_GlobalState.queue, 1)
        if job then
            if job.type == "bag" then
                UseContainerItem(job.bag, job.slot)
            elseif job.type == "guild" then
                AutoStoreGuildBankItem(job.tab, job.slot)
            end
        else
            TBH_GlobalState.isTransferring = false
            print("|cFF00FF00[TBH] Transfers Complete!|r")
        end
    end
end)

function TBH_TransferLogic.GetOpposingFrame(sourceFrameID)
    local function isShown(id)
        local f = _G["BagnonFrame" .. id]
        if f then
            if f:IsVisible() then return true end
            if f.IsFrameShown and f:IsFrameShown() then return true end
        end
        return false
    end

    local sid = sourceFrameID and tostring(sourceFrameID):lower() or ""

    if sid:find("guild") then
        if isShown("inventory") then return "inventory" end
        if isShown("bank") then return "bank" end
    elseif sid == "bank" then
        if isShown("inventory") then return "inventory" end
        if isShown("guildbank") then return "guildbank" end
    elseif sid == "inventory" then
        if isShown("guildbank") then return "guildbank" end
        if isShown("bank") then return "bank" end
    end

    if sid ~= "inventory" and isShown("inventory") then return "inventory" end
    if sid == "inventory" and isShown("guildbank") then return "guildbank" end
    if sid == "inventory" and isShown("bank") then return "bank" end

    return nil
end

local function GetItemIDFromLink(link)
    if not link then return nil end
    local _, _, id = string.find(link, "item:(%d+)")
    return id
end

local function CheckItemInBags(targetID, bagsTable)
    for _, bag in ipairs(bagsTable) do
        for slot = 1, GetContainerNumSlots(bag) do
            local link = GetContainerItemLink(bag, slot)
            if link and GetItemIDFromLink(link) == targetID then
                return true
            end
        end
    end
    return false
end

local function CheckItemInGuildBank(targetID, tab)
    for slot = 1, 98 do
        local link = GetGuildBankItemLink(tab, slot)
        if link and GetItemIDFromLink(link) == targetID then
            return true
        end
    end
    return false
end

local function QueueTransfers(sourceConfig, targetConfig, isMatchMode)
    local itemsToMove = {}

    if sourceConfig.type == "guild" then
        local tab = sourceConfig.tab
        for slot = 1, 98 do
            local link = GetGuildBankItemLink(tab, slot)
            local itemID = GetItemIDFromLink(link)
            if itemID then
                local foundMatch = false
                if isMatchMode then
                    if targetConfig.type == "bag" then
                        foundMatch = CheckItemInBags(itemID, targetConfig.bags)
                    end
                end

                if not isMatchMode or foundMatch then
                    table.insert(TBH_GlobalState.queue, { type = "guild", tab = tab, slot = slot })
                end
            end
        end
    elseif sourceConfig.type == "bag" then
        for _, bag in ipairs(sourceConfig.bags) do
            for slot = 1, GetContainerNumSlots(bag) do
                local link = GetContainerItemLink(bag, slot)
                local itemID = GetItemIDFromLink(link)
                if itemID then
                    local foundMatch = false
                    if isMatchMode then
                        if targetConfig.type == "guild" then
                            foundMatch = CheckItemInGuildBank(itemID, targetConfig.tab)
                        elseif targetConfig.type == "bag" then
                            foundMatch = CheckItemInBags(itemID, targetConfig.bags)
                        end
                    end

                    if not isMatchMode or foundMatch then
                        table.insert(TBH_GlobalState.queue, { type = "bag", bag = bag, slot = slot })
                    end
                end
            end
        end
    end

    if #TBH_GlobalState.queue > 0 then
        print("|cFFFFFF00[TBH] Queueing " .. #TBH_GlobalState.queue .. " transfers...|r")
        TBH_GlobalState.isTransferring = true
    else
        print("|cFFFF0000[TBH] Nothing to transfer!|r")
    end
end

function TBH_TransferLogic.Execute(sourceFrameID, isMatchMode)
    if TBH_GlobalState.isTransferring then
        print("|cFFFF0000[TBH] Already transferring! Please wait.|r")
        return
    end

    local oppositeID = TBH_TransferLogic.GetOpposingFrame(sourceFrameID)
    if not oppositeID then
        print("|cFFFF0000[TBH] Open another container (like Guild Bank or Bank) to transfer.|r")
        return
    end

    local inventoryBags = { 0, 1, 2, 3, 4 }
    local bankBags = { -1, 5, 6, 7, 8, 9, 10, 11 }

    local targetConfig = {}
    local sourceConfig = {}

    local function populateConfig(config, frameID)
        local fid = frameID and tostring(frameID):lower() or ""
        if fid == "inventory" then
            config.type = "bag"
            config.bags = inventoryBags
        elseif fid == "bank" then
            config.type = "bag"
            config.bags = bankBags
        elseif fid:find("guild") then
            config.type = "guild"
            config.tab = GetCurrentGuildBankTab()
        end
    end

    populateConfig(targetConfig, sourceFrameID)
    populateConfig(sourceConfig, oppositeID)

    if sourceConfig.type == "guild" and not sourceConfig.tab then
        print("|cFFFF0000[TBH] Valid Guild Bank tab not selected.|r")
        return
    end

    QueueTransfers(sourceConfig, targetConfig, isMatchMode)
end

function TBH_TransferLogic.ExecuteMatch(sourceFrameID)
    TBH_TransferLogic.Execute(sourceFrameID, true)
end

function TBH_TransferLogic.ExecuteMass(sourceFrameID)
    TBH_TransferLogic.Execute(sourceFrameID, false)
end

TBH_GlobalState = {
    isTransferring = false,
    queue = {}
}

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, addonName)
    if addonName == "Thormrands_Bagnon_Hooks" then
        print("|cFF00FF00Thormrand's Bagnon Hooks loaded!|r")
    end
end)

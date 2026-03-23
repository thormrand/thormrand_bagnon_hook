TBH_GlobalState = {
    isTransferring = false,
    queue = {},
    debugEnabled = false
}

function TBH_GlobalState.DebugPrint(msg)
    if TBH_GlobalState.debugEnabled then
        print(msg)
    end
end

SLASH_TBH1 = "/tbh"
SlashCmdList["TBH"] = function(msg)
    local cmd = string.lower(strtrim(msg or ""))
    if cmd == "debug on" then
        TBH_GlobalState.debugEnabled = true
        print("|cFF00FF00[TBH] Debug mode enabled.|r")
    elseif cmd == "debug off" then
        TBH_GlobalState.debugEnabled = false
        print("|cFFFF0000[TBH] Debug mode disabled.|r")
    else
        print("|cFFFFFF00[TBH] Usage: /tbh debug on | off|r")
    end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, addonName)
    if addonName == "Thormrands_Bagnon_Hooks" then
        if not TBH_SavedSettings then TBH_SavedSettings = {} end

        StaticPopupDialogs["TBH_CONFIRM_MASS_TRANSFER"] = {
            text = "You are about to queue %s items for transfer.\nAre you sure you want to proceed?",
            button1 = "Proceed",
            button2 = "Cancel",
            OnAccept = function(self)
                if self.tbhCheckbox and self.tbhCheckbox:GetChecked() then
                    TBH_SavedSettings.SkipMassTransferWarning = true
                end
                print("|cFFFFFF00[TBH] Queueing " .. (self.data or 0) .. " filtered transfers...|r")
                TBH_GlobalState.isTransferring = true
            end,
            OnShow = function(self)
                if not self.tbhCheckbox then
                    local cb = CreateFrame("CheckButton", nil, self, "UICheckButtonTemplate")
                    cb:SetPoint("BOTTOM", self.button1, "TOP", 0, 8)
                    cb:SetSize(24, 24)
                    local lbl = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                    lbl:SetPoint("LEFT", cb, "RIGHT", 4, 1)
                    lbl:SetText("Do not ask again")
                    self.tbhCheckbox = cb
                end
                self.tbhCheckbox:SetChecked(false)
                self.tbhCheckbox:Show()
            end,
            OnHide = function(self)
                if self.tbhCheckbox then
                    self.tbhCheckbox:Hide()
                end
            end,
            timeout = 0,
            whileDead = true,
            hideOnEscape = true,
            preferredIndex = 3,
        }

        print("|cFF00FF00Thormrand's Bagnon Hooks loaded!|r")
    end
end)

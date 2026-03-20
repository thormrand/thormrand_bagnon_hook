-- UI Hooking Logic for Bagnon
-- Hooks into Bagnon.Frame:Layout() to add custom match/mass transfer buttons inside a side tab.

local Bagnon = LibStub('AceAddon-3.0'):GetAddon('Bagnon', true)
if not Bagnon then return end

local function TBH_CreateButton(parent, name, iconPath, tooltipText, onClickFunc)
    local btn = CreateFrame("Button", name, parent)
    btn:SetSize(32, 32)
    btn:SetNormalTexture(iconPath)
    btn:SetPushedTexture(iconPath)
    btn:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")

    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(tooltipText)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    btn:SetScript("OnClick", onClickFunc)

    return btn
end

local function TBH_OnFrameLayout(frame)
    if not frame.tbh_tabFrame then
        -- Create the side tab container
        local tab = CreateFrame("Frame", frame:GetName() .. "_TBHTab", frame)
        tab:SetSize(48, 88)

        -- Push the tab's draw layer beneath the main frame so it looks like it attaches from behind
        local parentLevel = frame:GetFrameLevel()
        tab:SetFrameLevel(parentLevel > 0 and parentLevel - 1 or 0)

        tab:SetBackdrop({
            bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 16,
            tile = true,
            tileSize = 16,
            insets = { left = 4, right = 4, top = 4, bottom = 4 }
        })

        -- Anchor it protruding from the bottom left
        tab:SetPoint("BOTTOMRIGHT", frame, "BOTTOMLEFT", 6, 20)
        frame.tbh_tabFrame = tab

        -- Create the buttons inside it (arranged vertically)
        frame.tbh_matchBtn = TBH_CreateButton(
            tab,
            frame:GetName() .. "_TBHMatch",
            "Interface\\AddOns\\Thormrands_Bagnon_Hooks\\single_arrow",
            "Transfer Matching Items",
            function(self) TBH_TransferLogic.ExecuteMatch(frame:GetFrameID()) end
        )
        frame.tbh_matchBtn:SetPoint("TOP", tab, "TOP", 0, -10)

        frame.tbh_massBtn = TBH_CreateButton(
            tab,
            frame:GetName() .. "_TBHMass",
            "Interface\\AddOns\\Thormrands_Bagnon_Hooks\\triple_arrow",
            "Transfer All Items",
            function(self) TBH_TransferLogic.ExecuteMass(frame:GetFrameID()) end
        )
        frame.tbh_massBtn:SetPoint("TOP", frame.tbh_matchBtn, "BOTTOM", 0, -4)
    end

    -- Dynamically update colors to match Bagnon's frame settings whenever Layout() is called
    local settings = frame:GetSettings()
    if settings and frame.tbh_tabFrame then
        local r, g, b, a = settings:GetColor()
        if r then frame.tbh_tabFrame:SetBackdropColor(r, g, b, a) end

        local br, bg, bb, ba = settings:GetBorderColor()
        if br then frame.tbh_tabFrame:SetBackdropBorderColor(br, bg, bb, ba) end
    end
end

-- Wait for Bagnon to be fully loaded before hooking
local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function()
    if Bagnon and Bagnon.Frame then
        hooksecurefunc(Bagnon.Frame, "Layout", TBH_OnFrameLayout)
    end
end)

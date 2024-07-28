--- Kaliel's Tracker
--- Copyright (c) 2012-2024, Marouan Sabbagh <mar.sabbagh@gmail.com>
--- All Rights Reserved.
---
--- This file is part of addon Kaliel's Tracker.

local addonName, KT = ...
local M = KT:NewModule(addonName.."_AddonOthers")
KT.AddonOthers = M

local MSQ = LibStub("Masque", true)
local _DBG = function(...) if _DBG then _DBG("KT", ...) end end

-- WoW API
local _G = _G

local db
local OTF = KT_ObjectiveTrackerFrame
local msqGroup1, msqGroup2

local KTwarning = "  |cff00ffffAddon "..KT.title.." is active.  "

--------------
-- Internal --
--------------

-- Masque
local function Masque_SetSupport()
    if M.isLoadedMasque then
        msqGroup1 = MSQ:Group(KT.title, "Quest Item Buttons")
        msqGroup2 = MSQ:Group(KT.title, "Quest Active Button")
        hooksecurefunc(msqGroup2, "__Enable", function(self)
            for button in pairs(self.Buttons) do
                if button.Style then
                    button.Style:SetAlpha(0)
                end
            end
        end)
        hooksecurefunc(msqGroup2, "__Disable", function(self)
            for button in pairs(self.Buttons) do
                if button.Style then
                    button.Style:SetAlpha(1)
                end
            end
        end)
    end
end

-- ElvUI
local function ElvUI_SetSupport()
    if KT:CheckAddOn("ElvUI", "v13.64", true) then
        local E = unpack(_G.ElvUI)
        local B = E:GetModule("Blizzard")
        B.SetObjectiveFrameHeight = function() end    -- preventive
        B.SetObjectiveFrameAutoHide = function() end  -- preventive
        B.HandleMawBuffsFrame = function() end        -- preventive
        B.MoveObjectiveFrame = function() end
        if E.private.skins.blizzard.objectiveTracker then
            StaticPopup_Show(addonName.."_ReloadUI", nil, "Activate changes for |cff00ffe3ElvUI|r.")
        end
        hooksecurefunc(E, "CheckIncompatible", function(self)
            self.private.skins.blizzard.objectiveTracker = false
        end)
        hooksecurefunc(E, "ToggleOptions", function(self)
            if E.Libs.AceConfigDialog.OpenFrames[self.name] then
                local options = self.Options.args.general.args.blizzUIImprovements
                options.args[addonName.."Warning"] = {
                    name = "\n"..KTwarning,
                    type = "description",
                    order = 2.99,
                }
            end
        end)
    end
end

-- Tukui
local function Tukui_SetSupport()
    if KT:CheckAddOn("Tukui", "20.41", true) then
        local T = unpack(_G.Tukui)
        T.Miscellaneous.ObjectiveTracker.Enable = function() end
    end
end

-- RealUI
local function RealUI_SetSupport()
    if KT:CheckAddOn("nibRealUI", "2.3.14", true) then
        local R = _G.RealUI
        local module = "Objectives Adv."
        if R:GetModuleEnabled(module) then
            R:SetModuleEnabled(module, false)
            StaticPopup_Show(addonName.."_ReloadUI", nil, "Activate changes for |cff00ffe3RealUI|r.")
        end
    end
end

--------------
-- External --
--------------

function M:OnInitialize()
    _DBG("|cffffff00Init|r - "..self:GetName(), true)
    db = KT.db.profile
    self.isLoadedMasque = (KT:CheckAddOn("Masque", "10.2.7") and db.addonMasque)

    if self.isLoadedMasque then
        KT:Alert_IncompatibleAddon("Masque", "10.0.1")
    end
end

function M:OnEnable()
    _DBG("|cff00ff00Enable|r - "..self:GetName(), true)
    Masque_SetSupport()
    ElvUI_SetSupport()
    Tukui_SetSupport()
    RealUI_SetSupport()
end

-- Masque
function KT:Masque_AddButton(button, group)
    if db.addonMasque and MSQ and msqGroup1 then
        if not group or group == 1 then
            group = msqGroup1
        elseif group == 2 then
            group = msqGroup2
        end
        group:AddButton(button)
        if button.Style then
            if not group.db.Disabled then
                button.Style:SetAlpha(0)
            end
        end
    end
end
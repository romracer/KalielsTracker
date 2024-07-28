--- Kaliel's Tracker
--- Copyright (c) 2012-2024, Marouan Sabbagh <mar.sabbagh@gmail.com>
--- All Rights Reserved.
---
--- This file is part of addon Kaliel's Tracker.

local addonName, KT = ...
local M = KT:NewModule(addonName.."_AddonTomTom")
KT.AddonTomTom = M

local ACD = LibStub("MSA-AceConfigDialog-3.0")
local _DBG = function(...) if _DBG then _DBG("KT", ...) end end

local db
local mediaPath = "Interface\\AddOns\\"..addonName.."\\Media\\"
local questWaypoints = {}
local superTrackedQuestID = 0

--------------
-- Internal --
--------------

local function SetupOptions()
	KT.options.args.tomtom = {
		name = "TomTom",
		type = "group",
		args = {
			tomtomDesc1 = {
				name = "TomTom support combined Blizzard's POI and TomTom's Arrow.\n\n"..
						"|cffff7f00Warning:|r Original \"TomTom > Quest Objectives\" options are ignored!\n\n\n"..
						"|TInterface\\WorldMap\\UI-QuestPoi-NumberIcons:32:32:-2:10:256:256:128:160:96:128|t+"..
						"|T"..mediaPath.."KT-TomTomTag:32:32:-8:10|t...   Active POI button of quest with TomTom Waypoint.",
				type = "description",
				order = 1,
			},
			tomtomArrival = {
				name = "Arrival distance",
				type = "range",
				min = 0,
				max = 150,
				step = 5,
				set = function(_, value)
					db.tomtomArrival = value
				end,
				order = 2,
			},
			tomtomAnnounce = {
				name = "Waypoint announcement",
				desc = "Show announcement when add/remove quest waypoint, inside the chat frame. When disable this option, you always see messages \"No data for quest waypoint\".",
				type = "toggle",
				width = 1.1,
				set = function()
					db.tomtomAnnounce = not db.tomtomAnnounce
				end,
				order = 3,
			},
		},
	}

	KT.optionsFrame.tomtom = ACD:AddToBlizOptions(addonName, "Addon - "..KT.options.args.tomtom.name, KT.title, "tomtom")

	-- Reverts the option to display Quest Objectives
	if not GetCVarBool("questPOI") then
		SetCVar("questPOI", 1)
	end
end

local function Announce(msg, force)
	if db.tomtomAnnounce or force then
		ChatFrame1:AddMessage("|cff33ff99"..KT.title..":|r "..msg)
	end
end

local function WorldQuestPOIGetIconInfo(mapAreaID, questID)
	local x, y
	local taskInfo = C_TaskQuest.GetQuestsForPlayerByMapID(mapAreaID)
	if taskInfo then
		for _, info  in ipairs(taskInfo) do
			if HaveQuestData(info.questId) then
				if info.questId == questID then
					x = info.x
					y = info.y
					break
				end
			end
		end
	end
	return x, y
end

local function SetWaypointTag(button, show)
	if show then
		if button.KTtomtom then
			button.KTtomtom:Show()
		else
			if button.Display then
				button.KTtomtom = button.Display:CreateTexture(nil, "OVERLAY")
				button.KTtomtom:SetTexture(mediaPath.."KT-TomTomTag")
				button.KTtomtom:SetPoint("CENTER")
			end
		end

		-- Set Waypoint Tag size, but not for WQ
		if button.KTtomtom and button.pinScale then
			local scale = button.KTtomtom:GetParent():GetPinScale()
			button.KTtomtom:SetSize(scale * 32, scale * 32)
		end
	else
		if button.KTtomtom then
			button.KTtomtom:Hide()
		end
	end
end

local function AddWaypoint(questID, isSilent)
	if C_QuestLog.IsQuestCalling(questID) then
		return false
	end

	local title, mapID
	local x, y, completed
	if QuestUtils_IsQuestWorldQuest(questID) then
		title = C_TaskQuest.GetQuestInfoByQuestID(questID)
		mapID = C_TaskQuest.GetQuestZoneID(questID)
		if mapID and KT.GetCurrentMapContinent().mapID == KT.GetMapContinent(mapID).mapID then
			x, y = WorldQuestPOIGetIconInfo(mapID, questID)
		end
	else
		title = C_QuestLog.GetTitleForQuestID(questID)
		mapID = GetQuestUiMapID(questID)
		if mapID ~= 0 and KT.GetCurrentMapContinent().mapID == KT.GetMapContinent(mapID).mapID then
			completed, x, y = QuestPOIGetIconInfo(questID)
		end
	end

	if not title then
		return false
	end

	if completed then
		title = "|TInterface\\GossipFrame\\ActiveQuestIcon:0:0:0:0|t"..title
	else
		title = "|TInterface\\GossipFrame\\AvailableQuestIcon:0:0:0:0|t"..title
	end

	if mapID == 0 or not x or not y then
		if not isSilent then
			Announce("|cffff0000No data for quest waypoint|r ..."..title, true)
		end
		return false
	end

	local uid = TomTom:AddWaypoint(mapID, x, y, {
		title = title,
		silent = true,
		world = false,
		minimap = false,
		crazy = true,
		persistent = false,
		arrivaldistance = db.tomtomArrival,
	})
	uid["questID"] = questID
	questWaypoints[questID] = uid

	if not isSilent then
		Announce("Added a quest waypoint ..."..title)
	end

	return true
end

local function RemoveWaypoint(questID)
	local uid = questWaypoints[questID]
	if uid then
		TomTom:RemoveWaypoint(uid)
	end
end

local function SetSuperTrackedQuestWaypoint(questID, force)
	if questID ~= superTrackedQuestID or force then
		RemoveWaypoint(superTrackedQuestID)
		if QuestUtils_IsQuestWatched(questID) or KT.activeTasks[questID] then
			if AddWaypoint(questID, force) then
				superTrackedQuestID = questID
			end
		end
	end
end

local function SetHooks()
	-- TomTom
	local bck_TomTom_EnableDisablePOIIntegration = TomTom.EnableDisablePOIIntegration
	function TomTom:EnableDisablePOIIntegration()
		TomTom.profile.poi.enable = false
		TomTom.profile.poi.modifier = "A"
		TomTom.profile.poi.setClosest = false
		TomTom.profile.poi.arrival = 0
		bck_TomTom_EnableDisablePOIIntegration(self)
	end

	hooksecurefunc(TomTom, "ClearWaypoint", function(self, uid)
		local questID = uid.questID
		if questWaypoints[questID] then
			questWaypoints[questID] = nil
			if not KT.stopUpdate then
				superTrackedQuestID = 0
			end
			KT_ObjectiveTracker_Update()
			QuestMapFrame_UpdateAll()
		end
	end)

	hooksecurefunc(TomTom, "SetCrazyArrow", function(self, uid, dist, title)
		if superTrackedQuestID > 0 then
			RemoveWaypoint(superTrackedQuestID)
		end
	end)

	-- Blizzard
	hooksecurefunc(C_SuperTrack, "SetSuperTrackedQuestID", function(questID)
		SetSuperTrackedQuestWaypoint(questID)
	end)

	hooksecurefunc(C_SuperTrack, "SetSuperTrackedContent", function(trackableType, trackableID)
		RemoveWaypoint(superTrackedQuestID)
	end)

	hooksecurefunc(C_QuestLog, "RemoveQuestWatch", function(questID)
		if not KT.stopUpdate then
			RemoveWaypoint(questID)
		end
	end)

	hooksecurefunc(C_QuestLog, "AbandonQuest", function()
		local questID = QuestMapFrame.DetailsFrame.questID or QuestLogPopupDetailFrame.questID or QuestMapFrame.questID
		RemoveWaypoint(questID)
	end)

	hooksecurefunc("KT_BonusObjectiveTracker_OnTaskCompleted", function(questID, xp, money)
		RemoveWaypoint(questID)
	end)

    hooksecurefunc(POIButtonMixin, "Reset", function(self)
		SetWaypointTag(self)  -- hide tag for non-quest POI buttons
	end)

	local bck_KT_WORLD_QUEST_TRACKER_MODULE_OnFreeBlock = KT_WORLD_QUEST_TRACKER_MODULE.OnFreeBlock
	function KT_WORLD_QUEST_TRACKER_MODULE:OnFreeBlock(block)
		SetWaypointTag(block.TrackedQuest)  -- hide tag for hard watched WQ
		bck_KT_WORLD_QUEST_TRACKER_MODULE_OnFreeBlock(self, block)
	end

	hooksecurefunc(POIButtonMixin, "UpdateButtonStyle", function(self)
		if self.questID then
			SetWaypointTag(self, questWaypoints[self.questID])
		end
	end)

	hooksecurefunc(QuestUtil, "SetupWorldQuestButton", function(button, info, inProgress, selected, isCriteria, isSpellTarget, isEffectivelyTracked)
		SetWaypointTag(button, questWaypoints[button.questID])
	end)

	hooksecurefunc(POIButtonMixin, "OnClick", function(self)
		-- Update when click on active POI
		KT_ObjectiveTracker_Update()
		QuestMapFrame_UpdateAll()
	end)

	hooksecurefunc("KT_WorldQuestPOIButton_OnClick", function(self)
		-- Update when click on active POI
		KT_ObjectiveTracker_Update(KT_OBJECTIVE_TRACKER_UPDATE_MODULE_WORLD_QUEST)
	end)
end

local function SetEvents()
	KT:RegEvent("QUEST_LOG_UPDATE", function(eventID)
		SetSuperTrackedQuestWaypoint(C_SuperTrack.GetSuperTrackedQuestID())
		KT:UnregEvent(eventID)
	end)

	KT:RegEvent("QUEST_WATCH_UPDATE", function(_, questID)
		if questID == C_SuperTrack.GetSuperTrackedQuestID() then
			C_Timer.After(0, function()
				SetSuperTrackedQuestWaypoint(questID, true)
			end)
		end
	end)
end

--------------
-- External --
--------------

function M:OnInitialize()
	_DBG("|cffffff00Init|r - "..self:GetName(), true)
	db = KT.db.profile
	self.isLoaded = (KT:CheckAddOn("TomTom", "v3.6.2-release") and db.addonTomTom)

	if self.isLoaded then
		KT:Alert_IncompatibleAddon("TomTom", "v3.6.0-release")
	end

	local defaults = KT:MergeTables({
		profile = {
			tomtomArrival = 20,
			tomtomAnnounce = true,
		}
	}, KT.db.defaults)
	KT.db:RegisterDefaults(defaults)
end

function M:OnEnable()
	_DBG("|cff00ff00Enable|r - "..self:GetName(), true)
	SetupOptions()
	SetEvents()
	SetHooks()
end
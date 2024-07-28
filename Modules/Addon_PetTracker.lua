--- Kaliel's Tracker
--- Copyright (c) 2012-2024, Marouan Sabbagh <mar.sabbagh@gmail.com>
--- All Rights Reserved.
---
--- This file is part of addon Kaliel's Tracker.

local addonName, KT = ...
local M = KT:NewModule(addonName.."_AddonPetTracker")
KT.AddonPetTracker = M

local LSM = LibStub("LibSharedMedia-3.0")
local _DBG = function(...) if _DBG then _DBG("KT", ...) end end

local db, dbChar
local OTF = KT_ObjectiveTrackerFrame
local PetTracker = PetTracker

local header, content
local filterButton

OBJECTIVE_TRACKER_UPDATE_MODULE_PETTRACKER = 0x1000000
OBJECTIVE_TRACKER_UPDATE_PETTRACKER = 0x2000000
PETTRACKER_TRACKER_MODULE = KT_ObjectiveTracker_GetModuleInfoTable("PETTRACKER_TRACKER_MODULE")

M.Texts = {
	TrackPets = GetSpellInfo(122026),
	CapturedPets = "Show Captured",
	DisplayCondition = "Display Condition",
	DisplayAlways = "Always",
	DisplayMissingRares = "Missing Rares",
	DisplayMissingPets = "Missing Pets"
}

--------------
-- Internal --
--------------

local function SetHooks_Init()
	if PetTracker then
		PetTracker.Objectives.OnEnable = function() end

		if not db.addonPetTracker then
			hooksecurefunc(PetTracker, "OnEnable", function(self)
				self.sets.zoneTracker = false
			end)

			PetTracker.Objectives.Update = function() end
		end
	end
end

local function SetHooks()
	hooksecurefunc("KT_ObjectiveTracker_Initialize", function(self)
		tinsert(self.MODULES, PETTRACKER_TRACKER_MODULE)
		tinsert(self.MODULES_UI_ORDER, PETTRACKER_TRACKER_MODULE)
	end)

	function PetTracker.Objectives:Update()  -- R
		if PetTracker.sets.zoneTracker then
			self:GetClass().Update(self)
		end
		self:SetShown(PetTracker.sets.zoneTracker and not self.Bar:IsMaximized())
		KT_ObjectiveTracker_Update(OBJECTIVE_TRACKER_UPDATE_PETTRACKER)
	end

	local bck_PetTracker_Pet_Display = PetTracker.Pet.Display
	function PetTracker.Pet:Display()
		if not KT.InCombatBlocked() then
			bck_PetTracker_Pet_Display(self)
		end
	end

	function PetTracker.Tracker:Update()  -- R
		self:Clear()
		self:AddSpecies()
	end

	function PetTracker.Tracker:AddSpecie(specie, quality, level)  -- R
		local source = specie:GetSourceIcon()
		if source then
			-- original code
			local name, icon = specie:GetInfo()
			local text = name .. (level > 0 and format(' (%s)', level) or '')
			local r,g,b = self:GetColor(quality):GetRGB()

			local line = self:Add(text, icon, source, r,g,b)
			line:SetScript('OnClick', function() specie:Display() end)
			-- added code
			line.Dash:SetText("")
			line.SubIcon:ClearAllPoints()
			line.SubIcon:SetPoint("TOPLEFT", 0, 0)
			line.Icon:ClearAllPoints()
			line.Icon:SetPoint("LEFT", line.SubIcon, "RIGHT", 5, 0)
			line.Text:SetWidth(self.Bar:GetWidth() - line.Icon:GetWidth() - line.SubIcon:GetWidth() - 10)
			line.Text:ClearAllPoints()
			line.Text:SetPoint("LEFT", line.Icon, "RIGHT", 5, 0)
			line.Text:SetFont(KT.font, db.fontSize, db.fontFlag)
			line.Text:SetShadowColor(0, 0, 0, db.fontShadow)
			line.Text:SetWordWrap(false)
		end
	end

	hooksecurefunc(PetTracker.ProgressBar, "SetProgress", function(self, progress)
		if not self.KTskinned or KT.forcedUpdate then
			for _, bar in ipairs(self.Bars) do
				bar:SetStatusBarTexture(LSM:Fetch("statusbar", db.progressBar))
			end
			self.KTskinned = true
		end
	end)
end

local function SetHooks_PetTracker_Journal()
	if not db.addonPetTracker and PetTracker then
		PetTrackerTrackToggle:Disable()
		PetTrackerTrackToggle.Text:SetTextColor(0.5, 0.5, 0.5)
		local infoFrame = CreateFrame("Frame", nil, PetJournal)
		infoFrame:SetSize(PetTrackerTrackToggle:GetWidth() + PetTrackerTrackToggle.Text:GetWidth(), PetTrackerTrackToggle:GetHeight())
		infoFrame:SetPoint("TOPLEFT", PetTrackerTrackToggle, 0, 0)
		infoFrame:SetFrameLevel(PetTrackerTrackToggle:GetFrameLevel() + 1)
		infoFrame:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT")
			GameTooltip:AddLine(M.Texts.TrackPets, 1, 1, 1)
			GameTooltip:AddLine("Support can be enabled inside addon "..KT.title, 1, 0, 0, true)
			GameTooltip:Show()
		end)
		infoFrame:SetScript("OnLeave", function(self)
			GameTooltip:Hide()
		end)
	else
		PetTrackerTrackToggle:HookScript("OnClick", function()
			if dbChar.collapsed and PetTracker.sets.zoneTracker then
				KT:MinimizeButton_OnClick(true)
			end
		end)
	end
end

local function Event_PLAYER_ENTERING_WORLD(eventID)
	KT:RegEvent("PET_JOURNAL_LIST_UPDATE", function()
		M:SetPetsHeaderText()
	end)
	KT:UnregEvent(eventID)
end

local function SetEvents_Init()
	if not C_AddOns.IsAddOnLoaded("PetTracker_Journal") then
		KT:RegEvent("ADDON_LOADED", function(eventID, addon)
			if addon == "PetTracker_Journal" then
				SetHooks_PetTracker_Journal()
				KT:UnregEvent(eventID)
			end
		end)
	else
		SetHooks_PetTracker_Journal()
	end
end

local function SetFrames()
	-- Header frame
	header = CreateFrame("Frame", nil, OTF.BlocksFrame, "ObjectiveTrackerHeaderTemplate")
	header:Hide()

	-- Content frame
	content = CreateFrame("Frame", nil, OTF.BlocksFrame)
	content:SetSize(232 - PETTRACKER_TRACKER_MODULE.blockOffset[PETTRACKER_TRACKER_MODULE.blockTemplate][1], 10)
	content:Hide()

	-- Objectives
	local objectives = PetTracker.Objectives
	objectives.MaxEntries = 100
	objectives.Header = header

	objectives:SetParent(content)
	objectives:Hide()

	-- Progress bar
	objectives.Bar:SetSize(content:GetWidth() - 4, 13)
	objectives.Bar:SetPoint("TOPLEFT", content, -8, -4)
	objectives.Bar.xOff = -2

	objectives.Bar.Overlay.BorderLeft:Hide()
	objectives.Bar.Overlay.BorderRight:Hide()
	objectives.Bar.Overlay.BorderCenter:Hide()

	local border1 = objectives.Bar:CreateTexture(nil, "BACKGROUND", nil, -2)
	border1:SetPoint("TOPLEFT", -1, 1)
	border1:SetPoint("BOTTOMRIGHT", 1, -1)
	border1:SetColorTexture(0, 0, 0)

	local border2 = objectives.Bar:CreateTexture(nil, "BACKGROUND", nil, -3)
	border2:SetPoint("TOPLEFT", -2, 2)
	border2:SetPoint("BOTTOMRIGHT", 2, -2)
	border2:SetColorTexture(0.4, 0.4, 0.4)

	objectives.Bar.Overlay.Text:SetPoint("CENTER", 0, 0.5)
	objectives.Bar.Overlay.Text:SetFont(LSM:Fetch("font", "Arial Narrow"), 13, "")
end

--------------
-- External --
--------------

function PETTRACKER_TRACKER_MODULE:GetBlock()
	local block = content
	block.module = self
	block.used = true
	block.height = 0
	block.lineWidth = KT_OBJECTIVE_TRACKER_TEXT_WIDTH - self.blockOffset[self.blockTemplate][1]
	block.currentLine = nil
	if block.lines then
		for _, line in ipairs(block.lines) do
			line.used = nil
		end
	else
		block.lines = {}
	end
	return block
end

function PETTRACKER_TRACKER_MODULE:MarkBlocksUnused()
	content.used = nil
end

function PETTRACKER_TRACKER_MODULE:FreeUnusedBlocks()
	if not content.used then
		content:Hide()
	end
end

function PETTRACKER_TRACKER_MODULE:Update()
	self:BeginLayout()
	if PetTracker.Objectives:IsShown() then
		local block = self:GetBlock()
		block.height = PetTracker.Objectives:GetHeight() - 41
		block:SetHeight(block.height)
		if KT_ObjectiveTracker_AddBlock(block) then
			block:Show()
			self:FreeUnusedLines(block)
		else
			block.used = nil
		end
	end
	self:EndLayout()
end

function M:OnInitialize()
	_DBG("|cffffff00Init|r - "..self:GetName(), true)
	db = KT.db.profile
	dbChar = KT.db.char
	self.isLoaded = (KT:CheckAddOn("PetTracker", "10.2.7") and db.addonPetTracker)

	if self.isLoaded then
		KT:Alert_IncompatibleAddon("PetTracker", "10.2.6")

		tinsert(KT.db.defaults.profile.modulesOrder, "PETTRACKER_TRACKER_MODULE")
		KT.db:RegisterDefaults(KT.db.defaults)
	end

	SetEvents_Init()
	SetHooks_Init()
end

function M:OnEnable()
	_DBG("|cff00ff00Enable|r - "..self:GetName(), true)
	SetFrames()
	SetHooks()

	PETTRACKER_TRACKER_MODULE.updateReasonModule = OBJECTIVE_TRACKER_UPDATE_MODULE_PETTRACKER
	PETTRACKER_TRACKER_MODULE.updateReasonEvents = OBJECTIVE_TRACKER_UPDATE_PETTRACKER
	PETTRACKER_TRACKER_MODULE:SetHeader(header, PETS)

	KT:RegEvent("PLAYER_ENTERING_WORLD", Event_PLAYER_ENTERING_WORLD)
end

function M:IsShown()
	return (self.isLoaded and
			(PetTracker.sets and PetTracker.sets.zoneTracker) and
			PetTracker.Objectives:IsShown())
end

function M:SetPetsHeaderText(reset)
	if self.isLoaded and db.hdrPetTrackerTitleAppend then
		local _, numPetsOwned = C_PetJournal.GetNumPets()
		KT:SetHeaderText(PETTRACKER_TRACKER_MODULE, numPetsOwned)
	elseif reset then
		KT:SetHeaderText(PETTRACKER_TRACKER_MODULE)
	end
end
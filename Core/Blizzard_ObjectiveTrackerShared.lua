-- *****************************************************************************************************
-- ***** ITEM FUNCTIONS
-- *****************************************************************************************************
local function OnRelease(framePool, frame)
	frame:Hide();
	frame:ClearAllPoints();
	frame:SetParent(nil);
end

local g_questObjectiveItemPool = CreateFramePool("BUTTON", nil, "KT_QuestObjectiveItemButtonTemplate", OnRelease);
function KT_QuestObjectiveItem_AcquireButton(parent)
	local itemButton = g_questObjectiveItemPool:Acquire();
	itemButton:SetParent(parent);

	return itemButton;
end

function KT_QuestObjectiveItem_ReleaseButton(button)
	g_questObjectiveItemPool:Release(button);
end

function KT_QuestObjectiveItem_Initialize(itemButton, questLogIndex)
	local link, item, charges, showItemWhenComplete = GetQuestLogSpecialItemInfo(questLogIndex);
	itemButton:SetID(questLogIndex);
	itemButton.charges = charges;
	itemButton.rangeTimer = -1;
	SetItemButtonTexture(itemButton, item);
	SetItemButtonCount(itemButton, charges);
	KT_QuestObjectiveItem_UpdateCooldown(itemButton);
end

function KT_QuestObjectiveItem_OnLoad(self)
	self:RegisterForClicks("AnyUp");
end

function KT_QuestObjectiveItem_OnEvent(self, event, ...)
	if ( event == "PLAYER_TARGET_CHANGED" ) then
		self.rangeTimer = -1;
	elseif ( event == "BAG_UPDATE_COOLDOWN" ) then
		KT_QuestObjectiveItem_UpdateCooldown(self);
	end
end

function KT_QuestObjectiveItem_OnUpdate(self, elapsed)
	-- Handle range indicator
	local rangeTimer = self.rangeTimer;
	if ( rangeTimer ) then
		rangeTimer = rangeTimer - elapsed;
		if ( rangeTimer <= 0 ) then
			local link, item, charges, showItemWhenComplete = GetQuestLogSpecialItemInfo(self:GetID());
			if ( not charges or charges ~= self.charges ) then
				KT_ObjectiveTracker_Update(KT_OBJECTIVE_TRACKER_UPDATE_MODULE_QUEST);
				return;
			end
			local count = self.HotKey;
			local valid = IsQuestLogSpecialItemInRange(self:GetID());
			if ( valid == 0 ) then
				count:Show();
				count:SetVertexColor(1.0, 0.1, 0.1);
			elseif ( valid == 1 ) then
				count:Show();
				count:SetVertexColor(0.6, 0.6, 0.6);
			else
				count:Hide();
			end
			rangeTimer = TOOLTIP_UPDATE_TIME;
		end

		self.rangeTimer = rangeTimer;
	end
end

function KT_QuestObjectiveItem_OnShow(self)
	self:RegisterEvent("PLAYER_TARGET_CHANGED");
	self:RegisterEvent("BAG_UPDATE_COOLDOWN");
end

function KT_QuestObjectiveItem_OnHide(self)
	self:UnregisterEvent("PLAYER_TARGET_CHANGED");
	self:UnregisterEvent("BAG_UPDATE_COOLDOWN");
end

function KT_QuestObjectiveItem_OnEnter(self)
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
	GameTooltip:SetQuestLogSpecialItem(self:GetID());
end

function KT_QuestObjectiveItem_OnClick(self, button)
	if ( IsModifiedClick("CHATLINK") and ChatEdit_GetActiveWindow() ) then
		local link, item, charges, showItemWhenComplete = GetQuestLogSpecialItemInfo(self:GetID());
		if ( link ) then
			ChatEdit_InsertLink(link);
		end
	else
		UseQuestLogSpecialItem(self:GetID());
	end
end

function KT_QuestObjectiveItem_UpdateCooldown(itemButton)
	local start, duration, enable = GetQuestLogSpecialItemCooldown(itemButton:GetID());
	if ( start ) then
		CooldownFrame_Set(itemButton.Cooldown, start, duration, enable);
		if ( duration > 0 and enable == 0 ) then
			SetItemButtonTextureVertexColor(itemButton, 0.4, 0.4, 0.4);
		else
			SetItemButtonTextureVertexColor(itemButton, 1, 1, 1);
		end
	end
end

local g_questFindGroupButtonPool = CreateFramePool("BUTTON", nil, "KT_QuestObjectiveFindGroupButtonTemplate", OnRelease);
function KT_QuestObjectiveFindGroup_AcquireButton(parent, questID)
	local button = g_questFindGroupButtonPool:Acquire();
	button:SetParent(parent);
	button.questID = questID;

	return button;
end

function KT_QuestObjectiveFindGroup_ReleaseButton(self)
	self.questID = nil;
	g_questFindGroupButtonPool:Release(self);
end

function KT_QuestObjectiveFindGroup_OnMouseDown(self)
	if self:IsEnabled() then
		self.Icon:SetPoint("CENTER", self, "CENTER", -2, -1);
	end
end

function KT_QuestObjectiveFindGroup_OnMouseUp(self)
	if self:IsEnabled() then
		self.Icon:SetPoint("CENTER", self, "CENTER", -1, 0);
	end
end

function KT_QuestObjectiveFindGroup_OnEnter(self)
	GameTooltip:SetOwner(self);
	GameTooltip:AddLine(TOOLTIP_TRACKER_FIND_GROUP_BUTTON, HIGHLIGHT_FONT_COLOR:GetRGB());

	GameTooltip:Show();
end

function KT_QuestObjectiveFindGroup_OnLeave(self)
	GameTooltip:Hide();
end

function KT_QuestObjectiveFindGroup_OnClick(self)
	local isFromGreenEyeButton = true;
	--We only want green eye button groups to display the create a group button if there are already groups there.
	LFGListUtil_FindQuestGroup(self.questID, isFromGreenEyeButton);
end

function KT_QuestObjectiveSetupBlockButton_AddRightButton(block, button, buttonOffsetsTag)
	if block.rightButton == button then
		-- TODO: Fix for real, some event causes the findGroup button to get added twice (could happen for any button)
		-- so it doesn't need to be reanchored another time
		return;
	end

	button:ClearAllPoints();

	if block.rightButton then
		button:SetPoint("RIGHT", block.rightButton, "LEFT", -KT_ObjectiveTracker_GetPaddingBetweenButtons(block), 0);
	else
		button:SetPoint("TOPRIGHT", block, KT_ObjectiveTracker_GetButtonOffsets(block, buttonOffsetsTag));
	end

	button:Show();

	block.rightButton = button;
	block.lineWidth = block.lineWidth - button:GetWidth() - KT_ObjectiveTracker_GetPaddingBetweenButtons(block);
end

function KT_QuestObjectiveSetupBlockButton_FindGroup(block, questID)
	-- Cache this off to avoid spurious calls to C_LFGList.CanCreateQuestGroup, for a given quest the result will not change until
	-- completed, and when completed this world quest should no longer be on the tracker.
	if block.hasGroupFinderButton == nil then
		block.hasGroupFinderButton = C_LFGList.CanCreateQuestGroup(questID);
	end

	if block.hasGroupFinderButton then
		local groupFinderButton = block.groupFinderButton;
		if not groupFinderButton then
			groupFinderButton = KT_QuestObjectiveFindGroup_AcquireButton(block, questID);
			block.groupFinderButton = groupFinderButton;
		end

		KT_QuestObjectiveSetupBlockButton_AddRightButton(block, groupFinderButton, "groupFinder");
	else
		KT_QuestObjectiveReleaseBlockButton_FindGroup(block);
	end

	return block.hasGroupFinderButton;
end

local g_scenarioFindGroupButtonPool = CreateFramePool("BUTTON", nil, "KT_ScenarioObjectiveFindGroupButtonTemplate", OnRelease);
function KT_ScenarioObjectiveFindGroup_ReleaseButton(self)
	self.scenarioID = nil;
	g_scenarioFindGroupButtonPool:Release(self);
end

function KT_ScenarioObjectiveFindGroup_OnMouseDown(self)
	if self:IsEnabled() then
		self.Icon:SetPoint("CENTER", self, "CENTER", -2, -1);
		self.Highlight:SetPoint("CENTER", self, "CENTER", -2, -1);
	end
end

function KT_ScenarioObjectiveFindGroup_OnMouseUp(self)
	if self:IsEnabled() then
		self.Icon:SetPoint("CENTER", self, "CENTER", -1, 0);
		self.Highlight:SetPoint("CENTER", self, "CENTER", -1, 0);
	end
end

function KT_ScenarioObjectiveFindGroup_OnEnter(self)
	GameTooltip:SetOwner(self);
	GameTooltip:AddLine(TOOLTIP_TRACKER_FIND_GROUP_BUTTON, HIGHLIGHT_FONT_COLOR:GetRGB());

	GameTooltip:Show();
end

function KT_ScenarioObjectiveFindGroup_OnLeave(self)
	GameTooltip:Hide();
end

function KT_ScenarioObjectiveFindGroup_OnClick(self)
	local shouldShowCreateGroupButton = true;
	LFGListUtil_FindScenarioGroup(self.scenarioID, shouldShowCreateGroupButton);
end

function KT_ScenarioObjectiveReleaseBlockButton_FindGroup(block)
	block.hasGroupFinderButton = nil;

	if block.groupFinderButton then
		KT_ScenarioObjectiveFindGroup_ReleaseButton(block.groupFinderButton);
		block.groupFinderButton = nil;
	end
end

function KT_ScenarioObjectiveSetupBlockButton_FindGroup(block, scenarioID)
	if block.hasGroupFinderButton == nil then
		block.hasGroupFinderButton = C_LFGList.CanCreateScenarioGroup(scenarioID);
	end

	if block.hasGroupFinderButton then
		local groupFinderButton = block.groupFinderButton;
		if not groupFinderButton then
			groupFinderButton = g_scenarioFindGroupButtonPool:Acquire();
			groupFinderButton:SetParent(block);
			groupFinderButton.scenarioID = scenarioID;
			block.groupFinderButton = groupFinderButton;
		end

		groupFinderButton:SetPoint("TOPRIGHT", block, 30, 5);
		groupFinderButton:Show();
	else
		KT_ScenarioObjectiveReleaseBlockButton_FindGroup(block);
	end

	return block.hasGroupFinderButton;
end

function KT_QuestObjectiveReleaseBlockButton_FindGroup(block)
	block.hasGroupFinderButton = nil;

	if block.groupFinderButton then
		KT_QuestObjectiveFindGroup_ReleaseButton(block.groupFinderButton);
		block.groupFinderButton = nil;
	end
end

function KT_QuestObjectiveSetupBlockButton_Item(block, questLogIndex, isQuestComplete)
	local item, showItemWhenComplete, _;
	if questLogIndex then
		_, item, _, showItemWhenComplete = GetQuestLogSpecialItemInfo(questLogIndex);
	end

	local shouldShowItem = item and (not isQuestComplete or showItemWhenComplete);

	if shouldShowItem then
		local itemButton = block.itemButton;
		if not itemButton then
			itemButton = KT_QuestObjectiveItem_AcquireButton(block);
			block.itemButton = itemButton;
		end

		KT_QuestObjectiveItem_Initialize(itemButton, questLogIndex);
		KT_QuestObjectiveSetupBlockButton_AddRightButton(block, itemButton, "useItem");
	else
		KT_QuestObjectiveReleaseBlockButton_Item(block);
	end

	return shouldShowItem;
end

function KT_QuestObjectiveReleaseBlockButton_Item(block)
	if block.itemButton then
		KT_QuestObjectiveItem_ReleaseButton(block.itemButton);
		block.itemButton = nil;
	end
end

function KT_QuestObjective_SetupHeader(block, initialLineWidth)
	block.rightButton = nil;
	block.lineWidth = initialLineWidth or KT_OBJECTIVE_TRACKER_TEXT_WIDTH;
end

KT_BonusObjectiveRewardsFrameMixin = {};

function KT_BonusObjectiveRewardsFrameMixin:SetRewardData(data)
	self.storedData = data;
end

function KT_BonusObjectiveRewardsFrameMixin:OnAnimateRewardDone()
	local rewardsFrame = self;
	-- kill the data
	local oldPosIndex = self.storedData[rewardsFrame.id].posIndex;
	self.storedData[rewardsFrame.id] = nil;
	rewardsFrame.id = nil;

	self:OnAnimateNextReward(rewardsFrame.module, oldPosIndex);
end

--[[
	data = {
		posIndex,							-- position index of the block that awards frame is relevent to
		rewards[] = {
			count,							-- how much of the reward is being granted
			font,							-- font for the reward name
			label,							-- item name of the reward
			texture,						-- item icon
			overlay							-- overlay icon (can be nil)
		},

	}
]]--

function KT_BonusObjectiveRewardsFrameMixin:AnimateReward(block, data)
	self:AnimateRewardOnAnchor(block, data, block.id, block.module);
end

function KT_BonusObjectiveRewardsFrameMixin:AnimateRewardOnAnchor(anchor, data, id, trackerModule)
	local rewardsFrame = self;
	if ( not rewardsFrame.id ) then
		if ( not data ) then
			return;
		end
		if ( not self.storedData) then
			self.storedData = { };
		end
		self.storedData[id] = data;
		rewardsFrame.module = trackerModule;

		if ( self.HeaderText ) then
			self.Header:SetText(self.HeaderText);
		end

		rewardsFrame.id = id;
		rewardsFrame:SetParent(anchor);
		rewardsFrame:ClearAllPoints();
		rewardsFrame:SetPoint("TOPRIGHT", anchor, "TOPLEFT", 10, -4);
		rewardsFrame:Show();
		local numRewards = #data.rewards;
		local contentsHeight = 12 + numRewards * 36;
		rewardsFrame.Anim.RewardsBottomAnim:SetOffset(0, -contentsHeight);
		rewardsFrame.Anim.RewardsShadowAnim:SetScaleTo(0.8, contentsHeight / 16);
		rewardsFrame.Anim:Play();
		PlaySound(SOUNDKIT.UI_BONUS_EVENT_SYSTEM_VIGNETTES);
		-- configure reward frames
		for i = 1, numRewards do
			local rewardItem = rewardsFrame.Rewards[i];
			if ( not rewardItem ) then
				rewardItem = CreateFrame("FRAME", nil, rewardsFrame, "KT_BonusObjectiveTrackerRewardTemplate");
				rewardItem:SetPoint("TOPLEFT", rewardsFrame.Rewards[i-1], "BOTTOMLEFT", 0, -4);
			end
			local rewardData = data.rewards[i];
			if ( rewardData.count > 1 ) then
				rewardItem.Count:Show();
				rewardItem.Count:SetText(rewardData.count);
			else
				rewardItem.Count:Hide();
			end
			rewardItem.Label:SetFontObject(rewardData.font);
			rewardItem.Label:SetText(rewardData.label);
			rewardItem.ItemIcon:SetTexture(rewardData.texture);
			if ( rewardData.overlay ) then
				rewardItem.ItemOverlay:SetTexture(rewardData.overlay);
				rewardItem.ItemOverlay:Show();
			else
				rewardItem.ItemOverlay:Hide();
			end
			rewardItem:Show();
			if( rewardItem.Anim:IsPlaying() ) then
				rewardItem.Anim:Stop();
			end
			rewardItem.Anim:Play();
		end
		-- hide unused reward items
		for i = numRewards + 1, #rewardsFrame.Rewards do
			rewardsFrame.Rewards[i]:Hide();
		end
	end
end

function KT_BonusObjectiveRewardsFrameMixin:OnAnimateNextReward(trackerModule, oldPosIndex)
	local rewardsFrame = self;
	-- look for another reward to animate and fix positions
	local nextAnimBlock;
	for id, data in pairs(self.storedData) do
		local block = trackerModule:GetExistingBlock(id);
		-- make sure we're still showing this
		if ( block ) then
			nextAnimBlock = block;
			-- If we have position data and if the block that completed was ahead of this, bring it up
			if ( data.posIndex and oldPosIndex and data.posIndex > oldPosIndex ) then
				data.posIndex = data.posIndex - 1;
			end
		end
	end
	-- update tracker to remove dead bonus objective
	KT_ObjectiveTracker_Update(trackerModule.updateReasonModule);
	-- animate if we have something, otherwise clear it all
	if ( nextAnimBlock ) then
		self:AnimateReward(nextAnimBlock, self.storedData[nextAnimBlock.id]);
	else
		rewardsFrame:Hide();
		wipe(self.storedData);
	end
end

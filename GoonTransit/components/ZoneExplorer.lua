require "unicode"
require "table"
require "lib/lib_ChatLib"
require "lib/lib_Debug"
require "lib/lib_ItemCard"
require "lib/lib_QueueButton"
require "lib/lib_RowScroller"
require "lib/lib_Tooltip"
require "lib/lib_TextFormat"
require "lib/lib_WebCache"

require "./lib/lib_DropDownList"
require "./lib/lib_RowVerticalChoice"
require "./lib/lib_TableShow"

require "./lib/lib_GoonTransit"


-- Zone Explorer containers.
local TOOLTIP = nil;
local FRAME = Component.GetFrame("ZoneExplorer");

local ZONE = {
	TITLE = FRAME:GetChild("Title"),
	BODY = {
		FRAME = FRAME:GetChild("Body"),
		SCROLL = nil,
	},
	DETAILS = {
		FRAME = FRAME:GetChild("Details"),
		THUMBNAILS = nil,
		SCREENSHOT = nil,
		SCROLL = nil,
		TEXT = FRAME:GetChild("Details.text_group.text"),
		TEXTROW = nil,
		DIFFICULTY = nil,
		MATCHMAKING = FRAME:GetChild("Details.matchmaking"),

		LOOT = {
			GROUP = FRAME:GetChild("Details.loot"),
			CARDLIST = FRAME:GetChild("Details.loot.cards"),
			SLIDER = FRAME:GetChild("Details.loot.slider"),
			CARDS = {},
		},

		QUEUE = {
			GROUP = FRAME:GetChild("Details.queue"),
			BUTTON = nil,
		},

		TRAVEL = {
			GROUP = FRAME:GetChild("Details.travel");
			BUTTON = nil,
		},

		DAILY = {
			GROUP = FRAME:GetChild("Details.daily_completion"),
			ICON = FRAME:GetChild("Details.daily_completion.icon_grp"),
			LABEL = FRAME:GetChild("Details.daily_completion.label"),
		},
	},
	FOSTER = FRAME:GetChild("Foster"),
};


-- Matchmaking dropdown.
local MATCHMAKING_OPTIONS = {
	[1] = { label="Default Matchmaking", value=true },
	[2] = { label="Skip Matchmaking", value=true },
	[3] = { label="Force Matchmaking", value=false }
};

-- From Arcporter.lua
local COLOR_DAILY_AVAIL = "4477CC"
local COLOR_DAILY_COMPLETE = "55AA55"

-- Known difficulties.
local g_Difficulty = {
	INSTANCE_DIFFICULTY_NORMAL = "Normal",
	INSTANCE_DIFFICULTY_CHALLENGE = "Challenge",
	INSTANCE_DIFFICULTY_HARD = "Hardcore"
};

-- Constants.
local ZONEROW_TITLE_HEIGHT = 30;
local ZONEROW_ITEM_HEIGHT = 20;
local LOOT_CARD_SIZE = 32;

-- Zone listing.
local WebUrls = {};
local HostAssets = "";

local d_QueueRestrictions = {};
local g_SelectedItem = nil;
local g_SelectedZone = nil;


ZoneExplorer = {};


function ZoneExplorer.Init()
	WebUrls["zone_list"] = WebCache.MakeUrl("zone_list");
	HostAssets = System.GetOperatorSetting("ingame_host");
	WebCache.Subscribe(WebUrls["zone_list"], ZoneExplorer.OnZoneListResponse, false);

	-- Create our widgets.
	ZONE.DETAILS.THUMBNAILS = RowVerticalChoice.Create(ZONE.DETAILS.FRAME:GetChild("thumbnails"), 1);
	ZONE.DETAILS.SCREENSHOT = MultiArt.Create(ZONE.DETAILS.FRAME:GetChild("screenshot_group.screenshot"));
	ZONE.DETAILS.SCROLL = RowScroller.Create(ZONE.DETAILS.FRAME:GetChild("scroll_group.scroll"));
	ZONE.DETAILS.TEXTROW = ZONE.DETAILS.SCROLL:AddRow(ZONE.DETAILS.TEXT);
	ZONE.DETAILS.DIFFICULTY = DropDownList.Create(ZONE.DETAILS.FRAME:GetChild("difficulty.choice"));
	ZONE.DETAILS.QUEUE.BUTTON = QueueButton.Create(ZONE.DETAILS.QUEUE.GROUP);
	ZONE.DETAILS.TRAVEL.BUTTON = Component.CreateWidget('<Button dimensions="dock:fill;"></Button>', ZONE.DETAILS.TRAVEL.GROUP);
	ZONE.BODY.SCROLL = RowScroller.Create(ZONE.BODY.FRAME:GetChild("zones"));

	-- Allow the panel to be moved.
	MovablePanel.ConfigFrame({
		frame = FRAME,
		MOVABLE_PARENT = ZONE.TITLE:GetChild("MovableParent"),
	});

	-- Bind the close button.
	GT.Bind_Close(ZONE.TITLE, function() FRAME:Hide() end);

	-- Set up the zone scroller.
	ZONE.BODY.SCROLL:SetSlider(RowScroller.SLIDER_DEFAULT);
	ZONE.BODY.SCROLL:SetSliderMargin(24, 4);
	ZONE.BODY.SCROLL:UpdateSize();

	-- Set up the thumbnails.
	ZONE.DETAILS.THUMBNAILS:SetChoiceBounds(54, 98);
	ZONE.DETAILS.THUMBNAILS:BindOnSelect(function(args)
		if args.texture ~= nil then
			ZONE.DETAILS.SCREENSHOT:SetTexture(args.texture, args.region)
		else
			ZONE.DETAILS.SCREENSHOT:SetUrl(args);
		end
	end);

	-- Set up the zone text.
	ZONE.DETAILS.TEXTROW:SetWidget(ZONE.DETAILS.TEXT);

	-- Set up the travel button.
	ZONE.DETAILS.TRAVEL.BUTTON:SetFont("Demi_13");
	ZONE.DETAILS.TRAVEL.BUTTON:SetTextKey("TRAVEL");

	-- Hide the queue and travel buttons by default.
	ZONE.DETAILS.TRAVEL.GROUP:Show(false);
	ZONE.DETAILS.QUEUE.GROUP:Show(false);

	-- Matchmaking options.
	ZONE.DETAILS.MATCHMAKING:ClearItems();
	for i,v in pairs(MATCHMAKING_OPTIONS) do
		ZONE.DETAILS.MATCHMAKING:AddItem(v.label);
	end
	ZONE.DETAILS.MATCHMAKING:BindEvent("OnSelect", function()
		SetMatchmaking(MATCHMAKING_OPTIONS[1].value);
	end);

	-- Add the cancel queue button.
	local cancel_queue = ZONE.DETAILS.FRAME:GetChild("cancel_queue");
	cancel_queue:BindEvent("OnSubmit", function()
		System.PlaySound("confirm");
		OnCancelCommand(nil);
		ZONE.DETAILS.TRAVEL.BUTTON:Enable(true);
	end);

	-- Set up the difficulty drop down.
	ZONE.DETAILS.DIFFICULTY:SetTitle("Select difficulty");
	ZONE.DETAILS.DIFFICULTY:Disable(true);

	-- Set up the loot info.
	ZONE.DETAILS.LOOT.SLIDER:BindEvent("OnStateChanged", function() OnRewardsScroll() end);
	ZONE.DETAILS.LOOT.SLIDER:SetMinPercent(0);
	ZONE.DETAILS.LOOT.SLIDER:SetMaxPercent(1);
	-- ZONE.DETAILS.LOOT.CARD = ItemCard.Create(ZONE.DETAILS.LOOT.GROUP, 16);

	-- Tooltip.  It stays in the foster container until used.
	TOOLTIP = Component.CreateWidget("req_tooltip", ZONE.FOSTER);
	ZONE.DETAILS.QUEUE.GROUP:BindEvent("OnMouseLeave", function()
		Tooltip.Show(nil);
	end);
end

function ZoneExplorer.Open()
	UpdateQueueRestrictions();
	WebCache.QuickUpdate(WebUrls["zone_list"]);
	Component.SetInputMode("cursor");
	FRAME:ParamTo("alpha", 1, 0.1);
	System.PlaySound("panel_open");
end

function ZoneExplorer.Close()
	Component.SetInputMode("game");
	FRAME:ParamTo("alpha", 0, 0.1);
	FRAME:Hide(true, 0.1);
	System.PlaySound("panel_close");
end

function ZoneExplorer.OnZoneListResponse(resp, err)
	if resp == nil then return end

	local zones = {};

	-- Get information on all the zones.
	for i,v in ipairs(resp) do
		if zones[v.gametype] == nil then zones[v.gametype] = {} end;
		zones[v.gametype][v.description] = v;
	end

	-- Build the "travel" zones.
	if true then
		zones["-travel-"] = {};

		-- Grab all the world locations and the routes.
		local locations = Game.GetGlobeViewLocations();
		local routes = Game.ListRoutes();
		for k, locInfo in ipairs(locations) do
			local isValid = false;
			for k, zoneid in ipairs(routes) do
				if tonumber(zoneid) == tonumber(locInfo.zoneId) then
					isValid = true;
					break;
				end
			end

			local ReturnNonEmptyString = function(str, fallback)
				if str and str ~= "" then
					return str;
				else
					return fallback;
				end
			end

			-- We can reach this place from our zone.  Add it to the list.
			if isValid then
				Debug.Log("Adding zone " .. locInfo.name .. " to the travel list.");
				zones["-travel-"][locInfo.name] = {
					name = locInfo.name,
					displayed_desc = locInfo.desc,
					gametype = "travel",

					id = tonumber(locInfo.zoneId),
					zone_id = tonumber(locInfo.zoneId),

					min_players_per_team = 1,
					max_players_per_team = 1,
					min_level = locInfo.level_min,

					difficulty_levels = {},

					images = {
						thumbnail = ReturnNonEmptyString(locInfo.thumbnail[1], "/assets/zones/placeholder-tbn.png"),
						screenshot = {
							ReturnNonEmptyString(locInfo.screenshot[1], "/assets/zones/placeholder-ss.png"),
							ReturnNonEmptyString(locInfo.screenshot[2], "/assets/zones/placeholder-ss.png"),
							ReturnNonEmptyString(locInfo.screenshot[3], "/assets/zones/placeholder-ss.png"),
						}
					},
				};
			end
		end
	end

	-- Wipe out the previous listing.
	ZONE.BODY.SCROLL:Reset();
	g_SelectedItem = nil;
	g_SelectedZone = nil;
	local zl_zones = {};

	-- Re-sort the stupid table because fuck you Lua.
	local sorted_zones = {};
	for gametype,_ in pairs(zones) do
		table.insert(sorted_zones, gametype);
	end
	table.sort(sorted_zones, function(a, b) return a < b; end);

	-- Build the structure.
	for _,gametype in ipairs(sorted_zones) do
		local gametypezone = zones[gametype];

		-- Create the scroller row.
		local row = ZONE.BODY.SCROLL:AddRow();

		-- Create the zone title.
		local z = Component.CreateWidget("Zone", ZONE.BODY.FRAME);
		z:GetChild("title_section.title"):SetText(GT.trim7(gametype));
		row:SetWidget(z);

		-- Set the row height.
		row:UpdateSize({height=ZONEROW_TITLE_HEIGHT});

		-- Our row we are assembling.
		local zl_zone = {
			scroll = row,
			title = z:GetChild("title_section"),
			count = 0,
			entries = {}
		};

		-- Add the items to the list.
		for desc,zone in pairs(gametypezone) do
			local w = Component.CreateWidget("ZoneEntry", z:GetChild("zones"));
			local entry = w:GetChild("entry");
			local name = entry:GetChild("name");
			name:SetText(desc);
			w:SetDims("top:"..tostring(ZONEROW_ITEM_HEIGHT*zl_zone.count).."; height:"..ZONEROW_ITEM_HEIGHT..";");

			-- Insert our entry into our entries list.
			local e = { zone = zl_zone, zoneinfo = zone, desc = desc, entry = entry };
			table.insert(zl_zone.entries, e);
			zl_zone.count = zl_zone.count + 1;

			-- Bind events to this entry.
			entry:BindEvent("OnMouseEnter", function()
				if g_SelectedItem ~= entry then
					entry:GetChild("panel"):SetParam("alpha", "0.2");
				end
			end);
			entry:BindEvent("OnMouseLeave", function()
				if g_SelectedItem ~= entry then
					entry:GetChild("panel"):SetParam("alpha", "0.0");
				end
			end);
			entry:BindEvent("OnMouseDown", function()
				SelectEntry(e);
			end);
		end

		-- Add our zone entry.
		table.insert(zl_zones, zl_zone);

		-- Bind the open.
		z:GetChild("title_section"):BindEvent("OnMouseDown", function()
			ToggleTitle(zl_zone);
		end);

	end

	-- Open the first zone and select the first entry.
	if zl_zones[1] ~= nil and zl_zones[1].entries[1] ~= nil then
		ToggleTitle(zl_zones[1]);
		SelectEntry(zl_zones[1].entries[1]);
	end

	ZONE.BODY.SCROLL:UpdateSize();

end

function SelectEntry(entry)
	local zone = entry.zoneinfo;
	local desc = entry.desc;

	-- Play sound effect.
	System.PlaySound("select_item");

	-- Adjust coloring.
	if g_SelectedItem ~= nil then
		g_SelectedItem:GetChild("panel"):SetParam("alpha", "0.0");
	end
	g_SelectedItem = entry.entry;
	g_SelectedZone = entry.zone;
	g_SelectedItem:GetChild("panel"):SetParam("alpha", "0.4");

	-- Set name.
	ZONE.DETAILS.FRAME:GetChild("name"):SetText(desc);
	ZONE.DETAILS.FRAME:GetChild("zoneid"):SetText("id: "..zone.id);

	-- Set thumbnails.
	ZONE.DETAILS.THUMBNAILS:ClearChoices();
	if zone.images ~= nil then
		for i=1, 3 do
			local ss_url = HostAssets..zone.images.screenshot[i];
			ZONE.DETAILS.THUMBNAILS:AddChoice({url=ss_url}, ss_url);
		end
	else
		for i=1, 3 do
			local texture, region;
			if Component.CheckTextureExists(tostring(zone.zone_id)) then
				texture = tostring(zone.zone_id);
				region = "0"..tostring(i);
			else
				texture = "icons";
				region = "blank";
			end
			ZONE.DETAILS.THUMBNAILS:AddChoice({texture=texture, region=region}, {texture=texture, region=region});
		end
	end

	local has_difficulty = next(zone.difficulty_levels) ~= nil;

	-- Set the minimum level text.
	local level_min_group = ZONE.DETAILS.FRAME:GetChild("detail.level_min");
	local level_min = level_min_group:GetChild("label");
	if not has_difficulty and zone.min_level == nil then
		level_min_group:Hide();
	else
		level_min_group:Show();
		if (zone.min_level ~= nil) then
			UpdateMinLevel(level_min, zone.min_level);
		else
			UpdateMinLevel(level_min, 1);
		end
	end

	-- Set the group count text.
	local playercount_group = ZONE.DETAILS.FRAME:GetChild("detail.player_count");
	local playercount = playercount_group:GetChild("label");
	UpdateGroupSize(playercount, zone.min_players_per_team, zone.max_players_per_team);

	-- List the difficulties.
	local hardcore = false;
	local old_difficulty = ZONE.DETAILS.DIFFICULTY:GetSelected();
	ZONE.DETAILS.DIFFICULTY:ClearItems();
	ZONE.DETAILS.DIFFICULTY:Disable();
	if has_difficulty then
		ZONE.DETAILS.DIFFICULTY:Enable();
		for i,v in ipairs(zone.difficulty_levels) do
			local text = g_Difficulty[v.ui_string] or "Unknown";
			text = text.." ["..tostring(v.id).."]";
			ZONE.DETAILS.DIFFICULTY:AddItem(text, i);
		end
		if old_difficulty ~= nil and old_difficulty <= #ZONE.DETAILS.DIFFICULTY.List_Items then
			ZONE.DETAILS.DIFFICULTY:SetSelectedByValue(old_difficulty);
		else
			ZONE.DETAILS.DIFFICULTY:SetSelectedByValue(1);
		end

		-- Determine our selected difficulty.
		local difficulty_id = tonumber(ZONE.DETAILS.DIFFICULTY:GetSelected());
		if difficulty_id == nil then difficulty_id = 1; end

		-- Update information based on our difficulty.
		local d = zone.difficulty_levels[difficulty_id];
		UpdateMinLevel(level_min, d.min_level);
		UpdateDifficultyColor(d);

		-- Load loot based on our difficulty.
		LoadRewards(zone, d.difficulty_key);

		-- Test for hardcore.
		if d.difficulty_key == "HARD_MODE" then hardcore = true; end

		-- If we select the difficulty, update the zone information.
		ZONE.DETAILS.DIFFICULTY:BindOnSelect(function()
			local d = zone.difficulty_levels[tonumber(ZONE.DETAILS.DIFFICULTY:GetSelected())];
			if d ~= nil then
				-- Update the displayed min level.
				UpdateMinLevel(level_min, d.min_level);

				-- Tint the difficulty menu with our selected difficulty!
				UpdateDifficultyColor(d);

				-- Load loot based on our difficulty.
				LoadRewards(zone, d.difficulty_key);

				-- Set our matchmaking type.
				MATCHMAKING_OPTIONS[1].value = zone.skip_matchmaking;
				SetMatchmaking(zone.skip_matchmaking);

				-- Update the queue button with our selected difficulty.
				local queue = {};
				table.insert(queue, {id = d.zone_setting_id, difficulty = d.id});
				ZONE.DETAILS.QUEUE.BUTTON:SetSelectedQueues(queue);

				-- If we have daily completions, change the visibility.
				ZONE.DETAILS.DAILY.GROUP:Hide();
				if d.difficulty_key == "HARD_MODE" then
					ZONE.DETAILS.DAILY.GROUP:Show();
				end
			else
				LoadRewards(zone, nil);
			end
		end);
	else
		-- Clear our rewards.
		LoadRewards(zone, nil);
	end

	-- Check for hard mode daily completion certs.
	local certs = Game.GetCertIdsAssociatedWithZone(zone.zone_id);
	-- Debug.Log("zone certs: "..tostring(certs));
	local hasUnlock = false;
	for _, cert in ipairs(certs) do
		hasUnlock = hasUnlock or (Player.GetUnlockInfo("certificate", cert) ~= nil);
	end

	-- Update our labels for this zone.
	if hasUnlock then
		ZONE.DETAILS.DAILY.LABEL:SetTextKey("DAILY_COMPLETED_TODAY");
		ZONE.DETAILS.DAILY.LABEL:SetTextColor(COLOR_DAILY_COMPLETE);
		ZONE.DETAILS.DAILY.ICON:Show(true);
	else
		ZONE.DETAILS.DAILY.LABEL:SetTextKey("DAILY_COMPLETION_AVAIL");
		ZONE.DETAILS.DAILY.LABEL:SetTextColor(COLOR_DAILY_AVAIL);
		ZONE.DETAILS.DAILY.ICON:Show(false);
	end

	-- Finally, show our information.
	ZONE.DETAILS.DAILY.GROUP:Hide();
	if hardcore then
		ZONE.DETAILS.DAILY.GROUP:Show();
	end

	-- Set the flavor text.
	local t = Component.LookupText(zone.displayed_desc);
	if (unicode.len(t) == 0) then t = GT.trim7(zone.displayed_desc); end
	ZONE.DETAILS.TEXT:SetText(t);
	ZONE.DETAILS.TEXTROW:UpdateSize({height=ZONE.DETAILS.TEXT:GetTextDims().height});

	-- Determine if we are traveling, as that is initiated in a different fashion.
	local travel = zone.gametype == "travel";
	ZONE.DETAILS.TRAVEL.GROUP:Show(travel);
	ZONE.DETAILS.QUEUE.GROUP:Show(not travel);

	-- Update the queue buttons.
	if travel then
		ZONE.DETAILS.TRAVEL.BUTTON:BindEvent("OnSubmit", function()
			GT.Alert("Transfering to zone "..tostring(zone.zone_id)..".");
			local success = Game.RequestTransfer(zone.zone_id, 0);
			System.PlaySound("confirm");
			ZONE.DETAILS.TRAVEL.BUTTON:Enable(success);
		end);
	else
		if not has_difficulty then
			-- Old style.  Works for Arena PvP (missions that don't have a difficulty).
			ZONE.DETAILS.QUEUE.BUTTON:SetSelectedQueues(tonumber(zone.id));
		else
			local d = zone.difficulty_levels[tonumber(ZONE.DETAILS.DIFFICULTY:GetSelected())];

			-- New style.  For missions with a difficulty.
			local queue = {};
			table.insert(queue, {id = d.zone_setting_id, difficulty = d.id});
			ZONE.DETAILS.QUEUE.BUTTON:SetSelectedQueues(queue);
		end

		-- Set our matchmaking style.
		MATCHMAKING_OPTIONS[1].value = zone.skip_matchmaking;
		SetMatchmaking(zone.skip_matchmaking);

		-- Bind the tooltip that lists any reasons why we can't zone.
		ZONE.DETAILS.QUEUE.GROUP:BindEvent("OnMouseEnter", function()
			ShowReasonTooltip(zone, has_difficulty, zone.difficulty_levels[tonumber(ZONE.DETAILS.DIFFICULTY:GetSelected())]);
		end);
	end
end

function SetMatchmaking(zone_value)
	-- Set our matchmaking type.
	local skip_matchmaking = zone_value;
	local idx = select(2, ZONE.DETAILS.MATCHMAKING:GetSelected());
	if idx == 2 then
		skip_matchmaking = true;
	elseif idx == 3 then
		skip_matchmaking = false;
	end
	ZONE.DETAILS.QUEUE.BUTTON:SkipMatchmaking(skip_matchmaking);
	Debug.Log("Skip matchmaking: "..tostring(skip_matchmaking));
end

function ToggleTitle(entry)
	System.PlaySound("Play_UI_SlideNotification");

	local row = entry.scroll;
	local entries = entry.count;
	local h = row:GetSize();
	if h.height == ZONEROW_TITLE_HEIGHT then
		row:UpdateSize({height=ZONEROW_TITLE_HEIGHT+ZONEROW_ITEM_HEIGHT*entries}, 0.1);
	else
		row:UpdateSize({height=ZONEROW_TITLE_HEIGHT}, 0.1);
	end
end

function UpdateDifficultyColor(difficulty)
	if difficulty.difficulty_key == "HARD_MODE" then
		ZONE.DETAILS.DIFFICULTY:TintPlate("red", 0.25);
	elseif difficulty.difficulty_key == "CHALLENGE_MODE" then
		ZONE.DETAILS.DIFFICULTY:TintPlate("orange", 0.25);
	else
		ZONE.DETAILS.DIFFICULTY:TintPlate(DropDownList.DEFAULT_COLOR, 0.25);
	end
end

function UpdateMinLevel(widget, min_level)
	widget:SetText(Component.LookupText("MIN_LEVEL_X", min_level));
	widget:GetParent():SetDims("left:_; top:_; height:_; width:"..widget:GetTextDims().width+8);

	local group_min, names = GetGroupMinLevel(min_level);
	if group_min < min_level then
		widget:SetTextColor("red");
	else
		widget:SetTextColor("plate");
	end
end

function UpdateGroupSize(widget, min, max)
	if max == 1 then
		widget:SetText(Component.LookupText("ARCPORTER_SIZE_SOLO"));
	else
		widget:SetText(Component.LookupText("ARCPORTER_SIZE_GROUP", min, max));
	end
	widget:GetParent():SetDims("left:_; top:_; height:_; width:"..widget:GetTextDims().width+8);

	local size = GetGroupSize();
	if size < min or size > max then
		widget:SetTextColor("red");
	else
		widget:SetTextColor("plate");
	end
end

function UpdateQueueRestrictions()
	local AddQueueRestrictions = function(queueIds, name)
		for queue_id, difficulties in pairs(queueIds) do
			local queueRestriction = d_QueueRestrictions[tostring(queue_id)] or {};
			for _, difficultyId in ipairs(difficulties) do
				local restrictedDifficulty = queueRestriction[tostring(difficultyId)] or {names={}};
				table.insert(restrictedDifficulty.names, name);
				queueRestriction[tostring(difficultyId)] = restrictedDifficulty;
			end
			d_QueueRestrictions[tostring(queue_id)] = queueRestriction;
		end
	end

	d_QueueRestrictions = {};
	if IsPlayerInGroup() then
		local squadData = Squad.GetQueueRestrictions();
		local roster = Squad.GetRoster();
		local members = {};
		if roster and roster.members then
			for _,member in ipairs(roster.members) do
				members[tostring(member.chatId)] = member.name;
			end
		end
		for _, member in ipairs(squadData) do
			if member.restrictions then
				AddQueueRestrictions(member.restrictions, members[tostring(member.chatId)]);
			end
		end
	else
		local oldData, playerData = Player.GetQueueRestrictions();
		if playerData then
			AddQueueRestrictions(playerData, g_PlayerName);
		end
	end
end

function OnSquadQueueEligibility(args)
	UpdateQueueRestrictions();
	ZONE.DETAILS.QUEUE.BUTTON:OnEvent(args);
end

function OnMatchQueueResponse(args)
	ZONE.DETAILS.QUEUE.BUTTON:OnEvent(args);
end

function OnMatchQueueUpdate(args)
	ZONE.DETAILS.QUEUE.BUTTON:OnEvent(args);
end

function OnEnterZone()
	OnZEClose();
	ZONE.DETAILS.TRAVEL.BUTTON:Enable(true);
end

-- Yanked from Arcporter.
function IsPlayerInGroup()
	return Squad.IsInSquad() or Platoon.IsInPlatoon()
end

function IsPlayerGroupLeader()
	local squad = Squad.GetRoster()
	if not squad then
		return true
	end
	return squad.is_mine
end

function GetGroupSize()
	if IsPlayerInGroup() then
		return #Squad.GetRoster().members
	end
	return 1
end

function GetGroupMinLevel(target)
	local names = {}
	if IsPlayerInGroup() then
		local roster = Squad.GetRoster()
		local min_level = 9999
		for _, member in ipairs(roster.members) do
			min_level = math.min(min_level, member.level)
			if member.level < target then
				table.insert(names, member.name)
			end
		end
		return min_level, names
	else
		if Player.GetLevel() < target then
			local playername = Player.GetInfo();
			table.insert(names, playername)
		end
		return Player.GetLevel(), names
	end
end

function IsGroupValidSize(min, max)
	if IsPlayerInGroup() then
		local size = GetGroupSize()
		return ( min <= size and max >= size )
	else
		return min <= 1
	end
end

function GetPlayersNotInZone()
	local players = {};

	if not IsPlayerInGroup() then
		return players;
	end

	local leader = Squad.IsInSquad() and Squad.GetLeader() or Platoon.GetLeader();
	local roster = Squad.IsInSquad() and Squad.GetRoster().members or Platoon.GetRoster().members;
	local me = ChatLib.StripArmyTag(Player.GetInfo());

	-- Get the some entity ids.
	local leaderEntityId = nil;
	local myEntityId = nil;
	for _, member in pairs(roster) do
		if member.name == leader then
			leaderEntityId = member.entityId;
		end
		if member.name == me then
			myEntityId = member.entityId;
		end
	end

	-- Check if I am in the same instance as the leader.
	-- If not, just return my own name.
	local inLeaderInstance = IsPlayerGroupLeader() or Game.GetTargetInfo(leaderEntityId) ~= nil;
	if not inLeaderInstance then
		table.insert(players, me);
		return players;
	end

	-- We are in the same instance as the leader.  That means we can
	-- make judgements on the other members of the group.
	for _, member in pairs(roster) do
		local inInstance = Game.GetTargetInfo(member.entityId) ~= nil;
		if not inInstance then
			table.insert(players, member.name);
		end
	end

	return players;
end

function ShowReasonTooltip(zone, has_difficulty, difficulty)
	local width, height = 0;
	local vpadding, hpadding = 0;
	local dims;
	local has_reason = false;

	local tool_list = TOOLTIP:GetChild("reason_list");
	vpadding = tool_list:GetVPadding();
	hpadding = tool_list:GetHPadding();

	-- Group size requirements.
	local group_req = tool_list:GetChild("group_req");
	if not IsGroupValidSize(zone.min_players_per_team, zone.max_players_per_team) then
		has_reason = true;

		group_req:Show();
		local group_req_reason = group_req:GetChild("reason");
		group_req_reason:SetText(Component.LookupText("ARC_REQ_GROUP_SIZE", zone.min_players_per_team, zone.max_players_per_team));
		dims = group_req_reason:GetTextDims();
		group_req:SetDims("top:_; left:_; width:"..tostring(dims.width + hpadding).."; height:"..tostring(dims.height));
	else
		group_req:Hide();
	end

	-- Minimum level requirements.
	local level_req = tool_list:GetChild("level_req");
	local group_min, group_names = 0, {};
	if has_difficulty then
		group_min, group_names = GetGroupMinLevel(difficulty.min_level);
	end
	if has_difficulty and group_min < difficulty.min_level then
		has_reason = true;

		level_req:Show();
		local level_req_reason = level_req:GetChild("reason");
		level_req_reason:SetText(Component.LookupText("ARC_REQ_LEVEL", difficulty.min_level));
		dims = level_req_reason:GetTextDims();
		level_req_reason:SetDims("top:_; left:_; width:"..tostring(dims.width + hpadding).."; height:"..tostring(dims.height));

		local level_req_names = level_req:GetChild("names");
		if #group_names > 0 then
			level_req_names:Show();
			local TF = TextFormat.Create();
			TF:AppendColor(Component.LookupColor("squad"));
			TF:AppendText(group_names[1]);

			for i = 2, #group_names do
				if (i - 1) % 5 ~= 0 then
					TF:AppendText(" ");
				else
					TF:AppendText("\n");
				end
				TF:AppendText(group_names[i]);
			end

			TF:ApplyTo(level_req_names);

			dims = level_req_names:GetTextDims();
			level_req_names:SetDims("top:_; left:_; width:"..tostring(dims.width + hpadding).."; height:"..tostring(dims.height));

			dims = level_req:GetContentBounds();
			level_req:SetDims("top:_; left:_; width:"..tostring(dims.width).."; height:"..tostring(dims.height));
		else
			level_req_names:Hide();
		end
	else
		level_req:Hide();
	end

	-- Certification requirements.
	local cert_req = tool_list:GetChild("cert_req");
	if has_difficulty and d_QueueRestrictions[tostring(difficulty.zone_setting_id)] and d_QueueRestrictions[tostring(difficulty.zone_setting_id)][tostring(difficulty.id)] then
		has_reason = true;

		cert_req:Show();
		local cert_req_reason = cert_req:GetChild("reason");
		dims = cert_req_reason:GetTextDims();
		cert_req_reason:SetDims("top:_; left:_; width:"..tostring(dims.width + hpadding).."; height:"..tostring(dims.height));

		local cert_req_names = cert_req:GetChild("names");
		local names = d_QueueRestrictions[tostring(difficulty.zone_setting_id)][tostring(difficulty.id)].names;
		if #names > 0 then
			cert_req_names:Show();
			local TF = TextFormat.Create();
			TF:AppendColor(Component.LookupColor("squad"));
			TF:AppendText(names[1]);

			for i = 2, #names do
				if (i - 1) % 5 ~= 0 then
					TF:AppendText(" ");
				else
					TF:AppendText("\n");
				end
				TF:AppendText(names[i]);
			end

			TF:ApplyTo(cert_req_names);

			dims = cert_req_names:GetTextDims();
			cert_req_names:SetDims("top:_; left:_; width:"..tostring(dims.width + hpadding).."; height:"..tostring(dims.height));

			dims = cert_req:GetContentBounds();
			cert_req:SetDims("top:_; left:_; width:"..tostring(dims.width).."; height:"..tostring(dims.height));
		else
			cert_req_names:Hide();
		end
	else
		cert_req:Hide();
	end

	-- Zone requirements.
	local zone_req = tool_list:GetChild("zone_req");
	if IsPlayerInGroup() then
		local names = GetPlayersNotInZone();
		if #names > 0 then
			has_reason = true;
			zone_req:Show();

			local zone_req_reason = zone_req:GetChild("reason");
			dims = zone_req_reason:GetTextDims();
			zone_req_reason:SetDims("top:_; left:_; width:"..tostring(dims.width + hpadding).."; height:"..tostring(dims.height));

			local TF = TextFormat.Create();
			TF:AppendColor(Component.LookupColor("squad"));
			TF:AppendText(names[1]);

			for i = 2, #names do
				if (i - 1) % 5 ~= 0 then
					TF:AppendText(" ");
				else
					TF:AppendText("\n");
				end
				TF:AppendText(names[i]);
			end

			local zone_req_names = zone_req:GetChild("names");
			TF:ApplyTo(zone_req_names);

			dims = zone_req_names:GetTextDims();
			zone_req_names:SetDims("top:_; left:_; width:"..tostring(dims.width + hpadding).."; height:"..tostring(dims.height));

			dims = zone_req:GetContentBounds();
			zone_req:SetDims("top:_; left:_; width:"..tostring(dims.width).."; height:"..tostring(dims.height));
		else
			zone_req:Hide();
		end
	else
		zone_req:Hide();
	end

	if has_reason then
		local bounds = tool_list:GetContentBounds();
		Tooltip.Show(TOOLTIP,{width=bounds.width+5, height=bounds.height+8});
	end
end

function LoadRewards(zone, difficulty)
	-- Destroy all the current cards.
	for _, CARD in ipairs(ZONE.DETAILS.LOOT.CARDS) do
		CARD:Destroy();
	end
	ZONE.DETAILS.LOOT.CARDS = {};
	ZONE.DETAILS.LOOT.GROUP:Show(false);

	-- Sanity check.
	if zone.reward_winner == nil or zone.reward_winner.loots == nil then
		return;
	end

	local showedCards = 0;

	-- Get our reward id.
	local reward_id = nil;
	for _, d in pairs(zone.reward_winner.loots) do
		if d.difficulty_key == difficulty then reward_id = d.loot_sdb_id; end
	end

	-- If we have a reward_id, create our cards.
	if reward_id then
		local reward_items = {};
		local lootInfo = Player.GetSalvageInfo(reward_id);

		-- Get guaranteed rewards.
		for i, reward in ipairs(lootInfo.guaranteed_rewards) do
			table.insert(reward_items, reward);
		end

		-- Get chance rewards.
		for i, reward in ipairs(lootInfo.chance_rewards) do
			table.insert(reward_items, reward);
		end

		-- Create the item cards for them now.
		for i, reward in ipairs(reward_items) do
			local CARD = ItemCard.Create(ZONE.DETAILS.LOOT.CARDLIST, LOOT_CARD_SIZE);
			table.insert(ZONE.DETAILS.LOOT.CARDS, CARD);

			showedCards = showedCards + 1;
			CARD:LoadItem(reward);
			CARD:Show(true);
			-- CARD.rarity = "legendary";
			-- CARD:SetRarity();
		end
	end

	-- Update the size of the slider.
	local max_cards = math.floor(ZONE.DETAILS.LOOT.CARDLIST:GetBounds().width / (LOOT_CARD_SIZE + 5));
	local thumbsize = 1;
	if showedCards ~= 0 then thumbsize = math.min(1, max_cards / showedCards); end
	ZONE.DETAILS.LOOT.SLIDER:Show(showedCards > max_cards);
	ZONE.DETAILS.LOOT.SLIDER:SetPercent(0);
	ZONE.DETAILS.LOOT.SLIDER:SetParam("thumbsize", thumbsize);
	OnRewardsScroll();

	ZONE.DETAILS.LOOT.GROUP:Show(showedCards ~= 0);
end

function OnRewardsScroll()
	local diff = math.max(0, #ZONE.DETAILS.LOOT.CARDS * LOOT_CARD_SIZE + (#ZONE.DETAILS.LOOT.CARDS - 1) * 5 - ZONE.DETAILS.LOOT.SLIDER:GetBounds().width);
	local scroll_amt = ZONE.DETAILS.LOOT.SLIDER:GetPercent() * diff;
	ZONE.DETAILS.LOOT.CARDLIST:MoveTo("width:_; left:"..-scroll_amt, 0.01);
end

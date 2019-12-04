--[[
Broken Teams

Programmed by Nalin
Thanks to cartographer for getting me started.

Version wip
- Fixed incompatibilities with version 1.6.

Version 1.5
- Custom keybind is more stable.  Worked around a Red 5 bug with the options menu.

Version 1.4
- Fixed up the Lua includes.
- The custom keybind won't get bound unless the Activation Method is set to "Custom Keybind".

Version 1.3
- Added interface options for disabling the addon or changing colors.
- Added custom keybind support.
- Added a player watchlist.  Use /wl to open it.

Version 1.2
- Dynamically updating layout adjusts to support all 10 teams.

Version 1.1
- Renamed Knives and Skulls to Team 4 and Team 5.
- Removed the Knives icon.

Version 1.0
- Initial release.

--]]


require "math";
require "unicode";
require "table";

require "lib/lib_AutoComplete"
require "lib/lib_Debug"
require "lib/lib_ChatLib"
require "lib/lib_Callback2"
require "lib/lib_InputIcon"
require "lib/lib_InterfaceOptions"
require "lib/lib_MovablePanel"
require "lib/lib_RowScroller"
require "lib/lib_Slash"
require "lib/lib_Tooltip"
require "lib/lib_UserKeybinds"
-- require "./lib/lib_TableShow"


-- Widget containers.
local FRAME = Component.GetFrame("Main");
local TITLE = Component.GetWidget("Title_Section");
local BODY = Component.GetWidget("Body_Section");
local BODY2 = Component.GetWidget("Body_Section2");
local OVERFLOW = Component.GetWidget("Overflow_Section");
local TEAMS = {};

-- Watchlist widget containers.
local WLFRAME = Component.GetFrame("Watchlist");
local WLTITLE = Component.GetWidget("WL_Title");
local WLBODY = Component.GetWidget("WL_Body");
local WLPLAYERS = Component.GetWidget("WL_Players");
local WLINPUT = Component.GetWidget("WL_Input");
local WLSCROLL = nil;
local WLAUTOCOMPLETE = nil;

-- Keybind widget containers.
local KBFRAME = Component.GetFrame("Keybind");
local KBBIND = KBFRAME:GetChild("bind");
local KBCATCH = KBFRAME:GetChild("KeyCatch");


-- Team information.
local g_TEAM_DATA = {
	[1] = { name = "Omnidyne-M", icon = "omnidyne" },
	[2] = { name = "Astrek", icon = "astrek" },
	[3] = { name = "Kisuton", icon = "kisuton" },
	[4] = { name = "Team 4", icon = "empty" },
	[5] = { name = "Team 5", icon = "empty" },
	[6] = { name = "Team 6", icon = "empty" },
	[7] = { name = "Team 7", icon = "empty" },
	[8] = { name = "Team 8", icon = "empty" },
	[9] = { name = "Team 9", icon = "empty" },
	[10] = { name = "Team 10", icon = "empty" },
	["Overflow"] = { name = "Custom Team Overflow", icon = "overflow" }
};


-- If condensed viewing is enabled.
local g_CONDENSED = false;

-- Update callback.
local g_UPDATE = nil;
local g_UPDATE_COUNT = 0;

-- Interface options.
local g_OPTIONS = {
	enabled = true,
	show_army = true,
	use_tab = true,
	custom_key = UserKeybinds.Create(),
	color_players = {tint = "#FFFFFF"},
	color_self = {tint = "#FFC040"},	-- "me"
	color_watchlist = {tint = "#990000"},
	color_squad = {tint = "#009900"},
};

-- Saved data.
local g_WATCHLIST_VER = 0;
local g_WATCHLIST = {};
local g_KEYBIND = {};

-- Valid zone.
local g_ZONEENABLED = false;

--
local g_SYSICON =
	[[<FocusBox dimensions="left:0; top:0; width:25; height:25;" class="ui_button">
		<Group name="attractHookBack" dimensions="dock:fill" />
		<StillArt name="Icon" dimensions="dock:fill" style="texture:UI_Error;"/>
		<Group name="attractHookFront" dimensions="dock:fill" />
	</FocusBox>]]


function OnComponentLoad()

	---------------------------------------------------------------------------
	-- Set up our interface options.
	--
	InterfaceOptions.SaveVersion(1);
	InterfaceOptions.SetCallbackFunc(OnOptionsChanged);

	InterfaceOptions.StartGroup({label="General"});
	InterfaceOptions.AddCheckBox({id="opt_enabled", label="Enabled", default=true});
	InterfaceOptions.AddCheckBox({id="opt_debug", label="Debug mode", tooltip="Enables some debugging messages in the console", default=false});
	InterfaceOptions.StopGroup();

	-- InterfaceOptions.StartGroup({label="Display"});
	-- InterfaceOptions.AddCheckBox({id="opt_army", label="Show army tags", default=true});
	-- InterfaceOptions.StopGroup();

	InterfaceOptions.StartGroup({label="Activation"});
	InterfaceOptions.AddChoiceMenu({id="opt_act", label="Activation method", tooltip="The method to view the team listing", default="opt_act_tab"});
	InterfaceOptions.AddChoiceEntry({menuId="opt_act", val="opt_act_tab", label="T.A.B. Scoreboard"});
	InterfaceOptions.AddChoiceEntry({menuId="opt_act", val="opt_act_custom", label="Custom keybind"});
	-- InterfaceOptions.AddTextInput({id="opt_keybind_btn", label="Custom keybind", default="K"});
	InterfaceOptions.AddButton({id="opt_keybind", label="Set custom keybind", tooltip="Click to view or set the custom keybind"});
	InterfaceOptions.StopGroup();

	InterfaceOptions.StartGroup({label="Vanity"});
	InterfaceOptions.AddColorPicker({id="opt_van_players", label="Player text color", tooltip="Color for players in the listing", default={tint="#FFFFFF"}});
	InterfaceOptions.AddColorPicker({id="opt_van_me", label="Self text color", tooltip="Color for your own entry in the listing", default={tint="#FFC040"}});
	InterfaceOptions.AddColorPicker({id="opt_van_watchlist", label="Watchlist text color", tooltip="Color for players on your watchlist", default={tint="#990000"}});
	InterfaceOptions.AddColorPicker({id="opt_van_squad", label="Squad backdrop color", tooltip="Backdrop color for players in squads", default={tint="#009900", alpha="0.3"}});
	InterfaceOptions.StopGroup();

	InterfaceOptions.StartGroup({label="Instructions"});
	InterfaceOptions.AddCheckBox({id="ins_bp", label="The team listing is only viewable while in Broken Peninsula."});
	InterfaceOptions.AddCheckBox({id="ins_tab", label="Hold the T.A.B. Scoreboard keybind to view (default TAB)."});
	InterfaceOptions.AddCheckBox({id="ins_wl", label="Use the /wl or /watchlist commands to open the Watchlist."});
	InterfaceOptions.StopGroup();

	-- Load our custom keybind.
	g_KEYBIND = Component.GetSetting("Keybind") or {keycode = 75};	-- 75 = K

	-- Set up our keybinding icon.
	g_OPTIONS.custom_key_vis = InputIcon.CreateVisual(KBBIND);
	if g_KEYBIND.keycode ~= nil then
		g_OPTIONS.custom_key_vis:SetBind(g_KEYBIND);
	end

	-- Register the keybind action.
	g_OPTIONS.custom_key:RegisterAction("bt_view", OnToggle, "toggle");
	-- g_OPTIONS.custom_key:BindKey("bt_view", g_KEYBIND.keycode);
	---------------------------------------------------------------------------

	---------------------------------------------------------------------------
	-- Set up the team listing.
	--
	-- Load our team information.
	local load_teams = { 1, 2, 3, "Overflow" };
	for _,i in ipairs(load_teams) do
		local v = g_TEAM_DATA[i];

		-- log("Creating team " .. i);
		local w = Component.GetWidget("Team" .. i);
		if (w ~= nil) then
			TEAMS[i] = w;

			-- Set our team number.
			-- If overflow team, adjust dimensions slightly.
			if (i ~= "Overflow") then
				if (i > 9) then TEAMS[i]:GetChild("name"):SetDims("left:67; top:_; width:_; height:_;"); end
				TEAMS[i]:GetChild("id"):SetText("[" .. i .. "]");
			else
				TEAMS[i]:GetChild("id"):SetText("[" .. (#g_TEAM_DATA + 1) .. "+]");
				TEAMS[i]:GetChild("name"):SetDims("left:74; top:_; width:_; height:_;");
			end

			-- Set the team name and icon.
			TEAMS[i]:GetChild("name"):SetText(v.name);
			if (v.icon ~= nil) then
				TEAMS[i]:GetChild("icon"):SetTexture(v.icon);
			end

			-- Set initial tint.
			TEAMS[i]:GetChild("icon"):SetParam("tint", "hostile");
		end
	end

	-- Hack to get the proper dims to show.
	-- For some reason it won't refresh unless this is called.
	FRAME:ParamTo("alpha", 0, 0);

	-- Adjust our layout.
	RecalculateTeamPositions();

	-- Set up our update callback.
	g_UPDATE = Callback2.CreateCycle(OnUpdate);

	-- Check if we support the zone.
	OnEnterZone();
	---------------------------------------------------------------------------

	---------------------------------------------------------------------------
	-- Set up the watchlist.
	--
	LIB_SLASH.BindCallback({slash_list = "wl, watch", description = "Show Broken Teams watchlist", func = OnWatchlistOpen});
	MovablePanel.ConfigFrame({
		frame = WLFRAME,
		MOVABLE_PARENT = Component.GetWidget("MovableParent"),
	});

	-- Allow close.
	local CLOSE_BUTTON = Component.GetWidget("close");
	local X = CLOSE_BUTTON:GetChild("X");
	CLOSE_BUTTON:BindEvent("OnMouseDown", OnWatchlistClose);
	CLOSE_BUTTON:BindEvent("OnMouseEnter", function()
		X:ParamTo("tint", Component.LookupColor("red"), 0.15);
		X:ParamTo("glow", "#30991111", 0.15);
	end);
	CLOSE_BUTTON:BindEvent("OnMouseLeave", function()
		X:ParamTo("tint", Component.LookupColor("white"), 0.15);
		X:ParamTo("glow", "#00000000", 0.15);
	end);

	-- Create scroll
	WLSCROLL = RowScroller.Create(WLPLAYERS);
	WLSCROLL:SetSlider(RowScroller.SLIDER_DEFAULT);
	WLSCROLL:SetSliderMargin(24, 4);
	WLSCROLL:UpdateSize();

	-- Create auto complete.
	WLAUTOCOMPLETE = AutoComplete.Create(WLINPUT, {OnClick=WLI_OnTabKey, max_entries=10, anchor_x="left:0", anchor_y="top:100%+2"});

	-- Load saved settings.
	g_WATCHLIST = Component.GetSetting("Watchlist") or {};
	LoadWatchlist();
	---------------------------------------------------------------------------

	--[[local sysENTRY = {GROUP = Component.CreateWidget(g_SYSICON, FRAME) };
	local sysICON = sysENTRY.GROUP:GetChild("Icon");
	sysENTRY.AHB = sysENTRY.GROUP:GetChild("attractHookBack");
	sysENTRY.AHF = sysENTRY.GROUP:GetChild("attractHookFront");

	sysICON:SetTexture("sysicon_watchlist");
	sysICON:SetParam("alpha", 0.75);
	sysENTRY.GROUP:BindEvent("OnMouseDown", function()
		OnWatchlistOpen();
	end);
	sysENTRY.GROUP:BindEvent("OnMouseEnter", function()
		sysICON:ParamTo("alpha", 1, 0.1);
		Tooltip.Show("Opens the Broken Teams watchlist", {delay=0.6});
	end)
	sysENTRY.GROUP:BindEvent("OnMouseLeave", function()
		sysICON:ParamTo("alpha", 0.75, 0.1);
		Tooltip.Show(nil);
	end)
	Component.FosterWidget(sysENTRY.GROUP, "SystemIcons:Main.{1}");]]
	--[[local test = Component.GetWidget("SystemIcons:List");
	test:SetDims("width:50;height_");]]
end

function OnOptionsChanged(id, value)
	if id == "opt_enabled" then
		g_OPTIONS.enabled = value;
		if value == false then OnClose() end
	elseif id == "opt_debug" then
		Debug.EnableLogging(value);
	elseif id == "opt_army" then
		g_OPTIONS.show_army = value;
	elseif id == "opt_act" then
		if (value == "opt_act_tab") then
			g_OPTIONS.use_tab = true;
			g_OPTIONS.custom_key:BindKey("bt_view", nil);
			Debug.Log("Unbinding custom keybind.");
		else
			g_OPTIONS.use_tab = false;
			g_OPTIONS.custom_key:BindKey("bt_view", nil);
			g_OPTIONS.custom_key:BindKey("bt_view", g_KEYBIND.keycode);
			Debug.Log("Binding key: "..tostring(g_KEYBIND.keycode));
		end
	elseif id == "opt_van_players" then
		g_OPTIONS.color_players = value;
	elseif id == "opt_van_me" then
		g_OPTIONS.color_self = value;
	elseif id == "opt_van_watchlist" then
		g_OPTIONS.color_watchlist = value;
	elseif id == "opt_van_squad" then
		g_OPTIONS.color_squad = value;
	--[[elseif id == "opt_keybind_btn" then
		Debug.Log("Setting custom key to "..value:upper());
		if pcall(g_OPTIONS.custom_key.BindKey, g_OPTIONS.custom_key, "bt_view", value:upper()) == false then
			Alert(value:upper().." is not a valid custom key.");
		end]]
	elseif id == "opt_keybind" then
		Debug.Log("Opening keybind frame.");

		-- Close the options window.  Since this is a button, it should be open.
		Component.GenerateEvent("MY_OPTIONS_TOGGLE");

		-- Open up the keybind frame and set it to listen for a key.
		Component.SetInputMode("cursor");
		KBFRAME:Show();
		KBFRAME:ParamTo("alpha", 1, 0.1);
		KBCATCH:ListenForKey();
	end
end

function Alert(msg)
	ChatLib.SystemMessage({ text="[Broken Teams] " .. msg });
end

-------------------------------------------------------------------------------
-- Team listing ---------------------------------------------------------------

function OnEnterZone()
	-- Only allow in PvP zones.
	local zone = Game.GetZoneInfo(Game.GetZoneId());
	Debug.Log("Zone is "..zone.zone_type);
	if (zone.zone_type ~= "OpenWorldPvP") then
		g_ZONEENABLED = false;
	else
		g_ZONEENABLED = true;
	end
end

function OnToggle()
	if not g_OPTIONS.enabled then return end
	if g_OPTIONS.use_tab then return end

	if not FRAME:IsVisible() then
		OnOpen();
	else
		OnClose();
	end
end

function OnTabToggle(args)
	if not g_OPTIONS.enabled then return end
	if not g_OPTIONS.use_tab then return end

	-- Make visible!
	if args.show then
		OnOpen();
	else
		OnClose();
	end
end

function OnOpen()
	if not g_ZONEENABLED then return end

	FRAME:Show();
	FRAME:ParamTo("alpha", 1, 0.1);
	EraseScoreboard();
	FillScoreboard();

	g_UPDATE_COUNT = 0;
	g_UPDATE:Run(1);
end

function OnClose()
	if not g_ZONEENABLED then return end

	FRAME:ParamTo("alpha", 0, 0.1);
	FRAME:Hide(true, 0.1);

	g_UPDATE:Stop();
end

function EraseScoreboard()
	for i,team in pairs(TEAMS) do
		if (type(team) ~= "function") then
			local players = team:GetChild("players");
			for i = players:GetChildCount(), 2, -1 do
				local w = players:GetChild(i);
				Component.RemoveWidget(w);
			end
		end
	end
end

function FillScoreboard()
	local scoreboard = Player.GetScoreBoard();
	local zonecount = 0;
	local found_teams = {};

	local myname = unicode.gsub(Player.GetInfo(), "^%[.+%]%s+", ""):lower();

	for _,team in pairs(scoreboard) do

		-- Grab the team id.
		local teamid = tonumber(team.teamId);
		found_teams[teamid] = true;
		if (teamid > #g_TEAM_DATA) then teamid = "Overflow" end

		-- Get our widgets.
		local t = TEAMS[teamid];
		if (t == nil) then
			t = AddTeam(teamid);
		end
		local players = t:GetChild("players");

		-- Set the team hostile.
		t:GetChild("icon"):SetParam("tint", "hostile");

		-- Record player counts.
		zonecount = zonecount + #team;
		local pcount = t:GetChild("count");
		if (#team == 1) then
			pcount:SetText("(1 player)");
		else
			pcount:SetText("(" .. #team .. " players)");
		end

		-- Create entries for each player.
		for i,player in ipairs(team) do
			local w = Component.CreateWidget("BPPlayerEntry", players);

			-- Position the player's name.
			SetPlayerPosition(teamid, w, players:GetChildCount() - 2);

			local backdrop = w:GetChild("backdrop");
			local icon = w:GetChild("icon");
			local name = w:GetChild("name");
			local squad = w:GetChild("squad");

			-- Set the player icon.  Use the player class type unless dead.
			if (player.state ~= "living") then
				icon:SetTexture("MapMarkers");
				icon:SetRegion("skull");
				icon:SetParam("tint", "con_skull");
			else
				icon:SetTexture("battleframes");
				icon:SetRegion(player.class);
				icon:SetParam("tint", "white");
			end

			-- If army tags are enabled, attempt to get the army tag from the chat system.
			-- Seems to only work with people on your buddy list.  Dangit R5.
			--[[
			if g_OPTIONS.show_army then
				local userinfo = Chat.GetUserInfo(player.name);
				if userinfo ~= nil then
					player.name = userinfo.player_name;
				end
			end
			--]]

			-- Set the player name.
			if (teamid == "Overflow") then
				name:SetText("[" .. tonumber(team.teamId) .. "] " .. player.name);
			else
				name:SetText(player.name);
			end

			-- Set the player color.
			if (player.name:lower() == myname) then
				name:SetTextColor(g_OPTIONS.color_self.tint);
			else
				local color = g_OPTIONS.color_players.tint;

				-- Get watchlist colors.
				if g_WATCHLIST ~= nil and g_WATCHLIST.players ~= nil then
					local p = g_WATCHLIST.players[player.name:lower()];
					-- if p ~= nil then color = p.tint; end
					if p ~= nil then color = g_OPTIONS.color_watchlist.tint; end
				end

				name:SetTextColor(color);
			end

			-- If the player is in a squad, show the backdrop.
			if (player.squaded) then
				backdrop:SetParam("tint", g_OPTIONS.color_squad.tint);
				backdrop:SetParam("alpha", g_OPTIONS.color_squad.alpha);
			end
		end
	end

	-- Remove any teams with 0 players.
	for i,v in pairs(TEAMS) do
		if (type(i) == "number") then
			if (found_teams[i] == nil) then
				RemoveTeam(i);
			end
		end
	end

	-- Set our zone count.
	TITLE:GetChild("zonecount"):SetText("(" .. zonecount .. " in zone)");

	-- Get our team id.
	local myteamid = tonumber(Player.GetTeamId());
	if (myteamid > #g_TEAM_DATA) then myteamid = "Overflow" end

	-- Set our team blue.
	local myteam = TEAMS[myteamid];
	if (myteam ~= nil) then
		myteam:GetChild("icon"):SetParam("tint", "friendly");
	end
end

function SetPlayerPosition(teamid, widget, position)
	-- Position the player's name.
	-- If we are in the overflow zone, adjust the left value.
	local position = position;
	if (position < 0) then position = 0 end
	if (teamid == "Overflow") then
		local pcnt = 20;
		widget:SetDims("top:".. (position % 5 * 20 + 4) .. "; left:" .. (math.floor(position / 5) * pcnt) .. "%; width:" .. pcnt .. "%; height:20;");
	else
		-- Condensed mode does two columns.
		local top = position * 20 + 4;
		local left = "0";
		local width = "100%";
		if (g_CONDENSED) then
			top = math.floor(position / 2) * 20 + 4;
			width = "50%";
			if (position % 2 == 1) then left = "50%" end
		end

		widget:SetDims("top:".. top .. "; left:".. left .. "; width:" .. width .. "; height:20;");
	end
end

-- Debug function.
function AddTestPlayers(teamid, pcount)
	for i = 1, pcount do
		-- Get our widgets.
		-- local teamid = "Overflow";
		local teamid = teamid;
		local t = TEAMS[teamid];
		if (t == nil) then
			t = AddTeam(teamid);
		end
		if (t == nil) then
			Alert("Could not add team " .. teamid);
			return
		end

		local players = t:GetChild("players");
		local w = Component.CreateWidget("BPPlayerEntry", players);

		-- Position the player's name.
		SetPlayerPosition(teamid, w, players:GetChildCount() - 2);

		local backdrop = w:GetChild("backdrop");
		local icon = w:GetChild("icon");
		local name = w:GetChild("name");
		local squad = w:GetChild("squad");

		-- Set the player icon.  Use the player class type unless dead.
		icon:SetTexture("battleframes");
		icon:SetRegion("berzerker");
		icon:SetParam("tint", "white");

		-- Set the player name.
		if (teamid == "Overflow") then
			name:SetText("[13] Desertdwellerx2");
		else
			name:SetText("Desertdwellerx2");
		end

		-- Set the player color.
		name:SetTextColor("white");
	end
end

function AddTeam(teamid)
	local tid = tonumber(teamid);

	-- If our team has already been created, abort.
	if (TEAMS[tid] ~= nil) then return TEAMS[tid] end

	-- Get our team data from the array.
	local v = g_TEAM_DATA[tid];
	if (v == nil) then return nil end

	-- Create the widget!
	local w = Component.CreateWidget("BPTeam", BODY, "Team" .. tid);

	-- Set our team number.
	w:GetChild("id"):SetText("[" .. tid .. "]");

	-- Set the team name and icon.
	w:GetChild("name"):SetText(v.name);
	if (v.icon ~= nil) then
		w:GetChild("icon"):SetTexture(v.icon);
	end

	-- Set initial tint.
	w:GetChild("icon"):SetParam("tint", "hostile");

	-- Add our team to the list.
	-- Alert("Adding team " .. tid);
	TEAMS[tid] = w;

	-- Recalculate team positions.
	RecalculateTeamPositions();

	return w;
end

function RemoveTeam(teamid)
	if (teamid < 4) then return end
	if (TEAMS[teamid] == nil) then return end

	-- Alert("Removing team " .. teamid);
	Component.RemoveWidget(TEAMS[teamid]);
	TEAMS[teamid] = nil;

	-- Recalculate team positions.
	RecalculateTeamPositions();
end

function RecalculateTeamPositions()
	local tcount = TEAMS.count();

	-- Determine if we need to be in condensed mode.
	if (tcount > 5) then
		g_CONDENSED = true;
	else
		g_CONDENSED = false;
	end

	-- Calculate body height.
	if (g_CONDENSED == true) then
		BODY:SetDims("left:_; width:_; top:_; height:250");
		BODY2:SetDims("left:_; width:_; top:_; height:250");
		BODY2:Show();
	else
		BODY:SetDims("left:_; width:_; top:_; height:450");
		BODY2:Hide();
	end

	-- Calculate the width of the team entries.
	local width = 33.33;
	local columns = 3;
	if (g_CONDENSED == false) then
		if (tcount == 4) then width = 25; columns = 4; end
		if (tcount >= 5) then width = 20; columns = 5; end
	else
		if (tcount == 7 or tcount == 8) then width = 25; columns = 4; end
		if (tcount == 9 or tcount >= 10) then width = 20; columns = 5; end
	end

	-- Resize the teams.
	local tid = 0;
	for i,team in pairs(TEAMS) do
		if (type(i) == "number") then
			-- Resize the team.
			TEAMS[i]:SetDims("top:_; left:" .. (tid * width) .. "%; width:" .. width .. "%; height:_;");

			-- Resize and re-align the players.
			local players = team:GetChild("players");
			local pcount = players:GetChildCount();
			for j = 2, pcount do
				local w = players:GetChild(j);
				SetPlayerPosition(i, w, j - 2);
			end

			-- Increment column count.
			tid = tid + 1;
			if (tid > columns - 1) then tid = 0 end
		end
	end

	-- Re-foster the teams.
	if (g_CONDENSED == false) then
		for i,team in pairs(TEAMS) do
			if (type(i) == "number") then
				Component.FosterWidget(TEAMS[i], BODY);
			end
		end
	else
		-- Choose which of the two body sections to add ourself to.
		-- We want even top/bottom teams with the team number incrementing in rows.
		local half = math.floor((tcount / 2) + 0.5);
		local idx = 0;
		for i,t in pairs(TEAMS) do
			if (type(i) == "number") then
				idx = idx + 1;

				-- Never change the first 3 teams.
				if (idx > 3) then
					if (idx > half) then
						-- Alert("Fostering " .. i .. " to BODY2");
						Component.FosterWidget(TEAMS[i], BODY2);
					else
						-- Alert("Fostering " .. i .. " to BODY");
						Component.FosterWidget(TEAMS[i], BODY);
					end
				end
			end
		end
	end

	-- Re-align the overflow team.
	if (g_CONDENSED == true) then
		OVERFLOW:SetDims("left:_; width:_; top:550; height:_;");
	else
		OVERFLOW:SetDims("left:_; width:_; top:500; height:_;");
	end
end

function TEAMS.count()
	local size = 0;
	for i,_ in pairs(TEAMS) do
		if (type(i) == "number") then
			size = size + 1;
		end
	end
	return size;
end

function OnUpdate()
	EraseScoreboard();
	FillScoreboard();

	-- Debug
	--[[
	g_UPDATE_COUNT = g_UPDATE_COUNT + 1;
	-- if (g_UPDATE_COUNT >= 3) then AddTestPlayers("Overflow", 30); end
	-- if (g_UPDATE_COUNT >= 3) then AddTestPlayers(5, 15); end
	-- if (g_UPDATE_COUNT == 6) then AddTestPlayers(6, 10); end
	-- if (g_UPDATE_COUNT >= 9) then AddTestPlayers(7, 3);	end
	-- if (g_UPDATE_COUNT >= 12) then AddTestPlayers(8, 14); end
	RecalculateTeamPositions();
	--]]

end

-------------------------------------------------------------------------------
-- Keybinding -----------------------------------------------------------------

function OnKeyPress(args)
	local keyCode = args.widget:GetKeyCode();
	Debug.Log("Pressed key: " .. keyCode);

	-- Function to close the keypress window and re-open our options page.
	local close = function()
		Component.SetInputMode(nil);
		KBFRAME:ParamTo("alpha", 0, 0.1);
		KBFRAME:Hide(true, 0.1);
		Component.GenerateEvent("MY_OPTIONS_TOGGLE");
	end

	-- Check for escape.
	if keyCode == 27 then
		close();
		return
	end

	-- Store and adjust image.
	g_KEYBIND.keycode = keyCode;
	g_OPTIONS.custom_key_vis:SetBind(g_KEYBIND);
	Component.SaveSetting("Keybind", g_KEYBIND);

	-- Actually set the keybind.
	if not g_OPTIONS.use_tab then
		Debug.Log("Binding key: "..tostring(keyCode));
		g_OPTIONS.custom_key:BindKey("bt_view", nil);
		g_OPTIONS.custom_key:BindKey("bt_view", keyCode);
	end

	-- Slight delay so the user can see their choice.
	Callback2.FireAndForget(close, nil, 1.5);
end

-------------------------------------------------------------------------------
-- Watchlist ------------------------------------------------------------------

function OnWatchlistOpen()
	Component.SetInputMode("cursor");
	WLFRAME:Show();
	WLFRAME:ParamTo("alpha", 1, 0.1);
	WLINPUT:SetFocus();

	-- Clear the autocomplete.
	WLAUTOCOMPLETE:ClearEntries();

	-- Fill the autocomplete with players.
	local scoreboard = Player.GetScoreBoard();
	for _,team in pairs(scoreboard) do
		for i,player in ipairs(team) do
			-- Debug.Log("Adding "..player.name.." to autocomplete");
			WLAUTOCOMPLETE:AddEntries(player.name);
		end
	end
end

function OnWatchlistClose()
	Component.SetInputMode(nil);
	FRAME:ParamTo("alpha", 0, 0.1);
	FRAME:Hide(true, 0.1);
end

function LoadWatchlist()
	if g_WATCHLIST.version == nil then return end
	if g_WATCHLIST.players == nil then return end

	-- If our watchlist version doesn't match, a massive change occurred.
	-- Erase the watchlist.  Sorry.
	if g_WATCHLIST.version ~= g_WATCHLIST_VER then
		g_WATCHLIST = {};
		SaveWatchlist();
		return
	end

	Debug.Log("Loading the watchlist.");
	for _,player in pairs(g_WATCHLIST.players) do
		AddWatchlistPlayer(player.name);
	end
end

function SaveWatchlist()
	if g_WATCHLIST == nil then g_WATCHLIST = {}; end
	g_WATCHLIST.version = g_WATCHLIST_VER;
	Component.SaveSetting("Watchlist", g_WATCHLIST);
	Debug.Log("Saved the watchlist.");
end

function AddWatchlistPlayer(name)
	Debug.Log("Adding "..name.." to the watchlist.");

	-- I wish this worked.
	-- local userinfo = Chat.GetUserInfo(name);
	-- if userinfo ~= nil then
	-- 	Debug.Log("[userinfo success] player_name: "..userinfo.player_name..", unique_name: "..userinfo.unique_name..", player_id: "..tostring(userinfo.player_id));
	-- end

	-- Create our entry and set the name.
	local w = Component.CreateWidget("WLPlayerEntry", WLPLAYERS);
	local e = w:GetChild("entry");
	e:GetChild("name"):SetText(name);

	-- Update the scroller.
	local row = WLSCROLL:AddRow(w);
	row:UpdateSize({height=20});
	WLSCROLL:UpdateSize();

	-- Yay closures.
	local entry = {
		name = name,
		row = row
	};

	-- Give us a graphical effect when hovering over the remove button.
	-- Also do the actual remove thingy.
	local REMOVE = e:GetChild("remove");
	local MINUS = REMOVE:GetChild("icon");
	REMOVE:BindEvent("OnMouseDown", function() OnWatchlistRemove(entry); end);
	REMOVE:BindEvent("OnMouseEnter", function()
		MINUS:ParamTo("tint", "#FF0000", 0.15);
		MINUS:ParamTo("glow", "#30991111", 0.15);
	end);
	REMOVE:BindEvent("OnMouseLeave", function()
		MINUS:ParamTo("tint", "#333333", 0.15);
		MINUS:ParamTo("glow", "#00000000", 0.15);
	end);

	return w;
end

function OnWatchlistRemove(entry)
	Debug.Log("Removing "..entry.name.." from the watchlist.");
	entry.row:Remove();

	-- Save to the watchlist.
	if g_WATCHLIST.players == nil then g_WATCHLIST.players = {}; end
	g_WATCHLIST.players[entry.name:lower()] = nil;
	SaveWatchlist();
end

function OnWatchlistAdd()
	local name = WLINPUT:GetText();
	AddWatchlistPlayer(name);
	WLINPUT:SetText("");

	-- Save to the watchlist.
	if g_WATCHLIST.players == nil then g_WATCHLIST.players = {}; end
	g_WATCHLIST.players[name:lower()] = {
		name = name,
		tint = "#990000"
	};
	SaveWatchlist();
end

function WLI_OnSubmit()
	OnWatchlistAdd();
end

function WLI_OnLostFocus()
	WLAUTOCOMPLETE:Show(false);
end

function WLI_OnTabKey()
	if WLAUTOCOMPLETE:IsVisible() then
		match, search = WLAUTOCOMPLETE:GetMatch();
		if match then
			WLINPUT:SetText(match);
		end
	end
	WLINPUT:SetFocus(true);
end

function WLI_OnUpArrow()
	if WLAUTOCOMPLETE:IsVisible() then
		WLAUTOCOMPLETE:Previous();
	end
end

function WLI_OnDownArrow()
	if TO_AUTOCOMPLETE:IsVisible() then
		WLAUTOCOMPLETE:Next();
	end
end

function WLI_OnTextChange(args)
	local text = WLINPUT:GetText();
	if text == "" then
		WLAUTOCOMPLETE:Show(false);
	else
		WLAUTOCOMPLETE:FindMatches(text);
	end
end

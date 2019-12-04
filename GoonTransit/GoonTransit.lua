local changelog = [[
Goon Transit

Programmed by Nalin
Icons by JonusRockweller

Version 3.1
- Fixed a scrolling bug with the Zone Explorer zone loot list.
- Added the patch 1.7 zone icons to the Zone Explorer.
- Zone Explorer now also shows the Zone ID in the "id" field.
- Adjusted the size of the zone title in Zone Explorer to better fit long zone names.

Version 3.0
- Added interface sounds.
- Removed raids from the navwheel as they are currently removed from the game.
- The slash command and keybind to launch Zone Explorer now acts as a toggle.
- Added mission item rewards to the Zone Explorer.

Version 2.5
- Fixed the manual queueing commands /mqueue and /queue.
- Added a button to the Zone Explorer to cancel the queue.
- Added the ability to override the type of matchmaking in Zone Explorer.
- Added mission preview textures to Zone Explorer.

Version 2.4
- Fixed the ability to see which players are not in the leader's instance.
- The daily hardcore completion text now queries the proper certificates from the game.
- PvP matchmaking now works properly.

Version 2.3
- Fixed incompatibilities with Firefall 1.6.
- Added support for the new "Challenge" difficulty.
- Queue restrictions now show players not in your zone.

Version 2.2
- Fixed PTS bugs.

Version 2.1
- Viewing the changelog will close the options menu.
- Always skip matchmaking in the Zone Explorer.  It doesn't seem to work correctly.
- Fixed the Zone Explorer's broken colors on the PTS environment.

Version 2.0
- Fixed a sizing issue with the Zone Explorer launch requirements tooltip.
- Added daily hardcore completion information to the Zone Explorer.
- Added a debug mode option to cut back on console spam.
- Added the ability to see the changelog in-game.

Version 1.16
- Zone Explorer will properly skip matchmaking for instances that request that it do so.

Version 1.15
- Fixed the ID of the Travel zones in the Zone Explorer.

Version 1.14
- The Zone Explorer will auto-open the first entry whenever it is opened.

Version 1.13
- Fixed bugs with the Travel button in the Zone Explorer.

Version 1.12
- Added travel zones to the Zone Explorer.
- Fixed a bug with difficulty selection where it wasn't properly updating fields as you switched between zones.
- The difficulty dropdown is colored red when you pick a Hardcore difficulty.

Version 1.11
- Switched to unicode library.
- Added the zone id and difficulty ids to the Zone Explorer.
- Clicking an entry in the Zone Explorer will lock the background color, signifying that it has been "selected".
- Added custom keybind support for opening up the Arcporter menu and Zone Explorer.

Version 1.10
- Adjusted the Zone Explorer interface a bit, making it better and fixing bugs.

Version 1.9
- Fixed a bug where the queue tooltip in Zone Explorer wouldn't work on zones without difficulty levels.

Version 1.8
- Fixed a bug where Zone Explorer could queue on the wrong difficulty.

Version 1.7
- Zone Explorer shows min level and group counts for instances.
- Added difficulty dropdown to the Zone Explorer.
- Added requirements tooltip to the Zone Explorer queue button.
- Zone Explorer will close on zone changes.

Version 1.6
- Added the Zone Explorer.  Access via the navwheel or with /ze.
- Added a raw zone listing.  Access with /gtzl.

Version 1.5
- Support for queueing to a zone that doesn't have a difficulty.

Version 1.4
- Removed Warfront HC as it is identical to normal mode.
- Better compatibility with other addons that add themselves to the navwheel.

Version 1.3
- Added manual queueing feature.

Version 1.2
- Fixed a bug with starting raids.

Version 1.1
- Added nav wheel support.
- Added raid support.
]]

require "unicode"
require "table"
require "lib/lib_Debug"
require "lib/lib_InputIcon"
require "lib/lib_InterfaceOptions"
require "lib/lib_NavWheel"
require "lib/lib_RowScroller"
require "lib/lib_Slash"
require "lib/lib_UserKeybinds"
require "lib/lib_WebCache"

require "./lib/lib_GoonTransit"

require "./components/RawZone"
require "./components/ZoneExplorer"


-- Zone Explorer containers.
local ZONE = Component.GetFrame("ZoneExplorer");

-- Raw zone listing containers.
local RAWZONE = Component.GetFrame("RawZoneList");

-- -- Changelog containers.
local CHANGELOG_FRAME = Component.GetFrame("Changelog");
local CHANGELOG = {
	TITLE = CHANGELOG_FRAME:GetChild("title_section"),
	BODY = CHANGELOG_FRAME:GetChild("body_section"),
	SCROLL = nil,
};

-- Keybind widget containers.
local KBFRAME = Component.GetFrame("Keybind");
local KBBIND = KBFRAME:GetChild("bind");
local KBCATCH = KBFRAME:GetChild("KeyCatch");

-- NavWheel
local NAV = {};
local NAV_QUEUE = {
	[1] = 	{key="wf",		title="Warfront",		description="Warfront",				icon="warfront"},
	[2] = 	{key="bane",	title="Baneclaw",		description="Baneclaw",				icon="baneclaw"},
	[3] = 	{key="kana",	title="Kanaloa",		description="Kanaloa",				icon="kanaloa"},
	[4] = 	{key="kanahc",	title="Kanaloa HC",		description="Kanaloa Hardcore",		icon="kanaloa_hc"},
};


-- Raid queues.  Must be manually started.
local QUEUES = {
	wf		= { id = 2621, difficulty = 21 },
	bane	= { id = 2821, difficulty = 1821 },
	kana	= { id = 2721, difficulty = 2921 },
	kanahc	= { id = 2721, difficulty = 3021 }
};


-- Interface options.
local OPTIONS = {
	debug_mode = false,
	arcporter_usekeybind = false,
	arcporter_keybind = UserKeybinds.Create(),
	zoneexplorer_usekeybind = false,
	zoneexplorer_keybind = UserKeybinds.Create(),
};


-- Saved data.
local g_KEYBIND = {};


-- Variables.
local g_WebUrls = {};
local g_QUEUE_SEARCH = nil;
local g_QUEUE_DIFFICULTY = nil;


--Debug.EnableLogging(true);


-- Load!
function OnComponentLoad(args)

	InterfaceOptions.SaveVersion(1);
	InterfaceOptions.SetCallbackFunc(OnOptionsChanged);

	InterfaceOptions.StartGroup({label="General"});
	InterfaceOptions.AddCheckBox({id="opt_general_debug", label="Debug mode", default=false});
	InterfaceOptions.StopGroup();

	InterfaceOptions.StartGroup({label="Arcporter"});
	InterfaceOptions.AddCheckBox({id="opt_arcporter_usekeybind", label="Use Keybind", default=false});
	InterfaceOptions.AddButton({id="opt_arcporter_keybind", label="Set custom keybind", tooltip="Click to view or set the custom keybind"});
	InterfaceOptions.StopGroup();

	InterfaceOptions.StartGroup({label="Zone Explorer"});
	InterfaceOptions.AddCheckBox({id="opt_zoneexplorer_usekeybind", label="Use Keybind", default=false});
	InterfaceOptions.AddButton({id="opt_zoneexplorer_keybind", label="Set custom keybind", tooltip="Click to view or set the custom keybind"});
	InterfaceOptions.StopGroup();

	InterfaceOptions.StartGroup({label="Changelog"});
	InterfaceOptions.AddButton({id="opt_changelog_view", label="View", tooltip="View the changelog"});
	InterfaceOptions.StopGroup();

	-- Load our custom keybind.
	g_KEYBIND = Component.GetSetting("Keybind") or {arcporter = {keycode=0}, zoneexplorer = {keycode=0}};

	-- Set up our keybinding icon.
	OPTIONS.vis_keybind = InputIcon.CreateVisual(KBBIND);

	-- Register the keybind action.
	OPTIONS.arcporter_keybind:RegisterAction("gt_arcporter", function() OnTransitCommand() end, "press");
	OPTIONS.zoneexplorer_keybind:RegisterAction("gt_zoneexplorer", function() OnZECommand() end, "press");

	-- Set up our slash commands.
	LIB_SLASH.BindCallback({ slash_list="ft, gt", description="[Goon Transit] Open arcporter terminal", func=OnTransitCommand });
	LIB_SLASH.BindCallback({ slash_list="mqueue", description="[Goon Transit] Manually queues on a given id and difficulty", func=OnMQueueCommand });
	LIB_SLASH.BindCallback({ slash_list="queue", description="[Goon Transit] Queues based on description", func=OnQueueCommand });
	LIB_SLASH.BindCallback({ slash_list="cancel", description="[Goon Transit] Cancels the current queue", func=OnCancelCommand });
	LIB_SLASH.BindCallback({ slash_list="ze", description="[Goon Transit] Opens the Zone Explorer", func=OnZECommand });
	LIB_SLASH.BindCallback({ slash_list="gtzl", description="[Goon Transit] Opens a raw dump of the zone list", func=OnGTZLCommand });

	-- Set up the nav wheel.
	NAV.root = NavWheel.CreateNode("GOONTRANSIT_root");
	NAV.root:SetParent("hud_root", -101);
	NAV.root:SetTitle("Goon Transit");
	NAV.root:SetDescription("Go hog wild in places");
	NAV.root:GetIcon():SetTexture("navwheel_icon");

	-- Transit / raid submenus of the nav wheel.
	NAV.arcport = NavWheel.CreateNode("GOONTRANSIT_arcport");
	NAV.arcport:SetParent("GOONTRANSIT_root", -1);
	NAV.arcport:SetTitle("Arcporter");
	NAV.arcport:SetDescription("Opens the arcporter terminal menu");
	NAV.arcport:GetIcon():SetTexture("navwheel_icon");

	--[[
	NAV.raid = NavWheel.CreateNode("GOONTRANSIT_raid");
	NAV.raid:SetParent("GOONTRANSIT_root", -2);
	NAV.raid:SetTitle("Raid");
	NAV.raid:SetDescription("Select the raid you wish to start");
	NAV.raid:GetIcon():SetTexture("raid_icon");
	]]

	NAV.zoneexplore = NavWheel.CreateNode("GOONTRANSIT_zoneexplore");
	NAV.zoneexplore:SetParent("GOONTRANSIT_root", -3);
	NAV.zoneexplore:SetTitle("Explore");
	NAV.zoneexplore:SetDescription("Explore all the available zones");
	NAV.zoneexplore:GetIcon():SetTexture("zone_explore_icon");

	-- Bind an action to the wheel.
	NAV.arcport:SetAction(OpenArcporter);
	NAV.zoneexplore:SetAction(function ()
		NavWheel.Close();
		OnZECommand();
	end);

	-- Sub menus of the raid menu.
	--[[
	for i,v in ipairs(NAV_QUEUE) do

		-- Create the entry.
		local N = NavWheel.CreateNode(v.title);
		N:SetParent("GOONTRANSIT_raid", -i);
		N:SetTitle(v.title);
		N:SetDescription(v.description);

		-- Set the icon.
		if (v.icon ~= "") then
			N:GetIcon():SetTexture(v.icon);
		end

		-- Bind the action.
		if (v.key ~= "") then
			N:SetAction(function() EnterQueue(QUEUES[v.key]) end);
		end

	end
	]]

	-- Set up our zone listing.
	g_WebUrls["zone_list"] = WebCache.MakeUrl("zone_list");
	WebCache.Subscribe(g_WebUrls["zone_list"], OnZoneListResponse, false);

	-- Create our widgets.
	CHANGELOG.SCROLL = RowScroller.Create(CHANGELOG.BODY:GetChild("group.wrapper"));

	-- Set up our moveable frames.
	MovablePanel.ConfigFrame({
		frame = CHANGELOG_FRAME,
		MOVABLE_PARENT = CHANGELOG.TITLE:GetChild("MovableParent"),
	});

	-- Enable the close button and the scroller.
	GT.Bind_Close(CHANGELOG.TITLE, function() CHANGELOG_FRAME:Hide() end);
	GT.Bind_Scroll(CHANGELOG.SCROLL, CHANGELOG.BODY:GetChild("group.wrapper.body"), 15, 15, 10);

	-- Set the changelog text.
	local body = CHANGELOG.BODY:GetChild("group.wrapper.body");
	body:SetText(changelog);

	-- Update the changelog scroll.
	local row_h = (body:GetNumLines() + 1) * body:GetLineHeight();
	body:SetDims("top:_;height:"..row_h);
	CHANGELOG.SCROLL:GetRow(1):UpdateSize({height=row_h});
	CHANGELOG.SCROLL:UpdateSize();

	-- Raw Zone List
	RawZone.Init();

	-- Zone Explorer.
	ZoneExplorer.Init();

end

function OnOptionsChanged(id, value)
	if id == "opt_general_debug" then
		OPTIONS.debug_mode = value;
		Debug.EnableLogging(value);

	elseif id == "opt_arcporter_usekeybind" then
		OPTIONS.arcporter_usekeybind = value;
		if value == false then
			OPTIONS.arcporter_keybind:BindKey("gt_arcporter", nil);
			Debug.Log("Unbinding custom keybind.");
		else
			Debug.Log("Binding key: "..tostring(g_KEYBIND.arcporter));
			OPTIONS.arcporter_keybind:BindKey("gt_arcporter", nil);
			OPTIONS.arcporter_keybind:BindKey("gt_arcporter", g_KEYBIND.arcporter.keycode);
		end

	elseif id == "opt_zoneexplorer_usekeybind" then
		OPTIONS.zoneexplorer_usekeybind = value;
		if value == false then
			OPTIONS.zoneexplorer_keybind:BindKey("gt_zoneexplorer", nil);
			Debug.Log("Unbinding custom keybind.");
		else
			Debug.Log("Binding key: "..tostring(g_KEYBIND.zoneexplorer));
			OPTIONS.zoneexplorer_keybind:BindKey("gt_zoneexplorer", nil);
			OPTIONS.zoneexplorer_keybind:BindKey("gt_zoneexplorer", g_KEYBIND.zoneexplorer.keycode);
		end

	elseif id == "opt_arcporter_keybind" or id == "opt_zoneexplorer_keybind" then

		if id == "opt_arcporter_keybind" then
			g_KEYBIND.current = "arcporter";
		else g_KEYBIND.current = "zoneexplorer"; end

		Debug.Log("Opening "..g_KEYBIND.current.." keybind frame.");

		-- Set the current button icon.
		OPTIONS.vis_keybind:SetBind(g_KEYBIND[g_KEYBIND.current] or {keycode=0});

		-- Close the options window.  Since this is a button, it should be open.
		Component.GenerateEvent("MY_OPTIONS_TOGGLE");

		-- Open up the keybind frame and set it to listen for a key.
		Component.SetInputMode("cursor");
		KBFRAME:Show();
		KBFRAME:ParamTo("alpha", 1, 0.1);
		KBCATCH:ListenForKey();

	elseif id == "opt_changelog_view" then
		CHANGELOG_FRAME:Show();

		-- Close the options window.  Since this is a button, it should be open.
		Component.GenerateEvent("MY_OPTIONS_TOGGLE");
	end
end

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

	-- Adjust image.
	OPTIONS.vis_keybind:SetBind({keycode=keyCode});

	-- Sanity check.
	if g_KEYBIND.current == nil then return end

	-- Store new keybind.
	g_KEYBIND[g_KEYBIND.current] = {keycode = keyCode};
	Component.SaveSetting("Keybind", g_KEYBIND);

	-- Actually set the keybind.
	if OPTIONS[g_KEYBIND.current .. "_usekeybind"] then
		Debug.Log("Binding "..g_KEYBIND.current.." key: "..tostring(keyCode));
		OPTIONS[g_KEYBIND.current .. "_keybind"]:BindKey("gt_"..g_KEYBIND.current, nil);
		OPTIONS[g_KEYBIND.current .. "_keybind"]:BindKey("gt_"..g_KEYBIND.current, keyCode);
	end

	-- Slight delay so the user can see their choice.
	Callback2.FireAndForget(close, nil, 1.5);
end


function OnZoneListResponse(resp, err)
	if (g_QUEUE_SEARCH == nil) then
		return
	end

	local search = g_QUEUE_SEARCH:lower();
	for i,v in ipairs(resp) do
		if (v.description:lower():find(search) ~= nil) then

			local id = v.id;
			local difficulty = nil;

			local queue = v.difficulty_levels[g_QUEUE_DIFFICULTY];
			if (queue == nil) then
				queue = v.difficulty_levels[1];
			end

			if (queue ~= nil) then
				id = queue.zone_setting_id;
				difficulty = queue.id;
			end

			if (difficulty == nil) then
				-- Old style.  Works for Arena PvP (missions that don't have a difficulty).
				GT.Alert("Queued for " .. v.description .. " (" .. tostring(id) .. ")");
				Game.QueueForPvP(tonumber(id), true, v.skip_matchmaking);
			else
				-- New style.  For missions with a difficulty.
				GT.Alert("Queued for " .. v.description .. " { id = " .. tostring(id) .. ", difficulty = " .. tostring(difficulty) .. " }");
				Game.QueueForPvP({ id = id, difficulty = difficulty }, true, v.skip_matchmaking);
			end

			g_QUEUE_SEARCH = nil;
			return
		end
	end

	GT.Alert("Could not find an instance to queue on.");
	g_QUEUE_SEARCH = nil;
end

-- Opens the arcporter window.
function OpenArcporter()
	-- { terminal_type = "ARCFOLDER", terminal_obj_guid = Player.GetTargetId(), terminal_id = 0 }
	-- Component.GenerateEvent("ON_TERMINAL_AUTHORIZED", { terminal_type = "ARCFOLDER", terminal_obj_guid = Player.GetTargetId(), terminal_id = 0 })
	Component.PostMessage("Arcporter:Main", "open");
end

-- Enters a queue.
function EnterQueue(queue)
	if (queue ~= nil) then
		Game.QueueForPvP({ queue }, true);
	end

	NavWheel.Close();
end


-- FT/GT command.
function OnTransitCommand(args)
	OpenArcporter();
	NavWheel.Close();
end

-- MQueue command.
function OnMQueueCommand(args)
	local id = args[1];
	local difficulty = args[2];
	local matchmaking = args[3];

	-- Option to skip matchmaking.
	local skip_matchmaking = true;
	if matchmaking ~= nil and args[3] == "false" then
		skip_matchmaking = false;
	end

	if (difficulty == nil) then
		-- Old style.  Works for Arena PvP (missions that don't have a difficulty).
		GT.Alert("Queued for " .. tostring(id)..", skip_matchmaking: "..tostring(skip_matchmaking));
		Game.QueueForPvP(tonumber(id), true, skip_matchmaking);
	else
		-- New style.  For missions with a difficulty.
		local queue = {};
		table.insert(queue, { id = tonumber(id), difficulty = tonumber(difficulty) });
		GT.Alert("Queued for { id = " .. tostring(id) .. ", difficulty = " .. tostring(difficulty) .. " }"..", skip_matchmaking: "..tostring(skip_matchmaking));
		Game.QueueForPvP(queue, true, skip_matchmaking);
	end
end

-- Queue command.
function OnQueueCommand(args)
	g_QUEUE_SEARCH = args[1];
	g_QUEUE_DIFFICULTY = args[2];

	if (g_QUEUE_DIFFICULTY == nil) then
		g_QUEUE_DIFFICULTY = 1;
	end

	WebCache.QuickUpdate(g_WebUrls["zone_list"]);
end

-- ZE command.
function OnZECommand(args)
	if ZONE:IsVisible() then
		ZONE:Hide();
	else
		ZONE:Show();
	end
end

-- GTZL command.
function OnGTZLCommand()
	RAWZONE:Show();
end

-- Cancel command.
function OnCancelCommand(args)
	Game.QueueForPvP({}, false);
	GT.Alert("Canceled the current queue.");
end


-------------------------------------------------------------------------------
-- Zone Explorer

function OnZEOpen()
	ZoneExplorer.Open();
end

function OnZEClose()
	ZoneExplorer.Close();
end

-------------------------------------------------------------------------------
-- Raw Zone List

function OnRawZLOpen()
	RawZone.Open();
end

function OnRawZLClose()
	RawZone.Close();
end

-------------------------------------------------------------------------------
-- Changelog

function OnChangelogOpen()
	Component.SetInputMode("cursor");
	CHANGELOG_FRAME:ParamTo("alpha", 1, 0.1);
	System.PlaySound("panel_open");
end

function OnChangelogClose()
	Component.SetInputMode(nil);
	CHANGELOG_FRAME:ParamTo("alpha", 0, 0.1);
	CHANGELOG_FRAME:Hide(true, 0.1);
	System.PlaySound("panel_close");
end

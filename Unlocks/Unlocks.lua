-------------------------------------------------------------------------------
--	Unlocks by CookieDuster
-------------------------------------------------------------------------------
--	Thanks to:
--	- Arkii for looking up stuff about certifications
--	- vDepth for figuring out the missing certifications
--	- LoPhatKao for the time formatter in PDL:TE
--	- Brian Blose for Clock
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
--	Triage Edition by Nalin
-------------------------------------------------------------------------------
--[[

Version 1.3
- Added an option to hide the HUD while in a vehicle.
- HUD will now hide when downed.

Version 1.2
- Added an option to hide the HUD component.

Version 1.1
- Added daily campaign missions to the /unlocks command.
- Quicker response to certificate changes.
- Reduced console spam in debug mode.
- Fixed a bug where the HUD wouldn't update itself if the clock text was disabled.

Version 1.0
- Added Kanaloa HC certs.
- Added HUD icons for individual raid lockouts.
- HUD clock no longer shows individual lockout times as all lockouts reset at the same time.
- Options added for when to display the HUD clock.
- HUD disappears on downed state.

--]]
-------------------------------------------------------------------------------

require "math"
require "string"
require "table"
require "lib/lib_InterfaceOptions"
require "lib/lib_Slash"
require "lib/lib_Callback2"
require "lib/lib_Debug"
require "lib/lib_HudManager"
require "lib/lib_ChatLib"
require "./lib/lib_TableShow"


-- Widget stuff.
local FRAME = Component.GetFrame("Main");
local CLOCK = Component.GetWidget("MainText");
local LIST = Component.GetWidget("List");

-- Interface options.
local OPTIONS = {
	disable_hud = false,
	format_string = "",
	clock_vis = "clock_vis_mouse",
	clock_format = "nocolon",
	clock_refresh = 60,
	hide_in_vehicle = false
};

-- Colors we are using.
local COLOR = {
	NOTCERTIFIED = "#666666",
	LOCKED = "#999999",
	NORMAL = "#FFFFFF"
};

-- The raids we are following.
local UNLOCKS = {
	[784] = {
		locktimer = 4492,
		item = "Baneclaw",
		display_name = "Baneclaw"
	},
	[785] = {
		locktimer = 2654,
		item = "Kanaloa",
		display_name = "Kanaloa"
	},
	[4905] = {
		locktimer = 4904,
		item = "KanaloaHC",
		display_name = "Kanaloa HC"
	}
};

-- Daily mission completion
-- Certificates taken from Arcporter.lua
--
local HARDCORECERTS = {
	[1]	= { cert=5268, name="Mission 1: Crash Down" },
	[2]	= { cert=5269, name="Mission 3: Dirty Deeds" },
	[3]	= { cert=5270, name="Mission 5: Proving Ground" },
	[4] = { cert=5271, name="Mission 6: Power Grab" },
	[5] = { cert=5272, name="Mission 7: Risky Business" },
	[6]	= { cert=5273, name="Mission 8: Blackwater Anomaly" },
	[7]	= { cert=5274, name="Operation Miru" }
};

-- Other variables.
local certs;
local g_mouse_mode = false;
local Timers = {};


function OnComponentLoad()
	InterfaceOptions.AddMovableFrame({frame = FRAME, label = "Unlocks", scalable = true});

	InterfaceOptions.AddCheckBox({id="disable_hud", label="Disable HUD", default=false});
	InterfaceOptions.AddCheckBox({id="hide_in_vehicle", label="Hide HUD when in vehicle", default=false});

	InterfaceOptions.AddChoiceMenu({id="clock_vis", label="Clock display", default="clock_vis_mouse"});
	InterfaceOptions.AddChoiceEntry({menuId="clock_vis", val="clock_vis_mouse", label="Mouse mode only"});
	InterfaceOptions.AddChoiceEntry({menuId="clock_vis", val="clock_vis_always", label="Always visible"});
	InterfaceOptions.AddChoiceEntry({menuId="clock_vis", val="clock_vis_disabled", label="Disabled"});

	InterfaceOptions.AddChoiceMenu({id="clock_format", label="Clock display format", default="nocolon"});
	InterfaceOptions.AddChoiceEntry({menuId="clock_format", val="nocolon", label="1d 23h 45m"});
	InterfaceOptions.AddChoiceEntry({menuId="clock_format", val="colon", label="01:23:45"});
	InterfaceOptions.AddChoiceEntry({menuId="clock_format", val="nocolon_sec", label="1d 23h 45m 0s"});
	InterfaceOptions.AddChoiceEntry({menuId="clock_format", val="colon_sec", label="01:23:45:00"});
	InterfaceOptions.AddSlider({id="clock_refresh", label="Clock refresh rate (seconds)", default=60, min=1, max=60, inc=1, suffix="s"});

	InterfaceOptions.AddTextInput({id="date_format", label="Date format in /unlocks", tooltip="Use os.date format string", default="%Y-%m-%d (%A) %H:%M:%S"});

	InterfaceOptions.AddCheckBox({id="debug_mode", label="Debug mode", default=false});

	InterfaceOptions.SetCallbackFunc(OnOptionChanged, "Unlocks");

	-- Slash commands.
	LIB_SLASH.BindCallback({slash_list = "unlocks", description = "Show unlocks", func = OnUnlocksCommand});

	-- Timers.
	Timers.Clock = Callback2.CreateCycle(UpdateClockText);
	Timers.Clock:Run(OPTIONS.clock_refresh);

	-- Hud stuff.
	HudManager.BlacklistReasons({});
	HudManager.BindOnShow(OnHudShow);

	-- Set textures.
	LIST:GetChild("Baneclaw"):GetChild("Icon"):SetTexture("baneclaw");
	LIST:GetChild("Kanaloa"):GetChild("Icon"):SetTexture("kanaloa");
	LIST:GetChild("KanaloaHC"):GetChild("Icon"):SetTexture("kanaloa_hc");

	-- Initialize our clock and textures.
	UpdateCertificationData();
	UpdateClockText();
end

function Alert(msg)
	ChatLib.SystemMessage({ text="[Unlocks] " .. msg });
end

function OnOptionChanged(id, value)
	if id == "disable_hud" then
		OPTIONS.disable_hud = value;
		if value then
			FRAME:Hide();
		else
			FRAME:Show();
		end
	elseif id == "hide_in_vehicle" then
		OPTIONS.hide_in_vehicle = value;
	elseif id == "date_format" then
		OPTIONS.format_string = value;
	elseif id == "clock_format" then
		OPTIONS.clock_format = value;
		UpdateClockText();
	elseif id == "clock_refresh" then
		OPTIONS.clock_refresh = value;
		Timers.Clock:Stop();
		Timers.Clock:Run(OPTIONS.clock_refresh);
	elseif id == "debug_mode" then
		Debug.EnableLogging(value);
	elseif id == "clock_vis" then
		OPTIONS.clock_vis = value;
		clock_enabled = (value ~= "clock_vis_disabled");

		-- Adjust clock visibility.
		if clock_enabled and (value == "clock_vis_always" or ((value == "clock_vis_mouse") == g_mouse_mode)) then
			CLOCK:Show();
		else
			CLOCK:Hide();
		end
	end
end

function OnHudShow(show, dur)
	FRAME:ParamTo("alpha", tonumber(show), dur);
end

function OnUnlocksChanged(args)
	UpdateCertificationData();
end

function OnInputModeChanged(args)
	local cursor_mode = args.mode == "cursor";
	if cursor_mode then
		g_mouse_mode = true;
		if OPTIONS.clock_vis == "clock_vis_mouse" then
			CLOCK:Show();
		end
	else
		g_mouse_mode = false;
		if OPTIONS.clock_vis == "clock_vis_mouse" then
			CLOCK:Hide();
		end
	end
end

function UpdateCertificationData()
	certs = Player.GetCharacterCerts();
	UpdateClockText();
end

function UpdateClockText()
	local text = "unlocked";

	if certs then

		local entries = 0;
		local notcertified = 0;

		for id,data in pairs(UNLOCKS) do

			-- Count entries to compare with how many aren't certified.
			entries = entries + 1;

			if certs[data.locktimer] and certs[data.locktimer].expiration_time then
				local unlock_timestamp = tonumber(certs[data.locktimer].expiration_time);
				local local_time = tonumber(System.GetLocalUnixTime());
				if unlock_timestamp and unlock_timestamp > local_time then
					text = FormatClockString(unlock_timestamp - local_time);
					LIST:GetChild(data.item):GetChild("Disabled"):SetParam("alpha", "1.0");
					LIST:GetChild(data.item):GetChild("Icon"):SetParam("tint", COLOR.LOCKED);
				else
					-- For some reason we still have the lockout cert even though the expiration time has passed.
					LIST:GetChild(data.item):GetChild("Disabled"):SetParam("alpha", "0.0");
					LIST:GetChild(data.item):GetChild("Icon"):SetParam("tint", COLOR.NORMAL);
				end
			elseif certs[id] then
				LIST:GetChild(data.item):GetChild("Disabled"):SetParam("alpha", "0.0");
				LIST:GetChild(data.item):GetChild("Icon"):SetParam("tint", COLOR.NORMAL);
			else
				notcertified = notcertified + 1;
				LIST:GetChild(data.item):GetChild("Icon"):SetParam("tint", COLOR.NOTCERTIFIED);
			end
		end

		-- If we don't have ANY certified unlocks, announce that.
		if entries == notcertified then
			text = "none certified";
		end

	end

	if clock_enabled then
		CLOCK:SetText(text);
	end
end

function FormatClockString(timestamp) -- from PDL:TE (edited)
	local seconds = tonumber(timestamp);
	local days = math.floor(seconds/86400);
	local hours = math.floor(seconds/3600-(days*24));
	local minutes = math.floor(seconds/60 - (hours*60)-days*1440);
	local seconds = math.floor(seconds  -days*86400- hours*3600 - minutes *60);
	if OPTIONS.clock_format == "colon" then
		if tonumber(days) ~= 0 then
			return string.format("%02.f:%02.f:%02.f",days,hours,minutes);
		elseif tonumber(hours) ~= 0 then
			return string.format("%02.f:%02.f",hours,minutes);
		else
			return string.format("%02.f:%02.f",minutes);
		end
	elseif OPTIONS.clock_format == "nocolon" then
		if tonumber(days) ~= 0 then
			return string.format("%.fd %.fh %.fm",days,hours,minutes);
		elseif tonumber(hours) ~= 0 then
			return string.format("%.fh %.fm",hours,minutes);
		else
			return string.format("%.fm",minutes);
		end
	elseif OPTIONS.clock_format == "colon_sec" then
		if tonumber(days) ~= 0 then
			return string.format("%02.f:%02.f:%02.f:%02.f",days,hours,minutes,seconds);
		elseif tonumber(hours) ~= 0 then
			return string.format("%02.f:%02.f:%02.f",hours,minutes,seconds);
		else
			return string.format("%02.f:%02.f",minutes,seconds);
		end
	elseif OPTIONS.clock_format == "nocolon_sec" then
		if tonumber(days) ~= 0 then
			return string.format("%.fd %.fh %.fm %.fs",days,hours,minutes,seconds);
		elseif tonumber(hours) ~= 0 then
			return string.format("%.fh %.fm %.fs",hours,minutes,seconds);
		elseif tonumber(minutes) ~= 0 then
			return string.format("%.fm %.fs",minutes,seconds);
		else
			return string.format("%.fs",seconds);
		end
	end
end


function OnUnlocksCommand()
	UpdateCertificationData();
	Debug.Log(tostring(certs));

	local text = "\nCertifications:";
	for id,data in pairs(UNLOCKS) do
		if certs[data.locktimer] then -- check if it's completed first
			local unlock_timestamp;
			if certs[data.locktimer].expiration_time then
				unlock_timestamp = tonumber(certs[data.locktimer].expiration_time);
			end
			local_time = tonumber(System.GetLocalUnixTime());
			if unlock_timestamp then
				if unlock_timestamp > local_time then
					text = text.."\n"..data.display_name..": certified, unlocks at "..System.GetDate(OPTIONS.format_string, unlock_timestamp);
				else
					text = text.."\n"..data.display_name..": certified, unlocked";
				end
			else -- just in case
				text = text.."\n"..data.display_name..": unknown";
			end
		elseif certs[id] then -- if not completed, check it it's unlocked
			text = text.."\n"..data.display_name..": certified, unlocked";
		else
			text = text.."\n"..data.display_name..": not certified";
		end
	end

	text = text.."\n\nDaily Hardcore:";
	for _,v in ipairs(HARDCORECERTS) do
		local hasUnlock = (Player.GetUnlockInfo("certificate", v.cert) ~= nil);
		text = text.."\n"..v.name..": ";
		if hasUnlock then
			text = text.."locked";
		else
			text = text.."AVAILABLE";
		end
	end

	Alert(text);
end

function OnSeatChanged(args)
	if args.role == "None" or OPTIONS.hide_in_vehicle == false then
		OnHudShow(true, 0.2);
		return;
	end

	OnHudShow(false, 0.2);
end

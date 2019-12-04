--[[

Treasure Hunter
Originally designed by GreatKhan
Authors: GreatKhan, Nizidr, Nalin


Version 3.9  [Nalin]
- Fixed another bug with shared caches from older versions of the addon.

Version 3.8  [Nalin]
- Shared caches originating from versions 2.0 and earlier of the addon are properly ignored in Devil's Tusk.

Version 3.7  [Nalin]
- Shared caches are colored properly.
- Fixed a localization bug caused by how Firefall re-loads saved settings.

Version 3.6  [Nalin]
- Fixed a regex match that was not working properly.

Version 3.5  [Nalin]
- Fixed the "large cache only" option.

Version 3.4  [Nalin]
- Waypoints are cleaned up when transferring zones.
- Fixed some bugs.

Version 3.3  [Nizidr, Nalin]
- Addon loads properly now.
- Added ability to toggle sound on/off.
- New option to toggle Unknown Relic Caches off.
- Allowable max distance for shared waypoints (0 for no max distance).
- Added color for Unknown Relic Caches.
- Fixed a color bug with localization.

Version 3.2  [Nalin]
- Small caches are still shared if you discover one while the "large cache only" option is enabled.
- Fixed a bug where players would immediately re-share a shared cache.
- More reliable detection of when a cache disappears or goes out of range.
- Fixed waypoint sharing compatibility issues with original addon version.
- Cache disappearances are shared with other players.
- Translation information is saved so caches shared with version 3.2+ will appear in the user's language.
	(You must first visit a cache at least once for the internal translation to update)

Version 3.1  [Nalin]
- Shared caches are now prefixed with [Shared].
- Getting in range of a shared cache will check if it exists or not.

Version 3.0  [Nalin]
- Implemented new automatic waypoint sharing feature.
- Cleaned up the options menu a bit.
- Added some option tooltips.
- Added a sound effect that plays when a cache has been discovered.

Version 2.2  [Nalin]
- Added more configuration options.
- Improved reliability.
- [2.2a] Fixed a bug that resulted in duplicate markers.

Version 2.1  [Nizidr]
- Removed chat features.
- Added more configuration options.
- Improved reliability.
- Other stuff?

Version 2.0  [GreatKhan]
- Options work now.

Version 1.0  [GreatKhan]
- Initial release.

--]]

require "string"
require "unicode"
require "math"
require "lib/lib_math"
require "lib/lib_Debug"
require "lib/lib_Slash"
require "lib/lib_ChatLib"
require "lib/lib_MapMarker"
require "lib/lib_HudManager"
require "lib/lib_InterfaceOptions"

--[[
Game.GetTargetInfo(18374686480579149858)
__unnamed__ = {
   ["effective_level"] = 0;
   ["factionId"] = 1;
   ["pvp_rank"] = 0;
   ["elite_level"] = 0;
   ["mapHidden"] = true;
   ["name"] = "Relic Hunt Glider Pad";
   ["deployableTypeId"] = "4069";
   ["type"] = "deployable";
   ["scaling_level"] = 0;
   ["damageable"] = false;
   ["faction"] = "accord";
   ["level"] = 0;
   ["deployableCategory"] = "Glider pad";
   ["is_interactible"] = true;
   ["hostile"] = false;
   ["deployableType"] = "Relic Hunt Glider Pad";
   ["bounds"] = {
      ["length"] = 1.45112002;
      ["height"] = 1.75;
      ["width"] = 1.55179918;
   };
};

Game.GetTargetInfo(18374686480572151586)
__unnamed__ = {
   ["scaling_level"] = 0;
   ["deployableType"] = "Relic Cache";
   ["type"] = "deployable";
   ["elite_level"] = 0;
   ["name"] = "Relic Cache";
   ["hostile"] = false;
   ["level"] = 0;
   ["effective_level"] = 0;
   ["pvp_rank"] = 0;
   ["deployableTypeId"] = "4067";
   ["mapHidden"] = true;
   ["deployableCategory"] = "None";
   ["faction"] = "accord";
   ["damageable"] = false;
   ["hidden"] = true;
   ["factionId"] = 1;
   ["bounds"] = {
      ["length"] = 1.08659005;
      ["height"] = 0.55063099;
      ["width"] = 0.61899;
   };
};

Game.GetTargetInfo(18374686480579417378)
__unnamed__ = {
   ["name"] = "Large Relic Cache";
   ["deployableTypeId"] = "4068";
   ["deployableType"] = "Large Relic Cache";
   ["level"] = 0;
   ["deployableCategory"] = "None";
   ["hidden"] = true;
   ["pvp_rank"] = 0;
   ["type"] = "deployable";
   ["scaling_level"] = 0;
   ["faction"] = "accord";
   ["damageable"] = false;
   ["hostile"] = false;
   ["mapHidden"] = true;
   ["elite_level"] = 0;
   ["effective_level"] = 0;
   ["factionId"] = 1;
   ["bounds"] = {
      ["length"] = 1.30339408;
      ["width"] = 1.99721599;
      ["height"] = 0.88762003;
   };
};
--]]

local DEPLOYABLE_UNKNOWN = 0
local DEPLOYABLE_SMALL = 4067
local DEPLOYABLE_LARGE = 4068

local Options = {
	Enabled = true,
	OnlyLarge = false,
	Sound = true,
	CheckPeriod = 20,
	Share = true,
	Compatible = true,
	ChatTimeout = 90,
	Distance = 0,
	Color = {['alpha'] = 0.5, ['tint'] = "00FF00", ['exposure'] = 0},
	ColorL = {['alpha'] = 0.5, ['tint'] = "FF0000", ['exposure'] = 0},
	ColorU = {['alpha'] = 0.5, ['tint'] = "FFFFFF", ['exposure'] = 0},
	DebugMode = false
}
local DefaultTranslation = { ['i'..DEPLOYABLE_SMALL]="Relic Cache", ['i'..DEPLOYABLE_LARGE]="Large Relic Cache" }
local Translation = {}

local treasures = {}
local isSertao = false

local CBSHARE = nil


function OnComponentLoad()

	ChatLib.RegisterCustomLinkType('Treasure', OnChatPacket)
	ChatLib.RegisterCustomLinkType('Treasure2', OnChatPacket)
	-- LIB_SLASH.BindCallback({ slash_list="trtest", description="Treasure Test", func=OnTrTestCommand });

	-- Load up the translation.  Provide a fix for instances where the translation is bad.
	Translation = Component.GetSetting("Translation") or DefaultTranslation
	if Translation['i'..DEPLOYABLE_SMALL] == nil then Translation = DefaultTranslation end

	InterfaceOptions.SetCallbackFunc(OptionsChanged, "Treasure Hunt");

	InterfaceOptions.StartGroup({label="General"});
	InterfaceOptions.AddCheckBox({id="Enabled", label="Enable", default=Options.Enabled});
	InterfaceOptions.StopGroup();

	InterfaceOptions.StartGroup({label="Waypoints"});
	InterfaceOptions.AddCheckBox({id="OnlyLarge", label="Only show Large Relic Caches", default=Options.OnlyLarge});
	InterfaceOptions.AddCheckBox({id="Sound", label="Enable sound effects", default=Options.Sound, tooltip="Plays sound effect when new relic waypoint is added. Waypoints received from other players have a different sound effect."});
	InterfaceOptions.AddSlider({id="CheckPeriod", label="Keep waypoint while out of range for", default=Options.CheckPeriod, min=1, max=60, inc=1, suffix="sec", tooltip="When you leave the range of the waypoint, this is how long to keep it on the screen."});
	InterfaceOptions.StopGroup();

	InterfaceOptions.StartGroup({label="Sharing"});
	InterfaceOptions.AddCheckBox({id="Share", label="Share waypoints", default=Options.Share, tooltip="Shares waypoints with other users of this addon. If this is disabled, you won't receive waypoints from other users."});
	InterfaceOptions.AddCheckBox({id="Compatible", label="Receive waypoints from older add-on versions", default=Options.Compatible, tooltip="When enabled, you will receive Unknown Relic Cache waypoints from players.  NOTE: Make sure 'Only show Large Relic Caches' is disabled."});
	InterfaceOptions.AddSlider({id="ChatTimeout", label="3rd party waypoint timeout", default=Options.ChatTimeout, min=1, max=300, inc=5, suffix="sec", tooltip="If you receive a waypoint from another player, this is how long to wait before it is removed."});
	InterfaceOptions.AddSlider({id="Distance", label="Shared waypoint max distance", default=Options.Distance, min=0, max=2000, inc=50, suffix="m", tooltip="Ignore waypoints received from other players that are further away than this setting.  Use 0 for no limit."});
	InterfaceOptions.StopGroup();

	InterfaceOptions.StartGroup({label="Colors"});
	InterfaceOptions.AddColorPicker({id="Color", label="Small Relic Cache", default=Options.Color});
	InterfaceOptions.AddColorPicker({id="ColorL", label="Large Relic Cache", default=Options.ColorL});
	InterfaceOptions.AddColorPicker({id="ColorU", label="Unknown Relic Cache", default=Options.ColorU});
	InterfaceOptions.StopGroup();

	InterfaceOptions.StartGroup({label="Debug"});
	InterfaceOptions.AddCheckBox({id="DebugMode", label="Log debug info to the console", default=false});
	InterfaceOptions.StopGroup();

	-- This checks all the shared caches to see if we can remove them.
	CBSHARE = Callback2.CreateCycle(ShareUpdateCheck)

	-- This is not called when you first start the game.
	OnEnterZone()
end

function OptionsChanged(id, value)
	Options[id] = value
	if id == "Enabled" and not value then
		for i = #treasures, 1, -1 do
			RemoveTreasureByIndex(i)
		end
		treasures = {}
	elseif id == "Color" or id == "ColorL" or id == "ColorU" then
		UpdateColors()
	elseif id == "DebugMode" then
		Debug.EnableLogging(value);
	end
end

function OnEnterZone()
	-- Remove all caches.
	for i = #treasures, 1, -1 do
		RemoveTreasureByIndex(i)
	end
	treasures = {}

	-- See if we are in Sertao.
	isSertao = false
	if tonumber(Game.GetZoneId()) == 1030 then
		isSertao = true
	end

	-- If we are in Sertao, start the shared cache cleanup job.
	if isSertao then
		CBSHARE:Run(3)
	else CBSHARE:Stop() end
end

function UpdateColors()
	for i, T in pairs(treasures) do
		SetMarkerColor(T)
	end
end

function SetMarkerColor(T)
	if T.deployableTypeId == DEPLOYABLE_SMALL then
		T.MapMarker.ICON:SetParam("tint", Options.Color.tint);
		T.MapMarker:SetThemeColor(Options.Color)
	elseif T.deployableTypeId == DEPLOYABLE_LARGE then
		T.MapMarker.ICON:SetParam("tint", Options.ColorL.tint);
		T.MapMarker:SetThemeColor(Options.ColorL)
	else
		T.MapMarker.ICON:SetParam("tint", Options.ColorU.tint);
		T.MapMarker:SetThemeColor(Options.ColorU)
	end
end

function distanceFromLoc(locA, locB)
	dx = locA.x - locB.x
	dy = locA.y - locB.y
	dz = locA.z - locB.z
	return math.sqrt(dx^2 + dy^2 + dz^2)
end

function OnEntityAvailable(args)
	if not isSertao then return end
	local targetInfo = Game.GetTargetInfo(args.entityId)
	if not Options.Enabled or targetInfo == nil then return end

	--[[if targetInfo.name and string.find(targetInfo.name, "Relic") then
		Debug.Log(tostring(args.entityId).."\n"..tostring(targetInfo))
	end]]

	local deployableTypeId = tonumber(targetInfo.deployableTypeId)
	local isRelic = deployableTypeId == DEPLOYABLE_SMALL or deployableTypeId == DEPLOYABLE_LARGE

	if isRelic then
		-- See if we can update the translation.
		if Translation['i'..deployableTypeId] ~= targetInfo.name then
			Translation['i'..deployableTypeId] = targetInfo.name
			Component.SaveSetting("Translation", Translation)
		end

		Debug.Log("Discovered cache "..tostring(args.entityId)..".")

		local pos = Game.GetTargetBounds(args.entityId)
		CreateTreasureV3(args.entityId, deployableTypeId, pos)
	end
end

function OnEntityLost(args)
	for i, T in pairs(treasures) do
		if T.entityId == args.entityId then
			local p = Player.GetPosition()

			-- If we are less than 175m away from the marker, it most likely disappeared.
			-- In that case, remove it.  Otherwise, put a countdown timer on it.
			if distanceFromLoc(T.pos, p) < 175 then
				ShareCacheWithZone(T, "r")
				RemoveTreasureByIndex(i)
			else
				MarkerCallback(T)
			end

			return
		end
	end
end

function IfTreasureExists(pos)
	for i, T in pairs(treasures) do
		if (distanceFromLoc(T.pos, pos) < 10) then
			return T
		end
	end
	return false
end

function RemoveTreasure(marker)
	for i, T in pairs(treasures) do
		if marker == T then
			RemoveTreasureByIndex(i)
			return
		end
	end
end

function RemoveTreasureByIndex(idx)
	local T = treasures[idx]
	if T then
		Debug.Log("Removing marker "..tostring(T.entityId)..".")
		T.MapMarker:Destroy()
		if T.CB2 ~= nil then T.CB2:Release() end
		table.remove(treasures, idx)
	end
end

function RemoveTreasureByEntityId(entityId)
	for i, T in pairs(treasures) do
		if T.entityId == entityId then
			RemoveTreasureByIndex(i)
			return
		end
	end
end

function CreateTreasureV1(entityId, pos, name, fromchat)
	-- Only allow v1 caches if the user settings allow it.
	if not Options.Compatible or Options.OnlyLarge then return end

	-- Legacy code.  Always set fromchat.  This should never be called locally anymore.
	local T = {}
	T.entityId = entityId
	T.pos = pos
	T.fromchat = true --fromchat or false
	T.name = name
	T.deployableTypeId = DEPLOYABLE_UNKNOWN

	CreateTreasure(T)
end

function CreateTreasureV3(entityId, deployableTypeId, pos, fromchat)
	-- Grab the name of the cache from our translation list.
	local name = Translation['i'..deployableTypeId]

	local T = {}
	T.entityId = entityId
	T.pos = pos
	T.fromchat = fromchat or false
	T.name = name
	T.deployableTypeId = tonumber(deployableTypeId)

	CreateTreasure(T)
end

function CreateTreasure(T)
	-- Check our maximum distance.
	if T.fromchat
		and Options.Distance > 0
		and distanceFromLoc(pos, Player.GetPosition()) > Options.Distance
	then return end

	-- Check if our treasure already exists.
	local TE = IfTreasureExists(T.pos)
	if TE then
		if TE.fromchat and not T.fromchat then
			-- This was a shared cache.  Remove existing marker so we can re-create it.
			RemoveTreasure(TE)
		else
			Debug.Log("Marker "..tostring(T.entityId).." already exists, skipping.")
			return
		end
	end

	-- Advertise our cache to the zone.
	if not T.fromchat then
		ShareCacheWithZone(T)
	end

	-- If we only want to show large caches and this is a small one, don't continue.
	if Options.OnlyLarge and T.deployableTypeId ~= DEPLOYABLE_LARGE then
		return
	end

	-- Add the marker to our list of markers.
	table.insert(treasures, T)

	-- Play a sound effect to inform the user that a new cache has been found.
	-- Use a different sound effect for caches discovered through chat share.
	if Options.Sound then
		if T.fromchat then
			System.PlaySound("Play_UI_Beep_21")
		else System.PlaySound("Play_UI_Beep_35") end
	end

	-- Create the map marker.
	ConfigureMapMarker(T)

	-- Start the countdown for shared caches.  Local caches will start the countdown when
	-- the player leaves range.
	if T.fromchat then
		MarkerCallback(T)
	end
end

function ConfigureMapMarker(m)
	-- If we already have a marker, remove it first.
	if m.MapMarker then
		m.MapMarker:Destroy()
	end

	-- Create the map marker.
	m.MapMarker = MapMarker.Create()
	m.MapMarker:BindToPosition(m.pos)

	-- Set the name of the waypoint.
	if m.fromchat then
		m.MapMarker:SetTitle("[Shared] "..m.name)
	else
		m.MapMarker:SetTitle(m.name)
	end

	-- Set the waypoint icon and color it.
	m.MapMarker.ICON:SetTexture("Icon")
	SetMarkerColor(m)
	m.MapMarker:ShowOnHud(true)
end

function MarkerCallback(marker)
	marker.CB2 = Callback2.Create()
	marker.CB2:Bind(function(m)
		if m.entityId ~= 0 and Game.GetTargetInfo(m.entityId) ~= nil then
			Debug.Log("Marker "..tostring(m.entityId).." still exists, waiting "..tostring(Options.CheckPeriod).." seconds more.")
			m.CB2:Reschedule(Options.CheckPeriod)
			return
		end

		RemoveTreasure(m)
	end, marker)

	local check = Options.CheckPeriod
	if marker.fromchat then check = Options.ChatTimeout end
	marker.CB2:Reschedule(check)

	Debug.Log("Adding marker "..tostring(marker.entityId)..", checking status in "..tostring(check).." seconds.")
end

function ShareUpdateCheck()
	for i = #treasures, 1, -1 do
		local T = treasures[i]
		local p = Player.GetPosition()

		-- If this is a shared waypoint that we are within 150 meters of, and we cannot
		-- find it, then remove it.  It most likely is gone.  If it isn't gone (the game
		-- is being laggy), 150 meters is within range so it should re-appear again.
		if T
			and T.fromchat
			and (distanceFromLoc(T.pos, p) < 150)
			and Game.GetTargetInfo(T.entityId) == nil
		then
			RemoveTreasureByIndex(i)
		end
	end
end

function ShareCacheWithZone(marker, action)
	if not Options.Share then return end
	if marker.deployableTypeId == nil then
		Debug.Warn("ShareCacheWithZone had marker with no deployableTypeId!  This should not happen!")
		return
	end

	local END = ChatLib.GetEndcapString()
	local TYPE = ChatLib.GetLinkTypeIdBreak()
	local SEP = ':'
	local NEG = ';'

	-- Default to add action.
	action = action or "a"

	local function encodeNum(num)
		local value_break = SEP
		if num < 0 then
			value_break = NEG
			num = -num
		end
		num = math.floor(0.5 + (num * 10000))
		return value_break..compress(num)
	end

	-- Start the link.
	local str = END.."Treasure2"..TYPE

	-- Add the version string.
	str = str.."v3"

	-- Add the action.
	str = str..SEP..action

	-- Add the entity id.
	str = str..SEP..compress(marker.entityId)

	-- Add the deployable type.
	str = str..SEP..compress(marker.deployableTypeId)

	-- Add the position.
	str = str..encodeNum(marker.pos.x)
	str = str..encodeNum(marker.pos.y)
	str = str..encodeNum(marker.pos.z)

	-- End the link.
	str = str..END

	-- Send the information.
	Chat.SendChannelText("zone", str);
end

function OnChatPacket(args)
	if not isSertao then return end
	if not Options.Share then return end
	if args.author == Player.GetInfo() then return end

	if args.link_data:find(',') ~= nil then
		ParseChatV1(args)
	elseif args.link_data:find("^v3:") ~= nil then
		ParseChatV3(args)
	else ParseChatV2(args) end
end

function ParseChatV1(args)
	local pos = {}

	local str = args.link_data
	pos.x = str:sub(1, str:find(',') - 1)

	str = str:sub(pos.x:len()+2, str:len())
	pos.y = str:sub(1, str:find(',') - 1)

	str = str:sub(pos.y:len()+2, str:len())
	pos.z = str:sub(1,str:len())

	Debug.Log("Received v1 shared marker from "..args.author..".")
	CreateTreasureV1(0, pos, "Unknown Relic Cache", true)
end

function ParseChatV2(args)
	local SEP = ':'
	local NEG = ';'
	local data = args.link_data

	local function decodeNum(sign, num)
		num = decompress(num)
		return (num / 10000) * ((tonumber(sign == SEP) * 2) - 1)
	end

	local match_string = "(.-)([:;])(.-)([;:])(.-)([;:])(.-):(.+)"
	local entityId, x_sign, x, y_sign, y, z_sign, z, name = unicode.match(data, match_string)

	if entityId and x_sign and x and y_sign and y and z_sign and z and name then
		entityId = decompress(entityId)

		local pos = {}
		pos.x = decodeNum(x_sign, x)
		pos.y = decodeNum(y_sign, y)
		pos.z = decodeNum(z_sign, z)

		Debug.Log("Received v2 shared marker "..tostring(entityId).." from "..args.author..".")

		-- See if we can convert the name into a deployableTypeId
		if name == "Relic Cache" or name == "Large Relic Cache" then
			local deployableTypeId = DEPLOYABLE_SMALL
			if name == "Large Relic Cache" then deployableTypeId = DEPLOYABLE_LARGE end
			CreateTreasureV3(entityId, deployableTypeId, pos, true)
		else
			CreateTreasureV1(entityId, pos, name, true)
		end
	end
end

function ParseChatV3(args)
	local SEP = ':'
	local NEG = ';'
	local data = args.link_data

	local function decodeNum(sign, num)
		num = decompress(num)
		return (num / 10000) * ((tonumber(sign == SEP) * 2) - 1)
	end

	local match_string = "v3:(.):(.-):(.-)([:;])(.-)([;:])(.-)([;:])(.+)"
	local action, entityId, deployableTypeId, x_sign, x, y_sign, y, z_sign, z = unicode.match(data, match_string)

	if action and entityId and deployableTypeId and x_sign and x and y_sign and y and z_sign and z then
		entityId = decompress(entityId)
		deployableTypeId = decompress(deployableTypeId)

		local pos = {}
		pos.x = decodeNum(x_sign, x)
		pos.y = decodeNum(y_sign, y)
		pos.z = decodeNum(z_sign, z)

		if action == "a" then
			Debug.Log("Received v3 shared marker "..tostring(entityId).." from "..args.author..": add.")
			CreateTreasureV3(entityId, deployableTypeId, pos, true)
		elseif action == "r" then
			Debug.Log("Received v3 shared marker "..tostring(entityId).." from "..args.author..": remove.")
			RemoveTreasureByEntityId(entityId)
		else
			Debug.Log("Received v3 shared amrker "..tostring(entityId).." from "..args.auther..": unknown action: "..action)
		end
	end
end

function compress(number)
	return _math.Base10ToBaseN(number, true)
end

function decompress(number)
	return _math.BaseNToBase10(number, true)
end

--[[
function OnTrTestCommand(args)
	local END = ChatLib.GetEndcapString()
	local TYPE = ChatLib.GetLinkTypeIdBreak()
	local SEP = ':'
	local NEG = ';'

	local function encodeNum(num)
		local value_break = SEP
		if num < 0 then
			value_break = NEG
			num = -num
		end
		num = math.floor(0.5 + (num * 10000))
		return value_break..compress(num)
	end

	-- Add the version string.
	local str = "v3"

	-- Add the action.
	str = str..SEP..'a'

	-- Add the entity id.
	str = str..SEP..compress('9876543210987654321')

	-- Add the deployable type.
	str = str..SEP..compress(DEPLOYABLE_SMALL)

	-- Add the position.
	str = str..encodeNum(200)
	str = str..encodeNum(300)
	str = str..encodeNum(100)

	Debug.Log(str)

	local p = {}
	p.link_data = str
	p.author = "TestAuthor"
	OnChatPacket(p)
end
--]]

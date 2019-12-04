--[[
Nalin Test

Programmed by Nalin

--]]

require "unicode"
require "table"
require "lib/lib_Slash"
require "lib/lib_NavWheel"
require "lib/lib_WebCache"
require "lib/lib_MovablePanel"
require "lib/lib_RowScroller"
require "lib/lib_TextFormat"
require "lib/lib_ChatLib"
require "./lib_TableShow"


local g_WebUrls = {};
local t = {};

-- Frames.
local FRAME = Component.GetFrame("Main");
local TITLE_SECTION = Component.GetWidget("title_section");
local TITLE = TITLE_SECTION:GetChild("title");
local BODY = Component.GetWidget("body_section");
local TEXT = Component.GetWidget("text");


local SCROLL = nil;


-- Load!
function OnComponentLoad(args)

	-- Set up our slash commands.
	LIB_SLASH.BindCallback({ slash_list="nscore", description="[Nalin Test] Shows raw scoreboard information", func=OnNScoreCommand });
	LIB_SLASH.BindCallback({ slash_list="nalintest", description="[Nalin Test] Current test", func=OnNalinTestCommand });

	-- PanelManager.RegisterFrame(FRAME, OnClose)
	MovablePanel.ConfigFrame({
		frame = FRAME,
		MOVABLE_PARENT = Component.GetWidget("MovableParent"),
	});

	-- Allow close.
	local CLOSE_BUTTON = Component.GetWidget("close");
	CLOSE_BUTTON:BindEvent("OnMouseDown", OnClose);
	local X = CLOSE_BUTTON:GetChild("X");
	CLOSE_BUTTON:BindEvent("OnMouseEnter", function()
		X:ParamTo("tint", Component.LookupColor("red"), 0.15);
		X:ParamTo("glow", "#30991111", 0.15);
	end);
	CLOSE_BUTTON:BindEvent("OnMouseLeave", function()
		X:ParamTo("tint", Component.LookupColor("white"), 0.15);
		X:ParamTo("glow", "#00000000", 0.15);
	end);

	-- Create scroll
	SCROLL = RowScroller.Create(BODY:GetChild("group.wrapper"));
	SCROLL:SetSlider(RowScroller.SLIDER_DEFAULT);
	SCROLL:AddRow(TEXT);
	SCROLL:SetSliderMargin(15, 15);
	SCROLL:UpdateSize();

end

function OnOpen()
	Component.SetInputMode("cursor");
	FRAME:Show();
	FRAME:ParamTo("alpha", 1, 0.1);
end

function OnClose()
	FRAME:ParamTo("alpha", 0, 0.1);
	FRAME:Hide(true, 0.1);
	Component.SetInputMode(nil);
end

function Alert(msg)
	ChatLib.SystemMessage({ text="[Nalin Test] " .. msg });
end

function OnSinCardOp(args)
	warn(tostring(args))
end

function UpdateScrollSize()
	local row_h = (TEXT:GetNumLines() + 1) * TEXT:GetLineHeight();
	TEXT:SetDims("top:_;height:"..row_h);
	SCROLL:GetRow(1):UpdateSize({height=row_h});
	SCROLL:UpdateSize();
end

-- NScore command.
function OnNScoreCommand(args)
	TITLE:SetText("Raw Scoreboard");

	TF = TextFormat.Create("");

	TF:AppendText("Player.GetInfo()\n");
	TF:AppendText(table.show(Player.GetInfo()));
	TF:AppendText(unicode.gsub(Player.GetInfo(), "^%[.+%]%s+", "") .. "\n");
	TF:AppendText("\n");

	TF:AppendText("\nPlayer.GetTeamId()\n");
	TF:AppendText(table.show(Player.GetTeamId()));
	TF:AppendText("\n");

	TF:AppendText("\nPlayer.GetTeamInfo(1)\n");
	TF:AppendText(table.show(Game.GetTeamInfo(1)));
	TF:AppendText("\n");

	TF:AppendText("\nPlayer.GetTeamInfo(2)\n");
	TF:AppendText(table.show(Game.GetTeamInfo(2)));
	TF:AppendText("\n");

	TF:AppendText("\nPlayer.GetTeamInfo(3)\n");
	TF:AppendText(table.show(Game.GetTeamInfo(3)));
	TF:AppendText("\n");

	--[[local teams = Game.GetTeams(false);
	TF:AppendText("\nPlayer.GetTeams(false)\n");
	TF:AppendText(table.show(teams));
	TF:AppendText("\n");]]

	local scoreboard = Player.GetScoreBoard();
	TF:AppendText("\nPlayer.GetScoreBoard()\n");
	TF:AppendText(table.show(scoreboard));

	TEXT:SetText(TF:GetString());
	UpdateScrollSize();
	OnOpen();
end

-- NalinTest command.
function OnNalinTestCommand(args)
	local func = "Test1";
	if args ~= nil then func = args[1] end

	local newargs = {};
	for i=2, #args do
		newargs[i-1] = args[i];
	end

	if t[func] then
		t[func](newargs);
	end
end

function t.Template(args)
	TITLE:SetText("Template");
	TF = TextFormat.Create("");
	-----



	-----
	TF:AppendText("\n");
	TEXT:SetText(TF:GetString());
	UpdateScrollSize();
	OnOpen();
end

function t.Test1(args)
	TITLE:SetText("Roster");
	TF = TextFormat.Create("");
	-----

	TF:AppendText(table.show(Squad.GetRoster()));

	-----
	TF:AppendText("\n");
	TEXT:SetText(TF:GetString());
	UpdateScrollSize();
	OnOpen();
end

function t.Test2(args)
	TITLE:SetText("API Dump");
	TF = TextFormat.Create("");
	-----

	local search = {
		PvP = PvP,
		Chat = Chat,
		Game = Game,
		Player = Player,
		Squad = Squad,
		Platoon = Platoon,
	};

	for name, obj in pairs(search) do
		local s = "";
		for k, v in pairs(obj) do
			s = s..name.."."..tostring(k).."\n";
		end
		TF:AppendText(s);
	end

	-----
	TF:AppendText("\n");
	TEXT:SetText(TF:GetString());
	UpdateScrollSize();
	OnOpen();
end

function t.Test3(args)
	TITLE:SetText("API Dump");
	TF = TextFormat.Create("");
	-----

	TF:AppendText("Squad.GetRoster()\n");
	TF:AppendText(table.show(Squad.GetRoster()));
	TF:AppendText("\n");

	TF:AppendText("Squad.IsLeaderOnSameInstance:\n");
	TF:AppendText(tostring(Squad.IsLeaderOnSameInstance()).."\n");
	TF:AppendText("\n");

	TF:AppendText("Squad.GetLeader:\n");
	TF:AppendText(table.show(Squad.GetLeader()));
	TF:AppendText("\n");

	TF:AppendText("Player.GetInfo:\n");
	TF:AppendText(table.show(Player.GetInfo()));
	TF:AppendText("\n");

	TF:AppendText("Player.GetCharacterId:\n");
	TF:AppendText(table.show(Player.GetCharacterId()));
	TF:AppendText("\n");

	TF:AppendText("Squad.GetQueueRestrictions:\n");
	TF:AppendText(table.show(Squad.GetQueueRestrictions()));
	TF:AppendText("\n");

	-----
	TF:AppendText("\n");
	TEXT:SetText(TF:GetString());
	UpdateScrollSize();
	OnOpen();
end

function t.TargetInfo(args)
	TITLE:SetText("Target Info");
	TF = TextFormat.Create("");
	-----

	TF:AppendText("Game.GetTargetInfo("..args[1]..")\n");
	TF:AppendText(table.show(Game.GetTargetInfo(args[1])));

	-----
	TF:AppendText("\n");
	TEXT:SetText(TF:GetString());
	UpdateScrollSize();
	OnOpen();
end

function t.Cert(args)
	TITLE:SetText("Cert Info");
	TF = TextFormat.Create("");
	-----

	local cert = Game.GetCertificationInfo(args[1]);

	TF:AppendText("Game.GetCertificationInfo("..args[1]..")\n");
	TF:AppendText(table.show(cert));

	-----
	TF:AppendText("\n");
	TEXT:SetText(TF:GetString());
	UpdateScrollSize();
	OnOpen();
end

function t.PlaySound(args)
	System.PlaySound(args[1]);
end

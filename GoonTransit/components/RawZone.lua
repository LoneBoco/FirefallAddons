require "unicode"
require "table"
require "lib/lib_RowScroller"
require "lib/lib_WebCache"
require "./lib/lib_TableShow"
require "./lib/lib_GoonTransit"


-- Raw zone listing containers.
local FRAME = Component.GetFrame("RawZoneList");
local RAWZONE = {
	TITLE = FRAME:GetChild("Title"),
	BODY = FRAME:GetChild("Body"),
	SCROLL = nil,
};

local WebUrls = {};


RawZone = {};


function RawZone.Init()
	WebUrls["zone_list"] = WebCache.MakeUrl("zone_list");
	WebCache.Subscribe(WebUrls["zone_list"], RawZone.OnZoneListResponse, false);

	-- Create our widgets.
	RAWZONE.SCROLL = RowScroller.Create(RAWZONE.BODY:GetChild("group.wrapper"));

	-- Allow the panel to be moved.
	MovablePanel.ConfigFrame({
		frame = FRAME,
		MOVABLE_PARENT = RAWZONE.TITLE:GetChild("MovableParent"),
	});

	-- Bind the close button and the scroller.
	GT.Bind_Close(RAWZONE.TITLE, function() FRAME:Hide() end);
	GT.Bind_Scroll(RAWZONE.SCROLL, RAWZONE.BODY:GetChild("group.wrapper.zonelist"), 15, 15, 10);
end

function RawZone.Open()
	WebCache.QuickUpdate(WebUrls["zone_list"]);
	Component.SetInputMode("cursor");
	FRAME:ParamTo("alpha", 1, 0.1);
	System.PlaySound("panel_open");
end

function RawZone.Close()
	Component.SetInputMode("game");
	FRAME:ParamTo("alpha", 0, 0.1);
	FRAME:Hide(true, 0.1);
	System.PlaySound("panel_close");
end

function RawZone.OnZoneListResponse(resp, err)
	if resp == nil then return end

	-- Set the body text to the response.
	local zonelist = RAWZONE.BODY:GetChild("group.wrapper.zonelist");
	zonelist:SetText(table.show(resp));

	-- Update scroll.
	local row_h = (zonelist:GetNumLines() + 1) * zonelist:GetLineHeight();
	zonelist:SetDims("top:_;height:"..row_h);
	RAWZONE.SCROLL:GetRow(1):UpdateSize({height=row_h});
	RAWZONE.SCROLL:UpdateSize();
end

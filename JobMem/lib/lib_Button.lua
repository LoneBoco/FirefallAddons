
-- ------------------------------------------
-- Button - Creates a text labeled button
--   by: John Su
-- ------------------------------------------

--[[ Usage:
	BUTTON = Button.Create(PARENT)					-- creates a Dialog Button
	BUTTON:Destroy()								-- Removes the button

	BUTTON:Bind(function[, params...])				-- binds a function to call when the button is pressed; will call the function with supplied params if present
														will also fire if focusable and the user hits enter when it has focus via the OnSubmit event
	BUTTON:Enable(enabled)							-- enables the button
	enabled = BUTTON:IsEnabled()					-- returns true if the button is enabled
	BUTTON:TintPlate(color)							-- colors the button
	BUTTON:TintPlateTo(color, [duration, delay, method]) --changes the color of the button over time (during this time, refresh will not work so mouse overs won't change the color)

	BUTTON:SetFont(font)							-- overrides the default/auto font
	BUTTON:SetText(text[, autosize])				-- sets the text of the button (font is selected based on height at the time of the call)
														if [autosize] is present, will call BUTTON:Autosize(autosize)
	BUTTON:SetTextKey(text[, autosize])				-- same as BUTTON:SetText(), but accepts a localization key instead of a text string
	BUTTON:FosterLabel(WIDGET)						-- substitute a custom widget in place of the text label
	BUTTON:Autosize([align, dur])					-- automatically resizes button to fit the label; [align] can be "left" "right" or "center" (default)
														if [dur] is specified, will animate to these new dims over that time (default: 0)
	{width,height} = BUTTON:GetLabelSize()			-- returns the width and height of the label
	WIDGET = BUTTON:GetWidget()						-- returns the base widget (for fostering or shadowing)

	BUTTON:Pulse([should_pulse, args])				-- begins (or stops, if should_pulse = false) pulsing of the button to attract the user's attention.
														args is an optional table with optional fiels:
															tint	= color to pulse to (defaults to a brighter tint)
															freq	= cycles per second (defaults to 0.8 Hz)
															cycles	= number of times to pulse (defaults to -1, which is endless)
														button will not pulse while mouse is over it

	BUTTON:SetPressSound(BUTTON, sound)
	BUTTON:SetMouseOverSound(BUTTON, sound)

	BUTTON is also an EventDispatcher (see lib_EventDispatcher) which dispatches the following events:
		"OnMouseEnter",
		"OnMouseLeave",
		"OnMouseDown",
		"OnMouseUp",
		"OnScroll",
		"OnSubmit",
		"OnGotFocus",
		"OnLostFocus",
		"OnRightMouse",
--]]

if Button then
	-- only include once
	return nil
end
Button = {}
local Private = {}
local Api = {}

require "math";
require "unicode";
require "lib/lib_Callback2";
require "lib/lib_HoloPlate";
require "lib/lib_Colors";
require "lib/lib_EventDispatcher";

-- ------------------------------------------
-- CONSTANTS
-- ------------------------------------------
Button.DEFAULT_PLATE_COLOR = "#0E7192";				--Default
Button.DEFAULT_BLUE_COLOR = "#106288";				--Secondary
Button.DEFAULT_WHITE_COLOR = "#9C9C9C";				--Cancel
Button.DEFAULT_GREEN_COLOR = "#629E0A";				--Success
Button.DEFAULT_RED_COLOR = "#8E0909";				--Danger
Button.DEFAULT_YELLOW_COLOR = "#FFFF00";			--Store

local c_ButtonMetatable = {
	__index = function(t,key) return Api[key]; end,
	__newindex = function(t,k,v) error("cannot write to value '"..k.."' in ITEM"); end
};

local bp_Button =
	[[<FocusBox dimensions="dock:fill" class="ui_button">
		<Group name="skin" dimensions="dock:fill"/>
		<Group name="label" dimensions="dock:fill">
			<Text name="text" dimensions="width:100%; center-x:50%; center-y:47%; height:100%" style="font:Demi_10; halign:center; valign:center; wrap:false; clip:true; eatsmice:false" />
		</Group>
	</FocusBox>]]

local c_FontMapping = {	-- c_FontMapping[i] = {min_height, font_name}
	{16, "Demi_7"},
	{20, "Demi_8"},
	{24, "Demi_9"},
	{30, "Demi_10"},
	{36, "Demi_11"},
	{40, "Demi_12"},
	{50, "Demi_15"},
	{60, "Demi_20"},
	{1e8, "Demi_30"},
}

-- ------------------------------------------
-- GLOBAL FUNCTIONS
-- ------------------------------------------
function Button.Create(PARENT)
	local WIDGET = Component.CreateWidget(bp_Button, PARENT);

	local BUTTON = {
		GROUP = WIDGET,

		PLATE = HoloPlate.Create(WIDGET:GetChild("skin")),

		LABEL_GROUP = WIDGET:GetChild("label"),
		FOSTER_LABEL = false,
		TEXT_LABEL = WIDGET:GetChild("label.text"),

		OnPress = false,	-- on press
		align = "center",	-- last alignment
		enabled = true,
		mouse_over = false,
		mouse_down = false,
		has_focus = false,

		font = false,
		tint = false,
		pulse_args = false,
		CB2_Pulse = false,

		preventRefresh = false,

		sounds = {},
	}
	BUTTON.DISPATCHER = EventDispatcher.Create(BUTTON);
	BUTTON.DISPATCHER:Delegate(BUTTON);

	local FOCUS = WIDGET;
	FOCUS:BindEvent("OnMouseEnter", function(args)
		Private.OnButtonMouseEnter(BUTTON, args);
	end);
	FOCUS:BindEvent("OnMouseLeave", function(args)
		Private.OnButtonMouseLeave(BUTTON, args);
	end);
	FOCUS:BindEvent("OnMouseDown", function(args)
		Private.OnButtonMouseDown(BUTTON, args);
	end);
	FOCUS:BindEvent("OnMouseUp", function(args)
		Private.OnButtonMouseUp(BUTTON, args);
	end);
	FOCUS:BindEvent("OnSubmit", function(args)
		Private.OnButtonSubmit(BUTTON, args);
	end);
	FOCUS:BindEvent("OnGotFocus", function(args)
		Private.OnButtonGotFocus(BUTTON, args);
	end);
	FOCUS:BindEvent("OnLostFocus", function(args)
		Private.OnButtonLostFocus(BUTTON, args);
	end);

	local other_events = {"OnScroll", "OnRightMouse"}
	for _, event in ipairs(other_events) do
		FOCUS:BindEvent(event, function(args)
			BUTTON:DispatchEvent(event, args)
		end)
	end

	setmetatable(BUTTON, c_ButtonMetatable);
	BUTTON:TintPlate(Button.DEFAULT_PLATE_COLOR);

	return BUTTON;
end

-- ------------------------------------------
-- BUTTON API FUNCTIONS
-- ------------------------------------------
-- forward the following methods to the GROUP widget
local COMMON_METHODS = {
	"GetDims", "SetDims", "MoveTo", "QueueMove", "FinishMove",
	"GetParam", "SetParam", "ParamTo", "CycleParam", "QueueParam", "FinishParam",
	"SetFocusable", "SetFocus", "ReleaseFocus", "HasFocus",
	"Show", "Hide", "IsVisible", "GetBounds", "SetTag", "GetTag"
};
for _, method_name in pairs(COMMON_METHODS) do
	Api[method_name] = function(BUTTON, ...)
		return BUTTON.GROUP[method_name](BUTTON.GROUP, ...);
	end
end

function Api.Destroy(BUTTON)
	BUTTON.DISPATCHER:Destroy();
	if (BUTTON.CB2_Pulse) then
		BUTTON.CB2_Pulse:Release();
	end
	BUTTON.PLATE:Destroy();
	Component.RemoveWidget(BUTTON.GROUP);
	for k,v in pairs(BUTTON) do
		BUTTON[k] = nil;
	end
end

function Api.TintPlate(BUTTON, color)
	if BUTTON.tint ~= color then
		BUTTON.tint = color;
		BUTTON.PLATE:SetColor(color);
		Private.RefreshButtonState(BUTTON);
	end
end

function Api.TintPlateTo(BUTTON, color,...)
	local arg = {n=select('#',...),...}

	--prevent the refresh function from overwriting our tint changes for the duration
	cbtime = 0;
	if(arg[1] ~= nil) then
		cbtime = arg[1]
	end
	BUTTON.tint = color
	Private.RefreshButtonState(BUTTON, cbtime)
	if cbtime > 0 then
		BUTTON.preventRefresh = true
		callback(function()
			BUTTON.preventRefresh = false
		end, nil, cbtime)
	end
end

function Api.Bind(...)
	local arg = {n=select('#',...),...}

	local BUTTON = arg[1];
	local func = arg[2];
	local param_start, param_stop = 3, arg.n;
	assert(not func or type(func) == "function", "can only bind functions");
	if (func) then
		BUTTON.OnPress = function()
			func(unpack(arg, param_start, param_stop));
		end
	else
		BUTTON.OnPress = false;
	end
end

function Api.IsEnabled(BUTTON)
	return BUTTON.enabled;
end

function Api.Enable(BUTTON, ...)
	local arg = {n=select('#',...),...}

	--allow NULL to work as true to mimic Show() and nil to work as false to mimic Show(nil)
	if arg[1] or arg.n == 0 then
		BUTTON.enabled = true;
	else
		BUTTON.enabled = false;
	end
	Private.RefreshButtonState(BUTTON);
end

function Api.Disable(BUTTON, ...) --inverted Enable
	local arg = {n=select('#',...),...}
	BUTTON:Enable(not (arg[1] or arg.n == 0))
end

function Api.SetFont(BUTTON, font)
	BUTTON.font = font;
	BUTTON.TEXT_LABEL:SetFont(font);
end

function Api.SetText(BUTTON, text, autosize)
	if (not BUTTON.font) then
		local height = BUTTON.GROUP:GetBounds().height;
		-- select font based on height
		for i, height_font in ipairs(c_FontMapping) do
			if (height < height_font[1]) then
				BUTTON.TEXT_LABEL:SetFont(height_font[2]);
				break;
			end
		end
	end
	BUTTON.TEXT_LABEL:SetText(text);
	if (BUTTON.FOSTER_LABEL) then
		BUTTON:FosterLabel(nil);
	end

	if (autosize) then
		BUTTON:Autosize(autosize);
	end
end

function Api.SetTextKey(BUTTON, text_key, autosize)
	return BUTTON:SetText(Component.LookupText(text_key), autosize);
end

function Api.FosterLabel(BUTTON, WIDGET)
	if (BUTTON.FOSTER_LABEL) then
		Component.FosterWidget(BUTTON.FOSTER_LABEL, nil);
	end
	BUTTON.FOSTER_LABEL = WIDGET or false;
	if (BUTTON.FOSTER_LABEL) then
		Component.FosterWidget(BUTTON.FOSTER_LABEL, BUTTON.LABEL_GROUP);
		BUTTON.TEXT_LABEL:Show(false);
	else
		BUTTON.TEXT_LABEL:Show(true);
	end
end

function Api.GetLabelSize(BUTTON)
	if (BUTTON.FOSTER_LABEL) then
		return BUTTON.FOSTER_LABEL:GetBounds();
	else
		return BUTTON.TEXT_LABEL:GetTextDims(false);
	end
end

function Api.GetWidget(BUTTON)
	return BUTTON.GROUP;
end

function Api.Autosize(BUTTON, align, dur)
	if (not align or align == true) then
		align = BUTTON.align;	-- default to last align
	end
	assert(align == "left" or align == "right" or align == "center", "align can be 'left', 'right', or 'center'");
	BUTTON.align = align;
	if (align == "center") then
		align = "center-x";	-- for use in dims setting
	end
	local content_bounds = BUTTON:GetLabelSize();
	local button_bounds = BUTTON:GetBounds();
	if (BUTTON.FOSTER_LABEL) then
		-- resize so that LABEL_GROUP matches FOSTER_LABEL bounds
		local label_bounds = BUTTON.LABEL_GROUP:GetBounds();
		local diff = {	width = content_bounds.width - label_bounds.width,
						height = content_bounds.height - label_bounds.height,
					};
		BUTTON.GROUP:MoveTo(align..":_; center-y:_; width:"..(button_bounds.width + diff.width)..
							"; height:"..(button_bounds.height + diff.height), dur or 0);
	else
		-- resize to accomodate text
		BUTTON.GROUP:MoveTo(align..":_; width:"..(content_bounds.width+button_bounds.height), dur or 0);
	end
end

function Api.Pulse(BUTTON, should_pulse, args)
	if (not should_pulse) then
		if (BUTTON.CB2_Pulse) then
			BUTTON.CB2_Pulse:Cancel();
			BUTTON.CB2_Pulse = false;
		end
		BUTTON.pulse_args = false;
	else
		args = args or {};
		BUTTON.pulse_args = {
			tint = args.tint,
			freq = args.freq or 0.8,
			cycles = args.cycles or -1,
		};
		assert(BUTTON.pulse_args.cycles ~= 0, "invalid cycles");
		assert(BUTTON.pulse_args.freq > 0, "invalid frequency");
		if (not BUTTON.pulse_args.tint) then
			BUTTON.pulse_args.tint = Private.AdjustColor(BUTTON.tint, .2);
			BUTTON.pulse_args.tint:Multiply(1.25);
		end

		if (not BUTTON.CB2_Pulse) then
			BUTTON.CB2_Pulse = Callback2.Create();
			BUTTON.CB2_Pulse:Bind(Private.PulseButton, BUTTON);
			BUTTON.CB2_Pulse:Schedule(1/BUTTON.pulse_args.freq);
		end
		BUTTON.CB2_Pulse:Execute();
	end
end

function Api.SetPressSound(BUTTON, sound)
	BUTTON.sounds.on_press = sound;
end

function Api.SetMouseOverSound(BUTTON, sound)
	BUTTON.sounds.on_mouseover = sound;
end

-- ------------------------------------------
-- LOCAL FUNCTIONS
-- ------------------------------------------
function Private.SetChildrenParam(WIDGET, ...)
	WIDGET:SetParam(...);
end

function Private.ParamChildrenTo(WIDGET, ...)
	WIDGET:ParamTo(...);
end

function Private.QueueParamChildrenTo(WIDGET, ...)
	WIDGET:QueueParam(...);
end

function Private.OnButtonMouseEnter(BUTTON, args)
	BUTTON.mouse_over = true;
	Private.RefreshButtonState(BUTTON);
	if( BUTTON.sounds.on_mouseover )then
		System.PlaySound(tostring(BUTTON.sounds.on_mouseover));
	end

	BUTTON:DispatchEvent("OnMouseEnter", args);
end

function Private.OnButtonMouseLeave(BUTTON, args)
	BUTTON.mouse_down = false
	BUTTON.mouse_over = false;
	Private.RefreshButtonState(BUTTON);
	BUTTON:DispatchEvent("OnMouseLeave", args);
end

function Private.OnButtonMouseDown(BUTTON, args)
	BUTTON.mouse_down = true;
	Private.RefreshButtonState(BUTTON, 0);
	if (BUTTON.enabled and BUTTON.OnPress) then
		if( BUTTON.sounds.on_press )then
			System.PlaySound(tostring(BUTTON.sounds.on_press));
		end

		BUTTON.OnPress();
	end
	BUTTON:DispatchEvent("OnMouseDown", args);
end

function Private.OnButtonSubmit(BUTTON, args)
	BUTTON:DispatchEvent("OnSubmit", args);
	if (BUTTON.enabled and BUTTON.OnPress) then
		BUTTON.OnPress();
	end
end

function Private.OnButtonMouseUp(BUTTON, args)
	BUTTON.mouse_down = false;
	Private.RefreshButtonState(BUTTON, 0);
	BUTTON:DispatchEvent("OnMouseUp", args);
end

function Private.OnButtonGotFocus(BUTTON, args)
	BUTTON.has_focus = true;
	Private.RefreshButtonState(BUTTON, 0);
	BUTTON:DispatchEvent("OnGotFocus", args);
end

function Private.OnButtonLostFocus(BUTTON, args)
	BUTTON.has_focus = false;
	Private.RefreshButtonState(BUTTON, 0);
	BUTTON:DispatchEvent("OnLostFocus", args);
end

function Private.RefreshButtonState(BUTTON, dur)
	if(BUTTON.preventRefresh == true) then
		return;
	end

	dur = dur or .1;
	local hsv = Colors.toHSV(BUTTON.tint);
	if (BUTTON.enabled) then
		BUTTON.GROUP:SetCursor("sys_hand")
		BUTTON.PLATE.OUTER:ParamTo("tint", Private.AdjustColor(hsv, .2), dur);	-- brighter rim, by HoloPlate rules
		if (BUTTON.mouse_down) then
			-- mouse down; darken
			BUTTON.PLATE.INNER:ParamTo("tint", Private.AdjustColor(hsv, -.25), dur);
			BUTTON.PLATE.SHADE:ParamTo("tint", Private.AdjustColor(hsv, -.5), dur);
		elseif (BUTTON.mouse_over or BUTTON.has_focus) then
			-- mouse over; brighten
			BUTTON.PLATE.INNER:ParamTo("tint", Private.AdjustColor(hsv, .1), dur);
			BUTTON.PLATE.SHADE:ParamTo("tint", Private.AdjustColor(hsv, -.1), dur);
			--BUTTON.PLATE.INNER:ParamTo("tint", Colors.Create({h=hsv.h, s=hsv.s, v=hsv.v}), dur);
		else
			-- no mouse; dimmed
			BUTTON.PLATE.INNER:ParamTo("tint", Private.AdjustColor(hsv, -.1), dur);
			BUTTON.PLATE.SHADE:ParamTo("tint", Private.AdjustColor(hsv, -.4), dur);
		end

		BUTTON.LABEL_GROUP:ParamTo("alpha", 1, dur);
		BUTTON.PLATE.SHADE:ParamTo("alpha", 1, dur);
	else
		BUTTON.GROUP:SetCursor("sys_arrow")
		BUTTON.PLATE.SHADE:ParamTo("alpha", 0, dur);

		hsv.s = hsv.s * .2;	-- desaturate
		BUTTON.PLATE.INNER:ParamTo("tint", Private.AdjustColor(hsv, -.3), dur);
		BUTTON.PLATE.OUTER:ParamTo("tint", Private.AdjustColor(hsv, -.1), dur);

		BUTTON.LABEL_GROUP:ParamTo("alpha", 0.65, dur);
	end
end

function Private.PulseButton(BUTTON)
	if BUTTON.pulse_args == false then
		return
	end

	local dur = 1/BUTTON.pulse_args.freq;
	if (not BUTTON.mouse_over and not BUTTON.has_focus) then
		-- glow
		BUTTON.PLATE.INNER:ParamTo("exposure", -0.1, dur*.5, 0, "smooth");
		BUTTON.PLATE.OUTER:ParamTo("exposure", 0.5, dur*.5, 0, "smooth");
		BUTTON.PLATE:ColorTo(BUTTON.pulse_args.tint, dur*.5, 0, "smooth");
		-- normal
		BUTTON.PLATE.INNER:QueueParam("exposure", -0.3, dur*.5, 0, "smooth");
		BUTTON.PLATE.OUTER:QueueParam("exposure", 0.1, dur*.5, 0, "smooth");
		BUTTON.PLATE:QueueColor(BUTTON.tint, dur*.5, 0, "smooth");
	end
	BUTTON.pulse_args.cycles = BUTTON.pulse_args.cycles - 1;
	if (BUTTON.pulse_args.cycles ~= 0) then
		-- <0 is infinite cycling
		BUTTON.CB2_Pulse:Schedule(dur);
	end
end

function Private.AdjustColor(color, delta_v)
	local hsv = Colors.toHSV(color);
	if (hsv.h >= 30 and hsv.h <= 60 and delta_v < 0) then
		-- yellow dims to orange/red
		hsv.h = (hsv.h - 30) * (-delta_v*.5 + .5) + 30;
	elseif (hsv.h >= 60 and hsv.h <= 120 and delta_v > 0) then
		-- green brightens to yellow
		hsv.h = (hsv.h - 60) * (1-delta_v) + 60;
	end
	hsv.v = hsv.v + delta_v;
	return Colors.Create(hsv);
end

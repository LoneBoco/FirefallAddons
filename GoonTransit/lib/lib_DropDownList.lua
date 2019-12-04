
-- ------------------------------------------
-- lib_DropDownList
--   by: James Harless
-- ------------------------------------------
-- Lightly based off lib_Button for UI Consistency

-- WIP TODO:
-- Add More Features!

--[[ Usage:
	DROPDOWN = DropDownList.Create(PARENT)	-- Creates a DropDown List
	DROPDOWN:Destroy()						-- Removes the button

	DROPDOWN:SetTitle(text)					-- Adds a title text to show in button when no item is selected
	DROPDOWN:AddItem(text, value)		-- Adds an Item to the List with the return value set
	DROPDOWN:ClearItems()					-- Clears Item Listing
	DROPDOWN:GetSelected()					-- Returns the Value of the selected Item
	DROPDOWN:SetSelectedByValue(value)		-- Selects an Item by Value (Manual)
	DROPDOWN:SetSelectedByIndex(value)		-- Selects an Item by Index (Manual)
	DROPDOWN:SetListMaxSize(number)			-- Sets the max number of item entries to be displayed at once.

	DROPDOWN:BindOnSelect(function)			-- Function called when an item is selected, returns value, widget

	DROPDOWN:TintPlate(color, [dur])		-- Tints the Plate and Dropdown Menu (darker) in the Color of your choice

	DROPDOWN:ForceFlip([bool])				-- Forces the Dropdown to unfold up instead of down

	DROPDOWN:Enable([bool])					-- Enables or Disables the Dropdown Button
	DROPDOWN:Disable([bool])				-- Disables or Enables the Dropdown Button

	DROPDOWN also dispatches the following events using lib_EventDispatcher:
		"OnMouseEnter",
		"OnMouseLeave",
		"OnMouseDown",
		"OnMouseUp",
--]]

if DropDownList then
	return nil
end
DropDownList = {}

require "table"
require "math"
require "lib/lib_EventDispatcher"
require "lib/lib_HoloPlate"
require "./lib/lib_Slider"
require "lib/lib_Colors"

-- ------------------------------------------
-- CONSTANTS
-- ------------------------------------------

local SCREEN_FLIP_OFFSET = 10	-- 10px offset
local DROPDOWN_DEPTH = -50	-- Must appear in front at all times
local DROPDOWN_DUR	= 0.15
local DROPDOWN_SPACING = 20	-- 20px space border
local MOUSELEAVE_TIMER = 0.25
local ITEM_HEIGHT = 29
local ITEM_COLOR_HIGHLIGHT = "#505050"
local ITEM_COLOR_DEFAULT = "#000000"

local PRIVATE = {}
local API = {}

local DropDownList_MT = {__index = function(self, key) return API[key] end}

DropDownList.DEFAULT_COLOR = "#0E7192"
DropDownList.DEFAULT_LIST_SIZE = 8

-- PanelFrame, used for detecting if the cursor leaves bounds
local BP_FRAME = [[<PanelFrame dimensions="dock:fill" topmost="true" depth="1"/>]]
local BP_SCREENFOCUS = [[<FocusBox dimensions="dock:fill" style="cursor:sys_arrow"/>]]

local BP_DROPDOWNBUTTON = [[<Group dimensions="top:0; left:0; width:100%; height:100%">
		<FocusBox name="button" dimensions="width:100%; center-x:50%; top:0; height:100%" class="ui_button">
			<Group name="skin" dimensions="dock:fill"/>
			<StillArt name="arrow" dimensions="right:100%-11; center-y:50%; height:8; width:12" style="texture:arrows; region:down; exposure:0; alpha:0.4; eatsmice:false"/>
			<Text name="text" dimensions="left:5; right:100%; top:0; bottom:100%" style="font:UbuntuMedium_9; halign:left; valign:center; wrap:false; clip:true; cursor:sys_hand; eatsmice:false" />
		</FocusBox>
	</Group>]]

local BP_DROPDOWNLIST =[[<FocusBox dimensions="dock:fill">
		<Group name="ddl" dimensions="left:]]..DROPDOWN_SPACING..[[; right:100%-]]..DROPDOWN_SPACING..[[; top:]]..DROPDOWN_SPACING..[[; bottom:100%-]]..DROPDOWN_SPACING..[[">
			<Group name="skin" dimensions="dock:fill"/>
			<Group name="btn_mask" dimensions="dock:fill">
				<StillArt name="seperator" dimensions="left:5; bottom:100%; right:100%-5; height:1" style="texture:colors; region:white; alpha:0.5"/>
				<StillArt name="arrow" dimensions="right:100%-11; center-y:50%; height:8; width:12" style="texture:arrows; region:down; exposure:0; alpha:0.8; eatsmice:false"/>
				<Text name="text" dimensions="left:5; right:100%; top:0; bottom:100%" style="font:UbuntuMedium_9; halign:left; valign:center; wrap:false; clip:true; cursor:sys_hand; eatsmice:false" />
			</Group>
			<FocusBox name="button" dimensions="top:0; bottom:100%; left:0; right:100%" style="cursor:sys_hand"/>
			<FocusBox name="focusgroup" dimensions="top:0; bottom:100%; left:0; right:100%" >
				<ListLayout name="list" dimensions="left:2; right:100%-27; top:2; bottom:100%-2" style="clip-children:true"/>
				<Group name="slider" dimensions="left:100%-17; right:100%-3; top:2; bottom:100%-2"/>
			</FocusBox>
		</Group>
	</FocusBox>]]

local BP_LISTITEM = [[<FocusBox dimensions="left:0; right:100%; top:0; bottom:29" class="ui_button">
		<Border name="background" dimensions="top:1; bottom:100%-1; left:0; right:100%;" class="RoundedBorders" style="alpha:0; padding:6; tint:#000000;" />
		<Text name="text" dimensions="left:3; right: 100%; top:0; bottom:100%" style="font:UbuntuMedium_8; halign:left; valign:center; wrap:false; clip:true; cursor:sys_hand; eatsmice:false" key="{Empty Field}" />
	</FocusBox>]]

-- ------------------------------------------
-- GLOBAL FUNCTIONS
-- ------------------------------------------

function DropDownList.Create(PARENT, Font)
	local WIDGET		= Component.CreateWidget(BP_DROPDOWNBUTTON, PARENT)
	local DDL 			= {
		-- Widgets
		GROUP			= WIDGET,
		PLATE			= HoloPlate.Create(WIDGET:GetChild("button.skin")),

		BUTTON			= WIDGET:GetChild("button"),
		TEXT			= WIDGET:GetChild("button.text"),
		ARROW			= WIDGET:GetChild("button.arrow"),

		DROPDOWN_FRAME	= false,
		DROPDOWN		= false,
		DROPDOWN_FOCUS	= false,
		DROPDOWN_LIST	= false,
		DROPDOWN_BD		= false,
		DROPDOWN_BTN	= false,

		SLIDER			= false,

		LIST_WIDGETS 	= {},	-- List Widgets

		-- Variables
		List_Items		= {},	-- Data		{text="", value=X, color=""}
		List_Selected	= nil,
		List_Size		= 0,
		List_Title		= nil,
		Slider_Offset	= 0,	-- Default to Top
		Item_Width		= 0,
		releaseReady	= false,
		forceFlip		= false,
		flipped			= false,
		font			= Font,

		cb_automator	= nil,

		enabled			= true,
		list_expanded	= false,
		OnSelect 		= nil,
	}
	DDL.DISPATCHER = EventDispatcher.Create(DDL)
	DDL.DISPATCHER:Delegate(DDL)

	if Font then
		DDL.TEXT:SetFont(Font)
	end

	DDL.BUTTON:BindEvent("OnMouseEnter", function()
		PRIVATE.OnButtonMouseEnter(DDL)
	end)

	DDL.BUTTON:BindEvent("OnMouseLeave", function()
		PRIVATE.OnButtonMouseLeave(DDL)
	end)

	DDL.BUTTON:BindEvent("OnMouseDown", function()
		PRIVATE.OnButtonMouseDown(DDL)
	end)

	DDL.BUTTON:BindEvent("OnMouseUp", function()
		PRIVATE.OnButtonMouseUp(DDL)
	end)

	setmetatable(DDL, DropDownList_MT)
	DDL:SetListMaxSize(DropDownList.DEFAULT_LIST_SIZE)
	DDL:TintPlate(DropDownList.DEFAULT_COLOR)

	return DDL
end

-- ------------------------------------------
--  DROPDOWN API
-- ------------------------------------------

-- forward the following methods to the GROUP widget
local COMMON_METHODS = {
	"GetDims", "SetDims", "MoveTo", "QueueMove", "FinishMove",
	"GetParam", "SetParam", "ParamTo", "CycleParam", "QueueParam", "FinishParam",
	"SetFocusable", "SetFocus", "ReleaseFocus", "HasFocus",
	"Show", "Hide", "IsVisible", "GetBounds", "SetTag", "GetTag"
};
for _, method_name in pairs(COMMON_METHODS) do
	API[method_name] = function(DDL, ...)
		return DDL.GROUP[method_name](DDL.GROUP, ...);
	end
end

function API.SetFocusable(self, bool)
	self.BUTTON:SetFocusable(bool)
end

function API.AddItem(self, text, value, color, sub)
	--if not text or not value then
	--	warn("List Item must have both text & value! DropDownList:AddListItem(string, value)")
	--end
	table.insert(self.List_Items, {text=text, value=value, color=color, sub=sub})
	if #self.List_Items == 1 and not self.List_Title then
		self.List_Selected = 1
		PRIVATE.SetButtonTextByIndex(self)
	end

	--self:Enable(#self.List_Items > 0)

	return #self.List_Items
end

function API.SetTitle(self, title)
	assert(type(title) == "string")

	self.List_Title = title
	if not self.List_Selected then
		PRIVATE.SetButtonText(self, title)
	end
end

function API.GetSelected(self)
	local index = self.List_Selected
	if not (index and self.List_Items[index]) then
		return nil
	end
	local value = self.List_Items[index].value
	local text = self.List_Items[index].text
	return value, text, index
end

function API.SetSelectedByValue(self, value)
	for index, item in ipairs(self.List_Items) do
		if item.value == value then
			self.List_Selected = index
			PRIVATE.SetButtonTextByIndex(self)
			PRIVATE.OnItemSelect(self)
			break
		end
	end
end

function API.SetSelectedByIndex(self, index)
	if not index and self.List_Title then
		PRIVATE.SetButtonText(self, self.List_Title)
		self.List_Selected = nil
	elseif self.List_Items[index] then
		self.List_Selected = index
		PRIVATE.SetButtonTextByIndex(self)
		PRIVATE.OnItemSelect(self)
	end
end

function API.ClearItems(self)
	self.List_Items = {}
	PRIVATE.SetButtonText(self, "")
end

function API.SetListMaxSize(self, size)
	self.List_Size = size
end

function API.BindOnSelect(self, func)
	if type(func) ~= "function" then
		warn("Must be a function!")
		return nil
	end
	self.OnSelect = func
end

function API.TintPlate(self, color, dur)
	self.color = color
	if not dur then
		self.PLATE:SetColor(color)
	else
		self.PLATE:ColorTo(color, dur)
	end
end

function API.ForceFlip(self, state)
	self.forceFlip = state
end

function API.Enable(self, ...)
	local arg = {n=select('#',...),...}

	--allow NULL to work as true to mimic Show() and nil to work as false to mimic Show(nil)
	self.enabled = arg[1] or arg.n == 0
	if self.enabled then
		self.PLATE:ColorTo(self.color, 0.15)
		self.BUTTON:SetCursor("sys_hand")
	else
		self.PLATE:ColorTo("#A0A0A0", 0.15)
		self.BUTTON:SetCursor("sys_arrow")
	end
end

function API.Disable (self, ...) --inverted Enable
	local arg = {n=select('#',...),...}
	self:Enable(not (arg[1] or arg.n == 0))
end

-- Widget Compatibility API Functions
API.ClearOptions = API.ClearItems
API.AddOption = API.AddItem
API.Query = API.GetSelected
API.Select = API.SetSelectedByIndex

-- ------------------------------------------
-- PRIVATE FUNCTIONS
-- ------------------------------------------
function PRIVATE.CreateFrame(self)
	if not self.FRAME then
		self.FRAME = Component.CreateFrame(BP_FRAME, "DropDownList")
		self.FOCUS = Component.CreateWidget(BP_SCREENFOCUS, self.FRAME)
		self.FRAME:Show(true)
		self.FOCUS:BindEvent("OnMouseEnter", function()
			if self.releaseReady then
				PRIVATE.ToggleList(self, false)
			end
		end)
		self.FOCUS:BindEvent("OnMouseDown", function()
			PRIVATE.ToggleList(self, false)
		end)
		self.FOCUS:BindEvent("OnRightMouse", function()
			PRIVATE.ToggleList(self, false)
		end)
	end
end

function PRIVATE.DestroyFrame(self)
	if self.FRAME then
		Component.RemoveWidget(self.FOCUS)
		Component.RemoveFrame(self.FRAME)
		self.FRAME = false
		self.FOCUS = false
		self.releaseReady = false
	end
end

function PRIVATE.RequestDropdown(self)
	PRIVATE.CreateFrame(self)

	local WIDGET		= Component.CreateWidget(BP_DROPDOWNLIST, self.FRAME)
	self.DROPDOWN		= WIDGET
	self.DROPDOWN_FOCUS	= WIDGET:GetChild("ddl.focusgroup")
	self.DROPDOWN_LIST	= WIDGET:GetChild("ddl.focusgroup.list")
	self.DROPDOWN_BD	= WIDGET:GetChild("ddl.skin")
	self.DROPDOWN_BTN	= WIDGET:GetChild("ddl.button")
	self.DROPDOWN_MASK 	= WIDGET:GetChild("ddl.btn_mask")
	self.DROPDOWN_TEXT	= self.DROPDOWN_MASK:GetChild("text")

	local plate = HoloPlate.Create(self.DROPDOWN_BD)
	plate:SetColor(self.color)
	plate.INNER:SetParam("exposure", -0.1, 0.1)
	plate.SHADE:SetParam("exposure", -0.4, 0.1)

	local text = ""
	local color = "#FFFFFF"
	if self.List_Title then
		text = self.List_Title
	elseif self.List_Selected then
		local item = self.List_Items[self.List_Selected]
		color = item.color or "#FFFFFF"

		text = item.text
		if item.sub then
			for i=self.List_Selected-1, 1, -1 do
				local prev_item = self.List_Items[i]
				if prev_item and not prev_item.sub then
					text = prev_item.text .. " - " .. text
					break
				end
			end
		end
	end
	if self.font then
		self.DROPDOWN_TEXT:SetFont(self.font)
	end
	self.DROPDOWN_TEXT:SetText(text)
	self.DROPDOWN_TEXT:SetTextColor(color, Colors.Multiply(color, 0.15))

	self.DROPDOWN_BTN:BindEvent("OnMouseEnter", function()
		PRIVATE.OnButtonMouseEnter(self)
		PRIVATE.SetMouseFocus(self)
	end)

	self.DROPDOWN_BTN:BindEvent("OnMouseLeave", function()
		PRIVATE.OnButtonMouseLeave(self)
	end)

	self.DROPDOWN_BTN:BindEvent("OnMouseDown", function()
		PRIVATE.OnButtonMouseDown(self)
	end)

	self.DROPDOWN_BTN:BindEvent("OnMouseUp", function()
		PRIVATE.OnButtonMouseUp(self)
	end)

	self.DROPDOWN:SetParam("alpha", 0)

	local enableSlider = ( #self.List_Items > self.List_Size )
	if enableSlider then
		self.SLIDER = Slider.Create(WIDGET:GetChild("ddl.focusgroup.slider"), "vertical")
		self.SLIDER.SLIDER_WIDGET:SetDims("width:15")
		self.SLIDER:SetMinPercent(0)
		self.SLIDER:SetMaxPercent(1)
		self.SLIDER:SetPercent(0)
		self.SLIDER:SetScrollSteps(1)
		self.SLIDER:BindEvent("OnStateChanged", function()
			local pct = self.SLIDER:GetPercent()
			PRIVATE.Slider_OnChange(self, pct)
		end)
		PRIVATE.SliderReset(self)
	end
	PRIVATE.SliderEnable(self, enableSlider)

	PRIVATE.RefreshListGroup(self)
	PRIVATE.Slider_OnChange(self, 0)
end

function PRIVATE.ClearDropdown(self)
	PRIVATE.ClearListGroup(self)

	if self.SLIDER then
		self.SLIDER:Destroy()
		self.SLIDER = false
	end

	if self.DROPDOWN then
		Component.RemoveWidget(self.DROPDOWN)
		self.DROPDOWN		= false
		self.DROPDOWN_FOCUS	= false
		self.DROPDOWN_LIST	= false
		self.DROPDOWN_BD	= false
		self.DROPDOWN_BTN	= false
	end

	PRIVATE.DestroyFrame(self)
end

function PRIVATE.OnButtonGotFocus(DDL)
	if not DDL.enabled then return nil end
	DDL.PLATE.INNER:ParamTo("exposure", -0.1, 0.1)
	DDL.PLATE.SHADE:ParamTo("exposure", -0.4, 0.1)
	DDL.ARROW:ParamTo("alpha", 0.8, 0.1)
end

function PRIVATE.OnButtonLostFocus(DDL)
	if not DDL.enabled then return nil end
	DDL.PLATE.INNER:ParamTo("exposure", -0.3, 0.1)
	DDL.PLATE.SHADE:ParamTo("exposure", -0.6, 0.1)
	DDL.ARROW:ParamTo("alpha", 0.4, 0.1)
end

function PRIVATE.OnButtonMouseEnter(DDL)
	if not DDL.enabled then return nil end
	PRIVATE.OnButtonGotFocus(DDL)
	--PRIVATE.SetMouseFocus(DDL, true)
	DDL:DispatchEvent("OnMouseEnter")
end

function PRIVATE.OnButtonMouseLeave(DDL)
	if not DDL.enabled then return nil end
	PRIVATE.OnButtonLostFocus(DDL)
	--PRIVATE.SetMouseFocus(DDL, false)
	DDL:DispatchEvent("OnMouseLeave")
end

function PRIVATE.OnButtonMouseDown(DDL)
	if not DDL.enabled then return nil end
	DDL.PLATE.INNER:ParamTo("exposure", -0.3, 0.1)
	DDL.PLATE.SHADE:ParamTo("exposure", -0.8, 0.1)
	DDL:DispatchEvent("OnMouseDown")
end

function PRIVATE.OnButtonMouseUp(DDL)
	if not DDL.enabled then return nil end
	DDL.PLATE.INNER:ParamTo("exposure", -0.1, 0.1)
	DDL.PLATE.SHADE:ParamTo("exposure", -0.4, 0.1)
	--PRIVATE.SliderReset(DDL)
	PRIVATE.ToggleList(DDL, not DDL.list_expanded)
	DDL:DispatchEvent("OnMouseUp")
end

function PRIVATE.CreateListItem(self, index)
	local ITEM = Component.CreateWidget(BP_LISTITEM, self.DROPDOWN_LIST)

	local BACKGROUND = ITEM:GetChild("background")

	ITEM:BindEvent("OnMouseEnter", function()
		BACKGROUND:ParamTo("exposure", 0.35, 0.05)
		BACKGROUND:ParamTo("tint", ITEM_COLOR_HIGHLIGHT, 0.2)
		BACKGROUND:ParamTo("alpha", 0.5, 0.05)
		--PRIVATE.SetMouseFocus(self, true)
	end)
	ITEM:BindEvent("OnMouseLeave", function()
		BACKGROUND:ParamTo("exposure", 0, 0.05)
		BACKGROUND:ParamTo("tint", ITEM_COLOR_DEFAULT, 0.2)
		BACKGROUND:ParamTo("alpha", 0, 0.05)
		--PRIVATE.SetMouseFocus(self, false)
	end)
	ITEM:BindEvent("OnMouseDown", function()
		BACKGROUND:ParamTo("exposure", -0.3, 0.05)
	end)
	ITEM:BindEvent("OnMouseUp", function()
		BACKGROUND:ParamTo("exposure", 0.35, 0.05)
		BACKGROUND:ParamTo("alpha", 0, 0.05)

		self.List_Selected = index + self.Slider_Offset
		PRIVATE.ToggleList(self, false)
		PRIVATE.SetButtonTextByIndex(self)
		PRIVATE.OnItemSelect(self)
	end)
	ITEM:BindEvent("OnScroll", function(args)
		PRIVATE.OnScroll(self, args.amount)
	end)

	return ITEM
end

function PRIVATE.RefreshListGroup(self)
	local numWidgets = #self.LIST_WIDGETS
	local numItems = #self.List_Items
	local maxSize = math.min(self.List_Size, numItems)

	-- Prune unwanted Item Widgets
	if numWidgets > maxSize then
		for i=numWidgets, math.max(1, maxSize), -1 do
			Component.RemoveWidget(self.LIST_WIDGETS[i])
			self.LIST_WIDGETS[i] = nil
		end

	-- Expand to desired size
	elseif numWidgets < maxSize then
		for i=numWidgets+1, maxSize do
			self.LIST_WIDGETS[i] = PRIVATE.CreateListItem(self, i)
		end
	end

	self.List_Height = maxSize * ITEM_HEIGHT
	--self:Enable(numItems > 0)
end

function PRIVATE.ClearListGroup(self)
	for i=1, #self.LIST_WIDGETS do
		Component.RemoveWidget(self.LIST_WIDGETS[i])
		self.LIST_WIDGETS[i] = nil
	end
end

function PRIVATE.OnItemSelect(self)
	if self.OnSelect then
		local value = self.List_Items[self.List_Selected].value
		self.OnSelect(value, self.GROUP)
	end
end

function PRIVATE.ToggleList(self, state)
	self.list_expanded = state

	local bounds = self.GROUP:GetBounds()
	local screen_x, screen_y = Component.GetScreenSize(true)

	if state and #self.List_Items > 0 then
		PRIVATE.RequestDropdown(self)

		local dims_dropdown
		local dims_button
		local dims_focus_start
		local dims_focus_moveto
		local dims_mask

		local flipped = false
		local dd_bottom_y = bounds.top+bounds.height+self.List_Height+5
		if not self.forceFlip and dd_bottom_y <= screen_y - SCREEN_FLIP_OFFSET then
			dims_dropdown = "top:".. bounds.top-DROPDOWN_SPACING .."; left:".. bounds.left-DROPDOWN_SPACING .."; right:".. bounds.right+DROPDOWN_SPACING .."; bottom:"..bounds.bottom+self.List_Height+DROPDOWN_SPACING+5
			dims_button = "top:0; left:0; width:".. bounds.width .."; height:"..bounds.height+self.List_Height+5
			dims_focus_start = "top:".. bounds.height+1 .."; left:0; right:100%; bottom:".. bounds.height+20
			dims_focus_moveto = "top:_; bottom:"..bounds.height+self.List_Height+5
			dims_mask = "top:0; left:0; width:"..bounds.width..";height:"..bounds.height
		else
			flipped = true
			dims_dropdown = "bottom:".. bounds.bottom+DROPDOWN_SPACING .."; left:".. bounds.left-DROPDOWN_SPACING .."; right:".. bounds.right+DROPDOWN_SPACING .."; top:"..bounds.top-self.List_Height-DROPDOWN_SPACING-5
			dims_button = "bottom:100%; left:0; width:".. bounds.width .."; height:"..bounds.height+self.List_Height+5
			dims_focus_start = "bottom:100%-".. bounds.height+1 .."; left:0; right:100%; top:100%-".. bounds.height+20
			dims_focus_moveto = "bottom:_; top:100%-"..bounds.height+self.List_Height+5
			dims_mask = "bottom:100%; left:0; width:"..bounds.width..";height:"..bounds.height
		end
		self.flipped = flipped
		self.DROPDOWN_MASK:SetDims(dims_mask)
		self.DROPDOWN:SetDims(dims_dropdown)
		self.DROPDOWN_BTN:SetDims(dims_button)
		self.DROPDOWN_FOCUS:SetDims(dims_focus_start)
		self.DROPDOWN_FOCUS:MoveTo(dims_focus_moveto, DROPDOWN_DUR)
		self.DROPDOWN:ParamTo("alpha", 1, 0.1)
		self.DROPDOWN_BD:SetDims(dims_mask)
		self.DROPDOWN_BD:MoveTo(dims_focus_moveto, DROPDOWN_DUR)
	elseif self.DROPDOWN then
		local dims_moveto
		if not self.flipped then
			dims_moveto = "top:_; height:"..bounds.height
		else
			dims_moveto = "bottom:_; height:"..bounds.height
		end
		self.DROPDOWN:ParamTo("alpha", 0, 0.1, DROPDOWN_DUR - 0.1)
		self.DROPDOWN_FOCUS:MoveTo(dims_moveto, DROPDOWN_DUR)
		self.DROPDOWN_BD:MoveTo(dims_moveto, DROPDOWN_DUR)
		callback(PRIVATE.ClearDropdown, self, DROPDOWN_DUR+0.001)
	end
end

function PRIVATE.SetButtonTextByIndex(self)
	if not self.List_Selected then
		warn("Attempted to set text without selected Dropdown item")
		return
	end
	local item = self.List_Items[self.List_Selected]
	local color = item.color or "#FFFFFF"

	local text = item.text
	if item.sub then
		for i=self.List_Selected-1, 1, -1 do
			local prev_item = self.List_Items[i]
			if prev_item and not prev_item.sub then
				text = prev_item.text .. " - " .. text
				break
			end
		end
	end

	self.TEXT:SetText(text)
	self.TEXT:SetTextColor(color, Colors.Multiply(color, 0.15))
end

function PRIVATE.SetButtonText(self, text)
	self.TEXT:SetText(text)
end

-- Mouse Wheel
function PRIVATE.OnScroll(self, amount)
	if #self.List_Items > self.List_Size then
		local pct = self.SLIDER:GetPercent() + (amount * ( self.List_Size / #self.List_Items))
		self.SLIDER:SetPercent(pct)
		PRIVATE.Slider_OnChange(self, pct)
	end
end

-- Slider
function PRIVATE.SliderEnable(self, state)
	if state then
		self.DROPDOWN_LIST:SetDims("right:100%-19;")
		self.SLIDER.WIDGET:Show(state)
		self.SLIDER:SetParam("thumbsize", math.max(0.20, self.List_Size / #self.List_Items))
		self.SLIDER:SetSteps(#self.List_Items)
		self.SLIDER:SetJumpSteps(#self.LIST_WIDGETS / 25)
	else
		self.DROPDOWN_LIST:SetDims("right:100%-1")
	end
end

function PRIVATE.Slider_OnChange(self, pct)
	-- Update List Offset + Name Display
	if not pct then pct = 0 end
	local ListSize = #self.LIST_WIDGETS
	self.Slider_Offset = math.floor((#self.List_Items-self.List_Size) * math.max(0,math.min(1,pct)))
	PRIVATE.List_DisplayUpdate(self)
end

function PRIVATE.List_DisplayUpdate(self)
	for i=1, #self.LIST_WIDGETS do
		local idx = i + self.Slider_Offset
		local item_text = self.LIST_WIDGETS[i]:GetChild("text")
		local color_value = self.List_Items[idx].color or "#FFFFFF"
		item_text:SetTextColor(color_value)

		local text = self.List_Items[idx].text
		if self.List_Items[idx].sub then
			text = "   - "..text
		end
		item_text:SetText(text)
	end
end


function PRIVATE.SliderReset(self)
	self.SLIDER:SetPercent(0)
	self.Slider_Offset = 0
end

function PRIVATE.SetMouseFocus(self)
	self.releaseReady = true
end

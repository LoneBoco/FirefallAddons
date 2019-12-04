
--
-- lib_RowVerticalChoice
--   by: James Harless
--   by: Nalin
--

--[[ Usage:


--]]

if RowVerticalChoice then
	return nil
end
RowVerticalChoice = {}

require "unicode"
require "lib/lib_MultiArt"
require "lib/lib_Tooltip"
require "lib/lib_EventDispatcher"

local API = {}
local lf = {}
local ROW_METATABLE = {
	__index = function(t,key) return API[key]; end,
	__newindex = function(t,k,v) error("cannot write to value '"..k.."' in ROWCHOICE"); end
};

local c_COLOR_DEFAULT = "#FFFFFF"
local c_COLOR_HIGHLIGHT = "#0077FF"
local c_COLOR_SELECTED = "#00FF77"
local c_HPADDING_DEFAULT = 2

local BP_ROW = [[
	<Group dimensions="dock:fill">
		<ListLayout name="list" dimensions="dock:fill"  style="vertical:true; hpadding:%s" />
	</Group>]]


local BP_CHOICE = [[<Group dimensions="dock:fill" >
	<Border dimensions="center-x:50%; center-y:50%; width:100%-2; height:100%-2" class="ButtonSolid" style="tint:#000000; alpha:0.75; padding:8"/>
	<Border name="border" dimensions="dock:fill" class="ButtonBorder" style="alpha:0.15; exposure:0.9; padding:2"/>
	<Group name="icon" dimensions="left:1; right:100%-1; top:1; bottom:100%-1" />
	<FocusBox name="button" dimensions="dock:fill" class="ui_button"/>
</Group>]]



------------ --
-- RowVerticalChoice --
------------ --

function RowVerticalChoice.Create(PARENT, padding)
	local GROUP = Component.CreateWidget(unicode.format(BP_ROW, padding or c_HPADDING_DEFAULT), PARENT)
	local ROW = {
		GROUP = GROUP,
		LIST = GROUP:GetChild("list"),
		BORDERS = GROUP:GetChild("borders"),

		CHOICES = {},


		-- Variables
		selected_index = -1,
		vertical = true,
		tooltip = false,
		bounds = {height=64, width=64},

		func_onselect = false,
	}

	setmetatable(ROW, ROW_METATABLE)


	return ROW
end

---------- --
-- ROW API --
---------- --
-- forward the following methods to the GROUP widget
local COMMON_METHODS = {
	"GetDims", "SetDims", "MoveTo", "QueueMove", "FinishMove",
	"GetParam", "SetParam", "ParamTo", "CycleParam", "QueueParam", "FinishParam",
	"Show", "Hide", "IsVisible", "GetBounds"
}

for _, method_name in pairs(COMMON_METHODS) do
	API[method_name] = function(API, ...)
		return API.GROUP[method_name](API.GROUP, ...)
	end
end

function API.SetChoiceBounds(ROW, height, width)
	if height then
		ROW.bounds = {height=height, width=width or height}
	end
end

function API.BindOnSelect(ROW, func)
	assert(type(func) == "function", "No Valid Function supplied.")
	ROW.func_onselect = func
end

function API.AddChoice(ROW, params, value)
	local CHOICE = lf.CreateChoice(ROW, params, value)
	table.insert(ROW.CHOICES, CHOICE)
	CHOICE.index = #ROW.CHOICES
	if not ROW:GetSelected() then
		ROW:SelectIndex(1)
	end
end

function API.RemoveChoice(ROW, index)
	if ROW.CHOICES[index] then
		ROW.CHOICES[index]:Destroy()
	end
end

function API.UpdateChoice(ROW, index, params, value)
	local CHOICE = ROW.CHOICES[index]
	if CHOICE then
		lf.ChangeChoice(ROW, CHOICE, params, value)
	end
end

function API.ClearChoices(ROW)
	for _,CHOICE in ipairs(ROW.CHOICES) do
		CHOICE:Destroy()
	end
	ROW.CHOICES = {}
	ROW.selected_index = -1
end

function API.SelectIndex(ROW, index)
	if type(index) == "number" then
		lf.Row_SetSelected(ROW, index)
	end
end

function API.GetSelected(ROW)
	local CHOICE = ROW.CHOICES[ROW.selected_index]
	if CHOICE then
		return CHOICE.value
	end
end

function API.Enable(ROW)
	for i=1, #ROW.CHOICES do
		ROW:ChoiceEnable(i)
	end
end

function API.Disable(ROW)
	for i=1, #ROW.CHOICES do
		ROW:ChoiceDisable(i, true)
	end
end

function API.ChoiceEnable(ROW, index)
	local CHOICE = ROW.CHOICES[index]
	if CHOICE then
		lf.ChoiceEnable(CHOICE, ROW)
	end
end

function API.ChoiceDisable(ROW, index, disable_deselect)
	local CHOICE = ROW.CHOICES[index]
	if CHOICE then
		lf.ChoiceDisable(CHOICE, ROW, disable_deselect)
	end
end

--------- --
-- ROW LF --
--------- --
function lf.RemoveIndex(ROW, index)
	if ROW.CHOICES[index] then
		table.remove(ROW.CHOICES, index)
	end
	lf.UpdateIndexes(ROW)
end

function lf.UpdateIndexes(ROW)
	for i=1, #ROW.CHOICES do
		ROW.CHOICES[i].index = i
	end
end

function lf.Row_SetSelected(ROW, index)
	if ROW.CHOICES[index] then
		local PREV_CHOICE = ROW.CHOICES[ROW.selected_index]
		lf.Choice_Deselect(PREV_CHOICE)
		local CHOICE = ROW.CHOICES[index]
		lf.Choice_Select(CHOICE)

		ROW.selected_index = index
		if ROW.func_onselect then
			ROW.func_onselect(CHOICE.value)
		end
	else
		warn("Index: "..index.." does not exist!")
	end
end

------------ --
-- CHOICE LF --
------------ --
function lf.CreateChoice(ROW, params, value)

	local GROUP = Component.CreateWidget(BP_CHOICE, ROW.LIST)
	local CHOICE = {
		GROUP = GROUP,
		BORDER = GROUP:GetChild("border"),
		ICON = MultiArt.Create(GROUP:GetChild("icon")),
		BUTTON = GROUP:GetChild("button"),

		-- Variables
		index = -1,
		selected = false,
		enabled = true,
		label = false,
		width = ROW.bounds.width,
		value = value,
	}
	if params.width then
		CHOICE.width = params.width
	end
	if params.label_key then
		CHOICE.label = Component.LookupText(params.label_key)
	elseif params.label then
		CHOICE.label = params.label
	end

	GROUP:SetDims("left:0; top:0; height:"..ROW.bounds.height..";width:"..CHOICE.width)

	-- I feel this is sorta hacky
	CHOICE.Destroy = function(CHOICE)
			lf.Destroy(CHOICE, ROW)
		end

	CHOICE.BUTTON:BindEvent("OnMouseEnter", function(args)
		lf.ShowTooltip(ROW, CHOICE)
	end)
	CHOICE.BUTTON:BindEvent("OnMouseLeave", function(args)
		lf.HideTooltip(ROW)
	end)
	CHOICE.BUTTON:BindEvent("OnMouseDown", function(args)

	end)
	CHOICE.BUTTON:BindEvent("OnMouseUp", function(args)
		if not CHOICE.selected and CHOICE.enabled then
			lf.Row_SetSelected(ROW, CHOICE.index)
		end
	end)

	if params.url then
		CHOICE.ICON:SetUrl(params.url)
	elseif params.texture then
		local icon = {params.texture, params.region}
		CHOICE.ICON:SetTexture(unpack(icon))
	else
		warn("No Icon found!")
	end

	return CHOICE
end

function lf.UpdateChoice(ROW, CHOICE, params, value)
	CHOICE.width = ROW.bounds.width
	CHOICE.value = value

	if params.width then
		CHOICE.width = width
	end

	CHOICE.GROUP:SetDims("left:0; top:0; height:"..ROW.bounds.height..";width:"..CHOICE.width)

	if params.url then
		CHOICE.ICON:SetUrl(params.url)
	elseif params.texture then
		local icon = {params.texture, params.region}
		CHOICE.ICON:SetTexture(unpack(icon))
	else
		warn("No Icon found!")
	end
end

function lf.Destroy(CHOICE, ROW)
	CHOICE.ICON:Destroy()
	Component.RemoveWidget(CHOICE.GROUP)

	CHOICE = nil
end

function lf.ChoiceEnable(CHOICE, ROW)
	if not CHOICE.enabled then
		CHOICE.enabled = true
		CHOICE.ICON:ParamTo("alpha", 1, 0.1)

		if ROW.selected == -1 then
			local selected = false
			for i=1, #ROW.CHOICES do
				if ROW.CHOICES[i].enabled then
					ROW.selected_index = i
					lf.Row_SetSelected(ROW, i)
					selected = true
					break
				end
			end
		end
	end
end

function lf.ChoiceDisable(CHOICE, ROW, disable_deselect)
	if CHOICE.enabled then
		CHOICE.enabled = false
		CHOICE.ICON:ParamTo("alpha", 0.4, 0.1)
		if not disable_deselect then
			lf.Choice_Deselect(CHOICE)

			local selected = false
			for i=1, #ROW.CHOICES do
				if ROW.CHOICES[i].enabled then
					ROW.selected_index = i
					lf.Row_SetSelected(ROW, i)
					selected = true
					break
				end
			end
			if not selected then
				ROW.selected_index = -1
				if ROW.func_onselect then
					ROW.func_onselect(false)
				end
			end
		end
	end
end

function lf.Choice_Select(CHOICE)
	if not CHOICE then
		return nil
	end
	CHOICE.selected = true
	CHOICE.BORDER:ParamTo("tint", "#55CCFF", 0.15)
	CHOICE.BORDER:ParamTo("alpha", 0.5, 0.15)
end

function lf.Choice_Deselect(CHOICE)
	if not CHOICE then
		return nil
	end
	CHOICE.selected = false
	CHOICE.BORDER:ParamTo("tint", "#FFFFFF", 0.15)
	CHOICE.BORDER:ParamTo("alpha", 0.15, 0.15)
end

------------------ --
-- LOCAL FUNCTIONS --
------------------ --
-- Tooltips
function lf.RemoveTooltip(ROW)
	if ROW.tooltip then
		ROW.tooltip = false
		Tooltip.Show(false)
	end
end

function lf.ShowTooltip(ROW, CHOICE)
	if CHOICE.label then
		ROW.tooltip = true
		Tooltip.Show(CHOICE.label)
	end
end

function lf.HideTooltip(ROW)
	lf.RemoveTooltip(ROW)
end

require "lib/lib_ChatLib"


GT = {};


function GT.Bind_Close(title, func)
	local CLOSE_BUTTON = title:GetChild("close");
	local X = CLOSE_BUTTON:GetChild("X");
	CLOSE_BUTTON:BindEvent("OnMouseDown", func);
	CLOSE_BUTTON:BindEvent("OnMouseEnter", function()
		X:ParamTo("tint", Component.LookupColor("red"), 0.15);
		X:ParamTo("glow", "#30991111", 0.15);
	end);
	CLOSE_BUTTON:BindEvent("OnMouseLeave", function()
		X:ParamTo("tint", Component.LookupColor("white"), 0.15);
		X:ParamTo("glow", "#00000000", 0.15);
	end);
end

function GT.Bind_Scroll(widget, row, mx, my, spacing)
	widget:AddRow(row);
	widget:SetSliderMargin(mx, my);
	widget:SetSpacing(spacing);
	widget:UpdateSize();
end

function GT.Alert(msg)
	ChatLib.SystemMessage({ text="[Goon Transit] " .. msg });
end

-- Derived from http://lua-users.org/wiki/StringTrim
function GT.trim7(s)
	return unicode.match(s,'^()%s*$') and '' or unicode.match(s,'^%s*(.*%S)');
end

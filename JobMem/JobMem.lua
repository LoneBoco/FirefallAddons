--[[

JobMem

By Reicere
Modified by Nalin

Version WIP
- Fixed PTS bugs.
- Fixed /repeatjob command causing the GUI button to go out of sync.
- Added the /stoprepeat command, splitting off the repeat logic from /stopjob.

Version 2.2
- Added /startjob command.

Version 2.1
- Reduced repeat delay.
- Fixed a bug where /stopjob didn't properly update the GUI.

Version 2.0
- Simplified the commands.
- Added a "Repeat Job" button to the Job Board.

--]]


require "lib/lib_Slash";
require "./lib/lib_Button"
require "lib/lib_Callback2";
require "lib/lib_ChatLib";
require "lib/lib_math";		-- for determining Firefall version


local g_CurrentJob = nil;
local g_RepeatJob = false;
local REPEAT_BUTTON = nil;


function OnComponentLoad()
	local isPTS = _math.inOutQuad ~= nil;

	LIB_SLASH.BindCallback({slash_list="repeatjob", description="Repeats the currently active job", func=StartRepeat});
	LIB_SLASH.BindCallback({slash_list="stopjob", description="Stops the current job and ends a repeat, if active", func=OnStopJobCommand});
	LIB_SLASH.BindCallback({slash_list="stoprepeat", description="Ends a job repeat, if active", func=OnStopRepeatCommand});
	LIB_SLASH.BindCallback({slash_list="restartjob", description="Restarts the current job", func=OnRestartJobCommand});
	LIB_SLASH.BindCallback({slash_list="startjob", description="Starts a job with the given ID", func=OnStartJobCommand});

	-- Create the button to display on the job board.
	local FRAME = Component.CreateFrame("PanelFrame", "Temp");
	REPEAT_BUTTON = Button.Create(FRAME);

	-- Create and foster our button on the job board.
	if isPTS then
		REPEAT_BUTTON:GetWidget():SetDims("left:420; top:-17; height:24; width:160");
		Component.FosterWidget(REPEAT_BUTTON:GetWidget(), "JobBoard:Main.{2}");
	else
		REPEAT_BUTTON:GetWidget():SetDims("right:80%-5; top:0%+9; height:24; width:15%");
		Component.FosterWidget(REPEAT_BUTTON:GetWidget(), "JobBoard:Main.{2}.{1}");
	end

	StopRepeat(false);
end

function Alert(msg)
	ChatLib.SystemMessage({ text="[JobMem] " .. msg });
end

function OnArcStatusChanged()
	if Player.IsReady() then
		local jobStatus = Player.GetJobStatus();

		if jobStatus and jobStatus.job and jobStatus.job.arc_id then
			g_CurrentJob = jobStatus.job.arc_id;
			-- Alert("New job: "..tostring(g_CurrentJob));
		else
			-- Test for repeating a job that can't be repeated.
			if g_CurrentJob == nil then
				StopRepeat(false);
				Alert("Stopping the job repeat as the job is failing to repeat.");
			end

			-- Repeat job if set.
			if g_RepeatJob then
				local repeatJob = g_CurrentJob;
				Callback2.FireAndForget(function()
					Alert("Repeating job "..tostring(repeatJob)..".");
					Game.RequestStartArc(repeatJob);
				end, nil, 2);
			end

			-- Mark our active job as nil.
			g_CurrentJob = nil;
		end
	end
end

function OnEnterZone()
	--[[
	if g_RepeatJob then
		Alert("Stopping the job repeat as we have switched zones.");
	end
	StopRepeat(false);]]
end

function OnRepeatJobCommand()
	g_RepeatJob = true;
	if g_CurrentJob then
		Alert("Repeating job "..tostring(g_CurrentJob)..".");
	else
		Alert("Repeating any future jobs.");
	end
end

function OnStopJobCommand()
	-- First stop the repeat.
	StopRepeat(false);

	-- End our current job.
	Alert("Ending job "..tostring(g_CurrentJob)..".");
	Game.RequestCancelArc(g_CurrentJob);
end

function OnStopRepeatCommand()
	StopRepeat();
end

function OnRestartJobCommand()
	if not g_CurrentJob then return; end

	local job = g_CurrentJob;
	if job ~= nil then
		Game.RequestCancelArc(g_CurrentJob);
		Callback2.FireAndForget(function() Game.RequestStartArc(job); end, nil, 2);

		Alert("Restarting job "..tostring(job)..".");
	end
end

function OnStartJobCommand(args)
	Game.RequestStartArc(tonumber(args[1]));
	Alert("Starting job "..tostring(args[1])..".");
end

function StartRepeat()
	OnRepeatJobCommand();

	REPEAT_BUTTON:SetText("Stop Repeat");
	REPEAT_BUTTON:TintPlateTo(Button.DEFAULT_YELLOW_COLOR, 0.2);
	REPEAT_BUTTON:Bind(function()
		StopRepeat();
	end);
end

function StopRepeat(alert)
	if g_RepeatJob and (alert == nil or alert) then
		Alert("Stopping the job repeat.");
	end
	g_RepeatJob = false;

	REPEAT_BUTTON:SetText("Repeat Job");
	REPEAT_BUTTON:TintPlateTo(Button.DEFAULT_GREEN_COLOR, 0.2);
	REPEAT_BUTTON:Bind(function()
		StartRepeat();
	end);
end

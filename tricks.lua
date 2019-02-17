-- 
--
--    **TRICK ON A SWITCH  v0.91**
--    by Mactac

--    contact:
--      www.youtube.com/mactacfpv
--      www.instagram.com/mactac
--      p a u l (at) w a g o r n (dot) c o m

--    **Licence:** Creative commons Attribution-NonCommercial-ShareAlike 
--             https://creativecommons.org/licenses/by-nc-sa/2.5/
--             You may: Share and adapt this work only for NON-COMMERCIAL purposes    
--             You must give appropriate credit and indicate if changes were made.  
--             The header above and this licence must remain intact on redistribution.
--             If you remix, transform, or build upon the material, you must distribute
--             your contributions under the same license as this original.
----------------------------------------------------------------------------------------
--
-- >>>>> **WARNING** <<<<<
-- This script takes control of your sticks!  Be VERY careful using the script,
-- especially if you make modifications.  Always test in a simulator before using
-- it on a live quad.  Things can go VERY wrong, including flyaways, or full throttle
-- loss of control, and potential personal injury.
-- By using this script, you hereby take full responsibility for damage to property
-- or injuries to you or others that takes place directly or indirectly from its use.
-- Provided with no guarantees or warranties of any type.  If you don't know what you're
-- doing, you may very well lose a quad or hurt yourself or someone else.... it's all on you!

-- **THIS SCRIPT WILL NOT WORK FOR YOU** without modifications- see the notes below.  
-- You will need to edit the trick timing (& maybe switch assignments) if you want it to 
-- work with your setup.

-- **Trick settings:**
-- up to 3 tricks on one 3-position switch (could multiplex switches for more tricks)
-- each trick consists of one or more moves
-- each move contains stick positions and time to hold each move in 10ms increments
-- sticks go from -1024 to 1024 at full deflections.
-- syntax is: trick[Trick number][move number] = {time,throttle,yaw,roll,pitch}
-- Tricks can have as many moves as you want, just end the trick with all zeroes

-- **Rates:**
-- These times and stick movements are set up for MY rates.   You will have to adjust
-- them to suit your own rates- there is very little chance that these values will work
-- for you.
-- If you want to flip 180 degrees, you will want to look at your degrees/second of your 
-- rates and divide to find how long the stick should be held.  For example, if you are 
-- set to 800 degrees per second for your pitch and want to flip 180, 180 divided by 800 
-- equals 0.225 seconds if you use full stick throw ( which is a value of 1024).  Times
-- in open tx are in 10ms increments, so .225s = 225ms = a time value of 22 or 23.
-- So in this example, that segment of the trick for a 180 flip would be {22,-1000,0,0, 1024}
--
-- If you do no want to use full stick deflection (for example you you are mixing roll with 
-- a bit of yaw), you can use this calculator to figure out the percentage of stick deflection 
-- based on degrees per second:  https://apocolipse.github.io/RotorPirates/  just keep in  
-- mind that sticks go from -1024 to 1024, so 100% is 1024, and 50% would be 512.

-- **Still do do:**
-- Allow rates, expo, rc expo to be entered to automatically calculate stick deflections
-- Panic button (resets everything & aborts in the middle of a trick)



trick = {{}, {}, {}}

-- Inverted Yaw spin
trick[1][1] = {26,-1024,0,0,-1000}
trick[1][2] = {71,-1024,-1000,0,0}
trick[1][3] = {18,-1024,0,0,-1000}
trick[1][4] = {0,0,0,0,0}

-- Backwards knife edge
trick[2][1] = {23,-1024,0,0,-1000}
trick[2][2] = {10,-1024,-840,1000,0}
trick[2][3] = {0,0,0,0,0}

-- Rubik's cube
trick[3][1] = {24,-1024,0,0,-1000}
trick[3][2] = {24,-1024,0,-1000,0}
trick[3][3] = {24,-1024,0,0,1000}
trick[3][4] = {24,-1024,0,1000,0}
trick[3][5] = {0,0,0,0,0}


-- Switch assignments
-- You can change these around based on how your Taranis is set up.
-- Just make sure you use the correct switch types (ie 3 position or momentary)

local seg_switch = "sa"   -- switch to select only one move of trick (3 position switch) for adjusting timing, etc
local sel_switch = "se"   -- switch to select which trick to do (3 position switch)
local go_switch = "sh"    -- switch to execute trick (should be a momentary switch)
local disable_switch = "sc"  -- switch to turn tricks on/off or act as a panic.  Center = enabled, any other position = disabled

-- Other variables
local elapsed_time
local move = 0
local started = 0
local start_time = 0
local skip = 0
local move_time =0
local timing_mod = {}
local display_timer = 0
local return1 = 0
local return2 = 0

-- Outputs
local thr = 0
local yaw = 0
local roll = 0
local pitch = 0

local inputs = {
  {"orig_thr", SOURCE},
  {"orig_yaw", SOURCE},
  {"orig_roll", SOURCE},
  {"orig_pitch", SOURCE}
}

local outputs = { "thr", "yaw", "roll", "pitch","t1,3","t2,4"}
-- Maximum 4 characters

local function run(orig_thr,orig_yaw,orig_roll,orig_pitch)

  -- Get potentiometer values from radio for adjusting move times
  timing_mod[1] = getValue('s1')*.02    -- left knob.  Current range is 0-100ms  increase the 0.2 number for greater range
  timing_mod[2] = getValue('s2')*.02    -- right knob
  timing_mod[3] = getValue('ls')*.02    -- left trim slider (Remove for QX7)
  timing_mod[4] = getValue('rs')*.02    -- right trim slider (Remove for QX7)

-- The following section cycles the output display between trimpots 1&2 and 3&4.  
-- If you have a QX7, you don't have trimpots 3&4, so you can change this whole block to just:
--   return1 = getValue('s1')*.1
--   return2 = getValue('s2')*.1

if getTime() - display_timer > 600 then
  return1 = getValue('ls')*.1               
  return2 = getValue('rs')*.1             
  display_timer = getTime()
elseif getTime() - display_timer > 200 then
  return1 = getValue('s1')*.1
  return2 = getValue('s2')*.1  
end

  -- which trick are we doing? 
  if getValue(sel_switch) > 0 then 
    trick_num = 3
  elseif getValue(sel_switch) == 0 then
    trick_num = 2
  else 
    trick_num = 1
  end
  
  if getValue(go_switch) > 1 and started == 0 then  -- if trick not alrady started, then launch
    started = 1
    move = 1
  end

  local segment = getValue(seg_switch)   -- choose single trick segment (only segment #1 or #2) for tuning, center means do full trick

  if started == 1 and trick[trick_num][move][1] > 0 and getValue(disable_switch) == 0 then -- make sure we are not at end of trick

    if start_time == 0 then  -- start of a new move, reset timer
      start_time = getTime()
    end

    elapsed = getTime() - start_time

    if (move ~= 2 and segment > 0) or (move ~= 1 and segment < 0) then -- skip all moves except selected segment (1 or 2) 
                                                                       -- if single segment chosen, otherwise don't skip anything
      skip = 1
    else
      skip =0
    end
    
    if move < 5 then                    -- Change this to 3 instead of 5 for QX7 
      move_time = trick[trick_num][move][1] + timing_mod[move]
    else 
      move_time = trick[trick_num][move][1]
    end
    
    if elapsed < move_time and skip ~= 1 then -- do this until we reach end time for the move
      thr = trick[trick_num][move][2]
      yaw = trick[trick_num][move][3]
      roll = trick[trick_num][move][4]
      pitch= trick[trick_num][move][5]
    else
      start_time = 0  -- go to next move, reset sticks so no overshoot
      yaw = 0
      pitch = 0
      roll = 0
      thr = -1000
      move = move + 1
    end

  else    -- no trick  in progress, default to mirroring sticks
    yaw = orig_yaw
    thr = orig_thr
    roll = orig_roll
    pitch = orig_pitch
    start_time = 0
    started = 0
    move = 1
  end


-- Return the values.  Note that in addition to the 4 axes, we are also returning the value
-- of 2 of the knobs.  The reason for that is that after we tune the timing with the knobs, 
-- we can see their exact values and adjust the timing of the moves exactly.  OpenTX only
-- supports 6 returns, so we can't put all 4 of the potentiometers here.  The output cycles 
-- the knobs (1&2) and the sliders (3&4) (QX7 only supports the 2 knobs)

  return thr, yaw, roll, pitch,return1,return2

end

return { input=inputs, output=outputs, run=run }

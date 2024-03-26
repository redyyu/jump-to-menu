
local BASE_DURATION = 15 -- It's calculated number DO NOT change it, unless know what doing.
local JUMP_KEY = 'Crouch'  -- use for KeyPressToJumpEnabled is true, 
-- don't want add KEY binds to Vanilla, `Crouch`(Sneak) is best option, it's looks like prepare to jump.


local function getJumpDuration(playerObj)
    local moodles = playerObj:getMoodles()
    local endurance = moodles:getMoodleLevel(MoodleType.Endurance)
    local heavy_load = moodles:getMoodleLevel(MoodleType.HeavyLoad)
    local sick = moodles:getMoodleLevel(MoodleType.Sick)
    local injured = moodles:getMoodleLevel(MoodleType.Injured)
    local tired = moodles:getMoodleLevel(MoodleType.Tired)
    local pain = moodles:getMoodleLevel(MoodleType.Pain)
    
    if endurance > 3 or heavy_load > 3 or injured > 3 then
        return 0
    end

    local modifier = playerObj:getPerkLevel(Perks.Fitness) + playerObj:getPerkLevel(Perks.Sprinting)

    if playerObj:getTraits():contains("Obese") then
        modifier = modifier * 0.55
    elseif playerObj:getTraits():contains("Overweight") then
        modifier = modifier * 0.75
    end

    -- if isDebugEnabled() then
    --     print("================= JumpTo =================")
    --     local print_text = "Modifier: " .. modifier .. "  Endurance: " .. endurance .. "  HeavyLoad: " .. heavy_load
    --     print_text = print_text .."  Tired: " .. tired .. "  Sick: " .. sick .. "  Injured: " .. injured.."  Pain: " .. pain
    --     print(print_text)
    --     print("==============================================")
    -- end

    modifier = math.max(modifier - endurance - heavy_load * 2 - sick - tired - injured - pain, 0)
    
    return BASE_DURATION + modifier
end


local relatedBodyPart = {
    BodyPartType.Torso_Lower, BodyPartType.Groin,
    BodyPartType.UpperLeg_L, BodyPartType.UpperLeg_R,
    BodyPartType.LowerLeg_L, BodyPartType.LowerLeg_R,
    BodyPartType.Foot_L, BodyPartType.Foot_R
}

local function isRelatedBodyPartDamaged(playerObj)
    local body_damage = playerObj:getBodyDamage()
    if body_damage then
        for _, bp_type in ipairs(relatedBodyPart) do
            local body_part = body_damage:getBodyPart(bp_type)
            if body_part:getFractureTime() > 0.0F or 
               body_part:isDeepWounded() or 
               body_part:getStiffness() >= 50.0 then
                return true
            end
        end
    end

    return false
end


local JumpTo = {}


JumpTo.onJumpStartByKey = function(playerObj)
    if not playerObj or playerObj:hasTimedActions() or playerObj:getVehicle() then
        -- refused is not vaild scenes.
        return
    end

    if playerObj:getSquare() and playerObj:getSquare():HasStairs() then
        -- refused when player on stairs, that will cause strange anim.
        -- but pass if player not on a square, allow player to jump off it.
        -- etc. teleport to a none square coordinate.
        return
    end

    if isRelatedBodyPartDamaged(playerObj) or
       not playerObj:isCurrentState(IdleState.instance()) or playerObj:isbFalling() then
        -- refused when player already falling. or body part relate to jump is damaged.
        -- or player is doing something else.
        return
    end

    -- Credit: Tchernobill
    local orient_angle = playerObj:getAnimAngleRadians() 
    --0 = East, PI/2 = South, -PI/2=North, PI=West
    local destX = playerObj:getX() + math.cos(orient_angle) * 5
    local destY = playerObj:getY() + math.sin(orient_angle) * 5
    
    -- *5 is for make sure not too closed with character current position
    -- prevent turn round when move faster, because the dest point has been behind.

    ISTimedActionQueue.clear(playerObj)
    ISTimedActionQueue.add(ISJumpToAction:new(playerObj, getJumpDuration(playerObj), destX, destY))
end


JumpTo.onPlayerUpdate = function(playerObj)
    -- support joypad, they might diffcult to using context menu.
    -- untested might not work.
    local joypad_id = playerObj:getJoypadBind()
    if isJoypadPressed(joypad_id, Joypad.RBumper) and (playerObj:isRunning() or playerObj:isSprinting()) then
        JumpTo.onJumpStartByKey(playerObj)
    end
end


JumpTo.onKeyStartPressed = function(key)
    if SandboxVars.RefinedCharacterActions.KeyPressToJumpEnabled or isDebugEnabled() then
        if key == getCore():getKey(JUMP_KEY) then
            local playerObj = getPlayer()
            if playerObj:isRunning() or playerObj:isSprinting() then
                JumpTo.onJumpStartByKey(playerObj)
            end
        end
    end
end


JumpTo.onJumpCursor = function(playerNum)
    local playerObj = getSpecificPlayer(playerNum)
	local bo = ISJumpToCursor:new("", "", playerObj, getJumpDuration)
	getCell():setDrag(bo, playerNum)
end


JumpTo.onFillWorldObjectContextMenu = function(playerNum, context, worldobjects)
    local playerObj = getSpecificPlayer(playerNum)
    
    if not playerObj or playerObj:getVehicle() then
        -- refused is not vaild scenes.
        return
    end

    if playerObj:getSquare() and playerObj:getSquare():HasStairs() then
        -- refused when player on stairs, that will cause strange anim.
        -- but pass if player not on a square, allow player to jump off it.
        -- etc. teleport to a none square coordinate.
        return
    end

    if playerObj:isbFalling() or not playerObj:isCurrentState(IdleState.instance()) then
        -- refused when player already falling. or body part relate to jump is damaged.
        -- or player is doing something else.
        return
    end

    local option = context:insertOptionBefore(getText("ContextMenu_Walk_to"), getText("ContextMenu_JumpTo"), playerNum, JumpTo.onJumpCursor)
    option.toolTip = ISWorldObjectContextMenu.addToolTip()
    option.toolTip:setName(getText("Tooltip_Select_To_Jump"))
    option.toolTip.description = getText("Tooltip_How_To_Jump")
    option.notAvailable = getJumpDuration(playerObj) <= 0 or isRelatedBodyPartDamaged(playerObj)
    if option.notAvailable then
        option.toolTip.description = '<RGB:1,0,0> ' .. getText("Tooltip_Unable_To_Jump") ..' <RGB:1,1,1> <BR>'.. option.toolTip.description
    end
end


Events.OnPlayerUpdate.Add(JumpTo.onPlayerUpdate)
Events.OnKeyStartPressed.Add(JumpTo.onKeyStartPressed)
Events.OnFillWorldObjectContextMenu.Add(JumpTo.onFillWorldObjectContextMenu)
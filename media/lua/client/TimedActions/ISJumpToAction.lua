require "TimedActions/ISBaseTimedAction"

ISJumpToAction = ISBaseTimedAction:derive("ISJumpToAction")


function ISJumpToAction:isValid()
    return true
end


function ISJumpToAction:isValidStart()
    return true
end


function ISJumpToAction:animEvent(event, parameter)
    if event == 'JumpDone' then
        -- DONT restoreMovements() here.
        -- setIgnoreMovement(false) too early will cancel the inertial taxiing which is trigger by vanilla.
        -- the timedAction with maxTime, it will perform/stop anyway.
        -- otherwsie some other animtion will play.
        self.character:setRunning(self.hasRunning) -- give back running
        self.character:setSprinting(self.hasSprinting) -- give back running
        self.character:setSneaking(false) -- prevent sneaking animtion play in the end.
    elseif event == 'TouchGround' then
        self.forceZ = nil
    end
end


function ISJumpToAction:update()
    if self.forceZ then
        -- seems don't need those. and I don't how to restore those added floor.
        -- if currentSquare and currentSquare ~= self.lastKnownSquare then
        --     if not currentSquare:Is(IsoFlagType.solidfloor) then
        --         currentSquare:addFloor('')
        --         currentSquare:RecalcAllWithNeighbours(true)
        --     end
        --     self.lastKnownSquare = currentSquare
        -- end
        
        -- prevent falling while jumping.
        self.character:setFallTime(0)
        self.character:setbFalling(false)
        self.character:setZ(self.forceZ)

        self.character:getEmitter():stopSoundByName('HumanFootstepsCombined')

        -- that's all, NO NEED move player by self made coding.
        -- froced the player not falling, that mean can still moving on empty space.
        -- as long as the timedAction is not end.
        -- player is actually move to cross over, just a jump animtion is playing, 
        -- that make its looks like jumping.
        -- so there is no reason to coding custom movements.
        -- also keep using vanilla Collision, no need custom blocked check.

        if self.forceToFree then
            -- NO NEED care about the Collision. player already in a unfree square.
            -- this is for free the player.
            -- etc. player drop into a river or lake, and not enough materials to build floor. 
            -- that will unable to move any way.
            local deltaX = (self.destX - self.startX) * self:getJobDelta()
            local deltaY = (self.destY - self.startY) * self:getJobDelta()

            self.character:setX(self.startX + deltaX)
            self.character:setY(self.startY + deltaY)
            self.character:setZ(self.character:getZ())
        end
    end
end


function ISJumpToAction:waitToStart()
    -- NO NEED this face to dest position all time.
    -- if self.character:isPlayerMoving() and not self.forceToFree then
    --     -- self.forceToFree is for prevent jump backward while try jump to free.
    --     -- otherwise click behind character might cause wrong direction.
    --     -- let character turn round first.
    --     return false  -- return true mean is keep waiting.
    -- else
	--     self.character:faceLocation(self.destX, self.destY)
	--     return self.character:shouldBeTurning()  -- keep waiting shouldBeTurning() to be false.
    -- end
    self.character:faceLocation(self.destX, self.destY)
	return self.character:shouldBeTurning()  -- keep waiting shouldBeTurning() to be false.
end


function ISJumpToAction:start()
    if self.anim then
        self:consumeEndurance()  -- consumeEndurance anyway.
        self:setActionAnim(self.anim)
        self.startSquare = self.character:getCurrentSquare()
        self.startX = self.character:getX()
        self.startY = self.character:getY()
        self.forceZ = self.character:getZ()
        self.character:setIgnoreMovement(true)
        self.character:setRunning(false)
        self.character:setSprinting(false)
        self.character:setSneaking(false)
    end
end


-- function ISJumpToAction:create()
--     if self.hasSprinting then
--         self.anim = 'JumpSprintStart'
--     elseif self.hasRunning then
--         self.anim = 'JumpRunStart'
--     else
--         -- for select from menu while standing
--         self.anim = 'JumpStart'
--     end
--     ISBaseTimedAction.create(self)
-- end


function ISJumpToAction:stop()
    self:restoreMovements()
    ISBaseTimedAction.stop(self)
end


function ISJumpToAction:perform()
    self:restoreMovements()
    ISBaseTimedAction.perform(self)
end


function ISJumpToAction:new(character, duration, destX, destY)
    local o = {}
    setmetatable(o, self)
    self.__index = self
    o.character = character
    o.stopOnWalk = false
    o.stopOnRun = false
    o.stopOnAim = false

    o.hasSprinting = character:isSprinting()
    o.hasRunning = character:isRunning()

    o.useProgressBar = false
    
    -- use maxTime to control how far to jump.
    -- there is no need destX or destY anymore.
    -- Vanilla's physics engine will take care it by inertia.
    -- only need keep character not falling while jump animation is playing.
    -- keep the original collision,
    -- check square isblocked by lua may fail in extreme cases. 
    -- etc,. jump around a car, with A coincidental distance and angle can pass through.

    o.anim = 'JumpStart'
    -- No NEED minifiy anymore, 
    -- duration is calculated to not too big or small.
    -- for now the is between 15 ~ 35, 15 is base, Fitness and Sprinting add 20 maximum.
    -- o.maxTime = math.min(duration, 25)
    o.maxTime = math.min(duration, 25)

    if character:isSprinting() then
        o.anim = 'JumpSprintStart'
        o.maxTime = duration
        -- o.maxTime = math.min(duration, 50)
    elseif character:isRunning() then
        o.anim = 'JumpRunStart'
        o.maxTime = duration
        -- o.maxTime = math.min(duration, 35)
    end
    
    if not character:isPlayerMoving() then
        -- player is jump from standing.
        -- make sure the time is enough to corss one square.
        o.maxTime = 25
    end

    if isDebugEnabled() then
        print("================= JumpTo Menu =================")
        print("duration: " .. duration)
        print("maxTime: " .. o.maxTime)
        print("==============================================")
    end

    -- for turn character face to
    o.destX = destX or character:getX()
    o.destY = destY or character:getY()

    -- use when player need to be free, etc. in a river.
    o.forceToFree = not character:getCurrentSquare():isFree(false)
    
    return o
end


function ISJumpToAction:restoreMovements()
    self.character:setIgnoreMovement(false)
    self.character:setRunning(self.hasRunning)
    self.character:setSprinting(self.hasSprinting)
    self.character:setSneaking(false)
    self.forceZ = nil
end

function ISJumpToAction:consumeEndurance() --same as vault over fence
    local stats = self.character:getStats()
    if self.hasSprinting then
        stats:setEndurance(stats:getEndurance() - ZomboidGlobals.RunningEnduranceReduce * 700.0)
    elseif self.hasRunning then
        stats:setEndurance(stats:getEndurance() - ZomboidGlobals.RunningEnduranceReduce * 300.0)
    end
end
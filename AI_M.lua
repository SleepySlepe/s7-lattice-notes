dofile("./AI/USER_AI/Const.lua")

MA_DOUBLE = 8207
DOUBLE_STRAFE_LEVEL = 5
DOUBLE_STRAFE_SP_COST = 12
DOUBLE_STRAFE_DELAY_MS = 450
DOUBLE_STRAFE_CAST_RANGE = 9
ATTACK_REISSUE_MS = 200
MOVE_REISSUE_MS = 300

MyID = 0
MercTarget = 0
ManualTarget = 0
NextSkillAt = 0
NextAttackAt = 0
NextMoveAt = 0
MoveX = 0
MoveY = 0

function SafeNumber(value, defaultValue)
	if value == nil then
		return defaultValue
	end
	return tonumber(value) or defaultValue
end

function Distance(x1, y1, x2, y2)
	local dx = math.abs(x1 - x2)
	local dy = math.abs(y1 - y2)
	if dx > dy then
		return dx
	end
	return dy
end

function DistanceToActor(a, b)
	local ax, ay = GetV(V_POSITION, a)
	local bx, by = GetV(V_POSITION, b)
	if ax == nil or bx == nil or ax == -1 or bx == -1 then
		return 999
	end
	return Distance(ax, ay, bx, by)
end

function IsAliveMonster(id)
	return id ~= nil
		and id ~= 0
		and id ~= MyID
		and IsMonster(id) == 1
		and GetV(V_MOTION, id) ~= MOTION_DEAD
end

function AttackRange()
	local range = SafeNumber(GetV(V_ATTACKRANGE, MyID), 9)
	if range < 1 then
		return 9
	end
	return range
end

function SkillRange()
	local range = SafeNumber(GetV(V_SKILLATTACKRANGE, MyID, MA_DOUBLE), DOUBLE_STRAFE_CAST_RANGE)
	if range < 1 then
		return DOUBLE_STRAFE_CAST_RANGE
	end
	return range
end

function DoubleStrafeLevel()
	local mercType = SafeNumber(GetV(V_MERTYPE, MyID), 0)
	if mercType == 1 then
		return 2
	elseif mercType == 5 then
		return 5
	elseif mercType == 6 then
		return 7
	elseif mercType == 9 then
		return 10
	end

	return DOUBLE_STRAFE_LEVEL
end

function HasEnoughSP()
	local sp = SafeNumber(GetV(V_SP, MyID), 0)
	return sp >= DOUBLE_STRAFE_SP_COST
end

function OwnerID()
	return GetV(V_OWNER, MyID)
end

function OwnerTarget()
	local owner = OwnerID()
	if owner == nil or owner == 0 then
		return 0
	end

	local target = GetV(V_TARGET, owner)
	if IsAliveMonster(target) then
		return target
	end

	return 0
end

function FindDefenseTarget()
	local owner = OwnerID()
	if owner == nil or owner == 0 then
		return 0
	end

	local best = 0
	local bestDistance = 999
	local actors = GetActors()
	for _, actor in ipairs(actors) do
		if IsAliveMonster(actor) then
			local target = GetV(V_TARGET, actor)
			if target == owner or target == MyID then
				local distance = DistanceToActor(MyID, actor)
				if distance < bestDistance then
					best = actor
					bestDistance = distance
				end
			end
		end
	end

	return best
end

function ChooseTarget()
	if IsAliveMonster(ManualTarget) then
		return ManualTarget
	end
	ManualTarget = 0

	local ownerTarget = OwnerTarget()
	if ownerTarget ~= 0 then
		return ownerTarget
	end

	if IsAliveMonster(MercTarget) then
		return MercTarget
	end

	return FindDefenseTarget()
end

function CastDoubleStrafe(target, level)
	if IsAliveMonster(target) == false then
		return false
	end
	if HasEnoughSP() == false then
		return false
	end
	if GetTick() < NextSkillAt then
		return false
	end

	SkillObject(MyID, level or DoubleStrafeLevel(), MA_DOUBLE, target)
	NextSkillAt = GetTick() + DOUBLE_STRAFE_DELAY_MS
	return true
end

function AttackTarget(target)
	if IsAliveMonster(target) == false then
		return
	end

	local distance = DistanceToActor(MyID, target)
	if distance <= SkillRange() and CastDoubleStrafe(target, DoubleStrafeLevel()) then
		return
	end

	if distance <= AttackRange() then
		if GetTick() >= NextAttackAt then
			Attack(MyID, target)
			NextAttackAt = GetTick() + ATTACK_REISSUE_MS
		end
	else
		MoveTowardTarget(target)
	end
end

function MoveTowardTarget(target)
	if GetTick() < NextMoveAt then
		return
	end

	local myX, myY = GetV(V_POSITION, MyID)
	local targetX, targetY = GetV(V_POSITION, target)
	if myX == nil or targetX == nil or myX == -1 or targetX == -1 then
		return
	end

	local range = math.max(1, math.max(AttackRange(), SkillRange()) - 1)
	local stepX = 0
	local stepY = 0
	if targetX > myX then
		stepX = -1
	elseif targetX < myX then
		stepX = 1
	end
	if targetY > myY then
		stepY = -1
	elseif targetY < myY then
		stepY = 1
	end

	MoveX = targetX + (stepX * range)
	MoveY = targetY + (stepY * range)
	Move(MyID, MoveX, MoveY)
	NextMoveAt = GetTick() + MOVE_REISSUE_MS
end

function FollowOwner()
	if GetTick() < NextMoveAt then
		return
	end

	local owner = OwnerID()
	if owner == nil or owner == 0 then
		return
	end

	local ownerX, ownerY = GetV(V_POSITION, owner)
	local myX, myY = GetV(V_POSITION, MyID)
	if ownerX == nil or myX == nil or ownerX == -1 or myX == -1 then
		return
	end

	if Distance(myX, myY, ownerX, ownerY) > 2 then
		MoveX = ownerX
		MoveY = ownerY - 1
		Move(MyID, MoveX, MoveY)
		NextMoveAt = GetTick() + MOVE_REISSUE_MS
	end
end

function HandleCommand(msg)
	if msg[1] == ATTACK_OBJECT_CMD then
		if IsAliveMonster(msg[2]) then
			ManualTarget = msg[2]
			MercTarget = msg[2]
		end
	elseif msg[1] == SKILL_OBJECT_CMD then
		local level = tonumber(msg[2]) or DoubleStrafeLevel()
		local skillID = tonumber(msg[3]) or 0
		local target = msg[4]
		if skillID == MA_DOUBLE and IsAliveMonster(target) then
			ManualTarget = target
			MercTarget = target
			CastDoubleStrafe(target, level)
		end
	elseif msg[1] == MOVE_CMD or msg[1] == ATTACK_AREA_CMD then
		ManualTarget = 0
		MercTarget = 0
		MoveX = msg[2]
		MoveY = msg[3]
		Move(MyID, MoveX, MoveY)
	elseif msg[1] == HOLD_CMD or msg[1] == FOLLOW_CMD then
		ManualTarget = 0
		MercTarget = 0
	end
end

function AI(myid)
	MyID = myid

	local msg = GetMsg(myid)
	if msg[1] ~= NONE_CMD then
		HandleCommand(msg)
	else
		local reserved = GetResMsg(myid)
		if reserved[1] ~= NONE_CMD then
			HandleCommand(reserved)
		end
	end

	local target = ChooseTarget()
	if IsAliveMonster(target) then
		MercTarget = target
		AttackTarget(target)
	else
		MercTarget = 0
		FollowOwner()
	end
end

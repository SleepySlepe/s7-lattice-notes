dofile("./AI/USER_AI/Const.lua")
dofile("./AI/USER_AI/Util.lua")

TargetLists = TargetLists or {}
TargetLists.BehaviorMode = "Attack"
TargetLists.Mode = "off"
TargetLists.UseWhitelist = false
TargetLists.UseBlacklist = false
TargetLists.Whitelist = {}
TargetLists.Blacklist = {}
TargetLists.Patrol = {}
TargetLists.Runtime = {}
pcall(function() dofile("./AI/USER_AI/TargetLists.lua") end)

ARCHER01 = 1
ARCHER05 = 5
ARCHER06 = 6
ARCHER09 = 9

MA_DOUBLE = 8207
DOUBLE_STRAFE_RANGE = 9
DOUBLE_STRAFE_SP_COST = 12
DOUBLE_STRAFE_RETRY_MS = 100
DOUBLE_STRAFE_DELAY_MS = 500
DOUBLE_STRAFE_CONFIRM_TIMEOUT_MS = 900
MANUAL_DOUBLE_STRAFE_TIMEOUT_MS = 5000

STATE_IDLE = 0
STATE_FOLLOW = 1
STATE_CHASE_ATTACK = 2
STATE_ATTACK = 3
STATE_MOVE = 4
STATE_HOLD = 5
STATE_WAIT = 6

ATTACK_REISSUE_MS = 150
CHASE_REPATH_MS = 250
ANTI_IDLE_REISSUE_MS = 250
OWNER_PROTECTION_HOLD_MS = 500
OWNER_PROTECTION_REHIT_MS = 500
AVOID_DISTANCE_CELLS = 12
KITE_AWAY_DISTANCE_CELLS = 5

MyID = 0
CurrentState = STATE_IDLE
AttackTarget = 0
AttackTargetHit = 0
MoveX = 0
MoveY = 0
NextAttackCommandAt = 0
NextChaseRepathAt = 0
NextIdleStandbyMoveAt = 0
NextDoubleStrafeTryAt = 0
PendingDoubleStrafeAt = 0
PendingDoubleStrafeTarget = 0
PendingDoubleStrafeSP = 0
PendingDoubleStrafeLevel = 0
ManualDoubleStrafeTarget = 0
ManualDoubleStrafeLevel = 0
ManualDoubleStrafeSetAt = 0
AnchorEnabled = 0
AnchorX = 0
AnchorY = 0
LastOwnerPosX = -1
LastOwnerPosY = -1
OwnerMoveSince = 0
OwnerStandSince = 0
WaitModeReadyAt = 0
PendingCommands = Queue.new()
AttackedMob = {}
ProtectedMob = {}
KiteNoAttackDone = {}
SkillCastCount = {}

function ClampRuntimeMs(value, defaultValue, minimumValue, maximumValue)
	local number = tonumber(value) or defaultValue
	if number < minimumValue then
		number = minimumValue
	elseif number > maximumValue then
		number = maximumValue
	end

	return math.floor(number)
end

function EnsureRuntimeDefaults()
	if type(TargetLists.Runtime) ~= "table" then
		TargetLists.Runtime = {}
	end

	if TargetLists.Runtime.DefendOwner == nil then
		TargetLists.Runtime.DefendOwner = true
	else
		TargetLists.Runtime.DefendOwner = TargetLists.Runtime.DefendOwner == true
	end

	if TargetLists.Runtime.FollowOwnerOnMove == nil then
		TargetLists.Runtime.FollowOwnerOnMove = true
	else
		TargetLists.Runtime.FollowOwnerOnMove = TargetLists.Runtime.FollowOwnerOnMove == true
	end

	TargetLists.Runtime.FollowOwnerDelayMs = ClampRuntimeMs(TargetLists.Runtime.FollowOwnerDelayMs, 0, 0, 10000)
	TargetLists.Runtime.OwnerResumeMs = ClampRuntimeMs(TargetLists.Runtime.OwnerResumeMs, 100, 0, 10000)
	TargetLists.Runtime.PostSkillWaitMs = ClampRuntimeMs(TargetLists.Runtime.PostSkillWaitMs, 500, 0, 10000)
end

EnsureRuntimeDefaults()

function NormalizeSkillModeValue(value)
	local mode = string.lower(tostring(value or ""))
	if mode == "no skill" then
		return "No Skill"
	elseif mode == "one skill" then
		return "One Skill"
	elseif mode == "two skills" then
		return "Two Skills"
	elseif mode == "max skills" then
		return "Max Skills"
	end

	return "Max Skills"
end

function NormalizeListEntries(source)
	local ordered = {}
	local lookup = {}
	local tactics = {}

	if type(source) ~= "table" then
		return ordered, lookup, tactics
	end

	local function addEntry(value)
		local id = tonumber(value)
		if id ~= nil and id > 0 and lookup[id] ~= true then
			lookup[id] = true
			table.insert(ordered, id)
		end
	end

	local function mobIDFromEntry(entry)
		if type(entry) == "number" or type(entry) == "string" then
			return entry
		end

		if type(entry) == "table" then
			return entry.MobID or entry.MobId or entry.mob_id or entry.id
		end

		return nil
	end

	for _, value in ipairs(source) do
		local mobID = mobIDFromEntry(value)
		addEntry(mobID)
		if type(value) == "table" and tonumber(mobID) ~= nil and tonumber(mobID) > 0 then
			local skillLevel = tonumber(value.SkillLevel) or 0
			if skillLevel < 0 then
				skillLevel = 0
			elseif skillLevel > 10 then
				skillLevel = 10
			end

			tactics[tonumber(mobID)] = {
				Behavior = tostring(value.Behavior or ""),
				Skill = NormalizeSkillModeValue(value.Skill),
				SkillLevel = skillLevel
			}
		end
	end

	for key, value in pairs(source) do
		if type(key) == "number" and value == true then
			addEntry(key)
		end
	end

	return ordered, lookup, tactics
end

TargetLists.WhitelistOrder, TargetLists.WhitelistLookup, TargetLists.WhitelistTactics = NormalizeListEntries(TargetLists.Whitelist)
TargetLists.BlacklistOrder, TargetLists.BlacklistLookup, TargetLists.BlacklistTactics = NormalizeListEntries(TargetLists.Blacklist)

function Lower(value)
	return string.lower(tostring(value or ""))
end

function MonsterClass(id)
	return GetV(V_MERTYPE, id)
end

function GetTargetListMode()
	local mode = Lower(TargetLists.Mode or "off")
	if mode == "off" then
		if TargetLists.UseWhitelist then
			mode = "whitelist"
		elseif TargetLists.UseBlacklist then
			mode = "blacklist"
		end
	end

	return mode
end

function GetBehaviorMode()
	return tostring(TargetLists.BehaviorMode or "Attack")
end

function GetMonsterTactic(id)
	local class = MonsterClass(id)
	local mode = GetTargetListMode()
	local tactic = nil

	if mode == "blacklist" then
		tactic = TargetLists.BlacklistTactics[class]
		if tactic ~= nil then
			return tactic
		end
	end

	tactic = TargetLists.WhitelistTactics[class]
	if tactic ~= nil then
		return tactic
	end

	return TargetLists.BlacklistTactics[class]
end

function GetTargetBehavior(id)
	local tactic = GetMonsterTactic(id)
	if tactic ~= nil and tostring(tactic.Behavior or "") ~= "" then
		return Lower(tactic.Behavior)
	end

	return Lower(GetBehaviorMode())
end

function DefendOwnerEnabled()
	return TargetLists.Runtime ~= nil and TargetLists.Runtime.DefendOwner == true
end

function FollowOwnerOnMoveEnabled()
	return TargetLists.Runtime == nil or TargetLists.Runtime.FollowOwnerOnMove == true
end

function OwnerFollowDelayMs()
	return TargetLists.Runtime and TargetLists.Runtime.FollowOwnerDelayMs or 0
end

function OwnerResumeMs()
	return TargetLists.Runtime and TargetLists.Runtime.OwnerResumeMs or 100
end

function PostSkillWaitMs()
	return TargetLists.Runtime and TargetLists.Runtime.PostSkillWaitMs or 500
end

function PassesTargetLists(id)
	local class = MonsterClass(id)
	local mode = GetTargetListMode()

	if mode == "whitelist" and TargetLists.WhitelistLookup[class] ~= true then
		return false
	end

	if mode == "blacklist" and TargetLists.BlacklistLookup[class] == true then
		local tactic = TargetLists.BlacklistTactics[class]
		local behavior = Lower((tactic and tactic.Behavior) or "")
		if behavior == "avoid" then
			return false
		end
	end

	return true
end

function IsValidTarget(id)
	return id ~= 0
		and id ~= MyID
		and id ~= GetV(V_OWNER, MyID)
		and IsMonster(id) == 1
		and GetV(V_MOTION, id) ~= MOTION_DEAD
		and PassesTargetLists(id)
end

function IsValidProtectionTarget(id)
	return id ~= 0
		and id ~= MyID
		and id ~= GetV(V_OWNER, MyID)
		and IsMonster(id) == 1
		and GetV(V_MOTION, id) ~= MOTION_DEAD
end

function IsKSTarget(target)
	if target == 0 or IsValidProtectionTarget(target) == false then
		return false
	end

	local owner = GetV(V_OWNER, MyID)
	local actors = GetActors()
	local chasing = GetV(V_TARGET, target)

	if chasing ~= 0 and chasing ~= MyID and chasing ~= owner then
		for _, actor in ipairs(actors) do
			if actor == chasing and IsMonster(actor) ~= 1 then
				return true
			end
		end
	end

	for _, actor in ipairs(actors) do
		if actor ~= MyID
			and actor ~= owner
			and IsMonster(actor) ~= 1
			and GetV(V_TARGET, actor) == target then
			return true
		end
	end

	return false
end

function TargetUsesAvoidBehavior(id)
	return GetTargetBehavior(id) == "avoid"
end

function TargetUsesSnipeBehavior(id)
	local behavior = GetTargetBehavior(id)
	return behavior == "snipe" or behavior == "snipe first" or behavior == "snipe last"
end

function TargetUsesKiteAttackBehavior(id)
	return GetTargetBehavior(id) == "kite attack"
end

function TargetUsesKiteNoAttackBehavior(id)
	return GetTargetBehavior(id) == "kite no attack"
end

function IsTargetingOwner(target)
	local owner = GetV(V_OWNER, MyID)
	return owner ~= 0 and IsValidProtectionTarget(target) and GetV(V_TARGET, target) == owner
end

function IsTargetingMercenary(target)
	return IsValidProtectionTarget(target) and GetV(V_TARGET, target) == MyID
end

function IsReactiveBehaviorTarget(target)
	return IsTargetingOwner(target) or IsTargetingMercenary(target)
end

function WasProtected(id)
	local protectedUntil = ProtectedMob[id]
	if protectedUntil == nil then
		return false
	end

	if GetTick() >= protectedUntil then
		ProtectedMob[id] = nil
		return false
	end

	return true
end

function MarkProtected(id)
	if id ~= 0 then
		ProtectedMob[id] = GetTick() + OWNER_PROTECTION_REHIT_MS
	end
end

function NeedsOwnerProtectionHit(target)
	return DefendOwnerEnabled()
		and target ~= 0
		and IsValidProtectionTarget(target)
		and TargetUsesAvoidBehavior(target) == false
		and WasProtected(target) == false
		and IsTargetingOwner(target)
end

function ClearAttackTarget()
	AttackTarget = 0
	AttackTargetHit = 0
end

function WasAttacked(id)
	return AttackedMob[id] == 1
end

function MarkAttacked(id)
	if id ~= 0 then
		AttackedMob[id] = 1
	end
end

function GetSkillCastCount(id)
	return SkillCastCount[id] or 0
end

function MarkSkillCast(id)
	if id ~= 0 then
		SkillCastCount[id] = GetSkillCastCount(id) + 1
	end
end

function CleanupMemory()
	for id, _ in pairs(ProtectedMob) do
		if IsValidProtectionTarget(id) == false or IsTargetingOwner(id) == false then
			ProtectedMob[id] = nil
	end
end

function GetAttackBehaviorPriority(target)
	local behavior = GetTargetBehavior(target)
	if behavior == "" or behavior == "slepe mode" then
		behavior = "attack"
	end

	if behavior == "avoid" or behavior == "snipe" or behavior == "snipe first" or behavior == "snipe last" then
		return -1
	end

	if behavior == "kite no attack" and KiteNoAttackDone[target] == 1 then
		return -1
	end

	if behavior == "react first" then
		if IsReactiveBehaviorTarget(target) then
			return 650
		end
		return -1
	elseif behavior == "react" then
		if IsReactiveBehaviorTarget(target) then
			return 550
		end
		return -1
	elseif behavior == "react last" then
		if IsReactiveBehaviorTarget(target) then
			return 450
		end
		return -1
	elseif behavior == "attack first" then
		return 350
	elseif behavior == "attack last" then
		return 150
	elseif behavior == "kite attack" or behavior == "kite no attack" then
		return 300
	end

	return 250
end

function GetSkillBehaviorPriority(target)
	local behavior = GetTargetBehavior(target)
	if behavior == "" or behavior == "slepe mode" then
		behavior = "attack"
	end

	if behavior == "avoid" or behavior == "kite no attack" then
		return -1
	end

	if behavior == "react first" then
		if IsReactiveBehaviorTarget(target) then
			return 800
		end
		return -1
	elseif behavior == "react" then
		if IsReactiveBehaviorTarget(target) then
			return 700
		end
		return -1
	elseif behavior == "react last" then
		if IsReactiveBehaviorTarget(target) then
			return 600
		end
		return -1
	elseif behavior == "snipe first" then
		return 550
	elseif behavior == "snipe" then
		return 450
	elseif behavior == "snipe last" then
		return 350
	elseif behavior == "attack first" then
		return 500
	elseif behavior == "attack last" then
		return 300
	end

	return 400
end

function GetTargetSkillMode(id)
	local tactic = GetMonsterTactic(id)
	if tactic == nil then
		return "Max Skills"
	end

	return NormalizeSkillModeValue(tactic.Skill)
end

function GetDoubleStrafeLevel()
	local mercType = GetV(V_MERTYPE, MyID)
	if mercType == ARCHER01 then
		return 2
	elseif mercType == ARCHER05 then
		return 5
	elseif mercType == ARCHER06 then
		return 7
	elseif mercType == ARCHER09 then
		return 10
	end

	return 0
end

function HasDoubleStrafe()
	return GetDoubleStrafeLevel() > 0
end

function GetTargetSkillLevel(id)
	local defaultLevel = GetDoubleStrafeLevel()
	local tactic = GetMonsterTactic(id)
	if tactic == nil then
		return defaultLevel
	end

	local level = tonumber(tactic.SkillLevel) or defaultLevel
	if level <= 0 then
		return defaultLevel
	elseif level > defaultLevel then
		return defaultLevel
	end

	return math.floor(level)
end

function HasEnoughSPForDoubleStrafe()
	return GetV(V_SP, MyID) >= DOUBLE_STRAFE_SP_COST
end

function UsesSlepeCurrentTargetSkillRule(id)
	return GetTargetBehavior(id) == "slepe mode"
end

function HasTacticRepeatSkillMode(id)
	local tactic = GetMonsterTactic(id)
	if tactic == nil then
		return false
	end

	local skillMode = NormalizeSkillModeValue(tactic.Skill)
	return skillMode == "Two Skills" or skillMode == "Max Skills"
end

function TargetAllowsSkill(id, allowSlepeAfterAttack)
	if HasDoubleStrafe() == false or TargetUsesKiteNoAttackBehavior(id) then
		return false
	end

	local skillMode = GetTargetSkillMode(id)
	if skillMode == "No Skill" then
		return false
	end

	if allowSlepeAfterAttack ~= true
		and UsesSlepeCurrentTargetSkillRule(id)
		and WasAttacked(id)
		and HasTacticRepeatSkillMode(id) == false then
		return false
	end

	if skillMode == "One Skill" then
		return GetSkillCastCount(id) < 1
	elseif skillMode == "Two Skills" then
		return GetSkillCastCount(id) < 2
	end

	return true
end

function TargetAllowsSlepeCurrentTargetFallbackSkill(id)
	if UsesSlepeCurrentTargetSkillRule(id) == false then
		return false
	end

	if HasTacticRepeatSkillMode(id) then
		return TargetAllowsSkill(id, true)
	end

	return TargetAllowsSkill(id, false)
end

function SetManualDoubleStrafe(target, level)
	ManualDoubleStrafeTarget = target
	ManualDoubleStrafeLevel = level or 0
	ManualDoubleStrafeSetAt = GetTick()
end

function ClearManualDoubleStrafe()
	ManualDoubleStrafeTarget = 0
	ManualDoubleStrafeLevel = 0
	ManualDoubleStrafeSetAt = 0
end

function GetManualDoubleStrafeTarget()
	if ManualDoubleStrafeTarget == 0 then
		return 0
	end

	if GetTick() - ManualDoubleStrafeSetAt >= MANUAL_DOUBLE_STRAFE_TIMEOUT_MS then
		ClearManualDoubleStrafe()
		return 0
	end

	if IsValidProtectionTarget(ManualDoubleStrafeTarget) == false then
		ClearManualDoubleStrafe()
		return 0
	end

	return ManualDoubleStrafeTarget
end

function UpdateDoubleStrafeAttemptState()
	if PendingDoubleStrafeAt == 0 then
		return
	end

	if GetV(V_SP, MyID) < PendingDoubleStrafeSP then
		MarkSkillCast(PendingDoubleStrafeTarget)
		NextDoubleStrafeTryAt = GetTick() + DOUBLE_STRAFE_DELAY_MS
		if PendingDoubleStrafeTarget == ManualDoubleStrafeTarget then
			ClearManualDoubleStrafe()
		end
		PendingDoubleStrafeAt = 0
		PendingDoubleStrafeTarget = 0
		PendingDoubleStrafeLevel = 0
		return
	end

	if GetTick() - PendingDoubleStrafeAt >= DOUBLE_STRAFE_CONFIRM_TIMEOUT_MS then
		PendingDoubleStrafeAt = 0
		PendingDoubleStrafeTarget = 0
		PendingDoubleStrafeLevel = 0
	end
end

function FindOwnerAggroTarget(excludedTarget)
	if DefendOwnerEnabled() == false then
		return 0
	end

	local actors = GetActors()
	local bestTarget = 0
	local bestDistance = 999

	for _, actor in ipairs(actors) do
		if actor ~= excludedTarget
			and NeedsOwnerProtectionHit(actor)
			and IsKSTarget(actor) == false then
			local distance = DistanceToActor(MyID, actor)
			if distance ~= -1 and distance < bestDistance then
				bestTarget = actor
				bestDistance = distance
			end
		end
	end

	return bestTarget
end

function FindMonsterTarget(excludedTarget)
	local actors = GetActors()
	local bestTarget = 0
	local bestDistance = 999
	local bestPriority = -1

	for _, actor in ipairs(actors) do
		if actor ~= excludedTarget
			and IsValidTarget(actor)
			and IsKSTarget(actor) == false then
			local priority = GetAttackBehaviorPriority(actor)
			if priority >= 0 then
				local distance = DistanceToActor(MyID, actor)
				if distance ~= -1 and (priority > bestPriority or (priority == bestPriority and distance < bestDistance)) then
					bestTarget = actor
					bestPriority = priority
					bestDistance = distance
				end
			end
		end
	end

	return bestTarget
end

function FindSkillTarget(excludedTarget)
	local actors = GetActors()
	local bestTarget = 0
	local bestDistance = 999
	local bestPriority = -1

	for _, actor in ipairs(actors) do
		if actor ~= excludedTarget
			and IsValidTarget(actor)
			and IsKSTarget(actor) == false
			and TargetAllowsSkill(actor, false) then
			local level = GetTargetSkillLevel(actor)
			local priority = GetSkillBehaviorPriority(actor)
			if level > 0 and priority >= 0 and IsInDoubleStrafeRange(actor) then
				local distance = DistanceToActor(MyID, actor)
				if distance ~= -1 and (priority > bestPriority or (priority == bestPriority and distance < bestDistance)) then
					bestTarget = actor
					bestPriority = priority
					bestDistance = distance
				end
			end
		end
	end

	return bestTarget
end

function FindSnipeApproachTarget()
	local actors = GetActors()
	local bestTarget = 0
	local bestDistance = 999
	local bestPriority = -1

	for _, actor in ipairs(actors) do
		if IsValidTarget(actor)
			and IsKSTarget(actor) == false
			and TargetUsesSnipeBehavior(actor)
			and TargetAllowsSkill(actor, false) then
			local distance = DistanceToActor(MyID, actor)
			local priority = GetSkillBehaviorPriority(actor)
			if distance ~= -1 and priority >= 0 and (priority > bestPriority or (priority == bestPriority and distance < bestDistance)) then
				bestTarget = actor
				bestPriority = priority
				bestDistance = distance
			end
		end
	end

	return bestTarget
end

function StartAttackChase(target)
	if IsValidProtectionTarget(target) == false then
		ClearAttackTarget()
		CurrentState = STATE_IDLE
		return
	end

	AttackTarget = target
	AttackTargetHit = 0
	NextChaseRepathAt = 0
	NextAttackCommandAt = 0
	CurrentState = STATE_CHASE_ATTACK
end

function AcquireAttackTarget(excludedTarget)
	if AttackTarget ~= 0 and IsValidProtectionTarget(AttackTarget) then
		return
	end

	local protectTarget = FindOwnerAggroTarget(excludedTarget)
	if protectTarget ~= 0 then
		StartAttackChase(protectTarget)
		return
	end

	local fallbackTarget = FindMonsterTarget(excludedTarget)
	if fallbackTarget ~= 0 then
		StartAttackChase(fallbackTarget)
		return
	end

	ClearAttackTarget()
end

function GetStandbyCell()
	if AnchorEnabled == 1 then
		return AnchorX, AnchorY
	end

	local owner = GetV(V_OWNER, MyID)
	local ownerX, ownerY = GetV(V_POSITION, owner)
	if ownerX == -1 or ownerY == -1 then
		return ownerX, ownerY
	end

	return ownerX, ownerY - 1
end

function IsAtStandbyCell()
	local myX, myY = GetV(V_POSITION, MyID)
	local standbyX, standbyY = GetStandbyCell()
	if myX == -1 or standbyX == -1 then
		return false
	end

	return Distance(myX, myY, standbyX, standbyY) <= 1
end

function ForceMoveTo(x, y)
	if x == -1 or y == -1 then
		return false
	end

	Move(MyID, x, y)
	MoveX = x
	MoveY = y
	return true
end

function ForceStandby()
	local standbyX, standbyY = GetStandbyCell()
	if ForceMoveTo(standbyX, standbyY) then
		CurrentState = STATE_FOLLOW
	end
end

function EnsureIdleStandby()
	if AttackTarget ~= 0 or IsAtStandbyCell() then
		return false
	end

	if GetTick() < NextIdleStandbyMoveAt and CurrentState == STATE_FOLLOW then
		return true
	end

	ForceStandby()
	NextIdleStandbyMoveAt = GetTick() + ANTI_IDLE_REISSUE_MS
	return true
end

function AttackRange()
	local range = GetV(V_ATTACKRANGE, MyID)
	if range == nil or range < 1 then
		return 9
	end

	return range
end

function GetApproachCellForRange(target, desiredRange)
	local myX, myY = GetV(V_POSITION, MyID)
	local targetX, targetY = GetV(V_POSITION, target)
	if myX == -1 or targetX == -1 then
		return -1, -1
	end

	local distance = Distance(myX, myY, targetX, targetY)
	if distance ~= -1 and distance <= desiredRange then
		return myX, myY
	end

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

	return targetX + (stepX * desiredRange), targetY + (stepY * desiredRange)
end

function GetAttackApproachCell(target)
	return GetApproachCellForRange(target, AttackRange())
end

function GetSkillApproachCell(target)
	return GetApproachCellForRange(target, DOUBLE_STRAFE_RANGE)
end

function IsInDoubleStrafeRange(target)
	return DistanceToActor(MyID, target) <= DOUBLE_STRAFE_RANGE
end

function UpdateAttackChaseMovement()
	if AttackTarget == 0 then
		return
	end

	local nextX, nextY = GetAttackApproachCell(AttackTarget)
	if nextX == -1 then
		return
	end

	if GetTick() >= NextChaseRepathAt or GetV(V_MOTION, MyID) ~= MOTION_MOVE or MoveX ~= nextX or MoveY ~= nextY then
		ForceMoveTo(nextX, nextY)
		NextChaseRepathAt = GetTick() + CHASE_REPATH_MS
	end
end

function GetKiteAwayCell(target)
	local myX, myY = GetV(V_POSITION, MyID)
	local targetX, targetY = GetV(V_POSITION, target)
	if myX == -1 or targetX == -1 then
		return -1, -1
	end

	local stepX = 0
	local stepY = 0
	if myX > targetX then
		stepX = 1
	elseif myX < targetX then
		stepX = -1
	end
	if myY > targetY then
		stepY = 1
	elseif myY < targetY then
		stepY = -1
	end
	if stepX == 0 and stepY == 0 then
		stepY = -1
	end

	return myX + (stepX * KITE_AWAY_DISTANCE_CELLS), myY + (stepY * KITE_AWAY_DISTANCE_CELLS)
end

function HandleKiteBehavior(target)
	if target == 0 or IsValidProtectionTarget(target) == false then
		return false
	end

	if TargetUsesKiteNoAttackBehavior(target) and KiteNoAttackDone[target] == 1 then
		local kiteX, kiteY = GetKiteAwayCell(target)
		ClearAttackTarget()
		ForceMoveTo(kiteX, kiteY)
		CurrentState = STATE_MOVE
		return true
	end

	if TargetUsesKiteAttackBehavior(target) then
		local distance = DistanceToActor(MyID, target)
		if distance ~= -1 and distance < KITE_AWAY_DISTANCE_CELLS then
			local kiteX, kiteY = GetKiteAwayCell(target)
			ForceMoveTo(kiteX, kiteY)
			CurrentState = STATE_CHASE_ATTACK
			return true
		end
	end

	return false
end

function TryCastDoubleStrafe()
	if HasDoubleStrafe() == false or HasEnoughSPForDoubleStrafe() == false then
		return 0
	end

	if PendingDoubleStrafeAt ~= 0 or GetTick() < NextDoubleStrafeTryAt then
		return 0
	end

	local target = GetManualDoubleStrafeTarget()
	if target == 0 then
		if AttackTarget ~= 0 and TargetUsesSnipeBehavior(AttackTarget) == false and UsesSlepeCurrentTargetSkillRule(AttackTarget) == false then
			if TargetAllowsSkill(AttackTarget, true) and IsInDoubleStrafeRange(AttackTarget) then
				target = AttackTarget
			end
		end

		if target == 0 then
			target = FindSkillTarget(AttackTarget)
		end

		if target == 0
			and AttackTarget ~= 0
			and TargetAllowsSlepeCurrentTargetFallbackSkill(AttackTarget)
			and IsInDoubleStrafeRange(AttackTarget) then
			target = AttackTarget
		end
	end

	if target == 0 then
		return 0
	end

	local level = GetTargetSkillLevel(target)
	if target == ManualDoubleStrafeTarget and ManualDoubleStrafeLevel > 0 then
		level = math.min(ManualDoubleStrafeLevel, GetDoubleStrafeLevel())
	end

	if level <= 0 or IsInDoubleStrafeRange(target) == false then
		return 0
	end

	local spBefore = GetV(V_SP, MyID)
	SkillObject(MyID, level, MA_DOUBLE, target)
	PendingDoubleStrafeAt = GetTick()
	PendingDoubleStrafeTarget = target
	PendingDoubleStrafeSP = spBefore
	PendingDoubleStrafeLevel = level
	NextDoubleStrafeTryAt = GetTick() + DOUBLE_STRAFE_RETRY_MS
	return target
end

function TryApproachSnipeTarget()
	local target = FindSnipeApproachTarget()
	if target == 0 then
		return false
	end

	if TryCastDoubleStrafe() ~= 0 then
		return true
	end

	local nextX, nextY = GetSkillApproachCell(target)
	if nextX ~= -1 and nextY ~= -1 then
		ForceMoveTo(nextX, nextY)
		CurrentState = STATE_FOLLOW
		return true
	end

	return false
end

function HandleAvoidPriority()
	local actors = GetActors()
	local avoidTarget = 0
	local bestDistance = 999

	for _, actor in ipairs(actors) do
		if IsValidProtectionTarget(actor) and TargetUsesAvoidBehavior(actor) then
			local distance = DistanceToActor(MyID, actor)
			if distance ~= -1 and distance < bestDistance then
				avoidTarget = actor
				bestDistance = distance
			end
		end
	end

	if avoidTarget == 0 then
		return false
	end

	if bestDistance < AVOID_DISTANCE_CELLS then
		local kiteX, kiteY = GetKiteAwayCell(avoidTarget)
		ClearAttackTarget()
		ForceMoveTo(kiteX, kiteY)
		CurrentState = STATE_FOLLOW
	end

	return true
end

function HandleOwnerProtectionPriority()
	local target = FindOwnerAggroTarget(0)
	if target == 0 then
		return false
	end

	if AttackTarget ~= target then
		StartAttackChase(target)
	end

	return false
end

function HandlePostNormalAttack(target)
	MarkAttacked(target)
	if IsTargetingOwner(target) then
		MarkProtected(target)
		ClearAttackTarget()
		WaitModeReadyAt = GetTick() + OWNER_PROTECTION_HOLD_MS
		CurrentState = STATE_WAIT
		return
	end

	if TargetUsesKiteNoAttackBehavior(target) then
		KiteNoAttackDone[target] = 1
		ClearAttackTarget()
		local kiteX, kiteY = GetKiteAwayCell(target)
		ForceMoveTo(kiteX, kiteY)
		CurrentState = STATE_MOVE
	end
end

function HandleManualDoubleStrafePriority()
	local target = GetManualDoubleStrafeTarget()
	if target == 0 then
		return false
	end

	if TryCastDoubleStrafe() ~= 0 then
		return true
	end

	if HasEnoughSPForDoubleStrafe() == false then
		return true
	end

	local level = ManualDoubleStrafeLevel
	if level <= 0 then
		level = GetTargetSkillLevel(target)
	end

	if IsInDoubleStrafeRange(target) then
		return true
	end

	local nextX, nextY = GetSkillApproachCell(target)
	if nextX ~= -1 and nextY ~= -1 then
		ClearAttackTarget()
		ForceMoveTo(nextX, nextY)
		CurrentState = STATE_MOVE
	end

	return true
end

function OwnerMovementOverrideActive()
	if CurrentState == STATE_WAIT or AnchorEnabled == 1 then
		return false
	end

	local owner = GetV(V_OWNER, MyID)
	local ownerX, ownerY = GetV(V_POSITION, owner)
	if ownerX == -1 or ownerY == -1 then
		return false
	end

	local ownerMoving = false
	if LastOwnerPosX ~= -1 and LastOwnerPosY ~= -1 then
		ownerMoving = ownerX ~= LastOwnerPosX or ownerY ~= LastOwnerPosY
	end

	LastOwnerPosX = ownerX
	LastOwnerPosY = ownerY

	if GetV(V_MOTION, owner) == MOTION_MOVE then
		ownerMoving = true
	end

	if ownerMoving then
		if FollowOwnerOnMoveEnabled() == false then
			OwnerMoveSince = 0
			OwnerStandSince = 0
			return false
		end

		if OwnerMoveSince == 0 then
			OwnerMoveSince = GetTick()
		end
		OwnerStandSince = 0
		if GetTick() - OwnerMoveSince >= OwnerFollowDelayMs() then
			ClearAttackTarget()
			ForceStandby()
			return true
		end

		return false
	end

	OwnerMoveSince = 0
	if OwnerStandSince == 0 then
		OwnerStandSince = GetTick()
	end

	if GetTick() - OwnerStandSince < OwnerResumeMs() then
		ForceStandby()
		return true
	end

	return false
end

function TickIdle()
	local queued = Queue.pop_left(PendingCommands)
	if queued ~= nil then
		ProcessCommand(queued)
		return
	end

	TryCastDoubleStrafe()
	AcquireAttackTarget()
	if AttackTarget ~= 0 then
		return
	end

	if TryApproachSnipeTarget() then
		return
	end

	EnsureIdleStandby()
end

function TickFollow()
	TryCastDoubleStrafe()
	AcquireAttackTarget()
	if AttackTarget ~= 0 then
		return
	end

	if TryApproachSnipeTarget() then
		return
	end

	if IsAtStandbyCell() then
		CurrentState = STATE_IDLE
		return
	end

	EnsureIdleStandby()
end

function TickChaseAttack()
	if AttackTarget == 0 or IsValidProtectionTarget(AttackTarget) == false or IsKSTarget(AttackTarget) then
		local oldTarget = AttackTarget
		ClearAttackTarget()
		AcquireAttackTarget(oldTarget)
		if AttackTarget == 0 then
			CurrentState = STATE_IDLE
		end
		return
	end

	if TargetUsesSnipeBehavior(AttackTarget) then
		ClearAttackTarget()
		TryApproachSnipeTarget()
		return
	end

	if HandleKiteBehavior(AttackTarget) then
		return
	end

	local castTarget = TryCastDoubleStrafe()
	if castTarget == AttackTarget and AttackTargetHit == 0 and UsesSlepeCurrentTargetSkillRule(AttackTarget) then
		WaitModeReadyAt = GetTick() + PostSkillWaitMs()
		CurrentState = STATE_WAIT
		return
	end

	local distance = DistanceToActor(MyID, AttackTarget)
	if distance == -1 then
		ClearAttackTarget()
		CurrentState = STATE_IDLE
		return
	end

	if distance <= AttackRange() then
		Attack(MyID, AttackTarget)
		NextAttackCommandAt = GetTick() + ATTACK_REISSUE_MS
		AttackTargetHit = 1
		HandlePostNormalAttack(AttackTarget)
		if AttackTarget ~= 0 then
			CurrentState = STATE_ATTACK
		end
		return
	end

	UpdateAttackChaseMovement()
end

function TickAttack()
	if AttackTarget == 0 or IsValidProtectionTarget(AttackTarget) == false or IsKSTarget(AttackTarget) then
		local oldTarget = AttackTarget
		ClearAttackTarget()
		AcquireAttackTarget(oldTarget)
		if AttackTarget == 0 then
			CurrentState = STATE_IDLE
		end
		return
	end

	if HandleKiteBehavior(AttackTarget) then
		return
	end

	TryCastDoubleStrafe()

	local distance = DistanceToActor(MyID, AttackTarget)
	if distance == -1 then
		ClearAttackTarget()
		CurrentState = STATE_IDLE
		return
	end

	if distance > AttackRange() then
		CurrentState = STATE_CHASE_ATTACK
		UpdateAttackChaseMovement()
		return
	end

	if GetTick() >= NextAttackCommandAt then
		Attack(MyID, AttackTarget)
		NextAttackCommandAt = GetTick() + ATTACK_REISSUE_MS
		AttackTargetHit = 1
		HandlePostNormalAttack(AttackTarget)
	end
end

function TickMove()
	if AttackTarget == 0 then
		AcquireAttackTarget()
	end

	local x, y = GetV(V_POSITION, MyID)
	if x == MoveX and y == MoveY then
		CurrentState = STATE_IDLE
	end
end

function TickWait()
	if GetTick() < WaitModeReadyAt then
		return
	end

	WaitModeReadyAt = 0
	CurrentState = STATE_IDLE
end

function ForceImmediateActivity()
	if CurrentState == STATE_HOLD or CurrentState == STATE_WAIT then
		return
	end

	if AttackTarget ~= 0 and IsValidProtectionTarget(AttackTarget) then
		if CurrentState ~= STATE_ATTACK and CurrentState ~= STATE_CHASE_ATTACK then
			CurrentState = STATE_CHASE_ATTACK
		end
		return
	end

	AcquireAttackTarget()
	if AttackTarget ~= 0 then
		CurrentState = STATE_CHASE_ATTACK
		return
	end

	EnsureIdleStandby()
end

function SetAnchor(x, y)
	AnchorEnabled = 1
	AnchorX = x
	AnchorY = y
end

function ClearAnchor()
	AnchorEnabled = 0
	AnchorX = 0
	AnchorY = 0
end

function HandleMoveCommand(x, y)
	ClearManualDoubleStrafe()
	SetAnchor(x, y)
	ForceMoveTo(x, y)
	CurrentState = STATE_MOVE
end

function HandleAttackObjectCommand(target)
	ClearManualDoubleStrafe()
	ClearAnchor()
	StartAttackChase(target)
end

function HandleSkillObjectCommand(level, skillID, target)
	if skillID == MA_DOUBLE then
		SetManualDoubleStrafe(target, level)
		return
	end

	SkillObject(MyID, level, skillID, target)
end

function HandleHoldCommand()
	CurrentState = STATE_HOLD
	ClearAttackTarget()
end

function HandleFollowCommand()
	ClearAnchor()
	CurrentState = STATE_IDLE
	ForceStandby()
end

function ProcessCommand(msg)
	if msg[1] == MOVE_CMD then
		HandleMoveCommand(msg[2], msg[3])
	elseif msg[1] == ATTACK_OBJECT_CMD then
		HandleAttackObjectCommand(msg[2])
	elseif msg[1] == ATTACK_AREA_CMD then
		HandleMoveCommand(msg[2], msg[3])
	elseif msg[1] == SKILL_OBJECT_CMD then
		HandleSkillObjectCommand(msg[2], msg[3], msg[4])
	elseif msg[1] == HOLD_CMD then
		HandleHoldCommand()
	elseif msg[1] == FOLLOW_CMD then
		HandleFollowCommand()
	end
end

function AI(myid)
	MyID = myid
	UpdateDoubleStrafeAttemptState()
	CleanupMemory()

	local msg = GetMsg(myid)
	local reserved = GetResMsg(myid)

	if msg[1] == NONE_CMD then
		if reserved[1] ~= NONE_CMD and Queue.size(PendingCommands) < 10 then
			Queue.push_right(PendingCommands, reserved)
		end
	else
		Queue.clear(PendingCommands)
		ProcessCommand(msg)
	end

	if HandleManualDoubleStrafePriority() then
		return
	end

	if HandleAvoidPriority() then
		return
	end

	HandleOwnerProtectionPriority()

	if OwnerMovementOverrideActive() then
		return
	end

	if CurrentState == STATE_IDLE then
		TickIdle()
	elseif CurrentState == STATE_FOLLOW then
		TickFollow()
	elseif CurrentState == STATE_CHASE_ATTACK then
		TickChaseAttack()
	elseif CurrentState == STATE_ATTACK then
		TickAttack()
	elseif CurrentState == STATE_MOVE then
		TickMove()
	elseif CurrentState == STATE_HOLD then
		-- Hold keeps auto-engage off while still accepting manual commands.
	elseif CurrentState == STATE_WAIT then
		TickWait()
	end

	ForceImmediateActivity()
end

	for id, _ in pairs(KiteNoAttackDone) do
		if IsValidProtectionTarget(id) == false then
			KiteNoAttackDone[id] = nil
		end
	end

	for id, _ in pairs(SkillCastCount) do
		if IsValidProtectionTarget(id) == false then
			SkillCastCount[id] = nil
		end
	end
end

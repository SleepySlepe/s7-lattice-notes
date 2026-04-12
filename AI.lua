dofile("./AI/USER_AI/Const.lua")
dofile("./AI/USER_AI/Util.lua")

TargetLists = TargetLists or {}
TargetLists.BehaviorMode = "Slepe Mode"
TargetLists.Mode = "off"
TargetLists.UseWhitelist = false
TargetLists.UseBlacklist = false
TargetLists.Whitelist = {}
TargetLists.Blacklist = {}
TargetLists.HomunculusSkills = {}
TargetLists.Patrol = {}
TargetLists.Runtime = {}
pcall(function() dofile("./AI/USER_AI/TargetLists.lua") end)

DEFAULT_CAPRICE_LEVEL = 5

HOMUN_SKILL_DEFAULTS = {
	Amistr = {
		Bulwark = { MinSPPercent = 40, Level = 0 },
		Casting = { MinSPPercent = 10, Level = 0 }
	},
	Filir = {
		Moonlight = { MinSPPercent = 38, Level = 2 },
		AcceleratedFlight = { MinSPPercent = 30, Level = 1 },
		Flitting = { MinSPPercent = 35, Level = 0 }
	},
	Lif = {
		HealingTouch = { MinSPPercent = 30, Level = 5 },
		UrgentEscape = { MinSPPercent = 40, Level = 0 }
	},
	Vanilmirth = {
		Caprice = { MinSPPercent = 5, Level = 5 },
		ChaoticBlessings = { MinSPPercent = 40, Level = 0, OwnerHPPercent = 0, HomunHPPercent = 0 }
	}
}

function EnsureHomunculusSkillDefaults()
	if type(TargetLists.HomunculusSkills) ~= "table" then
		TargetLists.HomunculusSkills = {}
	end

	for family, skills in pairs(HOMUN_SKILL_DEFAULTS) do
		if type(TargetLists.HomunculusSkills[family]) ~= "table" then
			TargetLists.HomunculusSkills[family] = {}
		end

		for skillName, defaults in pairs(skills) do
			if type(TargetLists.HomunculusSkills[family][skillName]) ~= "table" then
				TargetLists.HomunculusSkills[family][skillName] = {}
			end

			local config = TargetLists.HomunculusSkills[family][skillName]
			if tonumber(config.MinSPPercent) == nil then
				config.MinSPPercent = defaults.MinSPPercent
			end

			if tonumber(config.Level) == nil then
				config.Level = defaults.Level
			end

			if skillName == "ChaoticBlessings" then
				if tonumber(config.OwnerHPPercent) == nil then
					config.OwnerHPPercent = defaults.OwnerHPPercent or 0
				end

				if tonumber(config.HomunHPPercent) == nil then
					config.HomunHPPercent = defaults.HomunHPPercent or 0
				end
			end
		end
	end
end

EnsureHomunculusSkillDefaults()

function EnsurePatrolDefaults()
	if type(TargetLists.Patrol) ~= "table" then
		TargetLists.Patrol = {}
	end

	local enabled = TargetLists.Patrol.Enabled
	TargetLists.Patrol.Enabled = enabled == true

	local shape = string.lower(tostring(TargetLists.Patrol.Shape or "square cw"))
	if shape == "square" then
		shape = "square cw"
	elseif shape == "diamond" then
		shape = "diamond cw"
	elseif shape == "circle" then
		shape = "circle cw"
	end

	if shape ~= "square cw"
		and shape ~= "square ccw"
		and shape ~= "diamond cw"
		and shape ~= "diamond ccw"
		and shape ~= "circle cw"
		and shape ~= "circle ccw" then
		shape = "square cw"
	end
	TargetLists.Patrol.Shape = shape

	local distance = tonumber(TargetLists.Patrol.Distance) or 4
	if distance < 1 then
		distance = 1
	elseif distance > 12 then
		distance = 12
	end
	TargetLists.Patrol.Distance = math.floor(distance)
end

EnsurePatrolDefaults()

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

	if TargetLists.Runtime.TurretStayOnCell == nil then
		TargetLists.Runtime.TurretStayOnCell = false
	else
		TargetLists.Runtime.TurretStayOnCell = TargetLists.Runtime.TurretStayOnCell == true
	end

	if TargetLists.Runtime.AntiStuckEnabled == nil then
		TargetLists.Runtime.AntiStuckEnabled = true
	else
		TargetLists.Runtime.AntiStuckEnabled = TargetLists.Runtime.AntiStuckEnabled == true
	end

	if TargetLists.Runtime.FollowOwnerOnMove == nil then
		TargetLists.Runtime.FollowOwnerOnMove = true
	else
		TargetLists.Runtime.FollowOwnerOnMove = TargetLists.Runtime.FollowOwnerOnMove == true
	end

	if TargetLists.Runtime.DanceAttackEnabled == nil then
		TargetLists.Runtime.DanceAttackEnabled = false
	else
		TargetLists.Runtime.DanceAttackEnabled = TargetLists.Runtime.DanceAttackEnabled == true
	end

	if TargetLists.Runtime.DanceMovingOnly == nil then
		TargetLists.Runtime.DanceMovingOnly = true
	else
		TargetLists.Runtime.DanceMovingOnly = TargetLists.Runtime.DanceMovingOnly == true
	end

	if TargetLists.Runtime.DanceEveryAttack == nil then
		TargetLists.Runtime.DanceEveryAttack = false
	else
		TargetLists.Runtime.DanceEveryAttack = TargetLists.Runtime.DanceEveryAttack == true
	end

	TargetLists.Runtime.AntiStuckMs = ClampRuntimeMs(TargetLists.Runtime.AntiStuckMs, 500, 100, 10000)
	TargetLists.Runtime.FollowOwnerDelayMs = ClampRuntimeMs(TargetLists.Runtime.FollowOwnerDelayMs, 0, 0, 10000)
	TargetLists.Runtime.SoftResetMs = ClampRuntimeMs(TargetLists.Runtime.SoftResetMs, 400, 100, 10000)
	TargetLists.Runtime.OwnerResumeMs = ClampRuntimeMs(TargetLists.Runtime.OwnerResumeMs, 100, 0, 10000)
	TargetLists.Runtime.DanceMoveMs = ClampRuntimeMs(TargetLists.Runtime.DanceMoveMs, 600, 100, 10000)
	TargetLists.Runtime.PostSkillWaitMs = ClampRuntimeMs(TargetLists.Runtime.PostSkillWaitMs, 700, 0, 10000)
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
		if type(value) == "table" and mobID ~= nil and mobID > 0 then
			local skillLevel = tonumber(value.SkillLevel) or DEFAULT_CAPRICE_LEVEL
			if skillLevel < 1 or skillLevel > 5 then
				skillLevel = DEFAULT_CAPRICE_LEVEL
			end

			tactics[mobID] = {
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

STATE_IDLE = 0
STATE_FOLLOW = 1
STATE_CHASE_ATTACK = 2
STATE_ATTACK = 3
STATE_MOVE = 4
STATE_HOLD = 5
STATE_WAIT = 6

CAPRICE_SKILL = 8013
CHAOTIC_BLESSINGS_SKILL = 8014
CAPRICE_LEVEL = 5
CAPRICE_SP_COST = 30
CAPRICE_DELAY_MS = 3000
CHAOTIC_BLESSINGS_SP_COST = 40
CHAOTIC_BLESSINGS_DELAY_MS = 3000
CAPRICE_RETRY_MS = 100
CAPRICE_CONFIRM_TIMEOUT_MS = 5000
MANUAL_CAPRICE_TIMEOUT_MS = 5000
MOONLIGHT_SKILL = 8009
FLITTING_SKILL = 8010
ACCELERATED_FLIGHT_SKILL = 8011
CHASE_REPATH_MS = 400
CHASE_REPATH_DISTANCE = 2
ATTACK_STICKY_EXTRA_RANGE = 2
ATTACK_REISSUE_MS = 150
ATTACK_LATCH_GRACE_MS = 150
DANCE_MOVE_MS = TargetLists.Runtime.DanceMoveMs
DANCE_ATTACK_BUFFER_MS = 120
STUCK_STAND_MS = TargetLists.Runtime.AntiStuckMs
CHASE_LEAD_CELLS = 1
SP_TICK_INTERVAL_MS = 10000
SP_TICK_PAUSE_WINDOW_MS = 500
ANCHOR_RANGE = 7
OWNER_LEASH_CELLS = 18
SOFT_RESET_WALK_MS = TargetLists.Runtime.SoftResetMs
OWNER_FOLLOW_DELAY_MS = TargetLists.Runtime.FollowOwnerDelayMs
OWNER_RESUME_DELAY_MS = TargetLists.Runtime.OwnerResumeMs
POST_SKILL_WAIT_MS = TargetLists.Runtime.PostSkillWaitMs
POST_SKILL_IGNORE_MS = 400
POST_PRIMARY_SKILL_IGNORE_MS = 1500
UNREACHABLE_TARGET_IGNORE_MS = 3000
OWNER_PROTECTION_REHIT_MS = 500
OWNER_PROTECTION_HOLD_MS = 500
AVOID_DISTANCE_CELLS = 12
KITE_AWAY_DISTANCE_CELLS = 5
PATROL_MOVE_MS = 0
PATROL_STALL_MS = 400
SNIPE_ORBIT_MS = 300
IDLE_STANDBY_REISSUE_MS = 250

MyID = 0
CurrentState = STATE_IDLE
AttackTarget = 0
AttackTargetHit = 0
LastSkillTarget = 0
MoveX = 0
MoveY = 0
NextCapriceAt = 0
NextChaoticBlessingsAt = 0
NextFlittingAt = 0
NextAcceleratedFlightAt = 0
NextCapriceTryAt = 0
PendingCapriceAt = 0
PendingCapriceSP = 0
PendingCapriceTarget = 0
PendingCapriceCost = 0
PendingCapriceDelayMs = 0
ManualCapriceTarget = 0
ManualCapriceSetAt = 0
ManualCapriceLevel = 0
ManualCapriceSkill = 0
NextChaseRepathAt = 0
NextAttackCommandAt = 0
NextAttackRefreshMoveAt = 0
NextDanceMoveAt = 0
DANCE_SIDE = 1
StandStillSince = 0
LastMyPosX = -1
LastMyPosY = -1
LastOwnerPosX = -1
LastOwnerPosY = -1
OwnerMoveSince = 0
OwnerStandSince = 0
LastSP = 0
LastSPTickTime = 0
RequireStandbyReset = 0
StandbyResetStartedAt = 0
StandbyResetReadyAt = 0
StandbyResetStrict = 0
StandbyResetMoveBack = 1
AnchorEnabled = 0
AnchorX = 0
AnchorY = 0
PendingCommands = Queue.new()
AttackedMob = {}
ProtectedMob = {}
KiteNoAttackDone = {}
SkillCastCount = {}
SkillCastCountByClass = {}
LastSeenPosX = {}
LastSeenPosY = {}
IgnoreTargetUntil = {}
PatrolStep = 1
NextPatrolMoveAt = 0
PatrolStuckSince = 0
PatrolRetryCount = 0
PatrolLastPosX = -1
PatrolLastPosY = -1
WaitModeReadyAt = 0
NextSnipeOrbitAt = 0
SnipeOrbitStep = 1
NextIdleStandbyMoveAt = 0

function IsVanilmirth(id)
	local homunType = GetV(V_HOMUNTYPE, id)
	return homunType == VANILMIRTH
		or homunType == VANILMIRTH2
		or homunType == VANILMIRTH_H
		or homunType == VANILMIRTH_H2
end

function IsFilir(id)
	local homunType = GetV(V_HOMUNTYPE, id)
	return homunType == FILIR
		or homunType == FILIR2
		or homunType == FILIR_H
		or homunType == FILIR_H2
end

function MonsterClass(id)
	return GetV(V_HOMUNTYPE, id)
end

function GetTargetListMode()
	local mode = string.lower(TargetLists.Mode or "off")
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
	return TargetLists.BehaviorMode or "Slepe Mode"
end

function IsSnipeMode()
	return GetBehaviorMode() == "Snipe"
end

function IsSlepeMode()
	return GetBehaviorMode() == "Slepe Mode"
end

function PassesTargetLists(id)
	local class = MonsterClass(id)
	local mode = GetTargetListMode()

	if mode == "whitelist" and TargetLists.WhitelistLookup[class] ~= true then
		return false
	end

	if mode == "blacklist" and TargetLists.BlacklistLookup[class] == true then
		local tactic = TargetLists.BlacklistTactics[class]
		local behavior = string.lower(tostring((tactic and tactic.Behavior) or ""))
		if behavior == "avoid" then
			return false
		end
	end

	return true
end

function DefendOwnerEnabled()
	return TargetLists.Runtime ~= nil and TargetLists.Runtime.DefendOwner == true
end

function TurretStayOnCellEnabled()
	return TargetLists.Runtime ~= nil and TargetLists.Runtime.TurretStayOnCell == true
end

function TurretStayActive()
	return AnchorEnabled == 1 and TurretStayOnCellEnabled()
end

function AntiStuckEnabled()
	return TargetLists.Runtime == nil or TargetLists.Runtime.AntiStuckEnabled == true
end

function FollowOwnerOnMoveEnabled()
	return TargetLists.Runtime == nil or TargetLists.Runtime.FollowOwnerOnMove == true
end

function DanceAttackEnabled()
	return TargetLists.Runtime ~= nil and TargetLists.Runtime.DanceAttackEnabled == true
end

function DanceMovingOnly()
	return TargetLists.Runtime == nil or TargetLists.Runtime.DanceMovingOnly == true
end

function DanceEveryAttack()
	return TargetLists.Runtime ~= nil and TargetLists.Runtime.DanceEveryAttack == true
end

function IsValidTarget(id)
	return id ~= 0
		and IsMonster(id) == 1
		and GetV(V_MOTION, id) ~= MOTION_DEAD
		and PassesTargetLists(id)
end

function IsValidProtectionTarget(id)
	return id ~= 0
		and IsMonster(id) == 1
		and GetV(V_MOTION, id) ~= MOTION_DEAD
end

function IsOwnerProtectionAttackTarget(target)
	return NeedsOwnerProtectionHit(target)
end

function IsValidAttackTargetForCurrentPurpose(target)
	return IsValidTarget(target) or IsOwnerProtectionAttackTarget(target)
end

function IsKSTarget(target)
	if target == 0 or IsValidTarget(target) == false then
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

function IsTargetingOwner(target)
	if target == 0 or IsValidProtectionTarget(target) == false then
		return false
	end

	local owner = GetV(V_OWNER, MyID)
	return owner ~= 0 and GetV(V_TARGET, target) == owner
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

function ClearProtected(id)
	if id ~= 0 then
		ProtectedMob[id] = nil
	end
end

function CleanupProtectedMob()
	for id, protectedUntil in pairs(ProtectedMob) do
		if IsValidProtectionTarget(id) == false or IsTargetingOwner(id) == false or GetTick() >= protectedUntil then
			ProtectedMob[id] = nil
		end
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
function FindOwnerAggroTarget(excludedTarget)
	if DefendOwnerEnabled() == false then
		return 0
	end

	local actors = GetActors()
	local bestTarget = 0
	local bestDistance = 999

	for _, actor in ipairs(actors) do
		if actor ~= GetV(V_OWNER, MyID)
			and actor ~= MyID
			and actor ~= excludedTarget
			and IsValidProtectionTarget(actor)
			and IsTargetInActiveRange(actor)
			and IsTargetReachableWhileTurretStaying(actor)
			and NeedsOwnerProtectionHit(actor) then
			local distance = DistanceToActor(MyID, actor)
			if distance ~= -1 and distance < bestDistance then
				bestTarget = actor
				bestDistance = distance
			end
		end
	end

	return bestTarget
end

function HandleOwnerProtectionPriority()
	if DefendOwnerEnabled() == false then
		return false
	end

	local peelTarget = FindOwnerAggroTarget(0)
	if peelTarget ~= 0 then
		CancelSoftStandbyReset()

		if AttackTarget ~= peelTarget then
			StartAttackChase(peelTarget)
			ForceAttackChaseMovement()
			return true
		end

		local distance = DistanceToActor(MyID, peelTarget)
		if distance ~= -1 then
			if distance <= StickyAttackRange() and TryStickyAttackCommand() == 1 then
				if distance <= AttackRange() then
					CurrentState = STATE_ATTACK
				else
					CurrentState = STATE_CHASE_ATTACK
				end
				return true
			end

			if IsActuallyAttackingTarget() == false then
				if TryAttackRefreshStep() == 1 then
					return true
				end

				if distance <= AttackRange() then
					Attack(MyID, peelTarget)
					NextAttackCommandAt = GetTick() + ATTACK_REISSUE_MS
					HandlePostNormalAttack(peelTarget)
					if AttackTarget ~= 0 then
						CurrentState = STATE_ATTACK
					end
					return true
				end

				ForceAttackChaseMovement()
				CurrentState = STATE_CHASE_ATTACK
				return true
			end
		end

		if CurrentState ~= STATE_ATTACK and CurrentState ~= STATE_CHASE_ATTACK then
			CurrentState = STATE_CHASE_ATTACK
		end

		return true
	end

	return false
end

function ClearAttackTarget()
	AttackTarget = 0
	AttackTargetHit = 0
	NextAttackRefreshMoveAt = 0
end

function WasAttacked(id)
	return AttackedMob[id] == 1
end

function MarkAttacked(id)
	if id ~= 0 then
		AttackedMob[id] = 1
	end
end

function WasKiteNoAttackDone(id)
	return KiteNoAttackDone[id] == 1
end

function MarkKiteNoAttackDone(id)
	if id ~= 0 then
		KiteNoAttackDone[id] = 1
	end
end

function CleanupKiteNoAttackDone()
	for id, _ in pairs(KiteNoAttackDone) do
		if IsValidTarget(id) == false then
			KiteNoAttackDone[id] = nil
		end
	end
end

function IgnoreTargetBriefly(id)
	if id ~= 0 then
		IgnoreTargetUntil[id] = GetTick() + POST_SKILL_IGNORE_MS
	end
end

function IgnoreTargetForDuration(id, durationMs)
	if id ~= 0 then
		IgnoreTargetUntil[id] = GetTick() + durationMs
	end
end

function IgnorePrimarySkillTarget(id)
	if id ~= 0 then
		IgnoreTargetUntil[id] = GetTick() + POST_PRIMARY_SKILL_IGNORE_MS
	end
end

function IsIgnoredTarget(id)
	if id == 0 then
		return false
	end

	local untilTick = IgnoreTargetUntil[id] or 0
	if untilTick <= GetTick() then
		IgnoreTargetUntil[id] = nil
		return false
	end

	return true
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

function GetHomunculusSkillSetting(family, skillName)
	if type(TargetLists.HomunculusSkills) ~= "table" then
		return nil
	end

	local familySkills = TargetLists.HomunculusSkills[family]
	if type(familySkills) ~= "table" then
		return nil
	end

	local setting = familySkills[skillName]
	if type(setting) ~= "table" then
		return nil
	end

	return setting
end

function GetOffensiveSkillFamily()
	if IsVanilmirth(MyID) then
		return "Vanilmirth"
	elseif IsFilir(MyID) then
		return "Filir"
	end

	return nil
end

function GetOffensiveSkillKey()
	if IsVanilmirth(MyID) then
		return "Caprice"
	elseif IsFilir(MyID) then
		return "Moonlight"
	end

	return nil
end

function GetOffensiveSkillID()
	if IsVanilmirth(MyID) then
		return CAPRICE_SKILL
	elseif IsFilir(MyID) then
		return MOONLIGHT_SKILL
	end

	return 0
end

function GetOffensiveSkillSetting()
	local family = GetOffensiveSkillFamily()
	local skillKey = GetOffensiveSkillKey()
	if family == nil or skillKey == nil then
		return nil
	end

	return GetHomunculusSkillSetting(family, skillKey)
end

function GetCapriceMinSPPercent()
	local setting = GetOffensiveSkillSetting()
	if setting == nil then
		return 0
	end

	local value = tonumber(setting.MinSPPercent) or 0
	if value < 0 then
		return 0
	elseif value > 100 then
		return 100
	end

	return value
end

function GetDefaultCapriceLevel()
	local setting = GetOffensiveSkillSetting()
	if setting == nil then
		return DEFAULT_CAPRICE_LEVEL
	end

	local level = tonumber(setting.Level) or DEFAULT_CAPRICE_LEVEL
	if level < 0 then
		return 0
	elseif level > 5 then
		return DEFAULT_CAPRICE_LEVEL
	end

	return level
end

function GetChaoticBlessingsSetting()
	return GetHomunculusSkillSetting("Vanilmirth", "ChaoticBlessings")
end

function GetChaoticBlessingsMinSPPercent()
	local setting = GetChaoticBlessingsSetting()
	if setting == nil then
		return 0
	end

	local value = tonumber(setting.MinSPPercent) or 0
	if value < 0 then
		return 0
	elseif value > 100 then
		return 100
	end

	return value
end

function GetChaoticBlessingsLevel()
	local setting = GetChaoticBlessingsSetting()
	if setting == nil then
		return 0
	end

	local level = tonumber(setting.Level) or 0
	if level < 0 then
		return 0
	elseif level > 5 then
		return 5
	end

	return level
end

function GetChaoticBlessingsOwnerHPPercent()
	local setting = GetChaoticBlessingsSetting()
	if setting == nil then
		return 0
	end

	local value = tonumber(setting.OwnerHPPercent) or 0
	if value < 0 then
		return 0
	elseif value > 100 then
		return 100
	end

	return value
end

function GetChaoticBlessingsHomunHPPercent()
	local setting = GetChaoticBlessingsSetting()
	if setting == nil then
		return 0
	end

	local value = tonumber(setting.HomunHPPercent) or 0
	if value < 0 then
		return 0
	elseif value > 100 then
		return 100
	end

	return value
end

function GetFilirSupportSetting(skillName)
	return GetHomunculusSkillSetting("Filir", skillName)
end

function GetFilirSupportMinSPPercent(skillName)
	local setting = GetFilirSupportSetting(skillName)
	if setting == nil then
		return 0
	end

	local value = tonumber(setting.MinSPPercent) or 0
	if value < 0 then
		return 0
	elseif value > 100 then
		return 100
	end

	return value
end

function GetFilirSupportLevel(skillName)
	local setting = GetFilirSupportSetting(skillName)
	if setting == nil then
		return 0
	end

	local level = tonumber(setting.Level) or 0
	if level < 0 then
		return 0
	elseif level > 5 then
		return 5
	end

	return level
end

function CapriceEnabledByDefault()
	return GetDefaultCapriceLevel() >= 1
end

function MeetsCapriceSPThreshold()
	local minPercent = GetCapriceMinSPPercent()
	if minPercent <= 0 then
		return true
	end

	local maxSP = GetV(V_MAXSP, MyID)
	if maxSP <= 0 then
		return true
	end

	local currentPercent = (GetV(V_SP, MyID) * 100) / maxSP
	return currentPercent >= minPercent
end

function MeetsChaoticBlessingsSPThreshold()
	local minPercent = GetChaoticBlessingsMinSPPercent()
	if minPercent <= 0 then
		return true
	end

	local maxSP = GetV(V_MAXSP, MyID)
	if maxSP <= 0 then
		return true
	end

	local currentPercent = (GetV(V_SP, MyID) * 100) / maxSP
	return currentPercent >= minPercent
end

function MeetsFilirSupportSPThreshold(skillName)
	local minPercent = GetFilirSupportMinSPPercent(skillName)
	if minPercent <= 0 then
		return true
	end

	local maxSP = GetV(V_MAXSP, MyID)
	if maxSP <= 0 then
		return true
	end

	local currentPercent = (GetV(V_SP, MyID) * 100) / maxSP
	return currentPercent >= minPercent
end

function GetTargetSkillMode(id)
	local tactic = GetMonsterTactic(id)
	if tactic == nil then
		if CapriceEnabledByDefault() then
			return "Max Skills"
		end

		return "No Skill"
	end

	return NormalizeSkillModeValue(tactic.Skill)
end

function GetTargetBehavior(id)
	local tactic = GetMonsterTactic(id)
	if tactic == nil then
		return ""
	end

	return string.lower(tostring(tactic.Behavior or ""))
end

function TargetUsesSnipeBehavior(id)
	local behavior = GetTargetBehavior(id)
	return behavior == "snipe" or behavior == "snipe first" or behavior == "snipe last"
end

function TargetUsesAvoidBehavior(id)
	return GetTargetBehavior(id) == "avoid"
end

function TargetUsesKiteAwayBehavior(id)
	return GetTargetBehavior(id) == "kite attack"
end

function TargetUsesKiteNoAttackBehavior(id)
	return GetTargetBehavior(id) == "kite no attack"
end

function FindAvoidBehaviorTarget()
	local actors = GetActors()
	local bestTarget = 0
	local bestDistance = 999

	for _, actor in ipairs(actors) do
		if actor ~= GetV(V_OWNER, MyID)
			and actor ~= MyID
			and IsValidTarget(actor)
			and IsIgnoredTarget(actor) == false
			and TargetUsesAvoidBehavior(actor)
			and IsTargetInActiveRange(actor) then
			local distance = DistanceToActor(MyID, actor)
			if distance ~= -1 and distance < bestDistance then
				bestTarget = actor
				bestDistance = distance
			end
		end
	end

	return bestTarget
end

function GetAvoidCell(target)
	local myX, myY = GetV(V_POSITION, MyID)
	local targetX, targetY = GetV(V_POSITION, target)
	if myX == -1 or targetX == -1 then
		return myX, myY
	end

	local stepX = Sign(myX - targetX)
	local stepY = Sign(myY - targetY)
	if stepX == 0 and stepY == 0 then
		local owner = GetV(V_OWNER, MyID)
		local ownerX, ownerY = GetV(V_POSITION, owner)
		if ownerX ~= -1 and ownerY ~= -1 then
			stepX = Sign(ownerX - targetX)
			stepY = Sign(ownerY - targetY)
		end
		if stepX == 0 and stepY == 0 then
			stepY = -1
		end
	end

	return targetX + (stepX * AVOID_DISTANCE_CELLS), targetY + (stepY * AVOID_DISTANCE_CELLS)
end

function GetKiteAwayCell(target)
	local myX, myY = GetV(V_POSITION, MyID)
	local targetX, targetY = GetV(V_POSITION, target)
	if myX == -1 or targetX == -1 then
		return myX, myY
	end

	local stepX = Sign(myX - targetX)
	local stepY = Sign(myY - targetY)
	if stepX == 0 and stepY == 0 then
		local owner = GetV(V_OWNER, MyID)
		local ownerX, ownerY = GetV(V_POSITION, owner)
		if ownerX ~= -1 and ownerY ~= -1 then
			stepX = Sign(ownerX - targetX)
			stepY = Sign(ownerY - targetY)
		end
		if stepX == 0 and stepY == 0 then
			stepY = -1
		end
	end

	return targetX + (stepX * KITE_AWAY_DISTANCE_CELLS), targetY + (stepY * KITE_AWAY_DISTANCE_CELLS)
end

function HandleKiteBehavior(target)
	if target == 0 or IsValidTarget(target) == false then
		return false
	end

	local distance = DistanceToActor(MyID, target)
	if distance == -1 then
		return false
	end

	if TargetUsesKiteNoAttackBehavior(target) and WasKiteNoAttackDone(target) then
		local kiteX, kiteY = GetKiteAwayCell(target)
		ClearAttackTarget()
		if kiteX ~= -1 and kiteY ~= -1 then
			ForceMoveTo(kiteX, kiteY)
			CurrentState = STATE_MOVE
		else
			CurrentState = STATE_IDLE
		end
		return true
	end

	if TargetUsesKiteAwayBehavior(target) and distance < KITE_AWAY_DISTANCE_CELLS then
		local kiteX, kiteY = GetKiteAwayCell(target)
		if kiteX ~= -1 and kiteY ~= -1 then
			if GetV(V_MOTION, MyID) ~= MOTION_MOVE or MoveX ~= kiteX or MoveY ~= kiteY then
				ForceMoveTo(kiteX, kiteY)
				NextChaseRepathAt = GetTick() + CHASE_REPATH_MS
			end
			CurrentState = STATE_CHASE_ATTACK
			return true
		end
	end

	return false
end

function HandlePostNormalAttack(target)
	if target == 0 then
		return
	end

	MarkAttacked(target)
	if IsTargetingOwner(target) then
		MarkProtected(target)
		ClearAttackTarget()
		BeginOwnerProtectionHold()
		return
	end

	if TargetUsesKiteNoAttackBehavior(target) then
		MarkKiteNoAttackDone(target)
		local kiteX, kiteY = GetKiteAwayCell(target)
		ClearAttackTarget()
		if kiteX ~= -1 and kiteY ~= -1 then
			ForceMoveTo(kiteX, kiteY)
			CurrentState = STATE_MOVE
		else
			CurrentState = STATE_IDLE
		end
	end
end

function HandleAvoidPriority()
	local avoidTarget = FindAvoidBehaviorTarget()
	if avoidTarget == 0 then
		return false
	end

	local distance = DistanceToActor(MyID, avoidTarget)
	ClearAttackTarget()
	CancelSoftStandbyReset()

	local avoidX, avoidY = GetAvoidCell(avoidTarget)
	if avoidX ~= -1 and avoidY ~= -1 then
		if distance < AVOID_DISTANCE_CELLS or GetV(V_MOTION, MyID) ~= MOTION_MOVE or MoveX ~= avoidX or MoveY ~= avoidY then
			ForceMoveTo(avoidX, avoidY)
		end
	end

	CurrentState = STATE_FOLLOW
	return true
end

function TargetUsesReactBehavior(id)
	local behavior = GetTargetBehavior(id)
	return behavior == "react" or behavior == "react first" or behavior == "react last"
end

function IsTargetingHomunculus(target)
	if target == 0 or IsValidTarget(target) == false then
		return false
	end

	return GetV(V_TARGET, target) == MyID
end

function IsOwnerFocusingTarget(target)
	if target == 0 or IsValidTarget(target) == false then
		return false
	end

	local owner = GetV(V_OWNER, MyID)
	if owner == 0 then
		return false
	end

	return GetV(V_TARGET, owner) == target
end

function IsReactiveBehaviorTarget(target)
	return IsTargetingOwner(target) or IsTargetingHomunculus(target)
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

	if behavior == "kite no attack" then
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

function GetTargetSkillLevel(id)
	local tactic = GetMonsterTactic(id)
	if tactic == nil then
		local defaultLevel = GetDefaultCapriceLevel()
		if defaultLevel >= 1 and defaultLevel <= 5 then
			return defaultLevel
		end

		return CAPRICE_LEVEL
	end

	local level = tonumber(tactic.SkillLevel) or CAPRICE_LEVEL
	if level < 1 or level > 5 then
		return CAPRICE_LEVEL
	end

	return level
end

function ClampLevel(level)
	local value = tonumber(level) or 0
	if value < 1 then
		return 0
	elseif value > 5 then
		return 5
	end

	return math.floor(value)
end

function GetOffensiveSkillSPCost(level)
	if IsVanilmirth(MyID) then
		return 20 + (level * 2)
	elseif IsFilir(MyID) then
		return level * 4
	end

	return 0
end

function GetOffensiveSkillDelayMs(level)
	if IsVanilmirth(MyID) then
		return 2000 + (level * 200)
	elseif IsFilir(MyID) then
		return 2000
	end

	return CAPRICE_DELAY_MS
end

function GetFilirSupportSPCost(skillName, level)
	if skillName == "Flitting" then
		return 20 + (level * 10)
	elseif skillName == "AcceleratedFlight" then
		return 20 + (level * 10)
	end

	return 0
end

function GetFilirSupportDelayMs(skillName, level)
	if skillName == "Flitting" then
		if level >= 5 then
			return 120000
		end
		return 50000 + (level * 10000)
	elseif skillName == "AcceleratedFlight" then
		if level >= 5 then
			return 120000
		end
		return 50000 + (level * 10000)
	end

	return 0
end

function GetSkillCastCount(id)
	return SkillCastCount[id] or 0
end

function GetSkillCastCountByClass(id)
	local class = MonsterClass(id)
	return SkillCastCountByClass[class] or 0
end

function MarkSkillCast(id)
	if id ~= 0 then
		SkillCastCount[id] = GetSkillCastCount(id) + 1
		local class = MonsterClass(id)
		SkillCastCountByClass[class] = GetSkillCastCountByClass(id) + 1
	end
end

function SlepeModeDisallowsSkillAfterAttack(id)
	return UsesSlepeCurrentTargetSkillRule(id) and WasAttacked(id)
end

function TargetAllowsSkill(id, allowSlepeAfterAttack)
	if TargetUsesKiteNoAttackBehavior(id) then
		return false
	end

	local skillMode = GetTargetSkillMode(id)
	if skillMode == "No Skill" then
		return false
	end

	if allowSlepeAfterAttack ~= true
		and SlepeModeDisallowsSkillAfterAttack(id)
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

function HasTacticRepeatSkillMode(id)
	local tactic = GetMonsterTactic(id)
	if tactic == nil then
		return false
	end

	local skillMode = NormalizeSkillModeValue(tactic.Skill)
	return skillMode == "Two Skills" or skillMode == "Max Skills"
end

function AllowsRepeatSkillOnCurrentTarget(id)
	return HasTacticRepeatSkillMode(id)
end

function AllowsSlepeCurrentTargetFallbackSkill(id)
	return UsesSlepeCurrentTargetSkillRule(id)
		and HasTacticRepeatSkillMode(id)
end

function TargetAllowsSlepeCurrentTargetFallbackSkill(id)
	if TargetUsesKiteNoAttackBehavior(id) then
		return false
	end

	local skillMode = GetTargetSkillMode(id)
	if skillMode == "No Skill" then
		return false
	end

	if HasTacticRepeatSkillMode(id) then
		if skillMode == "Two Skills" then
			return GetSkillCastCount(id) < 2
		end

		return true
	end

	if WasAttacked(id) then
		return false
	end

	return GetSkillCastCount(id) < 1
end

function UsesSlepeCurrentTargetSkillRule(id)
	local behavior = GetTargetBehavior(id)
	if behavior == "slepe mode" then
		return true
	end

	return GetBehaviorMode() == "Slepe Mode" and behavior == ""
end

function PrefersCurrentTargetForSkill(id)
	if id == 0 then
		return false
	end

	return UsesSlepeCurrentTargetSkillRule(id) == false
end

function HandlePostSkillPrimaryTarget(target, ignoreTarget)
	if ignoreTarget == true then
		IgnorePrimarySkillTarget(target)
		ClearAttackTarget()
	end
	BeginPostSkillWait()
end

function ShouldPauseAfterPrimarySkillAttempt(castTarget)
	return castTarget ~= 0
		and castTarget == AttackTarget
		and CurrentState == STATE_CHASE_ATTACK
		and AttackTargetHit == 0
		and UsesSlepeCurrentTargetSkillRule(castTarget)
end

function ShouldIgnoreAfterPrimarySkillAttempt(castTarget)
	return ShouldPauseAfterPrimarySkillAttempt(castTarget)
		and AttackTargetHit == 0
		and AllowsRepeatSkillOnCurrentTarget(castTarget) == false
end

function HandleStuckTargetReset(target)
	if target ~= 0 then
		IgnoreTargetForDuration(target, UNREACHABLE_TARGET_IGNORE_MS)
	end
	BeginSoftStandbyReset(1, 1)
end

function RememberActorPosition(id)
	if id == 0 then
		return
	end

	local x, y = GetV(V_POSITION, id)
	if x ~= -1 and y ~= -1 then
		LastSeenPosX[id] = x
		LastSeenPosY[id] = y
	end
end

function GetMoveLeadPosition(id)
	local currentX, currentY = GetV(V_POSITION, id)
	if currentX == -1 or currentY == -1 then
		return currentX, currentY
	end

	local lastX = LastSeenPosX[id]
	local lastY = LastSeenPosY[id]
	if lastX == nil or lastY == nil then
		return currentX, currentY
	end

	local stepX = Sign(currentX - lastX)
	local stepY = Sign(currentY - lastY)
	if stepX == 0 and stepY == 0 then
		return currentX, currentY
	end

	return currentX + (stepX * CHASE_LEAD_CELLS), currentY + (stepY * CHASE_LEAD_CELLS)
end

function IsTargetActuallyMoving(id)
	local currentX, currentY = GetV(V_POSITION, id)
	if currentX == -1 or currentY == -1 then
		return false
	end

	local lastX = LastSeenPosX[id]
	local lastY = LastSeenPosY[id]
	if lastX == nil or lastY == nil then
		return false
	end

	return (currentX ~= lastX or currentY ~= lastY) and GetV(V_MOTION, id) == MOTION_MOVE
end

function ClampToOwnerLeashSquare(x, y)
	local owner = GetV(V_OWNER, MyID)
	local ownerX, ownerY = GetV(V_POSITION, owner)
	if ownerX == -1 or ownerY == -1 then
		return x, y
	end

	if x < ownerX - OWNER_LEASH_CELLS then
		x = ownerX - OWNER_LEASH_CELLS
	elseif x > ownerX + OWNER_LEASH_CELLS then
		x = ownerX + OWNER_LEASH_CELLS
	end

	if y < ownerY - OWNER_LEASH_CELLS then
		y = ownerY - OWNER_LEASH_CELLS
	elseif y > ownerY + OWNER_LEASH_CELLS then
		y = ownerY + OWNER_LEASH_CELLS
	end

	return x, y
end

function IsOwnerCell(x, y)
	local owner = GetV(V_OWNER, MyID)
	local ownerX, ownerY = GetV(V_POSITION, owner)
	if ownerX == -1 or ownerY == -1 then
		return false
	end

	return x == ownerX and y == ownerY
end

function GetNearestOpenAdjacentPoint(centerX, centerY, ignoredTarget)
	local myX, myY = GetV(V_POSITION, MyID)
	if myX == -1 or centerX == -1 then
		return myX, myY, 999
	end

	local bestX, bestY = -1, -1
	local bestDistance = 999

	for dx = -1, 1 do
		for dy = -1, 1 do
			if dx ~= 0 or dy ~= 0 then
				local candidateX = centerX + dx
				local candidateY = centerY + dy
				if IsCellOccupiedByOther(candidateX, candidateY, ignoredTarget) == false then
					local candidateDistance = Distance(myX, myY, candidateX, candidateY)
					if candidateDistance ~= -1 and candidateDistance < bestDistance then
						bestX = candidateX
						bestY = candidateY
						bestDistance = candidateDistance
					end
				end
			end
		end
	end

	return bestX, bestY, bestDistance
end

function GetAlternateOpenAdjacentPoint(centerX, centerY, ignoredTarget)
	local myX, myY = GetV(V_POSITION, MyID)
	if myX == -1 or centerX == -1 then
		return myX, myY, 999
	end

	local bestX, bestY = -1, -1
	local bestDistance = 999

	for dx = -1, 1 do
		for dy = -1, 1 do
			if dx ~= 0 or dy ~= 0 then
				local candidateX = centerX + dx
				local candidateY = centerY + dy
				if (candidateX ~= myX or candidateY ~= myY)
					and IsCellOccupiedByOther(candidateX, candidateY, ignoredTarget) == false then
					local candidateDistance = Distance(myX, myY, candidateX, candidateY)
					if candidateDistance ~= -1 and candidateDistance < bestDistance then
						bestX = candidateX
						bestY = candidateY
						bestDistance = candidateDistance
					end
				end
			end
		end
	end

	return bestX, bestY, bestDistance
end

function ResolveOwnerBannedCell(x, y)
	if IsOwnerCell(x, y) == false then
		return x, y
	end

	local altX, altY, altDistance = GetNearestOpenAdjacentPoint(x, y, GetV(V_OWNER, MyID))
	if altDistance ~= 999 then
		return altX, altY
	end

	local myX, myY = GetV(V_POSITION, MyID)
	return myX, myY
end

function GetPreferredOwnerStandbyCell()
	local owner = GetV(V_OWNER, MyID)
	local ownerX, ownerY = GetV(V_POSITION, owner)
	if ownerX == -1 or ownerY == -1 then
		return ownerX, ownerY
	end

	local preferred = {
		{ ownerX, ownerY - 1 },
		{ ownerX + 1, ownerY - 1 },
		{ ownerX - 1, ownerY - 1 },
		{ ownerX + 1, ownerY },
		{ ownerX - 1, ownerY },
		{ ownerX + 1, ownerY + 1 },
		{ ownerX - 1, ownerY + 1 },
		{ ownerX, ownerY + 1 }
	}

	for _, candidate in ipairs(preferred) do
		local candidateX, candidateY = ClampToOwnerLeashSquare(candidate[1], candidate[2])
		if IsOwnerCell(candidateX, candidateY) == false
			and IsCellOccupiedByOther(candidateX, candidateY, owner) == false then
			return candidateX, candidateY
		end
	end

	return ResolveOwnerBannedCell(ownerX, ownerY)
end

function IsInOwnerLeashSquare(x, y)
	local owner = GetV(V_OWNER, MyID)
	local ownerX, ownerY = GetV(V_POSITION, owner)
	if ownerX == -1 or ownerY == -1 then
		return false
	end

	return math.abs(x - ownerX) <= OWNER_LEASH_CELLS
		and math.abs(y - ownerY) <= OWNER_LEASH_CELLS
end

function ClampMoveDestination(x, y)
	x, y = ClampToOwnerLeashSquare(x, y)
	return ResolveOwnerBannedCell(x, y)
end

function GetOwnerRecoveryCell(stepDistance)
	local owner = GetV(V_OWNER, MyID)
	local ownerX, ownerY = GetV(V_POSITION, owner)
	local myX, myY = GetV(V_POSITION, MyID)
	if ownerX == -1 or ownerY == -1 or myX == -1 or myY == -1 then
		return GetStandbyCell()
	end

	local deltaX = ownerX - myX
	local deltaY = ownerY - myY
	local stepX = Sign(deltaX)
	local stepY = Sign(deltaY)
	local maxDistance = math.max(math.abs(deltaX), math.abs(deltaY))
	local step = math.min(stepDistance or 5, maxDistance)
	if step < 1 then
		step = 1
	end

	local baseX = myX + (stepX * step)
	local baseY = myY + (stepY * step)
	local sideX = stepY
	local sideY = -stepX
	local candidates = {
		{ baseX, baseY },
		{ baseX + sideX, baseY + sideY },
		{ baseX - sideX, baseY - sideY },
		{ baseX + (sideX * 2), baseY + (sideY * 2) },
		{ baseX - (sideX * 2), baseY - (sideY * 2) },
		{ myX + stepX, myY + stepY },
		{ ownerX, ownerY }
	}

	for _, candidate in ipairs(candidates) do
		local candidateX, candidateY = ClampMoveDestination(candidate[1], candidate[2])
		if (candidateX ~= myX or candidateY ~= myY)
			and IsCellOccupiedByOther(candidateX, candidateY, owner) == false then
			return candidateX, candidateY
		end
	end

	return ClampMoveDestination(GetStandbyCell())
end

function ShouldUseFollowRecovery(standbyX, standbyY)
	if AnchorEnabled == 1 then
		return false
	end

	local owner = GetV(V_OWNER, MyID)
	if owner ~= 0 and IsOutOfSight(MyID, owner) then
		return true
	end

	local myX, myY = GetV(V_POSITION, MyID)
	if myX == -1 or standbyX == -1 then
		return false
	end

	return standbyX == MoveX
		and standbyY == MoveY
		and GetV(V_MOTION, MyID) ~= MOTION_MOVE
		and Distance(myX, myY, standbyX, standbyY) > 1
end

function GetFollowDestination(forceRecovery)
	local standbyX, standbyY = GetStandbyCell()
	if standbyX == -1 or standbyY == -1 then
		return standbyX, standbyY
	end

	local owner = GetV(V_OWNER, MyID)
	if forceRecovery == true or (AnchorEnabled ~= 1 and owner ~= 0 and IsOutOfSight(MyID, owner)) then
		return GetOwnerRecoveryCell(5)
	end

	return ClampMoveDestination(standbyX, standbyY)
end

function HasEnoughSPForCaprice()
	return HasEnoughSPForOffensiveSkill(GetDefaultCapriceLevel())
end

function HasEnoughSPForOffensiveSkill(level)
	return GetV(V_SP, MyID) >= GetOffensiveSkillSPCost(level)
end

function HasEnoughSPForChaoticBlessings()
	return GetV(V_SP, MyID) >= CHAOTIC_BLESSINGS_SP_COST
end

function GetHPPercent(id)
	if id == 0 then
		return 100
	end

	local maxHP = GetV(V_MAXHP, id)
	if maxHP <= 0 then
		return 100
	end

	return (GetV(V_HP, id) * 100) / maxHP
end

function ShouldCastChaoticBlessings()
	if IsVanilmirth(MyID) == false then
		return false
	end

	local level = GetChaoticBlessingsLevel()
	if level < 1 then
		return false
	end

	if HasEnoughSPForChaoticBlessings() == false or MeetsChaoticBlessingsSPThreshold() == false then
		return false
	end

	if GetTick() < NextChaoticBlessingsAt then
		return false
	end

	local ownerThreshold = GetChaoticBlessingsOwnerHPPercent()
	local homunThreshold = GetChaoticBlessingsHomunHPPercent()
	local owner = GetV(V_OWNER, MyID)

	if ownerThreshold > 0 and owner ~= 0 and GetHPPercent(owner) <= ownerThreshold then
		return true
	end

	if homunThreshold > 0 and GetHPPercent(MyID) <= homunThreshold then
		return true
	end

	return false
end

function TryCastChaoticBlessings()
	if ShouldCastChaoticBlessings() == false then
		return 0
	end

	SkillObject(MyID, GetChaoticBlessingsLevel(), CHAOTIC_BLESSINGS_SKILL, MyID)
	NextChaoticBlessingsAt = GetTick() + CHAOTIC_BLESSINGS_DELAY_MS
	return MyID
end

function TryCastFilirSupportSkill(skillName, skillID)
	if IsFilir(MyID) == false then
		return 0
	end

	local level = GetFilirSupportLevel(skillName)
	if level < 1 then
		return 0
	end

	if MeetsFilirSupportSPThreshold(skillName) == false then
		return 0
	end

	local nextAt = 0
	if skillName == "Flitting" then
		nextAt = NextFlittingAt
	elseif skillName == "AcceleratedFlight" then
		nextAt = NextAcceleratedFlightAt
	end

	if GetTick() < nextAt then
		return 0
	end

	local spCost = GetFilirSupportSPCost(skillName, level)
	if GetV(V_SP, MyID) < spCost then
		return 0
	end

	SkillObject(MyID, level, skillID, MyID)
	local readyAt = GetTick() + GetFilirSupportDelayMs(skillName, level)
	if skillName == "Flitting" then
		NextFlittingAt = readyAt
	else
		NextAcceleratedFlightAt = readyAt
	end
	return MyID
end

function TryCastFilirSupportSkills()
	local supportTarget = TryCastFilirSupportSkill("Flitting", FLITTING_SKILL)
	if supportTarget ~= 0 then
		return supportTarget
	end

	return TryCastFilirSupportSkill("AcceleratedFlight", ACCELERATED_FLIGHT_SKILL)
end

function AutoSkillReady()
	return GetOffensiveSkillID() ~= 0
		and MeetsCapriceSPThreshold()
		and GetTick() >= NextCapriceAt
		and GetTick() >= NextCapriceTryAt
end

function ManualSkillReady()
	return GetOffensiveSkillID() ~= 0
		and GetTick() >= NextCapriceAt
		and GetTick() >= NextCapriceTryAt
end

function SkillReady()
	return AutoSkillReady()
end

function ClearManualCapriceTarget()
	ManualCapriceTarget = 0
	ManualCapriceSetAt = 0
	ManualCapriceLevel = 0
	ManualCapriceSkill = 0
end

function IsValidManualCapriceTarget(target)
	return target ~= 0 and IsValidProtectionTarget(target)
end

function SetManualCapriceTarget(target, level, skillID)
	if target == nil or target == 0 then
		ClearManualCapriceTarget()
		return
	end

	ManualCapriceTarget = target
	ManualCapriceSetAt = GetTick()
	ManualCapriceLevel = ClampLevel(level or 0)
	ManualCapriceSkill = tonumber(skillID) or 0
	NextCapriceTryAt = 0
end

function GetManualCapriceLevel(target)
	if ManualCapriceLevel >= 1 and ManualCapriceLevel <= 5 then
		return ManualCapriceLevel
	end

	return GetTargetSkillLevel(target)
end

function GetManualCapriceTarget()
	if ManualCapriceTarget == 0 then
		return 0
	end

	if GetTick() - ManualCapriceSetAt >= MANUAL_CAPRICE_TIMEOUT_MS then
		ClearManualCapriceTarget()
		return 0
	end

	if IsValidManualCapriceTarget(ManualCapriceTarget) == false then
		ClearManualCapriceTarget()
		return 0
	end

	if ManualCapriceSkill ~= 0 and ManualCapriceSkill ~= GetOffensiveSkillID() then
		ClearManualCapriceTarget()
		return 0
	end

	return ManualCapriceTarget
end

function HandleManualCapricePriority()
	local manualTarget = GetManualCapriceTarget()
	if manualTarget == 0 then
		return false
	end

	CancelSoftStandbyReset()
	CancelPostSkillWait()

	if TryCastCaprice() ~= 0 then
		ClearAttackTarget()
		CurrentState = STATE_IDLE
		return true
	end

	if HasEnoughSPForOffensiveSkill(GetManualCapriceLevel(manualTarget)) == false then
		return true
	end

	if InSkillRange(MyID, manualTarget, GetOffensiveSkillID(), GetManualCapriceLevel(manualTarget)) then
		return true
	end

	local nextX, nextY = GetSkillApproachCell(manualTarget)
	if nextX ~= -1 and nextY ~= -1 then
		ClearAttackTarget()
		ForceMoveTo(nextX, nextY)
		CurrentState = STATE_MOVE
	end

	return true
end

function UpdateCapriceAttemptState()
	if PendingCapriceAt == 0 then
		return
	end

	if HasEnoughSPForCaprice() == false then
		PendingCapriceAt = 0
		PendingCapriceSP = 0
		PendingCapriceTarget = 0
		PendingCapriceCost = 0
		PendingCapriceDelayMs = 0
		return
	end

	local sp = GetV(V_SP, MyID)
	if PendingCapriceSP - sp >= PendingCapriceCost then
		MarkSkillCast(PendingCapriceTarget)
		if PendingCapriceTarget == ManualCapriceTarget then
			ClearManualCapriceTarget()
		end
		if ShouldPauseAfterPrimarySkillAttempt(PendingCapriceTarget) then
			HandlePostSkillPrimaryTarget(PendingCapriceTarget, ShouldIgnoreAfterPrimarySkillAttempt(PendingCapriceTarget))
		end

		NextCapriceAt = PendingCapriceAt + PendingCapriceDelayMs
		NextCapriceTryAt = NextCapriceAt
		LastSkillTarget = PendingCapriceTarget
		PendingCapriceAt = 0
		PendingCapriceSP = 0
		PendingCapriceTarget = 0
		PendingCapriceCost = 0
		PendingCapriceDelayMs = 0
		return
	end

	if GetTick() - PendingCapriceAt >= CAPRICE_CONFIRM_TIMEOUT_MS then
		PendingCapriceAt = 0
		PendingCapriceSP = 0
		PendingCapriceTarget = 0
		PendingCapriceCost = 0
		PendingCapriceDelayMs = 0
	end
end

function SetAnchor(x, y)
	AnchorEnabled = 1
	AnchorX = x
	AnchorY = y
end

function ClearAnchor()
	AnchorEnabled = 0
end

function InAnchorRange(x, y)
	if AnchorEnabled ~= 1 then
		return true
	end

	return Distance(AnchorX, AnchorY, x, y) <= ANCHOR_RANGE
end

function PatrolEnabled()
	return TargetLists.Patrol ~= nil and TargetLists.Patrol.Enabled == true
end

function GetPatrolShape()
	if TargetLists.Patrol == nil then
		return "square cw"
	end

	local shape = string.lower(tostring(TargetLists.Patrol.Shape or "square cw"))
	if shape == "square" then
		return "square cw"
	elseif shape == "diamond" then
		return "diamond cw"
	elseif shape == "circle" then
		return "circle cw"
	end

	if shape ~= "square cw"
		and shape ~= "square ccw"
		and shape ~= "diamond cw"
		and shape ~= "diamond ccw"
		and shape ~= "circle cw"
		and shape ~= "circle ccw" then
		return "square cw"
	end

	return shape
end

function GetPatrolDistance()
	if TargetLists.Patrol == nil then
		return 4
	end

	local distance = tonumber(TargetLists.Patrol.Distance) or 4
	if distance < 1 then
		return 1
	elseif distance > 12 then
		return 12
	end

	return math.floor(distance)
end

function IsTargetInActiveRange(target)
	if target == 0 then
		return false
	end

	local x, y = GetV(V_POSITION, target)
	if x == -1 or y == -1 then
		return false
	end

	return InAnchorRange(x, y)
end

function IsAtTurretStayCell()
	if TurretStayActive() == false then
		return true
	end

	local myX, myY = GetV(V_POSITION, MyID)
	return myX == AnchorX and myY == AnchorY
end

function IsTargetReachableWhileTurretStaying(target)
	if TurretStayActive() == false then
		return true
	end

	if IsAtTurretStayCell() == false then
		return false
	end

	local distance = DistanceToActor(MyID, target)
	return distance ~= -1 and distance <= AttackRange()
end

function UpdateSPTracking()
	local sp = GetV(V_SP, MyID)
	if LastSP == 0 then
		LastSP = sp
		return
	end

	if sp > LastSP and sp - LastSP < 100 then
		LastSPTickTime = GetTick()
	end

	LastSP = sp
end

function ShouldPauseForSPTick()
	local sp = GetV(V_SP, MyID)
	local maxSP = GetV(V_MAXSP, MyID)
	if LastSPTickTime == 0 or sp >= maxSP then
		return false
	end

	local elapsed = GetTick() - LastSPTickTime
	local untilNextTick = SP_TICK_INTERVAL_MS - elapsed
	return untilNextTick >= 0 and untilNextTick <= SP_TICK_PAUSE_WINDOW_MS
end

function MoveSmart(x, y)
	if ShouldPauseForSPTick() then
		return false
	end

	x, y = ClampMoveDestination(x, y)
	Move(MyID, x, y)
	MoveX = x
	MoveY = y
	return true
end

function ForceMoveTo(x, y)
	x, y = ClampMoveDestination(x, y)
	Move(MyID, x, y)
	MoveX = x
	MoveY = y
	return true
end

function GetStandbyCell()
	if AnchorEnabled == 1 then
		return AnchorX, AnchorY
	end

	if PatrolEnabled() ~= true then
		return GetPreferredOwnerStandbyCell()
	end

	local owner = GetV(V_OWNER, MyID)
	local ownerX, ownerY = GetV(V_POSITION, owner)
	return ownerX, ownerY
end

function GetPatrolCenter()
	if AnchorEnabled == 1 then
		return AnchorX, AnchorY
	end

	local owner = GetV(V_OWNER, MyID)
	return GetV(V_POSITION, owner)
end

function GetPatrolPoint(step)
	local centerX, centerY = GetPatrolCenter()
	if centerX == -1 or centerY == -1 then
		return -1, -1, 0
	end

	local distance = GetPatrolDistance()
	local diagonal = math.max(1, math.floor(distance * 0.7 + 0.5))
	local shape = GetPatrolShape()
	local points

	local function ReversePoints(source)
		local reversed = {}
		for i = table.getn(source), 1, -1 do
			table.insert(reversed, source[i])
		end
		return reversed
	end

	if shape == "diamond cw" or shape == "diamond ccw" then
		points = {
			{ centerX, centerY - distance },
			{ centerX + diagonal, centerY - diagonal },
			{ centerX + distance, centerY },
			{ centerX + diagonal, centerY + diagonal },
			{ centerX, centerY + distance },
			{ centerX - diagonal, centerY + diagonal },
			{ centerX - distance, centerY },
			{ centerX - diagonal, centerY - diagonal }
		}
		if shape == "diamond cw" then
			points = ReversePoints(points)
		end
	elseif shape == "circle cw" or shape == "circle ccw" then
		points = {
			{ centerX, centerY - distance },
			{ centerX + diagonal, centerY - diagonal },
			{ centerX + distance, centerY },
			{ centerX + diagonal, centerY + diagonal },
			{ centerX, centerY + distance },
			{ centerX - diagonal, centerY + diagonal },
			{ centerX - distance, centerY },
			{ centerX - diagonal, centerY - diagonal }
		}
		if shape == "circle cw" then
			points = ReversePoints(points)
		end
	else
		points = {
			{ centerX - distance, centerY + distance },
			{ centerX + distance, centerY + distance },
			{ centerX + distance, centerY - distance },
			{ centerX - distance, centerY - distance }
		}
		if shape == "square cw" then
			points = ReversePoints(points)
		end
	end

	local pointCount = table.getn(points)
	if pointCount == 0 then
		return centerX, centerY, 0
	end

	local index = ((step - 1) % pointCount) + 1
	return points[index][1], points[index][2], pointCount
end

function IsAtStandbyCell()
	local myX, myY = GetV(V_POSITION, MyID)
	local standbyX, standbyY = GetStandbyCell()
	if AnchorEnabled == 1 then
		return myX == standbyX and myY == standbyY
	end

	return Distance(myX, myY, standbyX, standbyY) <= 1
end

function StartFollow(forceRecovery)
	MoveX, MoveY = GetFollowDestination(forceRecovery == true or forceRecovery == 1)
	MoveSmart(MoveX, MoveY)
	CurrentState = STATE_FOLLOW
end

function ForceFollow(forceRecovery)
	MoveX, MoveY = GetFollowDestination(forceRecovery == true or forceRecovery == 1)
	ForceMoveTo(MoveX, MoveY)
	CurrentState = STATE_FOLLOW
end

function StandbyUsesPatrol()
	return PatrolEnabled() == true and AnchorEnabled ~= 1
end

function StartStandby()
	if StandbyUsesPatrol() then
		CurrentState = STATE_IDLE
		TryPatrol()
		return
	end

	StartFollow()
end

function ForceStandby()
	if StandbyUsesPatrol() then
		CurrentState = STATE_IDLE
		NextPatrolMoveAt = 0
		TryPatrol()
		return
	end

	ForceFollow()
end

function EnsureIdleStandby()
	if AttackTarget ~= 0 or RequireStandbyReset == 1 then
		return false
	end

	if IsAtStandbyCell() then
		return false
	end

	if TryPatrol() then
		return true
	end

	if GetTick() < NextIdleStandbyMoveAt and CurrentState == STATE_FOLLOW then
		return true
	end

	ForceStandby()
	NextIdleStandbyMoveAt = GetTick() + IDLE_STANDBY_REISSUE_MS
	return true
end

function TryPatrol()
	if PatrolEnabled() ~= true or AnchorEnabled == 1 then
		return false
	end

	if AttackTarget ~= 0 or RequireStandbyReset == 1 then
		return false
	end

	local myX, myY = GetV(V_POSITION, MyID)
	if myX == -1 or myY == -1 then
		return false
	end

	local _, _, pointCount = GetPatrolPoint(PatrolStep)
	if pointCount <= 0 then
		return false
	end

	for _ = 1, pointCount do
		local nextX, nextY = GetPatrolPoint(PatrolStep)
		if nextX == -1 or nextY == -1 then
			return false
		end

		if Distance(myX, myY, nextX, nextY) <= 1 then
			PatrolStuckSince = 0
			PatrolRetryCount = 0
			AdvancePatrolStep()
		else
			if GetV(V_MOTION, MyID) == MOTION_MOVE and MoveX == nextX and MoveY == nextY then
				PatrolStuckSince = 0
				PatrolRetryCount = 0
				PatrolLastPosX = myX
				PatrolLastPosY = myY
				CurrentState = STATE_MOVE
				return true
			end

			if GetTick() < NextPatrolMoveAt then
				CurrentState = STATE_IDLE
				return true
			end

			if ForceMoveTo(nextX, nextY) then
				PatrolStuckSince = 0
				PatrolLastPosX = myX
				PatrolLastPosY = myY
				NextPatrolMoveAt = GetTick() + PATROL_MOVE_MS
				CurrentState = STATE_MOVE
				return true
			end

			AdvancePatrolStep()
		end
	end

	return false
end

function ResetPatrolState()
	PatrolStep = 1
	NextPatrolMoveAt = 0
	PatrolStuckSince = 0
	PatrolRetryCount = 0
	PatrolLastPosX = -1
	PatrolLastPosY = -1
end

function AdvancePatrolStep()
	local _, _, pointCount = GetPatrolPoint(PatrolStep)
	if pointCount <= 0 then
		PatrolStep = 1
		return
	end

	PatrolStep = PatrolStep + 1
	if PatrolStep > pointCount then
		PatrolStep = 1
	end
end

function CancelSoftStandbyReset()
	RequireStandbyReset = 0
	StandbyResetStartedAt = 0
	StandbyResetReadyAt = 0
	StandbyResetStrict = 0
	StandbyResetMoveBack = 1
end

function CancelPostSkillWait()
	WaitModeReadyAt = 0
end

function BeginPostSkillWait()
	CancelSoftStandbyReset()
	WaitModeReadyAt = GetTick() + POST_SKILL_WAIT_MS
	CurrentState = STATE_WAIT
end

function BeginOwnerProtectionHold()
	CancelSoftStandbyReset()
	local myX, myY = GetV(V_POSITION, MyID)
	if myX ~= -1 and myY ~= -1 then
		ForceMoveTo(myX, myY)
	end
	WaitModeReadyAt = GetTick() + OWNER_PROTECTION_HOLD_MS
	CurrentState = STATE_WAIT
end

function BeginSoftStandbyReset(strict, moveBack)
	CancelPostSkillWait()
	ClearAttackTarget()
	RequireStandbyReset = 1
	StandbyResetStartedAt = GetTick()
	StandbyResetReadyAt = StandbyResetStartedAt + SOFT_RESET_WALK_MS
	StandbyResetStrict = strict == 1 and 1 or 0
	StandbyResetMoveBack = moveBack == 0 and 0 or 1
	if StandbyResetMoveBack == 1 then
		ForceStandby()
	else
		CurrentState = STATE_IDLE
	end
end

function OwnerMovementOverrideActive()
	if CurrentState == STATE_WAIT then
		return false
	end

	if AnchorEnabled == 1 then
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
		if GetTick() - OwnerMoveSince >= OWNER_FOLLOW_DELAY_MS then
			RequireStandbyReset = 0
			StandbyResetStartedAt = 0
			StandbyResetReadyAt = 0
			ClearAttackTarget()

			local standbyX, standbyY = GetStandbyCell()
			if standbyX ~= MoveX or standbyY ~= MoveY or GetV(V_MOTION, MyID) ~= MOTION_MOVE then
				ForceFollow(ShouldUseFollowRecovery(standbyX, standbyY))
			else
				CurrentState = STATE_FOLLOW
			end

			return true
		end

		return false
	end

	OwnerMoveSince = 0

	if OwnerStandSince == 0 then
		OwnerStandSince = GetTick()
	end

	if GetTick() - OwnerStandSince < OWNER_RESUME_DELAY_MS then
		local standbyX, standbyY = GetStandbyCell()
		if standbyX ~= MoveX or standbyY ~= MoveY or GetV(V_MOTION, MyID) ~= MOTION_MOVE then
			ForceFollow(ShouldUseFollowRecovery(standbyX, standbyY))
		else
			CurrentState = STATE_FOLLOW
		end

		return true
	end

	return false
end

function SoftResetInProgress()
	if RequireStandbyReset ~= 1 then
		return false
	end

	if StandbyResetStartedAt == 0 then
		StandbyResetStartedAt = GetTick()
		StandbyResetReadyAt = StandbyResetStartedAt + SOFT_RESET_WALK_MS
	end

	if GetTick() < StandbyResetReadyAt then
		return true
	end

	RequireStandbyReset = 0
	StandbyResetStartedAt = 0
	StandbyResetReadyAt = 0
	return false
end

function TryBreakSoftResetForTarget()
	if RequireStandbyReset ~= 1 then
		return false
	end

	if StandbyResetStrict ~= 1 then
		AcquireAttackTarget()
		if AttackTarget ~= 0 then
			CancelSoftStandbyReset()
			return true
		end
	end

	if GetTick() < StandbyResetReadyAt then
		return false
	end

	AcquireAttackTarget()
	if AttackTarget ~= 0 then
		CancelSoftStandbyReset()
		return true
	end

	return false
end

function StartAttackChase(target)
	if not IsValidAttackTargetForCurrentPurpose(target) then
		ClearAttackTarget()
		CurrentState = STATE_IDLE
		return
	end

	CancelPostSkillWait()
	AttackTarget = target
	AttackTargetHit = 0
	NextChaseRepathAt = 0
	NextAttackCommandAt = 0
	NextAttackRefreshMoveAt = 0
	CurrentState = STATE_CHASE_ATTACK
end

function FindMonsterTarget(excludedTarget)
	local actors = GetActors()
	local bestTarget = 0
	local bestDistance = 999
	local bestPriority = -1

	for _, actor in ipairs(actors) do
		if actor ~= GetV(V_OWNER, MyID)
			and actor ~= MyID
			and actor ~= excludedTarget
			and IsValidTarget(actor)
			and IsIgnoredTarget(actor) == false
			and IsKSTarget(actor) == false
			and IsTargetInActiveRange(actor)
			and IsTargetReachableWhileTurretStaying(actor) then
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

function FindMonsterInSkillRange(excludedTarget)
	local actors = GetActors()
	local bestTarget = 0
	local bestDistance = 999
	local bestPriority = -1
	local skillID = GetOffensiveSkillID()

	for _, actor in ipairs(actors) do
		if actor ~= GetV(V_OWNER, MyID)
			and actor ~= MyID
			and actor ~= excludedTarget
			and IsValidTarget(actor)
			and IsIgnoredTarget(actor) == false
			and TargetAllowsSkill(actor)
			and IsKSTarget(actor) == false
			and IsTargetInActiveRange(actor)
			and InSkillRange(MyID, actor, skillID, GetTargetSkillLevel(actor)) then
			local priority = GetSkillBehaviorPriority(actor)
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

function FindMonsterForSnipe(excludedTarget, taggedOnly)
	local actors = GetActors()
	local bestTarget = 0
	local bestDistance = 999
	local bestPriority = -1

	for _, actor in ipairs(actors) do
		if actor ~= GetV(V_OWNER, MyID)
			and actor ~= MyID
			and actor ~= excludedTarget
			and IsValidTarget(actor)
			and IsIgnoredTarget(actor) == false
			and TargetAllowsSkill(actor)
			and IsKSTarget(actor) == false
			and TargetUsesAvoidBehavior(actor) == false
			and (taggedOnly == false or TargetUsesSnipeBehavior(actor))
			and IsTargetInActiveRange(actor) then
			local priority = GetSkillBehaviorPriority(actor)
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

function TryCastCaprice()
	local manualTarget = GetManualCapriceTarget()
	local skillID = GetOffensiveSkillID()
	if skillID == 0 then
		return 0
	end

	if manualTarget ~= 0 then
		if ManualSkillReady() == false then
			return 0
		end
	elseif HasEnoughSPForCaprice() == false or not SkillReady() then
		return 0
	end

	if manualTarget == 0 and FindOwnerAggroTarget(0) ~= 0 then
		return 0
	end

	local excludedTarget = 0
	if AttackTarget ~= 0
		and UsesSlepeCurrentTargetSkillRule(AttackTarget) then
		excludedTarget = AttackTarget
	end

	local skillTarget = 0
	if manualTarget ~= 0 then
		if InSkillRange(MyID, manualTarget, skillID, GetManualCapriceLevel(manualTarget)) == false then
			return 0
		end
		skillTarget = manualTarget
	elseif AttackTarget ~= 0
		and excludedTarget ~= AttackTarget
		and PrefersCurrentTargetForSkill(AttackTarget)
		and IsValidTarget(AttackTarget)
		and IsIgnoredTarget(AttackTarget) == false
		and IsKSTarget(AttackTarget) == false
		and IsTargetInActiveRange(AttackTarget)
		and TargetUsesAvoidBehavior(AttackTarget) == false
		and TargetAllowsSkill(AttackTarget)
		and InSkillRange(MyID, AttackTarget, skillID, GetTargetSkillLevel(AttackTarget)) then
		skillTarget = AttackTarget
	elseif PendingCapriceAt ~= 0 and PendingCapriceTarget ~= excludedTarget and IsValidTarget(PendingCapriceTarget) and IsIgnoredTarget(PendingCapriceTarget) == false and IsKSTarget(PendingCapriceTarget) == false
		and IsTargetInActiveRange(PendingCapriceTarget)
		and TargetAllowsSkill(PendingCapriceTarget)
		and InSkillRange(MyID, PendingCapriceTarget, skillID, GetTargetSkillLevel(PendingCapriceTarget)) then
		skillTarget = PendingCapriceTarget
	else
		skillTarget = FindMonsterInSkillRange(excludedTarget)
		if skillTarget == 0
			and excludedTarget == AttackTarget
			and AttackTarget ~= 0
			and AllowsSlepeCurrentTargetFallbackSkill(AttackTarget)
			and IsValidTarget(AttackTarget)
			and IsIgnoredTarget(AttackTarget) == false
			and IsKSTarget(AttackTarget) == false
			and IsTargetInActiveRange(AttackTarget)
			and TargetUsesAvoidBehavior(AttackTarget) == false
			and TargetAllowsSlepeCurrentTargetFallbackSkill(AttackTarget)
			and InSkillRange(MyID, AttackTarget, skillID, GetTargetSkillLevel(AttackTarget)) then
			skillTarget = AttackTarget
		elseif skillTarget == 0 and excludedTarget == 0 then
			skillTarget = FindMonsterInSkillRange(0)
		end
	end

	if skillTarget == 0 then
		return 0
	end

	local skillLevel = GetTargetSkillLevel(skillTarget)
	if manualTarget ~= 0 and skillTarget == manualTarget then
		skillLevel = GetManualCapriceLevel(skillTarget)
	end
	local skillCost = GetOffensiveSkillSPCost(skillLevel)
	if HasEnoughSPForOffensiveSkill(skillLevel) == false then
		return 0
	end

	local spBefore = GetV(V_SP, MyID)
	SkillObject(MyID, skillLevel, skillID, skillTarget)
	NextCapriceTryAt = GetTick() + CAPRICE_RETRY_MS
	if PendingCapriceAt == 0 or PendingCapriceTarget ~= skillTarget then
		PendingCapriceAt = GetTick()
		PendingCapriceSP = spBefore
		PendingCapriceTarget = skillTarget
		PendingCapriceCost = skillCost
		PendingCapriceDelayMs = GetOffensiveSkillDelayMs(skillLevel)
	end
	return skillTarget
end

function TryCastConfiguredSkills()
	if GetManualCapriceTarget() ~= 0 then
		return TryCastCaprice()
	end

	local filirSupportTarget = TryCastFilirSupportSkills()
	if filirSupportTarget ~= 0 then
		return filirSupportTarget
	end

	local supportTarget = TryCastChaoticBlessings()
	if supportTarget ~= 0 then
		return supportTarget
	end

	return TryCastCaprice()
end

function AcquireAttackTarget(excludedTarget)
	if IsValidAttackTargetForCurrentPurpose(AttackTarget) then
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

function UpdateAttackChaseMovement()
	if TurretStayActive() then
		if IsAtTurretStayCell() == false then
			ForceStandby()
		end
		return
	end

	local targetX, targetY = GetV(V_POSITION, AttackTarget)
	if targetX == -1 or targetY == -1 then
		return
	end

	local nextX, nextY = GetAttackApproachCell(AttackTarget)
	if nextX == -1 or nextY == -1 then
		return
	end

	local repathMs = CHASE_REPATH_MS
	if GetV(V_MOTION, AttackTarget) == MOTION_MOVE then
		repathMs = 150
	end

	local shouldRepath = false
	if GetV(V_MOTION, MyID) ~= MOTION_MOVE then
		shouldRepath = true
	elseif GetTick() >= NextChaseRepathAt then
		if Distance(MoveX, MoveY, nextX, nextY) >= CHASE_REPATH_DISTANCE then
			shouldRepath = true
		end
	end

	if not shouldRepath then
		return
	end

	if MoveSmart(nextX, nextY) then
		NextChaseRepathAt = GetTick() + repathMs
	end
end

function ForceAttackChaseMovement()
	if AttackTarget == 0 or IsValidAttackTargetForCurrentPurpose(AttackTarget) == false then
		return
	end

	if TurretStayActive() then
		if IsAtTurretStayCell() == false then
			ForceStandby()
		end
		return
	end

	local nextX, nextY = GetAttackApproachCell(AttackTarget)
	if nextX == -1 or nextY == -1 then
		return
	end

	ForceMoveTo(nextX, nextY)
	NextChaseRepathAt = GetTick() + 150
end

function RawAttackRange()
	local range = GetV(V_ATTACKRANGE, MyID)
	if range == nil or range < 1 then
		return 1
	end

	return range
end

function AttackRange()
	if IsFilir(MyID) then
		return 1
	end

	return RawAttackRange()
end

function StickyAttackRange()
	return AttackRange() + ATTACK_STICKY_EXTRA_RANGE
end

function TryStickyAttackCommand()
	if IsSnipeMode() then
		return 0
	end

	if AttackTarget == 0 then
		return 0
	end

	if GetTick() < NextAttackCommandAt then
		return 0
	end

	local distance = DistanceToActor(MyID, AttackTarget)
	if distance == -1 or distance > StickyAttackRange() then
		return 0
	end

	if distance > AttackRange() and IsTargetActuallyMoving(AttackTarget) == false then
		return 0
	end

	Attack(MyID, AttackTarget)
	NextAttackCommandAt = GetTick() + ATTACK_REISSUE_MS
	if distance <= AttackRange() then
		AttackTargetHit = 1
		HandlePostNormalAttack(AttackTarget)
	end
	return 1
end

function TryAttackRefreshStep()
	if DanceAttackEnabled() == false then
		return 0
	end

	if TurretStayActive() then
		return 0
	end

	if AttackTarget == 0 or IsValidAttackTargetForCurrentPurpose(AttackTarget) == false then
		return 0
	end

	local everyAttack = DanceEveryAttack()
	if GetTick() < NextAttackRefreshMoveAt then
		return 0
	end

	if GetV(V_MOTION, MyID) == MOTION_MOVE or IsInAttackMotion(MyID) then
		return 0
	end

	local distance = DistanceToActor(MyID, AttackTarget)
	if distance == -1 or distance > StickyAttackRange() then
		return 0
	end

	if DanceMovingOnly() and IsTargetActuallyMoving(AttackTarget) == false then
		return 0
	end

	local myX, myY = GetV(V_POSITION, MyID)
	if myX == -1 or myY == -1 then
		return 0
	end

	local refreshX, refreshY = GetAlternateOpenAdjacentCell(AttackTarget)
	if refreshX == -1 or refreshY == -1 then
		refreshX, refreshY = GetAttackApproachCell(AttackTarget)
	end

	if refreshX == -1 or refreshY == -1 or (refreshX == myX and refreshY == myY) then
		return 0
	end

	ForceMoveTo(refreshX, refreshY)
	if everyAttack then
		NextAttackRefreshMoveAt = GetTick() + ATTACK_REISSUE_MS
	else
		NextAttackRefreshMoveAt = GetTick() + DANCE_MOVE_MS
	end
	NextChaseRepathAt = GetTick() + CHASE_REPATH_MS
	CurrentState = STATE_CHASE_ATTACK
	return 1
end

function IsCellOccupiedByOther(x, y, ignoredTarget)
	if IsOwnerCell(x, y) then
		return true
	end

	local actors = GetActors()
	for _, actor in ipairs(actors) do
		if actor ~= MyID and actor ~= ignoredTarget then
			local actorX, actorY = GetV(V_POSITION, actor)
			if actorX == x and actorY == y and GetV(V_MOTION, actor) ~= MOTION_DEAD then
				return true
			end
		end
	end

	return false
end

function GetNearestOpenAdjacentCell(target)
	local targetX, targetY = GetV(V_POSITION, target)
	local myX, myY = GetV(V_POSITION, MyID)
	if myX == -1 or targetX == -1 then
		return myX, myY, 999
	end

	local bestX, bestY, bestDistance = GetNearestOpenAdjacentPoint(targetX, targetY, target)
	if bestDistance == 999 and IsOwnerCell(myX, myY) == false then
		return myX, myY, bestDistance
	end

	return bestX, bestY, bestDistance
end

function GetAlternateOpenAdjacentCell(target)
	local targetX, targetY = GetV(V_POSITION, target)
	local myX, myY = GetV(V_POSITION, MyID)
	if myX == -1 or targetX == -1 then
		return myX, myY, 999
	end

	local bestX, bestY, bestDistance = GetAlternateOpenAdjacentPoint(targetX, targetY, target)
	return bestX, bestY, bestDistance
end

function GetDanceCell(target)
	local myX, myY = GetV(V_POSITION, MyID)
	local targetX, targetY = GetV(V_POSITION, target)
	if myX == -1 or targetX == -1 then
		return myX, myY
	end

	local currentDistance = Distance(myX, myY, targetX, targetY)
	local bestX, bestY = myX, myY
	local bestTargetDistance = currentDistance
	local bestStep = 999
	for dx = -1, 1 do
		for dy = -1, 1 do
			if dx ~= 0 or dy ~= 0 then
				local candidateX = targetX + dx
				local candidateY = targetY + dy
				local stepDistance = Distance(myX, myY, candidateX, candidateY)
				local targetDistance = Distance(candidateX, candidateY, targetX, targetY)
				if stepDistance ~= -1
					and stepDistance <= 1
					and targetDistance ~= -1
					and targetDistance < currentDistance
					and IsOwnerCell(candidateX, candidateY) == false
					and IsCellOccupiedByOther(candidateX, candidateY, target) == false then
					if targetDistance < bestTargetDistance
						or (targetDistance == bestTargetDistance and stepDistance < bestStep) then
						bestX = candidateX
						bestY = candidateY
						bestTargetDistance = targetDistance
						bestStep = stepDistance
					end
				end
			end
		end
	end

	if bestStep == 999 then
		return myX, myY
	end

	return bestX, bestY
end

function TryDanceAttackStep()
	return 0
end

function TryPreAttackDanceStep()
	return 0
end

function Sign(n)
	if n > 0 then
		return 1
	elseif n < 0 then
		return -1
	end
	return 0
end

function GetPreferredOpenAdjacentCell(target, preferredX, preferredY)
	local targetX, targetY = GetV(V_POSITION, target)
	if targetX == -1 or targetY == -1 then
		return -1, -1
	end

	local bestX, bestY = -1, -1
	local bestScore = 999

	for dx = -1, 1 do
		for dy = -1, 1 do
			if dx ~= 0 or dy ~= 0 then
				local candidateX = targetX + dx
				local candidateY = targetY + dy
				if IsOwnerCell(candidateX, candidateY) == false
					and IsCellOccupiedByOther(candidateX, candidateY, target) == false then
					local score = Distance(candidateX, candidateY, preferredX, preferredY)
					if score ~= -1 and score < bestScore then
						bestX = candidateX
						bestY = candidateY
						bestScore = score
					end
				end
			end
		end
	end

	return bestX, bestY
end

function ResolveAttackCell(target, desiredX, desiredY)
	if desiredX == -1 or desiredY == -1 then
		return desiredX, desiredY
	end

	local myX, myY = GetV(V_POSITION, MyID)
	if myX ~= -1
		and IsStackedOnTarget(target) == false
		and DistanceToActor(MyID, target) ~= -1
		and DistanceToActor(MyID, target) <= AttackRange() then
		return myX, myY
	end

	if IsOwnerCell(desiredX, desiredY) == false and IsCellOccupiedByOther(desiredX, desiredY, target) == false then
		return desiredX, desiredY
	end

	local preferredX, preferredY = GetPreferredOpenAdjacentCell(target, desiredX, desiredY)
	if preferredX ~= -1 and preferredY ~= -1 then
		return preferredX, preferredY
	end

	local nearX, nearY = GetNearbyStationaryCell(target)
	if nearX ~= -1 and nearY ~= -1 then
		return nearX, nearY
	end

	return myX, myY
end

function GetAttackApproachCell(target)
	local myX, myY = GetV(V_POSITION, MyID)
	local targetX, targetY = GetV(V_POSITION, target)
	if myX == -1 or targetX == -1 then
		return myX, myY
	end

	if IsTargetActuallyMoving(target) then
		targetX, targetY = GetMoveLeadPosition(target)
	end

	local stepX = Sign(targetX - myX)
	local stepY = Sign(targetY - myY)
	local attackRange = AttackRange()

	if attackRange <= 1 then
		local preferredX, preferredY = ResolveAttackCell(target, targetX - stepX, targetY - stepY)
		if preferredX ~= -1 and preferredY ~= -1 then
			return preferredX, preferredY
		end

		local nearX, nearY = GetNearbyStationaryCell(target)
		if nearX ~= -1 and nearY ~= -1 then
			return nearX, nearY
		end

		return myX, myY
	end

	return ResolveAttackCell(target, targetX - (stepX * attackRange), targetY - (stepY * attackRange))
end

function GetSkillApproachCell(target)
	local level = GetTargetSkillLevel(target)
	local nextX, nextY = SkillApproachPosition(target, GetOffensiveSkillID(), level)
	if nextX == nil or nextY == nil or nextX == -1 or nextY == -1 then
		return GetAttackApproachCell(target)
	end

	local targetX, targetY = GetV(V_POSITION, target)
	if targetX == -1 or targetY == -1 then
		return nextX, nextY
	end

	return nextX + (Sign(targetX - nextX) * 2), nextY + (Sign(targetY - nextY) * 2)
end

function GetSnipeOrbitCell(target)
	local myX, myY = GetV(V_POSITION, MyID)
	local targetX, targetY = GetV(V_POSITION, target)
	local baseX, baseY = GetSkillApproachCell(target)
	if myX == -1 or targetX == -1 or baseX == -1 then
		return -1, -1
	end

	local baseDistance = Distance(baseX, baseY, targetX, targetY)
	if baseDistance == -1 then
		baseDistance = Distance(myX, myY, targetX, targetY)
	end

	local offsets = {
		{ 1, 0 }, { 1, 1 }, { 0, 1 }, { -1, 1 },
		{ -1, 0 }, { -1, -1 }, { 0, -1 }, { 1, -1 }
	}

	for index = 0, 7 do
		local offset = offsets[((SnipeOrbitStep + index - 1) % 8) + 1]
		local candidateX = baseX + offset[1]
		local candidateY = baseY + offset[2]
		local stepDistance = Distance(myX, myY, candidateX, candidateY)
		local targetDistance = Distance(candidateX, candidateY, targetX, targetY)
		if stepDistance ~= -1
			and stepDistance <= 1
			and targetDistance ~= -1
			and targetDistance >= math.max(1, baseDistance - 1)
			and targetDistance <= baseDistance + 1
			and IsOwnerCell(candidateX, candidateY) == false
			and IsCellOccupiedByOther(candidateX, candidateY, target) == false then
			SnipeOrbitStep = ((SnipeOrbitStep + index) % 8) + 1
			return candidateX, candidateY
		end
	end

	return -1, -1
end

function TryApproachSnipeTarget(taggedOnly)
	if FindMonsterInSkillRange(0) ~= 0 then
		return false
	end

	local snipeTarget = FindMonsterForSnipe(0, taggedOnly)
	if snipeTarget == 0 then
		return false
	end

	local nextX, nextY = GetSkillApproachCell(snipeTarget)
	if nextX == nil or nextY == nil or nextX == -1 or nextY == -1 then
		return false
	end

	ClearAttackTarget()
	if GetV(V_MOTION, MyID) ~= MOTION_MOVE or MoveX ~= nextX or MoveY ~= nextY or GetTick() >= NextChaseRepathAt then
		if MoveSmart(nextX, nextY) then
			NextChaseRepathAt = GetTick() + CHASE_REPATH_MS
		end
	end
	CurrentState = STATE_FOLLOW
	return true
end

function GetPendingCapriceRetryTarget()
	if PendingCapriceAt == 0 or PendingCapriceTarget == 0 then
		return 0
	end

	if IsValidTarget(PendingCapriceTarget) == false or IsTargetInActiveRange(PendingCapriceTarget) == false then
		return 0
	end

	return PendingCapriceTarget
end

function TryMaintainSnipePendingTarget()
	local pendingTarget = GetPendingCapriceRetryTarget()
	if pendingTarget == 0 then
		return false
	end

	local nextX, nextY = GetSkillApproachCell(pendingTarget)
	if nextX == nil or nextY == nil or nextX == -1 or nextY == -1 then
		CurrentState = STATE_IDLE
		return true
	end

	if InSkillRange(MyID, pendingTarget, GetOffensiveSkillID(), GetTargetSkillLevel(pendingTarget)) then
		local myX, myY = GetV(V_POSITION, MyID)
		if myX ~= -1 and myY ~= -1 and Distance(myX, myY, nextX, nextY) <= 1 then
			if GetTick() >= NextSnipeOrbitAt then
				local orbitX, orbitY = GetSnipeOrbitCell(pendingTarget)
				if orbitX ~= -1 and orbitY ~= -1 then
					if MoveSmart(orbitX, orbitY) then
						NextChaseRepathAt = GetTick() + CHASE_REPATH_MS
						NextSnipeOrbitAt = GetTick() + SNIPE_ORBIT_MS
						CurrentState = STATE_FOLLOW
						return true
					end
				end
				NextSnipeOrbitAt = GetTick() + SNIPE_ORBIT_MS
			end
			CurrentState = STATE_IDLE
			return true
		end
	end

	ClearAttackTarget()
	if GetV(V_MOTION, MyID) ~= MOTION_MOVE or MoveX ~= nextX or MoveY ~= nextY or GetTick() >= NextChaseRepathAt then
		if MoveSmart(nextX, nextY) then
			NextChaseRepathAt = GetTick() + CHASE_REPATH_MS
		end
	end
	CurrentState = STATE_FOLLOW
	return true
end

function GetNearbyStationaryCell(target)
	local bestX, bestY = GetNearestOpenAdjacentCell(target)
	return bestX, bestY
end

function GetStationaryRecoveryCell(target)
	local myX, myY = GetV(V_POSITION, MyID)
	if myX == -1 or myY == -1 then
		return myX, myY
	end

	if IsStackedOnTarget(target) == false
		and DistanceToActor(MyID, target) ~= -1
		and DistanceToActor(MyID, target) <= AttackRange() then
		return myX, myY
	end

	local nearX, nearY = GetNearbyStationaryCell(target)
	if nearX ~= -1 and nearY ~= -1 and (nearX ~= myX or nearY ~= myY) then
		return nearX, nearY
	end

	local approachX, approachY = GetAttackApproachCell(target)
	if approachX ~= -1 and approachY ~= -1 and (approachX ~= myX or approachY ~= myY) then
		return approachX, approachY
	end

	return myX, myY
end

function IsStackedOnTarget(target)
	if target == 0 then
		return false
	end

	local myX, myY = GetV(V_POSITION, MyID)
	local targetX, targetY = GetV(V_POSITION, target)
	if myX == -1 or targetX == -1 then
		return false
	end

	return myX == targetX and myY == targetY
end

function TryUnstackFromTarget(target)
	if IsStackedOnTarget(target) == false then
		return 0
	end

	local recoverX, recoverY = GetStationaryRecoveryCell(target)
	local myX, myY = GetV(V_POSITION, MyID)
	if recoverX == -1 or recoverY == -1 or (recoverX == myX and recoverY == myY) then
		return 0
	end

	ForceMoveTo(recoverX, recoverY)
	NextChaseRepathAt = GetTick() + CHASE_REPATH_MS
	CurrentState = STATE_CHASE_ATTACK
	return 1
end

function StationaryRepositionRange()
	return AttackRange() + 1
end

function HandleMoveCommand(x, y)
	ClearManualCapriceTarget()
	SetAnchor(x, y)
	ResetPatrolState()
	MoveSmart(x, y)
	ClearAttackTarget()
	CurrentState = STATE_MOVE
end

function HandleStopCommand()
	ClearManualCapriceTarget()
	local x, y = GetV(V_POSITION, MyID)
	ResetPatrolState()
	MoveSmart(x, y)
	ClearAttackTarget()
	CurrentState = STATE_IDLE
end

function HandleAttackObjectCommand(target)
	ClearManualCapriceTarget()
	if IsSnipeMode() then
		return
	end

	StartAttackChase(target)
end

function HandleSkillObjectCommand(level, skillID, target)
	SetManualCapriceTarget(target, level, skillID)
	if TryCastCaprice() ~= 0 then
		CurrentState = STATE_IDLE
		return
	end

	if IsValidManualCapriceTarget(target) and IsTargetInActiveRange(target) then
		local nextX, nextY = GetSkillApproachCell(target)
		if nextX ~= -1 and nextY ~= -1 then
			ClearAttackTarget()
			ForceMoveTo(nextX, nextY)
			CurrentState = STATE_MOVE
		end
	end
end

function HandleHoldCommand()
	ClearManualCapriceTarget()
	ClearAttackTarget()
	CurrentState = STATE_HOLD
end

function HandleFollowCommand()
	ClearManualCapriceTarget()
	ClearAnchor()
	ResetPatrolState()
	ClearAttackTarget()
	StartFollow()
end

function ProcessCommand(msg)
	if IsSnipeMode() and (msg[1] == ATTACK_OBJECT_CMD or msg[1] == ATTACK_AREA_CMD) then
		return
	end

	if msg[1] == MOVE_CMD then
		HandleMoveCommand(msg[2], msg[3])
	elseif msg[1] == STOP_CMD then
		HandleStopCommand()
	elseif msg[1] == ATTACK_OBJECT_CMD then
		HandleAttackObjectCommand(msg[2])
	elseif msg[1] == SKILL_OBJECT_CMD then
		HandleSkillObjectCommand(msg[2], msg[3], msg[4])
	elseif msg[1] == HOLD_CMD then
		HandleHoldCommand()
	elseif msg[1] == FOLLOW_CMD then
		HandleFollowCommand()
	end
end

function TickIdle()
	local queued = Queue.pop_left(PendingCommands)
	if queued ~= nil then
		ProcessCommand(queued)
		return
	end

	if SoftResetInProgress() then
		if TryBreakSoftResetForTarget() then
			return
		end
		if StandbyResetMoveBack == 1 then
			ForceStandby()
		end
		return
	end

	TryCastConfiguredSkills()
	AcquireAttackTarget()
	if AttackTarget ~= 0 then
		return
	end

	if TryApproachSnipeTarget(true) then
		return
	end

	EnsureIdleStandby()
end

function TickFollow()
	if SoftResetInProgress() then
		if TryBreakSoftResetForTarget() then
			return
		end
		if StandbyResetMoveBack == 1 then
			local standbyX, standbyY = GetStandbyCell()
			if StandbyUsesPatrol() then
				ForceStandby()
			elseif standbyX ~= MoveX or standbyY ~= MoveY or GetV(V_MOTION, MyID) ~= MOTION_MOVE then
				ForceFollow(ShouldUseFollowRecovery(standbyX, standbyY))
			end
		end
		return
	end

	TryCastConfiguredSkills()
	AcquireAttackTarget()
	if AttackTarget ~= 0 then
		return
	end

	if TryApproachSnipeTarget(true) then
		return
	end

	if TryPatrol() then
		return
	end

	if IsAtStandbyCell() then
		CurrentState = STATE_IDLE
		return
	end

	EnsureIdleStandby()
end

function TickChaseAttack()
	if IsSnipeMode() then
		ClearAttackTarget()
		ForceStandby()
		return
	end

	local protectionTarget = IsOwnerProtectionAttackTarget(AttackTarget)
	if protectionTarget == false and GetAttackBehaviorPriority(AttackTarget) < 0 then
		local oldAttackTarget = AttackTarget
		ClearAttackTarget()
		AcquireAttackTarget(oldAttackTarget)
		if AttackTarget == 0 then
			BeginSoftStandbyReset(0, 1)
		end
		return
	end

	if IsValidAttackTargetForCurrentPurpose(AttackTarget) == false
		or IsOutOfSight(MyID, AttackTarget)
		or (protectionTarget == false and IsKSTarget(AttackTarget))
		or IsTargetInActiveRange(AttackTarget) == false
		or IsTargetReachableWhileTurretStaying(AttackTarget) == false then
		ClearAttackTarget()
		AcquireAttackTarget()
		if AttackTarget == 0 then
			CurrentState = STATE_IDLE
		end
		return
	end

	if TryUnstackFromTarget(AttackTarget) == 1 then
		return
	end

	if protectionTarget == false and HandleKiteBehavior(AttackTarget) then
		return
	end

	local castTarget = TryCastConfiguredSkills()
	if ShouldPauseAfterPrimarySkillAttempt(castTarget) then
		HandlePostSkillPrimaryTarget(castTarget, ShouldIgnoreAfterPrimarySkillAttempt(castTarget))
		return
	end

	local distance = DistanceToActor(MyID, AttackTarget)
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

	if distance <= StickyAttackRange() and TryStickyAttackCommand() == 1 then
		CurrentState = STATE_ATTACK
		return
	end

	if TryAttackRefreshStep() == 1 then
		return
	end

	if IsTargetActuallyMoving(AttackTarget) == false then
		if distance <= StationaryRepositionRange() then
			local recoverX, recoverY = GetStationaryRecoveryCell(AttackTarget)
			if recoverX ~= -1 and recoverY ~= -1 then
				if GetTick() >= NextChaseRepathAt and (recoverX ~= MoveX or recoverY ~= MoveY or GetV(V_MOTION, MyID) ~= MOTION_MOVE) then
					ForceMoveTo(recoverX, recoverY)
					NextChaseRepathAt = GetTick() + CHASE_REPATH_MS
				end
				CurrentState = STATE_CHASE_ATTACK
				return
			end
		end

		local nearX, nearY = GetNearbyStationaryCell(AttackTarget)
		if nearX ~= -1 and nearY ~= -1 then
			if GetTick() >= NextChaseRepathAt and (nearX ~= MoveX or nearY ~= MoveY or GetV(V_MOTION, MyID) ~= MOTION_MOVE) then
				ForceMoveTo(nearX, nearY)
				NextChaseRepathAt = GetTick() + CHASE_REPATH_MS
			end
			CurrentState = STATE_CHASE_ATTACK
		end
		return
	end

	UpdateAttackChaseMovement()
end

function TickAttack()
	if IsSnipeMode() then
		ClearAttackTarget()
		ForceStandby()
		return
	end

	local protectionTarget = IsOwnerProtectionAttackTarget(AttackTarget)
	if protectionTarget == false and GetAttackBehaviorPriority(AttackTarget) < 0 then
		local oldAttackTarget = AttackTarget
		ClearAttackTarget()
		AcquireAttackTarget(oldAttackTarget)
		if AttackTarget == 0 then
			BeginSoftStandbyReset(0, 1)
		end
		return
	end

	if IsValidAttackTargetForCurrentPurpose(AttackTarget) == false
		or IsOutOfSight(MyID, AttackTarget)
		or (protectionTarget == false and IsKSTarget(AttackTarget))
		or IsTargetInActiveRange(AttackTarget) == false
		or IsTargetReachableWhileTurretStaying(AttackTarget) == false then
		ClearAttackTarget()
		AcquireAttackTarget()
		if AttackTarget == 0 then
			CurrentState = STATE_IDLE
		end
		return
	end

	if TryUnstackFromTarget(AttackTarget) == 1 then
		return
	end

	if protectionTarget == false and HandleKiteBehavior(AttackTarget) then
		return
	end

	local castTarget = TryCastConfiguredSkills()
	if ShouldPauseAfterPrimarySkillAttempt(castTarget) then
		HandlePostSkillPrimaryTarget(castTarget, ShouldIgnoreAfterPrimarySkillAttempt(castTarget))
		return
	end

	local distance = DistanceToActor(MyID, AttackTarget)
	if distance > AttackRange() then
		if distance <= StickyAttackRange() and TryStickyAttackCommand() == 1 then
			return
		end

		if IsTargetActuallyMoving(AttackTarget) == false and distance <= StationaryRepositionRange() then
			local recoverX, recoverY = GetStationaryRecoveryCell(AttackTarget)
			if recoverX ~= -1 and recoverY ~= -1 then
				if recoverX ~= MoveX or recoverY ~= MoveY or GetV(V_MOTION, MyID) ~= MOTION_MOVE then
					ForceMoveTo(recoverX, recoverY)
					NextChaseRepathAt = GetTick() + CHASE_REPATH_MS
				end
				CurrentState = STATE_CHASE_ATTACK
				return
			end
		end

		if TryAttackRefreshStep() == 1 then
			return
		end

		CurrentState = STATE_CHASE_ATTACK
		return
	end

	if GetTick() + ATTACK_LATCH_GRACE_MS >= NextAttackCommandAt then
		Attack(MyID, AttackTarget)
		NextAttackCommandAt = GetTick() + ATTACK_REISSUE_MS
		AttackTargetHit = 1
		HandlePostNormalAttack(AttackTarget)
		return
	end

	if TryAttackRefreshStep() == 1 then
		return
	end

	return
end

function TickMove()
	if PatrolEnabled() then
		TryCastConfiguredSkills()
		AcquireAttackTarget()
		if AttackTarget ~= 0 then
			return
		end
	end

	local x, y = GetV(V_POSITION, MyID)
	if PatrolEnabled()
		and AttackTarget == 0
		and RequireStandbyReset == 0
		and (x ~= MoveX or y ~= MoveY) then
		if x ~= PatrolLastPosX or y ~= PatrolLastPosY then
			PatrolLastPosX = x
			PatrolLastPosY = y
			PatrolStuckSince = 0
		else
			if PatrolStuckSince == 0 then
				PatrolStuckSince = GetTick()
			elseif GetTick() - PatrolStuckSince >= PATROL_STALL_MS then
				PatrolStuckSince = 0
				NextPatrolMoveAt = 0
				if PatrolRetryCount == 0 then
					PatrolRetryCount = 1
				else
					PatrolRetryCount = 0
					AdvancePatrolStep()
				end
				PatrolLastPosX = -1
				PatrolLastPosY = -1
				if TryPatrol() == false then
					AdvancePatrolStep()
					TryPatrol()
				end
				return
			end
		end
	else
		PatrolStuckSince = 0
		PatrolRetryCount = 0
		PatrolLastPosX = -1
		PatrolLastPosY = -1
	end

	if PatrolEnabled() and AttackTarget == 0 and RequireStandbyReset == 0 and Distance(x, y, MoveX, MoveY) <= 1 then
		if TryPatrol() then
			return
		end
	end

	if x == MoveX and y == MoveY then
		if TryPatrol() then
			return
		end

		CurrentState = STATE_IDLE
	end
end

function TickHold()
	TryCastConfiguredSkills()
end

function TickWait()
	local queued = Queue.pop_left(PendingCommands)
	if queued ~= nil then
		ProcessCommand(queued)
		return
	end

	if GetTick() < WaitModeReadyAt then
		return
	end

	CancelPostSkillWait()
	CurrentState = STATE_IDLE
	TryCastConfiguredSkills()
	AcquireAttackTarget()
	if AttackTarget ~= 0 then
		return
	end

	if TryApproachSnipeTarget(true) then
		return
	end

	TryPatrol()
end

function TickSnipeMode()
	local queued = Queue.pop_left(PendingCommands)
	if queued ~= nil then
		if queued[1] == ATTACK_OBJECT_CMD or queued[1] == ATTACK_AREA_CMD then
			queued = nil
		else
		ProcessCommand(queued)
		return
		end
	end

	if CurrentState == STATE_MOVE then
		TickMove()
		if CurrentState == STATE_MOVE then
			return
		end
	end

	if CurrentState == STATE_HOLD then
		TickHold()
		return
	end

	if SoftResetInProgress() then
		if StandbyResetMoveBack == 1 then
			ForceStandby()
		end
		return
	end

	if AttackTarget ~= 0 or CurrentState == STATE_ATTACK or CurrentState == STATE_CHASE_ATTACK or IsInAttackMotion(MyID) then
		ClearAttackTarget()
		ForceStandby()
		return
	end

	local castTarget = TryCastConfiguredSkills()
	if castTarget ~= 0 then
		CurrentState = STATE_IDLE
		return
	end

	if TryMaintainSnipePendingTarget() then
		return
	end

	if FindMonsterInSkillRange(0) ~= 0 then
		CurrentState = STATE_IDLE
		return
	end

	if TryApproachSnipeTarget(false) then
		return
	end

	if TryPatrol() then
		return
	end

	local standbyX, standbyY = GetStandbyCell()
	if IsAtStandbyCell() == false then
		if StandbyUsesPatrol() then
			StartStandby()
		elseif standbyX ~= MoveX or standbyY ~= MoveY or GetV(V_MOTION, MyID) ~= MOTION_MOVE then
			StartFollow()
		else
			CurrentState = STATE_FOLLOW
		end
		return
	end

	CurrentState = STATE_IDLE
end

function IsInAttackMotion(id)
	local motion = GetV(V_MOTION, id)
	return motion == MOTION_ATTACK or motion == MOTION_ATTACK2
end

function IsActuallyAttackingTarget()
	if AttackTarget == 0 or IsValidAttackTargetForCurrentPurpose(AttackTarget) == false then
		return false
	end

	local myMotion = GetV(V_MOTION, MyID)
	if myMotion == MOTION_MOVE then
		if CurrentState == STATE_CHASE_ATTACK then
			return true
		end

		return true
	end

	if IsInAttackMotion(MyID) then
		return true
	end

	local distance = DistanceToActor(MyID, AttackTarget)
	if distance == -1 then
		return false
	end

	if CurrentState == STATE_ATTACK and distance <= AttackRange() then
		return NextAttackCommandAt > GetTick() and (NextAttackCommandAt - GetTick()) <= ATTACK_LATCH_GRACE_MS
	end

	if CurrentState == STATE_CHASE_ATTACK then
		return NextChaseRepathAt > GetTick() and (NextChaseRepathAt - GetTick()) <= ATTACK_LATCH_GRACE_MS
	end

	return false
end

function UpdateStandStillTimer()
	if AntiStuckEnabled() == false then
		StandStillSince = 0
		return
	end

	local myX, myY = GetV(V_POSITION, MyID)
	if myX == -1 or myY == -1 then
		StandStillSince = 0
		return
	end

	if myX ~= LastMyPosX or myY ~= LastMyPosY then
		LastMyPosX = myX
		LastMyPosY = myY
		StandStillSince = 0
		return
	end

	if IsAtStandbyCell() then
		StandStillSince = 0
		return
	end

	if CurrentState == STATE_HOLD then
		StandStillSince = 0
		return
	end

	if IsActuallyAttackingTarget() then
		StandStillSince = 0
		return
	end

	if StandStillSince == 0 then
		StandStillSince = GetTick()
	end
end

function EnsureActiveBehavior()
	if CurrentState == STATE_HOLD or CurrentState == STATE_WAIT then
		return
	end

	if RequireStandbyReset == 1 then
		if SoftResetInProgress() then
			if StandbyResetMoveBack == 1 and GetV(V_MOTION, MyID) == MOTION_STAND then
				ForceStandby()
			end
			return
		else
			CurrentState = STATE_IDLE
		end
	end

	if AntiStuckEnabled() == false then
		StandStillSince = 0
		return
	end

	UpdateStandStillTimer()
	if StandStillSince == 0 then
		return
	end

	if GetTick() - StandStillSince < STUCK_STAND_MS then
		return
	end

	local oldAttackTarget = AttackTarget
	if oldAttackTarget ~= 0 then
		HandleStuckTargetReset(oldAttackTarget)
		StandStillSince = 0
		return
	end

	AcquireAttackTarget()
	if AttackTarget ~= 0 then
		StandStillSince = 0
		return
	end

	BeginSoftStandbyReset(0, 1)
	StandStillSince = 0
end

function ForceImmediateActivity()
	if CurrentState == STATE_HOLD or CurrentState == STATE_WAIT or IsSnipeMode() then
		return
	end

	if RequireStandbyReset == 1 then
		if StandbyResetMoveBack == 1 and GetV(V_MOTION, MyID) == MOTION_STAND then
			ForceStandby()
		end
		return
	end

	if AttackTarget ~= 0 and IsValidAttackTargetForCurrentPurpose(AttackTarget) then
		if CurrentState == STATE_ATTACK or CurrentState == STATE_CHASE_ATTACK then
			if TryUnstackFromTarget(AttackTarget) == 1 then
				return
			end

			local distance = DistanceToActor(MyID, AttackTarget)
			if distance == -1 then
				ClearAttackTarget()
				CurrentState = STATE_IDLE
				return
			end

			if IsActuallyAttackingTarget() == false then
				if distance <= StickyAttackRange() and TryStickyAttackCommand() == 1 then
					if distance <= AttackRange() then
						CurrentState = STATE_ATTACK
					else
						CurrentState = STATE_CHASE_ATTACK
					end
					return
				end

				if TryAttackRefreshStep() == 1 then
					return
				end

				if distance <= AttackRange() then
					Attack(MyID, AttackTarget)
					NextAttackCommandAt = GetTick() + ATTACK_REISSUE_MS
					HandlePostNormalAttack(AttackTarget)
					if AttackTarget ~= 0 then
						CurrentState = STATE_ATTACK
					end
					return
				end

				if IsTargetActuallyMoving(AttackTarget) == false and distance <= StationaryRepositionRange() then
					local recoverX, recoverY = GetStationaryRecoveryCell(AttackTarget)
					if recoverX ~= -1 and recoverY ~= -1 then
						if recoverX ~= MoveX or recoverY ~= MoveY or GetV(V_MOTION, MyID) ~= MOTION_MOVE then
							ForceMoveTo(recoverX, recoverY)
							NextChaseRepathAt = GetTick() + CHASE_REPATH_MS
						end
						CurrentState = STATE_CHASE_ATTACK
						return
					end
				end

				ForceAttackChaseMovement()
				CurrentState = STATE_CHASE_ATTACK
				return
			end
		end

		local distance = DistanceToActor(MyID, AttackTarget)
		if distance ~= -1 then
			if distance <= StickyAttackRange() and TryStickyAttackCommand() == 1 then
				if distance <= AttackRange() then
					CurrentState = STATE_ATTACK
				else
					CurrentState = STATE_CHASE_ATTACK
				end
				return
			end

			if TryAttackRefreshStep() == 1 then
				return
			end

			if distance <= AttackRange() then
				Attack(MyID, AttackTarget)
				NextAttackCommandAt = GetTick() + ATTACK_REISSUE_MS
				HandlePostNormalAttack(AttackTarget)
				if AttackTarget ~= 0 then
					CurrentState = STATE_ATTACK
				end
				return
			end

			if IsTargetActuallyMoving(AttackTarget) == false and distance <= StationaryRepositionRange() then
				local recoverX, recoverY = GetStationaryRecoveryCell(AttackTarget)
				if recoverX ~= -1 and recoverY ~= -1 then
					if recoverX ~= MoveX or recoverY ~= MoveY or GetV(V_MOTION, MyID) ~= MOTION_MOVE then
						ForceMoveTo(recoverX, recoverY)
						NextChaseRepathAt = GetTick() + CHASE_REPATH_MS
					end
					CurrentState = STATE_CHASE_ATTACK
					return
				end
			end
		end

		ForceAttackChaseMovement()
		CurrentState = STATE_CHASE_ATTACK
		return
	end

	AcquireAttackTarget()
	if AttackTarget ~= 0 then
		ForceAttackChaseMovement()
		CurrentState = STATE_CHASE_ATTACK
		return
	end

	EnsureIdleStandby()
end

function IsMercenaryCall(id)
	local mercType = tonumber(GetV(V_MERTYPE, id)) or 0
	return mercType > 0
end

function AI(myid)
	if IsMercenaryCall(myid) then
		return
	end

	MyID = myid
	UpdateSPTracking()
	UpdateCapriceAttemptState()
	CleanupProtectedMob()
	CleanupKiteNoAttackDone()

	local msg = GetMsg(myid)
	local reserved = GetResMsg(myid)

	if msg[1] == NONE_CMD then
		if reserved[1] ~= NONE_CMD and (IsSnipeMode() == false or (reserved[1] ~= ATTACK_OBJECT_CMD and reserved[1] ~= ATTACK_AREA_CMD)) and Queue.size(PendingCommands) < 10 then
			Queue.push_right(PendingCommands, reserved)
		end
	else
		Queue.clear(PendingCommands)
		ProcessCommand(msg)
	end

	if HandleManualCapricePriority() then
		local actors = GetActors()
		for _, actor in ipairs(actors) do
			RememberActorPosition(actor)
		end
		return
	end

	if HandleAvoidPriority() then
		local actors = GetActors()
		for _, actor in ipairs(actors) do
			RememberActorPosition(actor)
		end
		return
	end

	if HandleOwnerProtectionPriority() then
		local actors = GetActors()
		for _, actor in ipairs(actors) do
			RememberActorPosition(actor)
		end
		return
	end

	if OwnerMovementOverrideActive() then
		local actors = GetActors()
		for _, actor in ipairs(actors) do
			RememberActorPosition(actor)
		end
		return
	end

	if IsSnipeMode() then
		TickSnipeMode()
		local actors = GetActors()
		for _, actor in ipairs(actors) do
			RememberActorPosition(actor)
		end
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
		TickHold()
	elseif CurrentState == STATE_WAIT then
		TickWait()
	end

	ForceImmediateActivity()
	EnsureActiveBehavior()

	local actors = GetActors()
	for _, actor in ipairs(actors) do
		RememberActorPosition(actor)
	end
end

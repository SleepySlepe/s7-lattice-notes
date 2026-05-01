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

function NormalizeKSModeValue(value)
	local mode = string.lower(tostring(value or ""))
	if mode == "no ks" or mode == "noks" or mode == "no_ks" then
		return "no ks"
	elseif mode == "first attack" or mode == "first_attack" or mode == "firstattack" then
		return "first attack"
	elseif mode == "full ks" or mode == "full_ks" or mode == "fullks" then
		return "full ks"
	end

	return ""
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

	local ksMode = NormalizeKSModeValue(TargetLists.Runtime.KSMode)
	if ksMode == "" then
		if TargetLists.Runtime.NoKS == nil or TargetLists.Runtime.NoKS == true then
			ksMode = "no ks"
		else
			ksMode = "full ks"
		end
	end
	TargetLists.Runtime.KSMode = ksMode
	TargetLists.Runtime.NoKS = ksMode == "no ks"

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

function NormalizeSkillCountValue(value)
	if value == nil then
		return 999
	end

	local numeric = tonumber(value)
	if numeric ~= nil then
		numeric = math.floor(numeric)
		if numeric < 0 then
			return 0
		end
		if numeric > 999 then
			return 999
		end
		return numeric
	end

	local mode = string.lower(tostring(value or ""))
	if mode == "no skill" then
		return 0
	elseif mode == "one skill" then
		return 1
	elseif mode == "two skills" then
		return 2
	elseif mode == "max skills" then
		return 999
	end

	return 999
end

function NormalizeKSModeValue(value)
	local mode = string.lower(tostring(value or ""))
	if mode == "no ks" or mode == "noks" or mode == "no_ks" then
		return "no ks"
	elseif mode == "first attack" or mode == "first_attack" or mode == "firstattack" then
		return "first attack"
	elseif mode == "full ks" or mode == "full_ks" or mode == "fullks" then
		return "full ks"
	end

	return ""
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
				Priority = tostring(value.Priority or ""),
				Skill = NormalizeSkillCountValue(value.Skill),
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
FILIR_OFFENSIVE_RETRY_MS = 100
CAPRICE_CONFIRM_TIMEOUT_MS = 5000
SKILL_RESERVATION_MS = 1200
ONE_SKILL_ATTEMPT_LOCK_MS = 3500
MANUAL_CAPRICE_TIMEOUT_MS = 5000
FILIR_SUPPORT_CONFIRM_TIMEOUT_MS = 1000
FILIR_SUPPORT_RETRY_MS = 10000
FILIR_SUPPORT_MAX_PERSIST_MS = 180000
MOONLIGHT_SKILL = 8009
FLITTING_SKILL = 8010
ACCELERATED_FLIGHT_SKILL = 8011
CHASE_REPATH_MS = 400
CHASE_REPATH_DISTANCE = 2
ATTACK_STICKY_EXTRA_RANGE = 2
ATTACK_REISSUE_MS = 150
ATTACK_LATCH_GRACE_MS = 150
ATTACK_TARGET_COMMIT_MS = 700
DANCE_MOVE_MS = TargetLists.Runtime.DanceMoveMs
DANCE_ATTACK_BUFFER_MS = 120
STUCK_STAND_MS = TargetLists.Runtime.AntiStuckMs
CHASE_LEAD_CELLS = 1
FILIR_CHASE_LEAD_CELLS = 1
FILIR_CHASE_REPATH_MS = 250
ATTACK_APPROACH_STICKY_MS = 450
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
CHASE_PROGRESS_CHECK_MS = 700
CHASE_PROGRESS_MIN_GAIN = 1
SIGHT_RECOVERY_STEP_CELLS = 5
SIGHT_RECOVERY_REISSUE_MS = 350
SIGHT_BREADCRUMB_DISTANCE = 2
SIGHT_BACKTRACK_MIN_DISTANCE = 4
OWNER_PROTECTION_REHIT_MS = 500
OWNER_PROTECTION_HOLD_MS = 500
AVOID_DISTANCE_CELLS = 12
KITE_AWAY_DISTANCE_CELLS = 5
PATROL_MOVE_MS = 0
PATROL_STALL_MS = 400
SNIPE_ORBIT_MS = 300
IDLE_STANDBY_REISSUE_MS = 250
MOTION_DANCE = MOTION_DANCE or 16
MOTION_PERFORM = MOTION_PERFORM or 17
VANIL_SONG_BUFF_RANGE = 3
VANIL_SONG_BUFF_DURATION_MS = 19000
VANIL_SONG_PROVIDER_ACTIVE_MS = 180000
VANIL_SONG_SEARCH_RANGE = 20
VANIL_SONG_REPATH_MS = 300

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
PendingFilirSupportAt = 0
PendingFilirSupportSP = 0
PendingFilirSupportName = ""
PendingFilirSupportCost = 0
PendingFilirSupportDelayMs = 0
FilirSupportCooldownsLoaded = false
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
StickyApproachTarget = 0
StickyApproachX = -1
StickyApproachY = -1
StickyApproachTargetX = -1
StickyApproachTargetY = -1
StickyApproachUntil = 0
NextAttackCommandAt = 0
NextAttackRefreshMoveAt = 0
AttackTargetCommittedUntil = 0
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
FirstAttackClaimedMob = {}
ProtectedMob = {}
KiteNoAttackDone = {}
SkillCastCount = {}
SkillCastCountByClass = {}
SkillCastReservations = {}
OneSkillAttemptLatch = {}
LastSeenPosX = {}
LastSeenPosY = {}
Breadcrumb1X = {}
Breadcrumb1Y = {}
Breadcrumb2X = {}
Breadcrumb2Y = {}
Breadcrumb3X = {}
Breadcrumb3Y = {}
IgnoreTargetUntil = {}
PathProbeTarget = 0
PathProbeStartedAt = 0
PathProbeBestDistance = 999
PathProbeStrikeCount = 0
PathProbeTargetX = -1
PathProbeTargetY = -1
SightRecoveryStep = 1
NextSightRecoveryAt = 0
PatrolStep = 1
NextPatrolMoveAt = 0
VanilBragiBuffUntil = 0
VanilServiceBuffUntil = 0
VanilBragiProviders = {}
VanilServiceProviders = {}
VanilCurrentBragiProvider = 0
VanilCurrentServiceProvider = 0
VanilSongSeekingKind = ""
VanilSongSeekingTarget = 0
VanilSongMoveX = 0
VanilSongMoveY = 0
VanilSongNextMoveAt = 0
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
	if IsFilir(MyID) then
		return false
	end

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

function NoKSEnabled()
	return GetKSMode() == "no ks"
end

function GetKSMode()
	if TargetLists.Runtime == nil then
		return "no ks"
	end

	local mode = NormalizeKSModeValue(TargetLists.Runtime.KSMode)
	if mode ~= "" then
		return mode
	end

	if TargetLists.Runtime.NoKS == false then
		return "full ks"
	end

	return "no ks"
end

function FirstAttackKSModeEnabled()
	return GetKSMode() == "first attack"
end

function FullKSEnabled()
	return GetKSMode() == "full ks"
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

function IsOtherPlayerControlledActor(actor)
	if actor == 0 or actor == MyID or actor == GetV(V_OWNER, MyID) then
		return false
	end

	local actorOwner = GetV(V_OWNER, actor)
	if actorOwner ~= 0 and actorOwner ~= GetV(V_OWNER, MyID) then
		return true
	end

	return IsMonster(actor) ~= 1
end

function IsKSContestedByOthers(target)
	if target == 0 or IsValidTarget(target) == false then
		return false
	end

	local owner = GetV(V_OWNER, MyID)
	local actors = GetActors()
	local chasing = GetV(V_TARGET, target)

	if chasing ~= 0 and chasing ~= MyID and chasing ~= owner then
		for _, actor in ipairs(actors) do
			if actor == chasing and IsOtherPlayerControlledActor(actor) then
				return true
			end
		end
	end

	for _, actor in ipairs(actors) do
		if IsOtherPlayerControlledActor(actor)
			and GetV(V_TARGET, actor) == target then
			return true
		end
	end

	return false
end

function WasFirstAttackClaimed(id)
	return FirstAttackClaimedMob[id] == 1
end

function ClaimFirstAttack(id)
	if id ~= 0 then
		FirstAttackClaimedMob[id] = 1
	end
end

function IsKSTarget(target)
	if FullKSEnabled() then
		return false
	end

	if FirstAttackKSModeEnabled() and WasFirstAttackClaimed(target) then
		return false
	end

	return IsKSContestedByOthers(target)
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
			if IsCommittedToCurrentAttackTarget() then
				return false
			end

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
	local oldAttackTarget = AttackTarget
	AttackTarget = 0
	AttackTargetHit = 0
	NextAttackRefreshMoveAt = 0
	AttackTargetCommittedUntil = 0
	if oldAttackTarget ~= 0 then
		ResetPathingProbe()
	end
	ClearStickyAttackApproach()
end

function ClearStickyAttackApproach()
	StickyApproachTarget = 0
	StickyApproachX = -1
	StickyApproachY = -1
	StickyApproachTargetX = -1
	StickyApproachTargetY = -1
	StickyApproachUntil = 0
end

function CacheStickyAttackApproach(target, approachX, approachY)
	local targetX, targetY = GetV(V_POSITION, target)
	StickyApproachTarget = target
	StickyApproachX = approachX
	StickyApproachY = approachY
	StickyApproachTargetX = targetX
	StickyApproachTargetY = targetY
	StickyApproachUntil = GetTick() + ATTACK_APPROACH_STICKY_MS
end

function CanReuseStickyAttackApproach(target, rawX, rawY)
	if StickyApproachTarget ~= target
		or StickyApproachX == -1
		or StickyApproachY == -1
		or GetTick() >= StickyApproachUntil then
		return false
	end

	local targetX, targetY = GetV(V_POSITION, target)
	if targetX == -1 or targetY == -1 then
		return false
	end

	if Distance(targetX, targetY, StickyApproachTargetX, StickyApproachTargetY) > 1 then
		return false
	end

	if IsOwnerCell(StickyApproachX, StickyApproachY)
		or IsCellOccupiedByOther(StickyApproachX, StickyApproachY, target) then
		return false
	end

	if Distance(StickyApproachX, StickyApproachY, targetX, targetY) > AttackRange() + 1 then
		return false
	end

	if rawX ~= -1 and rawY ~= -1 and Distance(StickyApproachX, StickyApproachY, rawX, rawY) <= 1 then
		return true
	end

	if GetV(V_MOTION, MyID) == MOTION_MOVE and MoveX == StickyApproachX and MoveY == StickyApproachY then
		return true
	end

	return false
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

function ShouldIgnoreDroppedTargetAfterSwap(target)
	if target == 0 then
		return false
	end

	if GetV(V_MOTION, target) == MOTION_DEAD then
		return true
	end

	local x, y = GetV(V_POSITION, target)
	if x == -1 or y == -1 then
		return true
	end

	return false
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

function ResetPathingProbe()
	PathProbeTarget = 0
	PathProbeStartedAt = 0
	PathProbeBestDistance = 999
	PathProbeStrikeCount = 0
	PathProbeTargetX = -1
	PathProbeTargetY = -1
end

function StartPathingProbe(target)
	if target == 0 then
		ResetPathingProbe()
		return
	end

	local targetX, targetY = GetV(V_POSITION, target)
	local distance = DistanceToActor(MyID, target)
	PathProbeTarget = target
	PathProbeStartedAt = GetTick()
	PathProbeBestDistance = distance ~= -1 and distance or 999
	PathProbeStrikeCount = 0
	PathProbeTargetX = targetX
	PathProbeTargetY = targetY
end

function MarkPathingProgress(target, distance)
	PathProbeBestDistance = distance
	PathProbeStartedAt = GetTick()
	PathProbeStrikeCount = 0
	local targetX, targetY = GetV(V_POSITION, target)
	PathProbeTargetX = targetX
	PathProbeTargetY = targetY
end

function RegisterPathingProbeStrike(target, distance)
	PathProbeStrikeCount = PathProbeStrikeCount + 1
	PathProbeStartedAt = GetTick()
	PathProbeBestDistance = distance ~= -1 and distance or PathProbeBestDistance

	local targetX, targetY = GetV(V_POSITION, target)
	PathProbeTargetX = targetX
	PathProbeTargetY = targetY
	NextChaseRepathAt = 0

	return PathProbeStrikeCount >= 2
end

function CheckTargetPathingFailure(target)
	if target == 0 or IsValidTarget(target) == false then
		ResetPathingProbe()
		return false
	end

	if IsOwnerProtectionAttackTarget(target) then
		ResetPathingProbe()
		return false
	end

	local distance = DistanceToActor(MyID, target)
	if distance == -1 then
		ResetPathingProbe()
		return false
	end

	if distance <= AttackRange() or IsInAttackMotion(MyID) or AttackTargetHit == 1 then
		ResetPathingProbe()
		return false
	end

	local targetX, targetY = GetV(V_POSITION, target)
	if PathProbeTarget ~= target
		or targetX ~= PathProbeTargetX
		or targetY ~= PathProbeTargetY then
		StartPathingProbe(target)
		return false
	end

	if distance <= PathProbeBestDistance - CHASE_PROGRESS_MIN_GAIN then
		MarkPathingProgress(target, distance)
		return false
	end

	if GetTick() - PathProbeStartedAt < GetTargetPathingFailureTimeoutMs(target, distance) then
		return false
	end

	if RegisterPathingProbeStrike(target, distance) == false then
		return false
	end

	if ShouldKeepCurrentTargetThroughRecovery(target)
		or ShouldKeepNearbyTargetThroughRecovery(target, distance) then
		IgnoreTargetUntil[target] = nil
		ResetPathingProbe()
		NextChaseRepathAt = 0
		return false
	end

	IgnoreTargetForDuration(target, UNREACHABLE_TARGET_IGNORE_MS)
	ResetPathingProbe()
	return true
end

function HandlePathingFailureTarget(target)
	if target == 0 then
		return
	end

	if AttackTarget == target then
		ClearAttackTarget()
	end

	AcquireAttackTarget(target)
	if AttackTarget == 0 then
		BeginSoftStandbyReset(1, 1)
	elseif RedirectAttackAfterTargetSwap(target) == 1 then
		return
	end
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

function GetTargetSkillCount(id)
	local tactic = GetMonsterTactic(id)
	if tactic == nil then
		if CapriceEnabledByDefault() then
			return 999
		end

		return 0
	end

	return NormalizeSkillCountValue(tactic.Skill)
end

function ParseTacticPriorityValue(value)
	local priority = string.lower(tostring(value or ""))
	if priority == "first" or priority == "normal" or priority == "last" then
		return priority
	end

	return ""
end

function SplitLegacyBehaviorAndPriority(value)
	local behavior = string.lower(tostring(value or ""))
	if behavior == "slepe first" then
		return "slepe mode", "first"
	elseif behavior == "slepe last" then
		return "slepe mode", "last"
	elseif behavior == "slepe mode" or behavior == "slepe" then
		return "slepe mode", "normal"
	elseif behavior == "snipe first" then
		return "snipe", "first"
	elseif behavior == "snipe last" then
		return "snipe", "last"
	elseif behavior == "snipe" then
		return "snipe", "normal"
	elseif behavior == "attack first" then
		return "attack", "first"
	elseif behavior == "attack last" then
		return "attack", "last"
	elseif behavior == "attack" then
		return "attack", "normal"
	elseif behavior == "react first" then
		return "react", "first"
	elseif behavior == "react last" then
		return "react", "last"
	elseif behavior == "react" then
		return "react", "normal"
	elseif behavior == "avoid" then
		return "avoid", "normal"
	elseif behavior == "kite attack" then
		return "kite attack", "normal"
	elseif behavior == "kite no attack" then
		return "kite no attack", "normal"
	end

	return "", ""
end

function NormalizeTacticBaseBehavior(value)
	local behavior = string.lower(tostring(value or ""))
	if behavior == "slepe" then
		return "slepe mode"
	elseif behavior == "slepe mode"
		or behavior == "snipe"
		or behavior == "avoid"
		or behavior == "kite attack"
		or behavior == "kite no attack"
		or behavior == "attack"
		or behavior == "react" then
		return behavior
	end

	local legacyBehavior = SplitLegacyBehaviorAndPriority(behavior)
	return legacyBehavior
end

function CombineTacticBehaviorAndPriority(behavior, priority)
	behavior = NormalizeTacticBaseBehavior(behavior)
	if behavior == "" then
		return ""
	end

	if behavior == "avoid" or behavior == "kite attack" or behavior == "kite no attack" then
		return behavior
	end

	priority = ParseTacticPriorityValue(priority)
	if priority == "first" then
		if behavior == "slepe mode" then
			return "slepe first"
		end
		return behavior .. " first"
	elseif priority == "last" then
		if behavior == "slepe mode" then
			return "slepe last"
		end
		return behavior .. " last"
	end

	return behavior
end

function GetTargetBehavior(id)
	local tactic = GetMonsterTactic(id)
	if tactic ~= nil then
		local legacyBehavior, legacyPriority = SplitLegacyBehaviorAndPriority(tactic.Behavior)
		local behavior = NormalizeTacticBaseBehavior(tactic.Behavior)
		local priority = ParseTacticPriorityValue(tactic.Priority)
		if behavior == "" then
			behavior = legacyBehavior
		end
		if priority == "" then
			priority = legacyPriority
		end
		if behavior ~= "" then
			return NormalizeBehaviorForHomunculus(CombineTacticBehaviorAndPriority(behavior, priority))
		end
	end

	return NormalizeBehaviorForHomunculus(string.lower(tostring(GetBehaviorMode() or "Slepe Mode")))
end

function NormalizeBehaviorForHomunculus(behavior)
	if IsFilir(MyID) == false then
		return behavior
	end

	if behavior == "snipe first" then
		return "attack first"
	elseif behavior == "snipe" then
		return "attack"
	elseif behavior == "snipe last" then
		return "attack last"
	end

	return behavior
end

function TargetUsesSnipeBehavior(id)
	local behavior = GetTargetBehavior(id)
	return behavior == "snipe" or behavior == "snipe first" or behavior == "snipe last"
end

function ShouldBlockNormalAttackCommand(target)
	if target == nil or target == 0 then
		return IsSnipeMode()
	end

	return TargetUsesSnipeBehavior(target)
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

	local wasAlreadyAttacked = WasAttacked(target)
	if wasAlreadyAttacked == false
		and FirstAttackKSModeEnabled()
		and IsKSContestedByOthers(target) == false then
		ClaimFirstAttack(target)
	end
	MarkAttacked(target)
	if IsTargetingOwner(target) then
		MarkProtected(target)
		if wasAlreadyAttacked == false then
			ClearAttackTarget()
			BeginOwnerProtectionHold()
		end
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

function IsCommittedToCurrentAttackTarget()
	if AttackTarget == 0 or IsValidAttackTargetForCurrentPurpose(AttackTarget) == false then
		return false
	end

	return AttackTargetHit == 1
		or WasAttacked(AttackTarget)
		or IsTargetingHomunculus(AttackTarget)
		or CurrentState == STATE_ATTACK
		or IsInAttackMotion(MyID)
		or PendingCapriceTarget == AttackTarget
end

function GetTargetPathingFailureTimeoutMs(target, distance)
	local timeoutMs = CHASE_PROGRESS_CHECK_MS
	if distance == nil or distance == -1 then
		distance = DistanceToActor(MyID, target)
	end

	if distance ~= -1 and distance <= StickyAttackRange() then
		timeoutMs = timeoutMs + 700
	end

	if IsFilir(MyID)
		and distance ~= -1
		and distance <= StationaryRepositionRange() + 1 then
		timeoutMs = timeoutMs + 900
	end

	return timeoutMs
end

function ShouldKeepNearbyTargetThroughRecovery(target, distance)
	if target == 0
		or target ~= AttackTarget
		or IsValidAttackTargetForCurrentPurpose(target) == false
		or TargetUsesAvoidBehavior(target)
		or TargetUsesKiteNoAttackBehavior(target)
		or IsKSTarget(target)
		or TargetUsesSnipeBehavior(target) then
		return false
	end

	if distance == nil or distance == -1 then
		distance = DistanceToActor(MyID, target)
	end

	if distance == -1 then
		return false
	end

	if distance <= StickyAttackRange() then
		return true
	end

	return IsFilir(MyID) and distance <= StationaryRepositionRange() + 1
end

function ShouldKeepCurrentTargetThroughRecovery(target)
	if target == 0
		or target ~= AttackTarget
		or IsFilir(MyID) == false
		or IsCommittedToCurrentAttackTarget() == false
		or IsValidAttackTargetForCurrentPurpose(target) == false
		or TargetUsesAvoidBehavior(target)
		or TargetUsesKiteNoAttackBehavior(target)
		or IsKSTarget(target) then
		return false
	end

	return true
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

function NormalizePriorityBehavior(behavior)
	if behavior == "" or behavior == "slepe mode" or behavior == "slepe" then
		return "attack"
	end

	return behavior
end

function GetBehaviorHierarchyTier(behavior)
	behavior = NormalizePriorityBehavior(behavior)

	if behavior == "react first"
		or behavior == "snipe first"
		or behavior == "slepe first"
		or behavior == "attack first" then
		return 3
	elseif behavior == "react last"
		or behavior == "snipe last"
		or behavior == "slepe last"
		or behavior == "attack last" then
		return 1
	end

	return 2
end

function GetAttackBehaviorTier(target)
	if target == 0 or IsOwnerProtectionAttackTarget(target) then
		return 4
	end

	if GetAttackBehaviorPriority(target) < 0 then
		return -1
	end

	return GetBehaviorHierarchyTier(GetTargetBehavior(target))
end

function GetAttackBehaviorPriority(target)
	local behavior = NormalizePriorityBehavior(GetTargetBehavior(target))

	if behavior == "avoid" or behavior == "snipe" or behavior == "snipe first" or behavior == "snipe last" then
		return -1
	end

	if behavior == "kite no attack" and KiteNoAttackDone[target] == 1 then
		return -1
	end

	if behavior == "react first" then
		if IsReactiveBehaviorTarget(target) then
			return 900
		end
		return -1
	elseif behavior == "slepe first" then
		return 800
	elseif behavior == "attack first" then
		return 800
	elseif behavior == "react" then
		if IsReactiveBehaviorTarget(target) then
			return 700
		end
		return -1
	elseif behavior == "react last" then
		if IsReactiveBehaviorTarget(target) then
			return 300
		end
		return -1
	elseif behavior == "slepe last" then
		return 200
	elseif behavior == "attack last" then
		return 200
	end

	return 600
end

function GetSkillBehaviorPriority(target)
	local behavior = NormalizePriorityBehavior(GetTargetBehavior(target))

	if behavior == "avoid" or behavior == "kite no attack" then
		return -1
	end

	if behavior == "kite no attack" then
		return -1
	end

	if behavior == "react first" then
		if IsReactiveBehaviorTarget(target) then
			return 900
		end
		return -1
	elseif behavior == "snipe first" then
		return 800
	elseif behavior == "slepe first" then
		return 800
	elseif behavior == "attack first" then
		return 800
	elseif behavior == "react" then
		if IsReactiveBehaviorTarget(target) then
			return 700
		end
		return -1
	elseif behavior == "snipe" then
		return 600
	elseif behavior == "react last" then
		if IsReactiveBehaviorTarget(target) then
			return 300
		end
		return -1
	elseif behavior == "snipe last" then
		return 200
	elseif behavior == "slepe last" then
		return 200
	elseif behavior == "attack last" then
		return 200
	end

	return 600
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
		return 1800 + (level * 200)
	elseif IsFilir(MyID) then
		return 200
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

function GetFilirSupportCooldownFile()
	local owner = GetV(V_OWNER, MyID)
	if owner == 0 then
		return nil
	end

	return "./AI/USER_AI/data/H_" .. tostring(owner) .. "FilirSupport.lua"
end

function PersistFilirSupportCooldowns()
	local path = GetFilirSupportCooldownFile()
	if path == nil then
		return
	end

	local file = io.open(path, "w")
	if file == nil then
		return
	end

	file:write("FilirSupportCooldowns={NextFlittingAt=" .. tostring(NextFlittingAt)
		.. ",NextAcceleratedFlightAt=" .. tostring(NextAcceleratedFlightAt) .. "}\n")
	file:close()
end

function UsePersistedFilirSupportTime(value)
	local now = GetTick()
	local readyAt = tonumber(value) or 0
	if readyAt <= now or readyAt > now + FILIR_SUPPORT_MAX_PERSIST_MS then
		return 0
	end

	return readyAt
end

function LoadFilirSupportCooldowns()
	if FilirSupportCooldownsLoaded then
		return
	end

	FilirSupportCooldownsLoaded = true
	if IsFilir(MyID) == false then
		return
	end

	local path = GetFilirSupportCooldownFile()
	if path == nil then
		return
	end

	local chunk = loadfile(path)
	if chunk == nil then
		return
	end

	local env = {}
	setfenv(chunk, env)
	local ok = pcall(chunk)
	if ok == false or type(env.FilirSupportCooldowns) ~= "table" then
		return
	end

	NextFlittingAt = UsePersistedFilirSupportTime(env.FilirSupportCooldowns.NextFlittingAt)
	NextAcceleratedFlightAt = UsePersistedFilirSupportTime(env.FilirSupportCooldowns.NextAcceleratedFlightAt)
end

function SetNextFilirSupportAttempt(skillName, readyAt)
	if skillName == "Flitting" then
		NextFlittingAt = readyAt
	elseif skillName == "AcceleratedFlight" then
		NextAcceleratedFlightAt = readyAt
	end

	PersistFilirSupportCooldowns()
end

function ClearPendingFilirSupport()
	PendingFilirSupportAt = 0
	PendingFilirSupportSP = 0
	PendingFilirSupportName = ""
	PendingFilirSupportCost = 0
	PendingFilirSupportDelayMs = 0
end

function HasPendingFilirSupport()
	return PendingFilirSupportAt ~= 0
end

function UpdateFilirSupportAttemptState()
	if PendingFilirSupportAt == 0 then
		return
	end

	local sp = GetV(V_SP, MyID)
	if PendingFilirSupportSP - sp >= PendingFilirSupportCost then
		local readyAt = PendingFilirSupportAt + PendingFilirSupportDelayMs
		SetNextFilirSupportAttempt(PendingFilirSupportName, readyAt)
		ClearPendingFilirSupport()
		return
	end

	if GetTick() - PendingFilirSupportAt >= FILIR_SUPPORT_CONFIRM_TIMEOUT_MS then
		SetNextFilirSupportAttempt(PendingFilirSupportName, GetTick() + FILIR_SUPPORT_RETRY_MS)
		ClearPendingFilirSupport()
	end
end

function GetConfirmedSkillCastCount(id)
	return SkillCastCount[id] or 0
end

function CleanupSkillCastReservations(id)
	if id == 0 or SkillCastReservations[id] == nil then
		return
	end

	local now = GetTick()
	local kept = {}
	for _, expiresAt in ipairs(SkillCastReservations[id]) do
		if expiresAt > now then
			table.insert(kept, expiresAt)
		end
	end

	if #kept == 0 then
		SkillCastReservations[id] = nil
	else
		SkillCastReservations[id] = kept
	end
end

function GetReservedSkillCastCount(id)
	CleanupSkillCastReservations(id)
	if SkillCastReservations[id] == nil then
		return 0
	end

	return #SkillCastReservations[id]
end

function GetSkillCastCount(id)
	return GetConfirmedSkillCastCount(id) + GetReservedSkillCastCount(id)
end

function GetSkillCastCountByClass(id)
	local class = MonsterClass(id)
	return SkillCastCountByClass[class] or 0
end

function ReserveSkillCast(id)
	if id == 0 then
		return
	end

	CleanupSkillCastReservations(id)
	if SkillCastReservations[id] == nil then
		SkillCastReservations[id] = {}
	end

	-- Short guard against rapid duplicate SkillObject calls while the server catches up.
	table.insert(SkillCastReservations[id], GetTick() + SKILL_RESERVATION_MS)
end

function ClearSkillCastReservations(id)
	if id ~= 0 then
		SkillCastReservations[id] = nil
	end
end

function LatchOneSkillAttempt(id)
	if id ~= 0 and GetTargetSkillCount(id) == 1 then
		OneSkillAttemptLatch[id] = GetTick() + ONE_SKILL_ATTEMPT_LOCK_MS
	end
end

function ClearOneSkillAttemptLatch(id)
	if id ~= 0 then
		OneSkillAttemptLatch[id] = nil
	end
end

function HasOneSkillAttemptLatch(id)
	if id == 0 or OneSkillAttemptLatch[id] == nil then
		return false
	end

	if OneSkillAttemptLatch[id] <= GetTick() then
		OneSkillAttemptLatch[id] = nil
		return false
	end

	return true
end

function ConsumeSkillCastReservation(id)
	if id == 0 or SkillCastReservations[id] == nil then
		return
	end

	table.remove(SkillCastReservations[id], 1)
	if #SkillCastReservations[id] == 0 then
		SkillCastReservations[id] = nil
	end
end

function MarkSkillCast(id)
	if id ~= 0 then
		ConsumeSkillCastReservation(id)
		ClearOneSkillAttemptLatch(id)
		SkillCastCount[id] = GetConfirmedSkillCastCount(id) + 1
		local class = MonsterClass(id)
		SkillCastCountByClass[class] = GetSkillCastCountByClass(id) + 1
	end
end

function SlepeModeDisallowsSkillAfterAttack(id)
	return UsesSlepeCurrentTargetSkillRule(id) and WasAttacked(id)
end

function TargetHasPendingSkillAttempt(id)
	return GetReservedSkillCastCount(id) > 0
end

function TargetAllowsSkill(id, allowSlepeAfterAttack)
	if TargetUsesKiteNoAttackBehavior(id) then
		return false
	end

	local skillCount = GetTargetSkillCount(id)
	if skillCount <= 0 then
		return false
	end

	if TargetHasPendingSkillAttempt(id) then
		return false
	end

	if skillCount == 1 and HasOneSkillAttemptLatch(id) then
		return false
	end

	if allowSlepeAfterAttack ~= true
		and SlepeModeDisallowsSkillAfterAttack(id)
		and HasTacticRepeatSkillMode(id) == false then
		return false
	end

	return GetSkillCastCount(id) < skillCount
end

function HasTacticRepeatSkillMode(id)
	local tactic = GetMonsterTactic(id)
	if tactic == nil then
		return false
	end

	return NormalizeSkillCountValue(tactic.Skill) >= 2
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

	local skillCount = GetTargetSkillCount(id)
	if skillCount <= 0 then
		return false
	end

	if TargetHasPendingSkillAttempt(id) then
		return false
	end

	if skillCount == 1 and HasOneSkillAttemptLatch(id) then
		return false
	end

	if HasTacticRepeatSkillMode(id) then
		return GetSkillCastCount(id) < skillCount
	end

	if WasAttacked(id) then
		return false
	end

	return GetSkillCastCount(id) < skillCount
end

function UsesSlepeCurrentTargetSkillRule(id)
	local behavior = GetTargetBehavior(id)
	if behavior == "slepe mode" or behavior == "slepe first" or behavior == "slepe last" then
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

function ShouldUseSlepeChaseOpenerSkill(id)
	return id ~= 0
		and id == AttackTarget
		and CurrentState == STATE_CHASE_ATTACK
		and AttackTargetHit == 0
		and UsesSlepeCurrentTargetSkillRule(id)
		and WasAttacked(id) == false
end

function ShouldForceVanilSlepeSideTarget()
	return IsFilir(MyID) == false
		and AttackTarget ~= 0
		and UsesSlepeCurrentTargetSkillRule(AttackTarget)
end

function IsCurrentTargetLockedForSkills(id)
	return id ~= 0
		and id == AttackTarget
		and UsesSlepeCurrentTargetSkillRule(id) == false
end

function IsCurrentAttackTargetValidForSkill(skillID)
	return AttackTarget ~= 0
		and IsValidTarget(AttackTarget)
		and IsIgnoredTarget(AttackTarget) == false
		and IsKSTarget(AttackTarget) == false
		and IsTargetInActiveRange(AttackTarget)
		and TargetUsesAvoidBehavior(AttackTarget) == false
		and OffensiveSkillInRange(AttackTarget, skillID, GetTargetSkillLevel(AttackTarget))
end

function HandlePostSkillPrimaryTarget(target, ignoreTarget)
	if ignoreTarget == true then
		IgnorePrimarySkillTarget(target)
		ClearAttackTarget()
	end
	BeginPostSkillWait()
end

function ShouldPauseAfterPrimarySkillAttempt(castTarget)
	if IsVanilmirth(MyID) == false then
		return false
	end

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
	if ShouldKeepCurrentTargetThroughRecovery(target) then
		IgnoreTargetUntil[target] = nil
		ResetPathingProbe()
		NextChaseRepathAt = 0
		CurrentState = STATE_CHASE_ATTACK
		return
	end

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
		local lastX = LastSeenPosX[id]
		local lastY = LastSeenPosY[id]
		if Breadcrumb1X[id] == nil then
			Breadcrumb1X[id] = x
			Breadcrumb1Y[id] = y
		elseif lastX ~= nil
			and lastY ~= nil
			and (x ~= lastX or y ~= lastY)
			and Distance(x, y, Breadcrumb1X[id], Breadcrumb1Y[id]) >= SIGHT_BREADCRUMB_DISTANCE then
			Breadcrumb3X[id] = Breadcrumb2X[id]
			Breadcrumb3Y[id] = Breadcrumb2Y[id]
			Breadcrumb2X[id] = Breadcrumb1X[id]
			Breadcrumb2Y[id] = Breadcrumb1Y[id]
			Breadcrumb1X[id] = x
			Breadcrumb1Y[id] = y
		end

		LastSeenPosX[id] = x
		LastSeenPosY[id] = y
	end
end

function GetActorBacktrackPosition(id, minDistanceFromMe)
	if id == 0 then
		return -1, -1
	end

	local myX, myY = GetV(V_POSITION, MyID)
	local minimum = minDistanceFromMe or 0
	local candidates = {
		{ Breadcrumb3X[id], Breadcrumb3Y[id] },
		{ Breadcrumb2X[id], Breadcrumb2Y[id] },
		{ Breadcrumb1X[id], Breadcrumb1Y[id] },
		{ LastSeenPosX[id], LastSeenPosY[id] }
	}

	for _, candidate in ipairs(candidates) do
		local x, y = candidate[1], candidate[2]
		if x ~= nil and y ~= nil then
			if minimum <= 0
				or myX == -1
				or myY == -1
				or Distance(myX, myY, x, y) >= minimum then
				return x, y
			end
		end
	end

	return -1, -1
end

function GetKnownActorPosition(id)
	if id == 0 then
		return -1, -1
	end

	local x, y = GetV(V_POSITION, id)
	if x ~= -1 and y ~= -1 then
		return x, y
	end

	x = LastSeenPosX[id]
	y = LastSeenPosY[id]
	if x ~= nil and y ~= nil then
		return x, y
	end

	return -1, -1
end

function GetKnownOwnerPosition()
	return GetKnownActorPosition(GetV(V_OWNER, MyID))
end

function GetRecoveryCellToward(targetX, targetY, stepDistance)
	local myX, myY = GetV(V_POSITION, MyID)
	if myX == -1 or myY == -1 or targetX == -1 or targetY == -1 then
		return -1, -1
	end

	local deltaX = targetX - myX
	local deltaY = targetY - myY
	local stepX = Sign(deltaX)
	local stepY = Sign(deltaY)
	local maxDistance = math.max(math.abs(deltaX), math.abs(deltaY))
	local step = math.min(stepDistance or SIGHT_RECOVERY_STEP_CELLS, maxDistance)
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
		{ myX + stepX, myY + stepY },
		{ targetX, targetY }
	}

	for _, candidate in ipairs(candidates) do
		local candidateX, candidateY = ClampMoveDestination(candidate[1], candidate[2])
		if candidateX ~= -1 and candidateY ~= -1 and (candidateX ~= myX or candidateY ~= myY) then
			return candidateX, candidateY
		end
	end

	return -1, -1
end

function GetSightSearchCell()
	local myX, myY = GetV(V_POSITION, MyID)
	if myX == -1 or myY == -1 then
		return -1, -1
	end

	local offsets = {
		{ 1, 0 }, { 1, 1 }, { 0, 1 }, { -1, 1 },
		{ -1, 0 }, { -1, -1 }, { 0, -1 }, { 1, -1 }
	}
	local offset = offsets[((SightRecoveryStep - 1) % 8) + 1]
	SightRecoveryStep = (SightRecoveryStep % 8) + 1
	return ClampMoveDestination(myX + (offset[1] * 3), myY + (offset[2] * 3))
end

function TryRecoverVisibilityToward(targetX, targetY, preferBacktrack)
	if GetTick() < NextSightRecoveryAt and GetV(V_MOTION, MyID) == MOTION_MOVE then
		return true
	end

	local moveX, moveY = -1, -1
	if preferBacktrack == true then
		moveX, moveY = GetActorBacktrackPosition(MyID, SIGHT_BACKTRACK_MIN_DISTANCE)
	end

	if moveX == -1 or moveY == -1 then
		moveX, moveY = GetRecoveryCellToward(targetX, targetY, SIGHT_RECOVERY_STEP_CELLS)
	end
	if moveX == -1 or moveY == -1 then
		moveX, moveY = GetSightSearchCell()
	end

	if moveX == -1 or moveY == -1 then
		return false
	end

	ForceMoveTo(moveX, moveY)
	NextSightRecoveryAt = GetTick() + SIGHT_RECOVERY_REISSUE_MS
	CurrentState = STATE_FOLLOW
	return true
end

function TryRecoverLostTargetSight(target)
	local backtrackX, backtrackY = GetActorBacktrackPosition(MyID, SIGHT_BACKTRACK_MIN_DISTANCE)
	if backtrackX ~= -1 and backtrackY ~= -1 and TryRecoverVisibilityToward(backtrackX, backtrackY, false) then
		return true
	end

	local targetX, targetY = GetActorBacktrackPosition(target, 0)
	if targetX ~= -1 and targetY ~= -1 and TryRecoverVisibilityToward(targetX, targetY, false) then
		return true
	end

	targetX, targetY = GetKnownActorPosition(target)
	if targetX ~= -1 and targetY ~= -1 and TryRecoverVisibilityToward(targetX, targetY, false) then
		return true
	end

	local owner = GetV(V_OWNER, MyID)
	local ownerX, ownerY = GetActorBacktrackPosition(owner, 0)
	if ownerX ~= -1 and ownerY ~= -1 and TryRecoverVisibilityToward(ownerX, ownerY, false) then
		return true
	end

	ownerX, ownerY = GetKnownOwnerPosition()
	return TryRecoverVisibilityToward(ownerX, ownerY, false)
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
	local ownerX, ownerY = GetKnownActorPosition(owner)
	if ownerX == -1 or ownerY == -1 then
		return GetSightSearchCell()
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
	local ownerX, ownerY = GetKnownOwnerPosition()
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
	local ownerX, ownerY = GetKnownActorPosition(owner)
	local myX, myY = GetV(V_POSITION, MyID)
	if ownerX == -1 or ownerY == -1 or myX == -1 or myY == -1 then
		return GetSightSearchCell()
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

	if HasPendingFilirSupport() then
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

	local spBefore = GetV(V_SP, MyID)
	SkillObject(MyID, level, skillID, MyID)

	PendingFilirSupportAt = GetTick()
	PendingFilirSupportSP = spBefore
	PendingFilirSupportName = skillName
	PendingFilirSupportCost = spCost
	PendingFilirSupportDelayMs = GetFilirSupportDelayMs(skillName, level)
	SetNextFilirSupportAttempt(skillName, PendingFilirSupportAt + FILIR_SUPPORT_RETRY_MS)
	return MyID
end

function TryCastFilirSupportSkills()
	local supportTarget = TryCastFilirSupportSkill("AcceleratedFlight", ACCELERATED_FLIGHT_SKILL)
	if supportTarget ~= 0 then
		return supportTarget
	end

	return TryCastFilirSupportSkill("Flitting", FLITTING_SKILL)
end

function HandleFilirBuffPriority()
	if HasPendingFilirSupport() then
		return false
	end

	local supportTarget = TryCastFilirSupportSkills()
	if supportTarget == 0 then
		return false
	end

	CancelSoftStandbyReset()
	return true
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

function OffensiveSkillInRange(target, skillID, level)
	if target == 0 or skillID == 0 then
		return false
	end

	if IsFilir(MyID) and skillID == MOONLIGHT_SKILL then
		local distance = DistanceToActor(MyID, target)
		return distance == 1
	end

	return InSkillRange(MyID, target, skillID, level)
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

	if OffensiveSkillInRange(manualTarget, GetOffensiveSkillID(), GetManualCapriceLevel(manualTarget)) then
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

function GetVanilSongProviders(kind)
	if kind == "Bragi" then
		return VanilBragiProviders
	end

	return VanilServiceProviders
end

function GetVanilCurrentSongProvider(kind)
	if kind == "Bragi" then
		return VanilCurrentBragiProvider
	end

	return VanilCurrentServiceProvider
end

function SetVanilCurrentSongProvider(kind, provider)
	if kind == "Bragi" then
		VanilCurrentBragiProvider = provider
	else
		VanilCurrentServiceProvider = provider
	end
end

function GetVanilSongBuffUntil(kind)
	if kind == "Bragi" then
		return VanilBragiBuffUntil
	end

	return VanilServiceBuffUntil
end

function SetVanilSongBuffUntil(kind, value)
	if kind == "Bragi" then
		VanilBragiBuffUntil = value
	else
		VanilServiceBuffUntil = value
	end
end

function VanilNeedsSongBuff(kind)
	return GetVanilSongBuffUntil(kind) <= GetTick()
end

function ResetVanilSongSeekIfTarget(target)
	if VanilSongSeekingTarget == target then
		VanilSongSeekingKind = ""
		VanilSongSeekingTarget = 0
		VanilSongMoveX = 0
		VanilSongMoveY = 0
		VanilSongNextMoveAt = 0
	end
end

function UpdateVanilSongBuffTimers()
	local now = GetTick()
	if VanilBragiBuffUntil ~= 0 and now >= VanilBragiBuffUntil then
		VanilBragiBuffUntil = 0
	end

	if VanilServiceBuffUntil ~= 0 and now >= VanilServiceBuffUntil then
		VanilServiceBuffUntil = 0
	end
end

function CleanupVanilSongProviders(kind)
	local providers = GetVanilSongProviders(kind)
	local now = GetTick()
	for provider, info in pairs(providers) do
		local x, y = GetV(V_POSITION, provider)
		if x == -1 or y == -1 or tonumber(info.songEndTime or 0) <= now then
			providers[provider] = nil
			if GetVanilCurrentSongProvider(kind) == provider then
				SetVanilCurrentSongProvider(kind, 0)
			end
			ResetVanilSongSeekIfTarget(provider)
		end
	end
end

function RememberVanilSongProvider(kind, actor)
	local x, y = GetV(V_POSITION, actor)
	if x == -1 or y == -1 then
		return
	end

	local providers = GetVanilSongProviders(kind)
	if providers[actor] == nil then
		providers[actor] = {}
	end

	providers[actor].lastSeen = GetTick()
	providers[actor].songEndTime = GetTick() + VANIL_SONG_PROVIDER_ACTIVE_MS
end

function ScanVanilSongProviders()
	CleanupVanilSongProviders("Bragi")
	CleanupVanilSongProviders("Service")

	local owner = GetV(V_OWNER, MyID)
	local actors = GetActors()
	for _, actor in ipairs(actors) do
		if actor ~= MyID and actor ~= owner and IsMonster(actor) ~= 1 then
			local motion = GetV(V_MOTION, actor)
			if motion == MOTION_PERFORM then
				RememberVanilSongProvider("Bragi", actor)
			elseif motion == MOTION_DANCE then
				RememberVanilSongProvider("Service", actor)
			end
		end
	end
end

function IsVanilSongProviderVisible(provider, info)
	local x, y = GetV(V_POSITION, provider)
	if x == -1 or y == -1 then
		return false
	end

	if tonumber(info.songEndTime or 0) <= GetTick() then
		return false
	end

	local distance = DistanceToActor(MyID, provider)
	return distance ~= -1 and distance <= VANIL_SONG_SEARCH_RANGE
end

function FindVanilSongProvider(kind)
	local providers = GetVanilSongProviders(kind)
	local currentProvider = GetVanilCurrentSongProvider(kind)
	if currentProvider ~= 0
		and providers[currentProvider] ~= nil
		and IsVanilSongProviderVisible(currentProvider, providers[currentProvider]) then
		return currentProvider
	end

	local bestProvider = 0
	local bestDistance = 999
	for provider, info in pairs(providers) do
		if IsVanilSongProviderVisible(provider, info) then
			local distance = DistanceToActor(MyID, provider)
			if distance ~= -1 and distance < bestDistance then
				bestProvider = provider
				bestDistance = distance
			end
		end
	end

	return bestProvider
end

function FindNeededVanilSongProvider()
	if VanilNeedsSongBuff("Bragi") then
		local provider = FindVanilSongProvider("Bragi")
		if provider ~= 0 then
			return "Bragi", provider
		end
	end

	if VanilNeedsSongBuff("Service") then
		local provider = FindVanilSongProvider("Service")
		if provider ~= 0 then
			return "Service", provider
		end
	end

	return "", 0
end

function MarkVanilSongBuff(kind, provider)
	SetVanilSongBuffUntil(kind, GetTick() + VANIL_SONG_BUFF_DURATION_MS)
	SetVanilCurrentSongProvider(kind, provider)
	ResetVanilSongSeekIfTarget(provider)

	local providers = GetVanilSongProviders(kind)
	if providers[provider] == nil then
		providers[provider] = {}
	end
	providers[provider].lastBuffed = GetTick()
	providers[provider].songEndTime = GetTick() + VANIL_SONG_PROVIDER_ACTIVE_MS
end

function GetVanilSongApproachCell(provider)
	local myX, myY = GetV(V_POSITION, MyID)
	local songX, songY = GetV(V_POSITION, provider)
	if myX == -1 or songX == -1 then
		return -1, -1
	end

	local bestX, bestY = -1, -1
	local bestDistance = 999
	for dx = -VANIL_SONG_BUFF_RANGE, VANIL_SONG_BUFF_RANGE do
		for dy = -VANIL_SONG_BUFF_RANGE, VANIL_SONG_BUFF_RANGE do
			local candidateX = songX + dx
			local candidateY = songY + dy
			if Distance(candidateX, candidateY, songX, songY) <= VANIL_SONG_BUFF_RANGE
				and (candidateX ~= songX or candidateY ~= songY)
				and IsCellOccupiedByOther(candidateX, candidateY, 0) == false then
				local candidateDistance = Distance(myX, myY, candidateX, candidateY)
				if candidateDistance ~= -1 and candidateDistance < bestDistance then
					bestX = candidateX
					bestY = candidateY
					bestDistance = candidateDistance
				end
			end
		end
	end

	if bestX ~= -1 then
		return bestX, bestY
	end

	local adjacentX, adjacentY, adjacentDistance = GetNearestOpenAdjacentPoint(songX, songY, provider)
	if adjacentDistance ~= 999 then
		return adjacentX, adjacentY
	end

	return myX, myY
end

function HandleVanilSongPriority()
	if IsVanilmirth(MyID) == false then
		return false
	end

	UpdateVanilSongBuffTimers()
	ScanVanilSongProviders()

	local kind, provider = FindNeededVanilSongProvider()
	if provider == 0 then
		VanilSongSeekingKind = ""
		VanilSongSeekingTarget = 0
		return false
	end

	CancelSoftStandbyReset()
	CancelPostSkillWait()
	ClearAttackTarget()

	local distance = DistanceToActor(MyID, provider)
	if distance ~= -1 and distance <= VANIL_SONG_BUFF_RANGE then
		MarkVanilSongBuff(kind, provider)
		CurrentState = STATE_IDLE
		return true
	end

	local nextX, nextY = GetVanilSongApproachCell(provider)
	if nextX ~= -1 and nextY ~= -1 then
		local myX, myY = GetV(V_POSITION, MyID)
		if nextX == myX and nextY == myY and (distance == -1 or distance > VANIL_SONG_BUFF_RANGE) then
			return false
		end

		if GetTick() >= VanilSongNextMoveAt
			or VanilSongSeekingTarget ~= provider
			or VanilSongMoveX ~= nextX
			or VanilSongMoveY ~= nextY
			or GetV(V_MOTION, MyID) ~= MOTION_MOVE then
			ForceMoveTo(nextX, nextY)
			VanilSongMoveX = nextX
			VanilSongMoveY = nextY
			VanilSongNextMoveAt = GetTick() + VANIL_SONG_REPATH_MS
		end

		VanilSongSeekingKind = kind
		VanilSongSeekingTarget = provider
		CurrentState = STATE_MOVE
	end

	return true
end

function UpdateCapriceAttemptState()
	if PendingCapriceAt == 0 then
		return
	end

	local sp = GetV(V_SP, MyID)
	if PendingCapriceSP - sp >= PendingCapriceCost then
		local confirmedCasts = 1
		if PendingCapriceCost > 0 then
			confirmedCasts = math.floor((PendingCapriceSP - sp) / PendingCapriceCost)
			if confirmedCasts < 1 then
				confirmedCasts = 1
			end
		end
		local reservedCasts = GetReservedSkillCastCount(PendingCapriceTarget)
		if reservedCasts > 0 and confirmedCasts > reservedCasts then
			confirmedCasts = reservedCasts
		end
		for i = 1, confirmedCasts do
			MarkSkillCast(PendingCapriceTarget)
		end
		ClearSkillCastReservations(PendingCapriceTarget)
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

function ClearPendingOffensiveSkillAttempt()
	PendingCapriceAt = 0
	PendingCapriceSP = 0
	PendingCapriceTarget = 0
	PendingCapriceCost = 0
	PendingCapriceDelayMs = 0
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

	local ownerX, ownerY = GetKnownOwnerPosition()
	if ownerX == -1 or ownerY == -1 then
		return GetSightSearchCell()
	end

	return ownerX, ownerY
end

function GetPatrolCenter()
	if AnchorEnabled == 1 then
		return AnchorX, AnchorY
	end

	return GetKnownOwnerPosition()
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
	if MoveX == -1 or MoveY == -1 then
		MoveX, MoveY = GetSightSearchCell()
	end
	if MoveX == -1 or MoveY == -1 then
		return
	end
	MoveSmart(MoveX, MoveY)
	CurrentState = STATE_FOLLOW
end

function ForceFollow(forceRecovery)
	MoveX, MoveY = GetFollowDestination(forceRecovery == true or forceRecovery == 1)
	if MoveX == -1 or MoveY == -1 then
		MoveX, MoveY = GetSightSearchCell()
	end
	if MoveX == -1 or MoveY == -1 then
		return
	end
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

	AcquireAttackTarget()
	if AttackTarget ~= 0 then
		return EngageFreshAttackTarget(0)
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

	if AttackTarget ~= 0
		and IsValidAttackTargetForCurrentPurpose(AttackTarget)
		and (CurrentState == STATE_ATTACK or CurrentState == STATE_CHASE_ATTACK or IsInAttackMotion(MyID)) then
		OwnerStandSince = 0
		return false
	end

	if HasActiveSnipeWork() then
		OwnerStandSince = 0
		return false
	end

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
			EngageFreshAttackTarget(0)
			CancelSoftStandbyReset()
			return true
		end
	end

	if GetTick() < StandbyResetReadyAt then
		return false
	end

	AcquireAttackTarget()
	if AttackTarget ~= 0 then
		EngageFreshAttackTarget(0)
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

	if AttackTarget ~= target then
		ClearStickyAttackApproach()
	end

	CancelPostSkillWait()
	AttackTarget = target
	AttackTargetHit = 0
	StartPathingProbe(target)
	NextChaseRepathAt = 0
	NextAttackCommandAt = 0
	NextAttackRefreshMoveAt = 0
	AttackTargetCommittedUntil = GetTick() + ATTACK_TARGET_COMMIT_MS
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
			and IsOutOfSight(MyID, actor) == false
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
			and OffensiveSkillInRange(actor, skillID, GetTargetSkillLevel(actor)) then
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

function FindSnipeMonsterInSkillRange(excludedTarget)
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
			and TargetUsesSnipeBehavior(actor)
			and IsTargetInActiveRange(actor)
			and OffensiveSkillInRange(actor, skillID, GetTargetSkillLevel(actor)) then
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

function HasSnipeTargetInView(taggedOnly)
	local pendingTarget = GetPendingCapriceRetryTarget()
	if pendingTarget ~= 0 and (taggedOnly == false or TargetUsesSnipeBehavior(pendingTarget)) then
		return true
	end

	if taggedOnly == false and FindMonsterInSkillRange(0) ~= 0 then
		return true
	end

	return FindMonsterForSnipe(0, taggedOnly) ~= 0
end

function HasActiveSnipeWork()
	local snipeTarget = FindMonsterForSnipe(0, true)
	return SkillTargetCanPreemptAttackWork(snipeTarget)
end

function IsValidSnipeSkillTarget(target, skillID)
	return target ~= 0
		and IsValidTarget(target)
		and IsIgnoredTarget(target) == false
		and IsKSTarget(target) == false
		and TargetUsesSnipeBehavior(target)
		and IsTargetInActiveRange(target)
		and TargetAllowsSkill(target)
		and OffensiveSkillInRange(target, skillID, GetTargetSkillLevel(target))
end

function SkillTargetBeats(candidate, current)
	if candidate == 0 then
		return false
	end

	if current == 0 then
		return true
	end

	local candidatePriority = GetSkillBehaviorPriority(candidate)
	local currentPriority = GetSkillBehaviorPriority(current)
	if candidatePriority > currentPriority then
		return true
	elseif candidatePriority < currentPriority then
		return false
	end

	local candidateDistance = DistanceToActor(MyID, candidate)
	local currentDistance = DistanceToActor(MyID, current)
	return candidateDistance ~= -1 and (currentDistance == -1 or candidateDistance < currentDistance)
end

function SnipeTargetBeats(candidate, current)
	return SkillTargetBeats(candidate, current)
end

function SkillTargetCanPreemptAttackWork(skillTarget)
	if skillTarget == 0 then
		return false
	end

	local skillPriority = GetSkillBehaviorPriority(skillTarget)
	if skillPriority < 0 then
		return false
	end

	local attackTarget = FindMonsterTarget(0)
	if attackTarget == 0 or attackTarget == skillTarget then
		return true
	end

	local attackPriority = GetAttackBehaviorPriority(attackTarget)
	if attackPriority < 0 then
		return true
	end

	if skillPriority > attackPriority then
		return true
	elseif skillPriority < attackPriority then
		return false
	end

	local skillDistance = DistanceToActor(MyID, skillTarget)
	local attackDistance = DistanceToActor(MyID, attackTarget)
	return skillDistance ~= -1 and (attackDistance == -1 or skillDistance <= attackDistance)
end

function IssueOffensiveSkillOnTarget(skillTarget, skillLevel)
	local skillID = GetOffensiveSkillID()
	if skillTarget == 0 or skillID == 0 then
		return 0
	end

	local skillCost = GetOffensiveSkillSPCost(skillLevel)
	if HasEnoughSPForOffensiveSkill(skillLevel) == false then
		return 0
	end

	if OffensiveSkillInRange(skillTarget, skillID, skillLevel) == false then
		return 0
	end

	local spBefore = GetV(V_SP, MyID)
	SkillObject(MyID, skillLevel, skillID, skillTarget)
	if IsFilir(MyID) then
		MarkSkillCast(skillTarget)
		NextCapriceAt = GetTick() + GetOffensiveSkillDelayMs(skillLevel)
		NextCapriceTryAt = NextCapriceAt
		LastSkillTarget = skillTarget
		if skillTarget == ManualCapriceTarget then
			ClearManualCapriceTarget()
		end
		ClearPendingOffensiveSkillAttempt()
		return skillTarget
	else
		LatchOneSkillAttempt(skillTarget)
		ReserveSkillCast(skillTarget)
		NextCapriceTryAt = GetTick() + CAPRICE_RETRY_MS
	end
	if PendingCapriceAt == 0 or PendingCapriceTarget ~= skillTarget then
		PendingCapriceAt = GetTick()
		PendingCapriceSP = spBefore
		PendingCapriceTarget = skillTarget
		PendingCapriceCost = skillCost
		PendingCapriceDelayMs = GetOffensiveSkillDelayMs(skillLevel)
	end

	return skillTarget
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
	elseif not SkillReady() then
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
		if OffensiveSkillInRange(manualTarget, skillID, GetManualCapriceLevel(manualTarget)) == false then
			return 0
		end
		skillTarget = manualTarget
	end

	if manualTarget == 0
		and IsCurrentTargetLockedForSkills(AttackTarget) then
		if IsCurrentAttackTargetValidForSkill(skillID)
			and TargetAllowsSkill(AttackTarget, true) then
			skillTarget = AttackTarget
		else
			return 0
		end
	end

	if manualTarget == 0 and IsCurrentTargetLockedForSkills(AttackTarget) == false then
		local forceVanilSlepeSideTarget = ShouldForceVanilSlepeSideTarget()
		local sideTarget = FindMonsterInSkillRange(excludedTarget)
		if SkillTargetBeats(sideTarget, skillTarget) then
			skillTarget = sideTarget
		end

		local currentTarget = 0
		if forceVanilSlepeSideTarget == false
			and AttackTarget ~= 0
			and IsValidTarget(AttackTarget)
			and IsIgnoredTarget(AttackTarget) == false
			and IsKSTarget(AttackTarget) == false
			and IsTargetInActiveRange(AttackTarget)
			and TargetUsesAvoidBehavior(AttackTarget) == false
			and OffensiveSkillInRange(AttackTarget, skillID, GetTargetSkillLevel(AttackTarget)) then
			if ShouldUseSlepeChaseOpenerSkill(AttackTarget) and TargetAllowsSkill(AttackTarget) then
				currentTarget = AttackTarget
			elseif IsFilir(MyID) and TargetAllowsSkill(AttackTarget, UsesSlepeCurrentTargetSkillRule(AttackTarget) == false) then
				currentTarget = AttackTarget
			elseif excludedTarget ~= AttackTarget and PrefersCurrentTargetForSkill(AttackTarget) and TargetAllowsSkill(AttackTarget) then
				currentTarget = AttackTarget
			elseif excludedTarget == AttackTarget and AllowsSlepeCurrentTargetFallbackSkill(AttackTarget) and TargetAllowsSlepeCurrentTargetFallbackSkill(AttackTarget) then
				currentTarget = AttackTarget
			end
		end
		if SkillTargetBeats(currentTarget, skillTarget) then
			skillTarget = currentTarget
		end

		local pendingTarget = 0
		if PendingCapriceAt ~= 0 and PendingCapriceTarget ~= excludedTarget and IsValidTarget(PendingCapriceTarget) and IsIgnoredTarget(PendingCapriceTarget) == false and IsKSTarget(PendingCapriceTarget) == false
			and IsTargetInActiveRange(PendingCapriceTarget)
			and TargetAllowsSkill(PendingCapriceTarget)
			and OffensiveSkillInRange(PendingCapriceTarget, skillID, GetTargetSkillLevel(PendingCapriceTarget)) then
			pendingTarget = PendingCapriceTarget
		end
		if SkillTargetBeats(pendingTarget, skillTarget) then
			skillTarget = pendingTarget
		end
	end

	if skillTarget == 0 then
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
			and OffensiveSkillInRange(AttackTarget, skillID, GetTargetSkillLevel(AttackTarget)) then
			skillTarget = AttackTarget
		elseif skillTarget == 0 and excludedTarget == 0 then
			skillTarget = FindMonsterInSkillRange(0)
		end
	end

	if skillTarget == 0 then
		return 0
	end

	if manualTarget == 0
		and IsCurrentTargetLockedForSkills(skillTarget) == false
		and SkillTargetCanPreemptAttackWork(skillTarget) == false then
		return 0
	end

	local skillLevel = GetTargetSkillLevel(skillTarget)
	if manualTarget ~= 0 and skillTarget == manualTarget then
		skillLevel = GetManualCapriceLevel(skillTarget)
	end

	return IssueOffensiveSkillOnTarget(skillTarget, skillLevel)
end

function TryCastSnipeSkill()
	local skillID = GetOffensiveSkillID()
	if skillID == 0 then
		return 0
	end

	if not SkillReady() then
		return 0
	end

	if FindOwnerAggroTarget(0) ~= 0 then
		return 0
	end

	local skillTarget = FindMonsterForSnipe(0, true)
	if skillTarget == 0 or IsValidSnipeSkillTarget(skillTarget, skillID) == false then
		return 0
	end

	if SkillTargetCanPreemptAttackWork(skillTarget) == false then
		return 0
	end

	return IssueOffensiveSkillOnTarget(skillTarget, GetTargetSkillLevel(skillTarget))
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

function TryCastFilirContactMoonlight()
	if IsFilir(MyID) == false then
		return 0
	end

	local castTarget = TryCastCaprice()
	if castTarget == 0 then
		return 0
	end

	ResetPathingProbe()
	if ResumeFilirAttackAfterOffensiveSkill(castTarget) == 1 then
		return 1
	end

	CurrentState = STATE_ATTACK
	return 1
end

function AcquireAttackTarget(excludedTarget)
	if IsValidAttackTargetForCurrentPurpose(AttackTarget) then
		if TryPreemptLowPriorityAttackTarget() then
			return
		end

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

function TryPreemptLowPriorityAttackTarget()
	if AttackTarget == 0 or IsOwnerProtectionAttackTarget(AttackTarget) then
		return false
	end

	if GetTick() < AttackTargetCommittedUntil then
		return false
	end

	if CurrentState == STATE_ATTACK
		or AttackTargetHit == 1
		or IsInAttackMotion(MyID)
		or PendingCapriceTarget == AttackTarget then
		return false
	end

	local currentTier = GetAttackBehaviorTier(AttackTarget)
	if currentTier < 1 then
		return false
	end

	local betterTarget = FindMonsterTarget(AttackTarget)
	if betterTarget == 0 then
		return false
	end

	local betterTier = GetAttackBehaviorTier(betterTarget)
	if betterTier < currentTier then
		return false
	end

	if betterTier == currentTier then
		local currentPriority = GetAttackBehaviorPriority(AttackTarget)
		local betterPriority = GetAttackBehaviorPriority(betterTarget)
		if betterPriority < currentPriority then
			return false
		end

		if betterPriority == currentPriority then
			local currentDistance = DistanceToActor(MyID, AttackTarget)
			local betterDistance = DistanceToActor(MyID, betterTarget)
			if betterDistance == -1 then
				return false
			end

			if currentDistance ~= -1 and betterDistance >= currentDistance then
				return false
			end
		end
	end

	StartAttackChase(betterTarget)
	return true
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

	if TryCastFilirContactMoonlight() == 1 then
		return
	end

	local repathMs = CHASE_REPATH_MS
	if IsFilir(MyID) then
		repathMs = FILIR_CHASE_REPATH_MS
	elseif GetV(V_MOTION, AttackTarget) == MOTION_MOVE then
		repathMs = 150
	end

	local shouldRepath = false
	if GetV(V_MOTION, MyID) ~= MOTION_MOVE then
		shouldRepath = true
	elseif GetTick() >= NextChaseRepathAt then
		if IsFilir(MyID) then
			shouldRepath = MoveX ~= nextX or MoveY ~= nextY
		elseif Distance(MoveX, MoveY, nextX, nextY) >= CHASE_REPATH_DISTANCE then
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
	if IsFilir(MyID) then
		NextChaseRepathAt = GetTick() + FILIR_CHASE_REPATH_MS
	else
		NextChaseRepathAt = GetTick() + 150
	end
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
	if AttackTarget == 0 then
		return 0
	end

	if TargetUsesSnipeBehavior(AttackTarget) then
		return 0
	end

	if GetTick() < NextAttackCommandAt then
		return 0
	end

	local distance = DistanceToActor(MyID, AttackTarget)
	if distance == -1 or distance > StickyAttackRange() then
		return 0
	end

	if IsFilir(MyID) == false and distance > AttackRange() and IsTargetActuallyMoving(AttackTarget) == false then
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

function TryFilirAttackFallback()
	if IsFilir(MyID) == false or AttackTarget == 0 then
		return 0
	end

	if TargetUsesSnipeBehavior(AttackTarget) then
		return 0
	end

	if GetTick() + ATTACK_LATCH_GRACE_MS < NextAttackCommandAt then
		return 0
	end

	local distance = DistanceToActor(MyID, AttackTarget)
	if distance == -1 or distance > AttackRange() then
		return 0
	end

	ResetPathingProbe()
	Attack(MyID, AttackTarget)
	NextAttackCommandAt = GetTick() + ATTACK_REISSUE_MS
	AttackTargetHit = 1
	HandlePostNormalAttack(AttackTarget)
	if AttackTarget ~= 0 then
		CurrentState = STATE_ATTACK
	end
	return 1
end

function ShouldHoldFilirCloseEngage(target)
	if IsFilir(MyID) == false
		or target == 0
		or target ~= AttackTarget
		or TargetUsesSnipeBehavior(target) then
		return false
	end

	local distance = DistanceToActor(MyID, target)
	if distance == -1 or distance > StickyAttackRange() or distance <= AttackRange() then
		return false
	end

	return GetTick() < NextAttackCommandAt
end

function ShouldFilirHoldForRepeatSkill(target)
	if IsFilir(MyID) == false
		or target == 0
		or target ~= AttackTarget
		or IsValidAttackTargetForCurrentPurpose(target) == false
		or IsIgnoredTarget(target)
		or IsKSTarget(target)
		or IsTargetInActiveRange(target) == false
		or TargetUsesAvoidBehavior(target)
		or TargetUsesSnipeBehavior(target) then
		return false
	end

	local skillID = GetOffensiveSkillID()
	local skillLevel = GetTargetSkillLevel(target)
	if HasStartedFilirMoonlightChain(target) == false then
		return false
	end

	if skillID == 0
		or HasEnoughSPForOffensiveSkill(skillLevel) == false
		or OffensiveSkillInRange(target, skillID, skillLevel) == false then
		return false
	end

	return GetSkillCastCount(target) < GetTargetSkillCount(target)
end

function HasStartedFilirMoonlightChain(target)
	if IsFilir(MyID) == false or target == 0 or target ~= AttackTarget then
		return false
	end

	return GetSkillCastCount(target) > 0
end

function ShouldFilirPrioritizeRepeatSkillTarget(target)
	if IsFilir(MyID) == false
		or target == 0
		or target ~= AttackTarget
		or IsValidAttackTargetForCurrentPurpose(target) == false
		or IsIgnoredTarget(target)
		or IsKSTarget(target)
		or IsTargetInActiveRange(target) == false
		or TargetUsesAvoidBehavior(target)
		or TargetUsesSnipeBehavior(target) then
		return false
	end

	if HasStartedFilirMoonlightChain(target) == false then
		return false
	end

	if GetSkillCastCount(target) >= GetTargetSkillCount(target) then
		return false
	end

	local skillLevel = GetTargetSkillLevel(target)
	return HasEnoughSPForOffensiveSkill(skillLevel)
end

function TargetAllowsFilirImmediateRepeatSkill(id)
	if id == 0 or IsFilir(MyID) == false then
		return false
	end

	if TargetUsesKiteNoAttackBehavior(id) then
		return false
	end

	if HasStartedFilirMoonlightChain(id) == false then
		return false
	end

	return GetSkillCastCount(id) < GetTargetSkillCount(id)
end

function TryCastFilirRepeatSkillOnCurrentTarget()
	if ShouldFilirPrioritizeRepeatSkillTarget(AttackTarget) == false then
		return 0
	end

	if SkillReady() == false then
		return 0
	end

	local skillID = GetOffensiveSkillID()
	local skillLevel = GetTargetSkillLevel(AttackTarget)
	if skillID == 0
		or OffensiveSkillInRange(AttackTarget, skillID, skillLevel) == false
		or TargetAllowsFilirImmediateRepeatSkill(AttackTarget) == false then
		return 0
	end

	return IssueOffensiveSkillOnTarget(AttackTarget, skillLevel)
end

function HandleFilirRepeatSkillPriority(target)
	if ShouldFilirPrioritizeRepeatSkillTarget(target) == false then
		return 0
	end

	if TryCastFilirRepeatSkillOnCurrentTarget() ~= 0 then
		ResetPathingProbe()
		CurrentState = STATE_ATTACK
		return 1
	end

	local skillID = GetOffensiveSkillID()
	local skillLevel = GetTargetSkillLevel(target)
	local distance = DistanceToActor(MyID, target)
	if distance == -1 or skillID == 0 then
		return 0
	end

	if OffensiveSkillInRange(target, skillID, skillLevel) then
		CurrentState = STATE_ATTACK
		return 1
	end

	ForceAttackChaseMovement()
	CurrentState = STATE_CHASE_ATTACK
	return 1
end

function TryImmediateFilirCombatHandoff()
	if IsFilir(MyID) == false
		or AttackTarget == 0
		or IsValidAttackTargetForCurrentPurpose(AttackTarget) == false
		or TargetUsesSnipeBehavior(AttackTarget) then
		return 0
	end

	if HandleFilirRepeatSkillPriority(AttackTarget) == 1 then
		return 1
	end

	if TryFilirAttackFallback() == 1 then
		return 1
	end

	if TryStickyAttackCommand() == 1 then
		if AttackTarget ~= 0 then
			CurrentState = STATE_ATTACK
		end
		return 1
	end

	if ShouldHoldFilirCloseEngage(AttackTarget) then
		CurrentState = STATE_ATTACK
		return 1
	end

	ForceAttackChaseMovement()
	CurrentState = STATE_CHASE_ATTACK
	return 1
end

function RedirectAttackAfterTargetSwap(previousTarget)
	if AttackTarget == 0 or TargetUsesSnipeBehavior(AttackTarget) then
		return 0
	end

	if TryFilirAttackFallback() == 1 then
		return 1
	end

	if TryStickyAttackCommand() == 1 then
		if AttackTarget ~= 0 then
			if DistanceToActor(MyID, AttackTarget) <= AttackRange() then
				CurrentState = STATE_ATTACK
			else
				CurrentState = STATE_CHASE_ATTACK
			end
		end
		return 1
	end

	local nextX, nextY = GetAttackApproachCell(AttackTarget)
	if nextX == -1 or nextY == -1 then
		return 0
	end

	local shouldRedirect = false
	if GetV(V_MOTION, MyID) == MOTION_MOVE then
		shouldRedirect = true
	end

	if MoveX ~= nextX or MoveY ~= nextY then
		shouldRedirect = true
	end

	if previousTarget ~= 0 then
		local previousX, previousY = GetKnownActorPosition(previousTarget)
		if previousX ~= -1 and previousY ~= -1 then
			local oldMoveDistance = Distance(MoveX, MoveY, previousX, previousY)
			local newMoveDistance = Distance(MoveX, MoveY, nextX, nextY)
			if oldMoveDistance ~= -1 and oldMoveDistance <= 1 and (newMoveDistance == -1 or newMoveDistance > 1) then
				shouldRedirect = true
			end
		end
	end

	if shouldRedirect == false then
		return 0
	end

	ForceAttackChaseMovement()
	CurrentState = STATE_CHASE_ATTACK
	return 1
end

function EngageFreshAttackTarget(previousTarget)
	if AttackTarget == 0 or IsValidAttackTargetForCurrentPurpose(AttackTarget) == false then
		return false
	end

	if HandleFilirRepeatSkillPriority(AttackTarget) == 1 then
		return true
	end

	if RedirectAttackAfterTargetSwap(previousTarget) == 1 then
		return true
	end

	if TargetUsesSnipeBehavior(AttackTarget) then
		return false
	end

	local distance = DistanceToActor(MyID, AttackTarget)
	if distance ~= -1 then
		if distance <= StickyAttackRange() and TryStickyAttackCommand() == 1 then
			if distance <= AttackRange() then
				CurrentState = STATE_ATTACK
			else
				CurrentState = STATE_CHASE_ATTACK
			end
			return true
		end

		if IsFilir(MyID) == false and distance <= AttackRange() then
			ResetPathingProbe()
			Attack(MyID, AttackTarget)
			NextAttackCommandAt = GetTick() + ATTACK_REISSUE_MS
			AttackTargetHit = 1
			HandlePostNormalAttack(AttackTarget)
			if AttackTarget ~= 0 then
				CurrentState = STATE_ATTACK
			end
			return true
		end
	end

	ForceAttackChaseMovement()
	CurrentState = STATE_CHASE_ATTACK
	return true
end

function ResumeFilirAttackAfterOffensiveSkill(castTarget)
	if IsFilir(MyID) == false
		or castTarget == 0
		or AttackTarget == 0
		or castTarget ~= AttackTarget then
		return 0
	end

	if TargetUsesSnipeBehavior(AttackTarget)
		or IsValidAttackTargetForCurrentPurpose(AttackTarget) == false then
		return 0
	end

	local distance = DistanceToActor(MyID, AttackTarget)
	if distance == -1 or distance > AttackRange() then
		CurrentState = STATE_CHASE_ATTACK
		return 0
	end

	ResetPathingProbe()
	Attack(MyID, AttackTarget)
	NextAttackCommandAt = GetTick() + ATTACK_REISSUE_MS
	AttackTargetHit = 1
	HandlePostNormalAttack(AttackTarget)
	if AttackTarget ~= 0 then
		CurrentState = STATE_ATTACK
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

	if everyAttack == false and DanceMovingOnly() and IsTargetActuallyMoving(AttackTarget) == false then
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

function GetAttackApproachCellRaw(target)
	local myX, myY = GetV(V_POSITION, MyID)
	local targetX, targetY = GetV(V_POSITION, target)
	if myX == -1 or targetX == -1 then
		return myX, myY
	end

	if IsFilir(MyID) then
		return GetFilirAttackApproachCellRaw(target)
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

function GetAttackApproachCell(target)
	local nextX, nextY = GetAttackApproachCellRaw(target)
	if nextX == -1 or nextY == -1 then
		ClearStickyAttackApproach()
		return nextX, nextY
	end

	if CanReuseStickyAttackApproach(target, nextX, nextY) then
		return StickyApproachX, StickyApproachY
	end

	CacheStickyAttackApproach(target, nextX, nextY)
	return nextX, nextY
end

function GetFilirAttackApproachCellRaw(target)
	local myX, myY = GetV(V_POSITION, MyID)
	local targetX, targetY = GetV(V_POSITION, target)
	if myX == -1 or targetX == -1 then
		return myX, myY
	end

	if IsStackedOnTarget(target) == false and DistanceToActor(MyID, target) ~= -1 and DistanceToActor(MyID, target) <= AttackRange() then
		return myX, myY
	end

	if IsTargetActuallyMoving(target) == false then
		local passX, passY = GetFilirStationaryPassThroughCell(target)
		if passX ~= -1 and passY ~= -1 then
			return passX, passY
		end
	end

	local nearX, nearY = GetNearbyStationaryCell(target)
	if nearX ~= -1 and nearY ~= -1 then
		return nearX, nearY
	end

	local altX, altY = GetAlternateOpenAdjacentCell(target)
	if altX ~= -1 and altY ~= -1 then
		return altX, altY
	end

	return ResolveAttackCell(target, targetX - Sign(targetX - myX), targetY - Sign(targetY - myY))
end

function GetFilirStationaryPassThroughCell(target)
	local myX, myY = GetV(V_POSITION, MyID)
	local targetX, targetY = GetV(V_POSITION, target)
	if myX == -1 or targetX == -1 then
		return -1, -1
	end

	local stepX = Sign(targetX - myX)
	local stepY = Sign(targetY - myY)
	if stepX == 0 and stepY == 0 then
		return -1, -1
	end

	local candidates = {
		{ targetX + stepX, targetY + stepY },
		{ targetX + stepX, targetY },
		{ targetX, targetY + stepY },
		{ targetX + stepX, targetY - stepY },
		{ targetX - stepX, targetY + stepY }
	}

	for _, candidate in ipairs(candidates) do
		local candidateX = candidate[1]
		local candidateY = candidate[2]
		if (candidateX ~= targetX or candidateY ~= targetY)
			and IsOwnerCell(candidateX, candidateY) == false
			and IsCellOccupiedByOther(candidateX, candidateY, target) == false then
			return candidateX, candidateY
		end
	end

	return -1, -1
end

function GetSkillApproachCell(target)
	if IsFilir(MyID) then
		return GetAttackApproachCell(target)
	end

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
	if taggedOnly == false and FindMonsterInSkillRange(0) ~= 0 then
		return false
	end

	local snipeTarget = FindMonsterForSnipe(0, taggedOnly)
	if snipeTarget == 0 then
		return false
	end

	if SkillTargetCanPreemptAttackWork(snipeTarget) == false then
		return false
	end

	if CheckTargetPathingFailure(snipeTarget) then
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

function TryHandleSnipeBehavior(taggedOnly)
	local castTarget = TryCastSnipeSkill()
	if castTarget ~= 0 then
		ResetPathingProbe()
		ClearAttackTarget()
		CurrentState = STATE_IDLE
		return true
	end

	if TryMaintainSnipePendingTarget() then
		return true
	end

	local bestSnipeTarget = FindMonsterForSnipe(0, taggedOnly)
	if bestSnipeTarget ~= 0
		and SkillTargetCanPreemptAttackWork(bestSnipeTarget)
		and OffensiveSkillInRange(bestSnipeTarget, GetOffensiveSkillID(), GetTargetSkillLevel(bestSnipeTarget)) then
		ClearAttackTarget()
		CurrentState = STATE_IDLE
		return true
	end

	return TryApproachSnipeTarget(taggedOnly)
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

	if SkillTargetCanPreemptAttackWork(pendingTarget) == false then
		return false
	end

	local betterTarget = FindMonsterForSnipe(0, true)
	if SnipeTargetBeats(betterTarget, pendingTarget) then
		return false
	end

	if CheckTargetPathingFailure(pendingTarget) then
		return false
	end

	local nextX, nextY = GetSkillApproachCell(pendingTarget)
	if nextX == nil or nextY == nil or nextX == -1 or nextY == -1 then
		CurrentState = STATE_IDLE
		return true
	end

	if OffensiveSkillInRange(pendingTarget, GetOffensiveSkillID(), GetTargetSkillLevel(pendingTarget)) then
		CurrentState = STATE_IDLE
		return true
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
	if ShouldBlockNormalAttackCommand(target) then
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
	if msg[1] == ATTACK_OBJECT_CMD and ShouldBlockNormalAttackCommand(msg[2]) then
		return
	end

	if msg[1] == ATTACK_AREA_CMD and IsSnipeMode() then
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

	if RequireStandbyReset == 1 and HasActiveSnipeWork() then
		CancelSoftStandbyReset()
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

	if TryHandleSnipeBehavior(true) then
		return
	end

	if IsFilir(MyID) then
		AcquireAttackTarget()
		if AttackTarget ~= 0 then
			EngageFreshAttackTarget(0)
			return
		end
	end

	if TryCastConfiguredSkills() ~= 0 then
		CurrentState = STATE_IDLE
		return
	end

	AcquireAttackTarget()
	if AttackTarget ~= 0 then
		EngageFreshAttackTarget(0)
		return
	end

	EnsureIdleStandby()
end

function TickFollow()
	if RequireStandbyReset == 1 and HasActiveSnipeWork() then
		CancelSoftStandbyReset()
	end

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

	if TryHandleSnipeBehavior(true) then
		return
	end

	if IsFilir(MyID) then
		AcquireAttackTarget()
		if AttackTarget ~= 0 then
			EngageFreshAttackTarget(0)
			return
		end
	end

	if TryCastConfiguredSkills() ~= 0 then
		CurrentState = STATE_IDLE
		return
	end

	AcquireAttackTarget()
	if AttackTarget ~= 0 then
		EngageFreshAttackTarget(0)
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
	if AttackTarget ~= 0 and TargetUsesSnipeBehavior(AttackTarget) then
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

	if AttackTarget ~= 0 and IsOutOfSight(MyID, AttackTarget) then
		if TryRecoverLostTargetSight(AttackTarget) then
			return
		end
	end

	if IsValidAttackTargetForCurrentPurpose(AttackTarget) == false
		or IsOutOfSight(MyID, AttackTarget)
		or (protectionTarget == false and IsKSTarget(AttackTarget))
		or IsTargetInActiveRange(AttackTarget) == false
		or IsTargetReachableWhileTurretStaying(AttackTarget) == false then
		local oldAttackTarget = AttackTarget
		local shouldIgnoreOldAttackTarget = ShouldIgnoreDroppedTargetAfterSwap(oldAttackTarget)
		ClearAttackTarget()
		if shouldIgnoreOldAttackTarget then
			IgnoreTargetBriefly(oldAttackTarget)
		end
		AcquireAttackTarget(oldAttackTarget)
		if AttackTarget == 0 then
			CurrentState = STATE_IDLE
		elseif RedirectAttackAfterTargetSwap(oldAttackTarget) == 1 then
			return
		elseif TryImmediateFilirCombatHandoff() == 1 then
			return
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
	if castTarget ~= 0 then
		ResetPathingProbe()
		if IsFilir(MyID) then
			if ShouldFilirHoldForRepeatSkill(castTarget) then
				CurrentState = STATE_ATTACK
				return
			end
			if ResumeFilirAttackAfterOffensiveSkill(castTarget) == 1 then
				return
			end
			if TryImmediateFilirCombatHandoff() == 1 then
				return
			end

			CurrentState = STATE_ATTACK
			return
		end
	end

	if HandleFilirRepeatSkillPriority(AttackTarget) == 1 then
		return
	end

	if ShouldFilirHoldForRepeatSkill(AttackTarget) then
		return
	end

	if TryFilirAttackFallback() == 1 then
		return
	end

	local distance = DistanceToActor(MyID, AttackTarget)
	if IsFilir(MyID) == false and distance <= AttackRange() then
		ResetPathingProbe()
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

	if ShouldHoldFilirCloseEngage(AttackTarget) then
		CurrentState = STATE_ATTACK
		return
	end

	if CheckTargetPathingFailure(AttackTarget) then
		local failedTarget = AttackTarget
		HandlePathingFailureTarget(failedTarget)
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
	if AttackTarget ~= 0 and TargetUsesSnipeBehavior(AttackTarget) then
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

	if AttackTarget ~= 0 and IsOutOfSight(MyID, AttackTarget) then
		if TryRecoverLostTargetSight(AttackTarget) then
			return
		end
	end

	if IsValidAttackTargetForCurrentPurpose(AttackTarget) == false
		or IsOutOfSight(MyID, AttackTarget)
		or (protectionTarget == false and IsKSTarget(AttackTarget))
		or IsTargetInActiveRange(AttackTarget) == false
		or IsTargetReachableWhileTurretStaying(AttackTarget) == false then
		local oldAttackTarget = AttackTarget
		local shouldIgnoreOldAttackTarget = ShouldIgnoreDroppedTargetAfterSwap(oldAttackTarget)
		ClearAttackTarget()
		if shouldIgnoreOldAttackTarget then
			IgnoreTargetBriefly(oldAttackTarget)
		end
		AcquireAttackTarget(oldAttackTarget)
		if AttackTarget == 0 then
			CurrentState = STATE_IDLE
		elseif RedirectAttackAfterTargetSwap(oldAttackTarget) == 1 then
			return
		elseif TryImmediateFilirCombatHandoff() == 1 then
			return
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
	if castTarget ~= 0 then
		ResetPathingProbe()
		if IsFilir(MyID) then
			if ShouldFilirHoldForRepeatSkill(castTarget) then
				CurrentState = STATE_ATTACK
				return
			end
			if ResumeFilirAttackAfterOffensiveSkill(castTarget) == 1 then
				return
			end
			if TryImmediateFilirCombatHandoff() == 1 then
				return
			end

			CurrentState = STATE_ATTACK
			return
		end
	end

	if HandleFilirRepeatSkillPriority(AttackTarget) == 1 then
		return
	end

	if ShouldFilirHoldForRepeatSkill(AttackTarget) then
		return
	end

	if TryFilirAttackFallback() == 1 then
		return
	end

	local distance = DistanceToActor(MyID, AttackTarget)
	if distance > AttackRange() then
		if distance <= StickyAttackRange() and TryStickyAttackCommand() == 1 then
			return
		end

		if ShouldHoldFilirCloseEngage(AttackTarget) then
			CurrentState = STATE_ATTACK
			return
		end

		if CheckTargetPathingFailure(AttackTarget) then
			local failedTarget = AttackTarget
			HandlePathingFailureTarget(failedTarget)
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

	if IsFilir(MyID) == false and GetTick() + ATTACK_LATCH_GRACE_MS >= NextAttackCommandAt then
		ResetPathingProbe()
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
		TryCastConfiguredSkills()
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

	if TryPatrol() then
		return
	end

	EnsureIdleStandby()
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

	if RequireStandbyReset == 1 and HasActiveSnipeWork() then
		CancelSoftStandbyReset()
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

	if HasActiveSnipeWork() then
		CancelSoftStandbyReset()
		StandStillSince = 0
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
		EngageFreshAttackTarget(0)
		StandStillSince = 0
		return
	end

	BeginSoftStandbyReset(0, 1)
	StandStillSince = 0
end

function ForceImmediateActivity()
	if CurrentState == STATE_HOLD or CurrentState == STATE_WAIT or HasActiveSnipeWork() then
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
			if HandleFilirRepeatSkillPriority(AttackTarget) == 1 then
				return
			end

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

		if HandleFilirRepeatSkillPriority(AttackTarget) == 1 then
			return
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

function AI(myid)
	MyID = myid
	LoadFilirSupportCooldowns()
	RememberActorPosition(MyID)
	RememberActorPosition(GetV(V_OWNER, MyID))
	UpdateSPTracking()
	UpdateCapriceAttemptState()
	UpdateFilirSupportAttemptState()
	CleanupProtectedMob()
	CleanupKiteNoAttackDone()

	local msg = GetMsg(myid)
	local reserved = GetResMsg(myid)

	if msg[1] == NONE_CMD then
		if reserved[1] ~= NONE_CMD
			and (reserved[1] ~= ATTACK_OBJECT_CMD or ShouldBlockNormalAttackCommand(reserved[2]) == false)
			and (reserved[1] ~= ATTACK_AREA_CMD or IsSnipeMode() == false)
			and Queue.size(PendingCommands) < 10 then
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

	if HandleVanilSongPriority() then
		local actors = GetActors()
		for _, actor in ipairs(actors) do
			RememberActorPosition(actor)
		end
		return
	end

	if HandleFilirBuffPriority() then
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

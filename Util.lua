Queue = {}

function Queue.new()
	return { first = 0, last = -1 }
end

function Queue.push_right(queue, value)
	local last = queue.last + 1
	queue.last = last
	queue[last] = value
end

function Queue.pop_left(queue)
	local first = queue.first
	if first > queue.last then
		return nil
	end

	local value = queue[first]
	queue[first] = nil
	queue.first = first + 1
	return value
end

function Queue.clear(queue)
	local first = queue.first
	local last = queue.last

	for i = first, last do
		queue[i] = nil
	end

	queue.first = 0
	queue.last = -1
end

function Queue.size(queue)
	return queue.last - queue.first + 1
end

function Distance(x1, y1, x2, y2)
	return math.floor(math.sqrt((x1 - x2) ^ 2 + (y1 - y2) ^ 2))
end

function DistanceToActor(id1, id2)
	local x1, y1 = GetV(V_POSITION, id1)
	local x2, y2 = GetV(V_POSITION, id2)

	if x1 == -1 or x2 == -1 then
		return -1
	end

	return Distance(x1, y1, x2, y2)
end

function DistanceToOwner(id)
	local owner = GetV(V_OWNER, id)
	return DistanceToActor(id, owner)
end

function IsGone(id)
	local x, y = GetV(V_POSITION, id)
	return x == -1 or y == -1
end

function IsOutOfSight(id1, id2)
	local distance = DistanceToActor(id1, id2)
	return distance == -1 or distance > 20
end

function SkillRange(id, skill, level)
	return GetV(V_SKILLATTACKRANGE_LEVEL, id, skill, level)
end

function InSkillRange(id, target, skill, level)
	local distance = DistanceToActor(id, target)
	if distance == -1 then
		return false
	end

	return distance <= SkillRange(id, skill, level)
end

function SkillApproachPosition(target, skill, level)
	return GetV(V_POSITION_APPLY_SKILLATTACKRANGE, target, skill, level)
end

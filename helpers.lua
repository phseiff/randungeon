--
-- Helper Functions For Block Comparisons
--

local function contains(array, value)
	for i= 1, #array do
		if array[i] == value then
			return true
		end
	end
	return false
end

local function intersects(array1, array2)
	for _, v1 in ipairs(array1) do
		for _2, v2 in ipairs(array2) do
			if v1 == v2 then
				return true
			end
		end
	end
	return false
end

local function bool_to_number(value)
	if value == true then
		return 1
	else
		return 0
	end
end

local function number_to_bool(value)
	if value == 1 then
		return true
	else
		return false
	end
end

local function is_even(a)
	return a - (math.floor(a/2)*2) == 0
end


return {
    contains = contains,
    intersects = intersects,
    bool_to_number = bool_to_number,
	number_to_bool = number_to_bool,
	is_even = is_even
}
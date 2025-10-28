local _, ns = ...
local E = ns.E

function E:InitDatabase()
	-- Initialize SavedVariables
	NihuiOptimizerDB = NihuiOptimizerDB or {}

	-- Set up database with defaults
	local function copyDefaults(src, dst)
		if type(src) ~= "table" then return {} end
		if type(dst) ~= "table" then dst = {} end
		for k, v in pairs(src) do
			if type(v) == "table" then
				dst[k] = copyDefaults(v, dst[k])
			elseif type(dst[k]) == "nil" then
				dst[k] = v
			end
		end
		return dst
	end

	NihuiOptimizerDB = copyDefaults(E.defaults, NihuiOptimizerDB)
	E.db = NihuiOptimizerDB
end

local M = {}

local native_print = print
local lines = {}

local function value_to_string(value, seen)
	if type(value) ~= "table" then
		return tostring(value)
	end

	seen = seen or {}
	if seen[value] then
		return "<cycle>"
	end
	seen[value] = true

	local keys = {}
	for key in pairs(value) do
		keys[#keys + 1] = key
	end
	table.sort(keys, function(left, right)
		return tostring(left) < tostring(right)
	end)

	local fields = {}
	for _, key in ipairs(keys) do
		fields[#fields + 1] = tostring(key) .. "=" .. value_to_string(value[key], seen)
	end

	seen[value] = nil
	return "{" .. table.concat(fields, ", ") .. "}"
end

local function append(...)
	local values = {}
	for index = 1, select("#", ...) do
		values[index] = value_to_string(select(index, ...))
	end
	lines[#lines + 1] = table.concat(values, "\t") .. "\n"
end

_G.print = function(...)
	native_print(...)
	append(...)
end

function M.clear()
	lines = {}
	gui.set_text(gui.get_node("console"), "")
end

function M.update(node)
	local text = table.concat(lines)
	local font_name = gui.get_font(node)
	local font = gui.get_font_resource(font_name)
	local size = gui.get_size(node)
	local metrics_options = {
		width = size.x,
		line_break = true,
	}
	local metrics = resource.get_text_metrics(font, text, metrics_options)

	while metrics.height > size.y and #lines > 1 do
		table.remove(lines, 1)
		text = table.concat(lines)
		metrics = resource.get_text_metrics(font, text, metrics_options)
	end

	gui.set_text(node, text)
end

function M.get_table_as_str(value)
	if type(value) ~= "table" then
		return tostring(value)
	end
	return value_to_string(value)
end

return M

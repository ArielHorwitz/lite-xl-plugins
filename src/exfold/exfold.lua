-- mod-version:3

local core = require "core"
local command = require "core.command"
local DocView = require "core.docview"

local function fold_selections(doc)
  for _idx, line1, _col1, line2, _col2 in doc:get_selections(true) do
    local text = table.concat(doc.lines, "\n", line1, line2)
    local folded = text:gsub("\n%s*", ""):gsub("%s*,%s*", ", "):gsub("%s*,%s*%)", ")")
    doc:remove(line1, 1, line2 + 1, 1)
    doc:text_input(folded .. "\n")
  end
end

local function expand_current_line(doc)
  local current_line = doc:get_selection()
  local single_indent = doc:get_indent_string()
  local line = doc.lines[current_line]
  local indent = line:match("^%s*")
  local name = line:match("[%w_]+%s*%(%s*")
  local args, rest = line:match("%((.-)%)(.*)$")
  if name == nil or args == nil then
    core.warn("Function signature not found")
    return
  end
  local parts = {}
  for arg in args:gmatch("[^,]+") do
    local non_whitespace = arg:match("^%s*(.-)%s*$")
    if non_whitespace ~= "" then
      parts[#parts + 1] = indent .. single_indent .. non_whitespace
    end
  end
  local sig_args = table.concat(parts, ",\n")
  local expanded = indent .. name .. "\n" .. sig_args .. ",\n" .. indent .. ")" .. rest
  doc:remove(current_line, 1, current_line + 1, 1)
  doc:text_input(expanded)
end

-- Command predicates
local function docview_predicate()
  if getmetatable(core.active_view) ~= DocView then
    return false
  end
  return true, core.active_view.doc
end

-- Initialize plugin
command.add(docview_predicate, {
  ["exfold:fold"] = function(docview) fold_selections(docview) end,
  ["exfold:expand"] = function(docview) expand_current_line(docview) end,
})

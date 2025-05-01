-- mod-version:3

local system = require "system"
local core = require "core"
local common = require "core.common"
local command = require "core.command"
local STORAGE_VERSION = 1

local function open_doc(filename, line, col)
  local path = common.home_expand(filename)
  local doc = core.open_doc(path)
  core.root_view:open_doc(doc)
  local av_doc = core.active_view.doc
  local open_line, open_col = av_doc:get_selection()
  if open_line ~= line or open_col ~= col then
    av_doc:set_selection(line, col, line, col)
  end
end

local function warn_empty_name(text, warning_text, as_error)
  if not text or text == "" then
    if warning_text then
      if as_error then
        core.error(warning_text)
      else
        core.warn(warning_text)
      end
    end
    return true
  end
  return false
end

-- Bookmarks
local cached_bookmarks = {}

local function add_bookmark_context(name, bookmark)
  local b = bookmark
  local filename = b.filename:gsub("%[", "_")
	return string.format("%s [ %d:%d @ %s ]", name, b.line, b.col, filename)
end

local function strip_bookmark_context(name)
  return name:match("^(.+) %[") or name
end

local function get_bookmark(name)
  return cached_bookmarks[name]
end

local function suggest_bookmarks(text)
  local suggestions = {}
  for name, bookmark in pairs(cached_bookmarks) do
    table.insert(suggestions, add_bookmark_context(name, bookmark))
  end
  return common.fuzzy_match(suggestions, text, false)
end

-- Persistence
local function get_storage_path()
  local storage_dir = USERDIR .. PATHSEP .. "storage"
  system.mkdir(storage_dir)
  storage_dir = storage_dir .. PATHSEP .. "bookmarks"
  system.mkdir(storage_dir)
  local workspace_id = system.absolute_path(core.project_dir):gsub("[^%w]", "_")
  return storage_dir .. PATHSEP .. workspace_id
end

local function save_bookmarks()
  local data = {
    bookmarks = cached_bookmarks,
    version = STORAGE_VERSION
  }
  local serialized = common.serialize(data, {pretty = true})
  local storage_file = get_storage_path()
  print("Saving to:" .. storage_file)
  print(serialized)
  local fp = io.open(storage_file, "w")
  if fp then
    fp:write(string.format("return %s\n", serialized))
    fp:close()
  else
    core.error("Failed to save bookmarks to file: " .. storage_file)
  end
end

local function load_bookmarks()
  local storage_file = get_storage_path()
  local storage_file_info = system.get_file_info(storage_file)
  if storage_file_info == nil or storage_file_info.size == 0 then
    cached_bookmarks = {}
    save_bookmarks()
  end
  local load_f = loadfile(storage_file)
  if load_f then
    local data = load_f()
    if data.version == nil or data.version ~= STORAGE_VERSION then
      local loaded_version = data.version or "nil"
      core.warn("Delete or fix your saved bookmarks file at: " .. storage_file)
      core.error("Saved bookmarks version mismatch (expected: '" .. STORAGE_VERSION .. "', loaded: '" .. loaded_version .. "')")
      return
    end
    cached_bookmarks = data.bookmarks
  else
    core.error("Failed to load bookmarks from file: " .. storage_file)
  end
end

-- Management
local function add_bookmark(name, doc_view)
  name = strip_bookmark_context(name)
  local line, col = doc_view.doc:get_selection()
  cached_bookmarks[name] = {
    filename = doc_view.doc.filename,
    line = line,
    col = col
  }
  core.log("Added bookmark: '" .. name .. "'")
  save_bookmarks()
end

local function rename_bookmark(old_name, new_name)
  old_name = strip_bookmark_context(old_name)
  local bookmark = get_bookmark(old_name)
  cached_bookmarks[old_name] = nil
  cached_bookmarks[new_name] = bookmark
  core.log("Renamed bookmark: '" .. old_name .. "'" .. " to: '" .. new_name .. "'")
  save_bookmarks()
end

local function delete_bookmark(name)
  name = strip_bookmark_context(name)
  if cached_bookmarks[name] ~= nil then
    core.error("No bookmark named '" .. name .. "'")
    return
  end
  cached_bookmarks[name] = nil
  core.log("Deleted bookmark: '" .. name .. "'")
  save_bookmarks()
end

local function open_bookmark(name)
  name = strip_bookmark_context(name)
  local bookmark = get_bookmark(name)
  if bookmark == nil then
    core.error("No bookmark named '" .. name .. "'")
    return
  end
  open_doc(bookmark.filename, bookmark.line, bookmark.col)
  core.log("Opened bookmark: '" .. name .. "'")
end

local function clean_deleted_bookmarks()
  for name, bookmark in pairs(cached_bookmarks) do
    if not system.get_file_info(bookmark.filename) then
      cached_bookmarks[name] = nil
    end
  end
end

-- Initialize plugin
load_bookmarks()

command.add(nil, {
  ["bookmarks:open-bookmark"] = function()
    clean_deleted_bookmarks()
    if next(cached_bookmarks) == nil then
      core.warn("No bookmarks")
      return
    end
    core.command_view:enter("Open bookmark", {
      submit = function(name)
        if warn_empty_name(name, "No bookmark selected") then return end
        open_bookmark(name)
      end,
      suggest = function(text) return suggest_bookmarks(text) end
    })
  end,
  ["bookmarks:delete-bookmark"] = function()
    core.command_view:enter("Delete bookmark", {
      submit = function(name)
        if warn_empty_name(name, "No bookmark selected") then return end
        delete_bookmark(name)
      end,
      suggest = function(text) return suggest_bookmarks(text) end
    })
  end,
  ["bookmarks:rename-bookmark"] = function()
    core.command_view:enter("Rename bookmark", {
      submit = function(old_name)
        if warn_empty_name(old_name, "No bookmark selected") then return end
        core.command_view:enter("New name", {
          submit = function(new_name)
            if warn_empty_name(new_name, "No name given") then return end
            rename_bookmark(old_name, new_name)
          end,
        })
      end,
      suggest = function(text) return suggest_bookmarks(text) end
    })
  end,
  ["bookmarks:clear-workspace-bookmarks"] = function()
    cached_bookmarks = {}
    save_bookmarks()
  end,
})

command.add("core.docview", {
  ["bookmarks:add-bookmark"] = function(doc_view)
    core.command_view:enter("Add bookmark", {
      submit = function(name)
        if warn_empty_name(name, "Bookmark must have a name", true) then return end
        add_bookmark(name, doc_view)
      end,
      suggest = function(text) return suggest_bookmarks(text) end
    })
  end,
})

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

local function warn_empty_name(text, warning_text)
  if not text or text == "" then
    if warning_text then
      core.warn(warning_text)
    end
    return true
  end
  return false
end

-- Bookmarks
local saved_bookmarks = {}

local function get_bookmark_names()
  local results = {}
  for key in pairs(saved_bookmarks) do
    table.insert(results, key)
  end
  return results
end

local function get_bookmark(name)
  return saved_bookmarks[name]
end

local function suggest_bookmarks(name)
  local bookmark_names = get_bookmark_names()
  return common.fuzzy_match(bookmark_names, name, false)
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
    print("Saved")
  else
    print("Failed to open file: " .. storage_file)
  end
end

local function load_bookmarks()
  local storage_file = get_storage_path()
  local storage_file_info = system.get_file_info(storage_file)
  if storage_file_info == nil or storage_file_info.size == 0 then
    saved_bookmarks = {}
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
    saved_bookmarks = data.bookmarks
  else
    print("Failed to load file: " .. storage_file)
  end
end

-- Management
local function add_bookmark(name, doc_view)
  local line, col = doc_view.doc:get_selection()
  saved_bookmarks[name] = {
    filename = doc_view.doc.filename,
    line = line,
    col = col
  }
  save_bookmarks()
end

local function rename_bookmark(old_name, new_name)
  local bookmark = get_bookmark(old_name)
  saved_bookmarks[old_name] = nil
  saved_bookmarks[new_name] = bookmark
  save_bookmarks()
end

local function delete_bookmark(name)
  saved_bookmarks[name] = nil
  save_bookmarks()
end

local function open_bookmark(name)
  local bookmark = get_bookmark(name)
  open_doc(bookmark.filename, bookmark.line, bookmark.col)
end

local function clean_deleted_bookmarks()
  for name, bookmark in pairs(saved_bookmarks) do
    if not system.get_file_info(bookmark.filename) then
      saved_bookmarks[name] = nil
    end
  end
end

-- Initialize plugin
load_bookmarks()

command.add(nil, {
  ["bookmarks:open-bookmark"] = function()
    clean_deleted_bookmarks()
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
})

command.add("core.docview", {
  ["bookmarks:add-bookmark"] = function(doc_view)
    core.command_view:enter("Add bookmark", {
      submit = function(name)
        if warn_empty_name(name, "No bookmark selected") then return end
        add_bookmark(name, doc_view)
      end,
      suggest = function(text) return suggest_bookmarks(text) end
    })
  end,
})

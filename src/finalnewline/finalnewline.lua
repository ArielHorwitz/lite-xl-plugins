-- mod-version:3

-- Taken from:
-- https://github.com/lite-xl/lite-xl/issues/1858#issuecomment-2240043427

local Doc = require "core.doc"

local doc_load = Doc.load
function Doc:load(filename, ...)
  local results = table.pack(doc_load(self, filename, ...))

  local fp <close> = assert(io.open(filename, "rb"))
  local size = fp:seek("end", -1)
  if size and fp:read(1) == "\n" then
    table.insert(self.lines, "\n")
  end
  self:reset_syntax()

  return table.unpack(results)
end

local doc_save = Doc.save
function Doc:save(filename, abs_filename, ...)
  self.lines[#self.lines] = self.lines[#self.lines]:sub(1, -2)

  local results = table.pack(doc_save(self, filename, abs_filename, ...))

  self.lines[#self.lines] = self.lines[#self.lines] .. "\n"

  return table.unpack(results)
end

local M = {}
local rsync = require("remote-upload.rsync")

function M.status()
  if rsync.progress and rsync.progress.active then
    return string.format(" %s%% ", rsync.progress.status or "")
  end
  return ""
end

return M
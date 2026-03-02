local M = {}
local rsync = require("remote-upload.rsync")

function M.status()

  if rsync.progress then

    if rsync.progress.completed and rsync.progress.status then

      -- Show completed status

      return rsync.progress.status .. " "

    elseif rsync.progress.active and rsync.progress.status then

      -- Show uploading status

      return "Uploading " .. rsync.progress.status .. " "

    end

  end

  return ""

end

return M
local M = {}

local config = require("remote-upload.config")
local telescope = require("remote-upload.telescope")
local rsync = require("remote-upload.rsync")
local notify = require("remote-upload.notify")

function M.upload_current_file()
  local file = vim.fn.expand("%:p")
  if file == "" then
    notify.warn("No file open")
    return
  end
  if vim.fn.filereadable(file) == 0 then
    notify.warn("File not saved or not readable")
    return
  end
  rsync.upload({ file }, function(err)
    if err then
      notify.error("Upload failed: " .. err)
    else
      notify.info("Uploaded: " .. file)
    end
  end)
end

function M.pick_and_upload()
  telescope.pick_files()
end

function M.upload_all()
  telescope.upload_all()
end

function M.setup_autocmd()
  if config.get().auto_upload then
    vim.api.nvim_create_autocmd("BufWritePost", {
      pattern = "*",
      callback = function()
        M.upload_current_file()
      end,
      group = vim.api.nvim_create_augroup("RemoteUploadAuto", { clear = true }),
    })
  end
end

function M.setup()
  vim.api.nvim_create_user_command("RemoteUpload", M.pick_and_upload, {})
  vim.api.nvim_create_user_command("RemoteUploadCurrent", M.upload_current_file, {})
  vim.api.nvim_create_user_command("RemoteUploadAll", M.upload_all, {})
  M.setup_autocmd()
end

return M

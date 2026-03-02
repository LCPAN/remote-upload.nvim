local M = {}
local config = require("remote-upload.config")
local notify = require("remote-upload.notify")

-- Progress tracking for lualine
M.progress = {

  active = false,

  status = nil,

  current_file = 0,

  total_files = 0,

}

function M.build_remote_path(local_path)
  local cfg = config.get()
  local cwd = vim.fn.getcwd()
  local project_name = vim.fn.fnamemodify(cwd, ":t")
  local relative = vim.fn.fnamemodify(local_path, ":~:.")
  if relative:sub(1, 2) == "./" then
    relative = relative:sub(3)
  end
  return cfg.remote_prefix .. "/" .. project_name .. "/" .. relative
end

function M.build_remote_dir()
  local cfg = config.get()
  local cwd = vim.fn.getcwd()
  local project_name = vim.fn.fnamemodify(cwd, ":t")
  return cfg.remote_prefix .. "/" .. project_name
end

local function ensure_remote_dir(host, remote_dir, callback)
  local args = { "ssh", host, "mkdir", "-p", remote_dir }
  vim.fn.jobstart(args, {
    on_exit = function(_, exit_code)
      if exit_code ~= 0 then
        callback("Failed to create remote directory: " .. remote_dir)
      else
        callback(nil)
      end
    end,
  })
end

function M.upload(files, callback)
  local cfg = config.get()
  
  if cfg.host == "" or cfg.remote_prefix == "" then
    callback("Config: host or remote_prefix is empty", nil)
    return
  end
  
  if #files == 0 then
    callback("No files to upload", nil)
    return
  end
  
  notify.info("Uploading " .. #files .. " file(s)...")
  
  -- Initialize progress tracking

  M.progress.active = true

  M.progress.status = nil

  M.progress.current_file = 0

  M.progress.total_files = #files
  
  local remote_dir = M.build_remote_dir()
  ensure_remote_dir(cfg.host, remote_dir, function(err)
    if err then
      M.progress.active = false
      callback(err, nil)
      return
    end
    
    local args = { "rsync", "-avz" }
    
    for flag in cfg.rsync_flags:gmatch("%S+") do
      table.insert(args, flag)
    end
    
    for _, pattern in ipairs(cfg.ignore or {}) do
      table.insert(args, "--exclude=" .. pattern)
    end
    
    for _, file in ipairs(files) do
      table.insert(args, file)
    end
    
    table.insert(args, cfg.host .. ":" .. remote_dir .. "/")
    
    local errors = {}
    
    local job_id = vim.fn.jobstart(args, {

      on_stdout = function(_, data)

        if data then

          for _, line in ipairs(data) do

            -- Parse file count from rsync output: (xfer#80, to-check=96/101)

            local current, remaining, total = line:match("xfer#(%d+), to%-check=(%d+)/(%d+)")

            if current and total then

              M.progress.current_file = tonumber(current)

              M.progress.total_files = tonumber(total)

              M.progress.status = string.format("%d/%d", M.progress.current_file, M.progress.total_files)

              vim.cmd("redrawstatus")

            end

          end

        end

      end,

      on_stderr = function(_, data)

        if data then

          for _, line in ipairs(data) do

            -- Parse file count from rsync output: (xfer#80, to-check=96/101)

            local current, remaining, total = line:match("xfer#(%d+), to%-check=(%d+)/(%d+)")

            if current and total then

              M.progress.current_file = tonumber(current)

              M.progress.total_files = tonumber(total)

              M.progress.status = string.format("%d/%d", M.progress.current_file, M.progress.total_files)

              vim.cmd("redrawstatus")

            elseif line ~= "" and not line:match("^sending") and not line:match("^total size") then

              table.insert(errors, line)

            end

          end

        end

      end,

      on_exit = function(_, exit_code)
        if exit_code ~= 0 then
          -- Failed upload: clear progress immediately
          M.progress.active = false
          vim.cmd("redrawstatus")
          
          if #errors > 0 then
            callback(table.concat(errors, "\n"), nil)
          else
            callback("rsync exited with code " .. exit_code, nil)
          end
        else
          -- Successful upload: retain progress for 4 seconds
          callback(nil, "Uploaded " .. #files .. " file(s)")
          
          -- Use defer_fn to clear progress after 4 seconds
          vim.defer_fn(function()
            M.progress.active = false
            vim.cmd("redrawstatus")
          end, 4000)
        end
      end,

    })
    

    if job_id <= 0 then

      M.progress.active = false

      callback("Failed to start rsync", nil)

    end

  end)

end



return M
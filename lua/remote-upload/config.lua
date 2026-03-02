local M = {}

local default_config = {
  host = "",
  remote_prefix = "",
  rsync_flags = "-avz",
  auto_upload = false,
  ignore = {}
}

function M.global_config_path()
  return vim.fn.stdpath("data") .. "/plugins/remote-upload.nvim/config.json"
end

function M.project_config_path()
  return vim.fn.getcwd() .. "/.nvim-upload.json"
end

local function read_config(path)
  if vim.fn.filereadable(path) == 1 then
    local content = vim.fn.readfile(path)
    local ok, user_config = pcall(vim.json.decode, table.concat(content, "\n"))
    if ok then
      return user_config
    end
  end
  return nil
end

function M.get()
  local config = vim.deepcopy(default_config)
  
  local global = read_config(M.global_config_path())
  if global then
    config = vim.tbl_deep_extend("force", config, global)
  end
  
  local project = read_config(M.project_config_path())
  if project then
    config = vim.tbl_deep_extend("force", config, project)
  end
  
  return config
end

return M

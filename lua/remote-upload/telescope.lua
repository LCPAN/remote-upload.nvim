-- luache: max_line_length 120
-- vim: tabstop=2 shiftwidth=2 expandtab

local M = {}
local rsync = require("remote-upload.rsync")
local notify = require("remote-upload.notify")

local function has_telescope()
  local ok, _ = pcall(require, "telescope")
  return ok
end

function M.pick_files()
  if not has_telescope() then
    notify.error("Telescope not installed!")
    return
  end

  local pickers = require("telescope.pickers")
  local finders = require("telescope.finders")
  local conf = require("telescope.config").values
  local actions = require("telescope.actions")
  local action_state = require("telescope.actions.state")

  pickers.new({}, {
    prompt_title = "Select files (Tab: multi, Ctrl-a: all)",
    finder = finders.new_oneshot_job(
      { "find", ".", "-type", "f", "-not", "-path", "./.git/*" },
      { cwd = vim.fn.getcwd() }
    ),
    sorter = conf.file_sorter({}),
    previewer = conf.file_previewer({}),
    attach_mappings = function(prompt_bufnr, map)
      map("i", "<Tab>", actions.toggle_selection)
      map("n", "<Tab>", actions.toggle_selection)
      map("i", "<C-a>", actions.select_all)
      map("n", "<C-a>", actions.select_all)

      actions.select_default:replace(function()
        local picker = action_state.get_current_picker(prompt_bufnr)
        local selections = picker:get_multi_selection()

        if #selections == 0 then
          local selection = action_state.get_selected_entry()
          if selection then
            selections = { selection }
          end
        end

        actions.close(prompt_bufnr)

        if #selections > 0 then
          local files = {}
          for _, sel in ipairs(selections) do
            local file = type(sel[1]) == "string" and sel[1] or sel.value or sel.path
            if file then
              table.insert(files, vim.fn.getcwd() .. "/" .. file)
            end
          end

          rsync.upload(files, function(err, output)
            if err then
              notify.error("Upload failed: " .. err)
            else
              notify.info(output or "Upload complete")
            end
          end)
        else
          notify.warn("No files selected")
        end
      end)

      return true
    end,
 }):find()
end

function M.upload_all()
  local all_files = {}
  local handle = io.popen('find . -type f -not -path "./.git/*"')
  if handle then
    for line in handle:lines() do
      if line and line ~= "" then
        table.insert(all_files, vim.fn.getcwd() .. "/" .. line:sub(3))
      end
    end
    handle:close()
  end

  if #all_files == 0 then
    notify.warn("No files found to upload")
    return
  end

  rsync.upload(all_files, function(err, output)
    if err then
      notify.error("Upload failed: " .. err)
    else
      notify.info(output or "Upload complete")
    end
  end)
end

return M

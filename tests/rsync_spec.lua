local rsync = require('remote-upload.rsync')
local uv = vim.loop

-- Helper function to create temporary directory
local function create_temp_dir()
  local temp_dir = os.tmpname()
  -- On macOS, tmpname() might return a file, so we ensure it's a directory
  if vim.fn.isdirectory(temp_dir) == 0 then
    os.remove(temp_dir)
    uv.fs_mkdir(temp_dir, 448) -- 0700 permissions
  end
  return temp_dir
end

-- Helper function to write content to a file
local function write_file(path, content)
  local file = io.open(path, "w")
  if file then
    file:write(content)
    file:close()
    return true
  end
  return false
end

describe('get_main_repo_name', function()
  local test_dir
  local original_cwd

  before_each(function()
    -- Store original working directory
    original_cwd = vim.fn.getcwd()
    -- Create temporary test directory
    test_dir = create_temp_dir()
  end)

  after_each(function()
    -- Restore original working directory
    vim.cmd("cd " .. original_cwd)
    -- Clean up temporary directory
    if test_dir then
      -- Use rm -rf equivalent via Lua
      local function remove_dir(path)
        local iter = uv.fs_scandir(path)
        if iter then
          local name, typ
          while true do
            name, typ = uv.fs_scandir_next(iter)
            if not name then break end
            local full_path = path .. "/" .. name
            if typ == "directory" then
              remove_dir(full_path)
            else
              uv.fs_unlink(full_path)
            end
          end
        end
        uv.fs_rmdir(path)
      end
      remove_dir(test_dir)
    end
  end)

  it('should return directory name for regular git repository', function()
    -- Create a regular git repository structure
    local repo_name = "regular-repo"
    local repo_path = test_dir .. "/" .. repo_name
    uv.fs_mkdir(repo_path, 448)
    local git_dir = repo_path .. "/.git"
    uv.fs_mkdir(git_dir, 448)
    
    -- Change to the repo directory
    vim.cmd("cd " .. repo_path)
    
    local result = rsync.get_main_repo_name()
    assert.equals(repo_name, result)
  end)

  it('should return main repository name for git worktree with absolute path', function()
    -- Create main repository
    local main_repo_name = "main-repo"
    local main_repo_path = test_dir .. "/" .. main_repo_name
    uv.fs_mkdir(main_repo_path, 448)
    local main_git_dir = main_repo_path .. "/.git"
    uv.fs_mkdir(main_git_dir, 448)
    
    -- Create worktree
    local worktree_name = "worktree-absolute"
    local worktree_path = test_dir .. "/" .. worktree_name
    uv.fs_mkdir(worktree_path, 448)
    
    -- Create .git file in worktree pointing to main repo
    local git_file_content = "gitdir: " .. main_git_dir .. "/worktrees/" .. worktree_name
    write_file(worktree_path .. "/.git", git_file_content)
    
    -- Change to worktree directory
    vim.cmd("cd " .. worktree_path)
    
    local result = rsync.get_main_repo_name()
    assert.equals(main_repo_name, result)
  end)

  it('should return main repository name for git worktree with relative path', function()
    -- Create main repository
    local main_repo_name = "main-repo-relative"
    local main_repo_path = test_dir .. "/" .. main_repo_name
    uv.fs_mkdir(main_repo_path, 448)
    local main_git_dir = main_repo_path .. "/.git"
    uv.fs_mkdir(main_git_dir, 448)
    
    -- Create worktree
    local worktree_name = "worktree-relative"
    local worktree_path = test_dir .. "/" .. worktree_name
    uv.fs_mkdir(worktree_path, 448)
    
    -- Create .git file in worktree with relative path
    -- Assuming worktree is at same level as main repo
    local relative_path = "../" .. main_repo_name .. "/.git/worktrees/" .. worktree_name
    local git_file_content = "gitdir: " .. relative_path
    write_file(worktree_path .. "/.git", git_file_content)
    
    -- Change to worktree directory
    vim.cmd("cd " .. worktree_path)
    
    local result = rsync.get_main_repo_name()
    assert.equals(main_repo_name, result)
  end)

  it('should handle malformed .git file gracefully', function()
    -- Create directory with malformed .git file
    local dir_name = "malformed-git"
    local dir_path = test_dir .. "/" .. dir_name
    uv.fs_mkdir(dir_path, 448)
    
    -- Create .git file with invalid content
    write_file(dir_path .. "/.git", "invalid content without gitdir")
    
    -- Change to directory
    vim.cmd("cd " .. dir_path)
    
    local result = rsync.get_main_repo_name()
    assert.equals(dir_name, result)
  end)

  it('should return directory name for non-git directory', function()
    -- Create non-git directory
    local dir_name = "non-git-dir"
    local dir_path = test_dir .. "/" .. dir_name
    uv.fs_mkdir(dir_path, 448)
    
    -- Change to directory
    vim.cmd("cd " .. dir_path)
    
    local result = rsync.get_main_repo_name()
    assert.equals(dir_name, result)
  end)

  it('should handle worktrees with spaces in path names', function()
    -- Create main repository with spaces
    local main_repo_name = "main repo with spaces"
    local main_repo_path = test_dir .. "/" .. main_repo_name
    uv.fs_mkdir(main_repo_path, 448)
    local main_git_dir = main_repo_path .. "/.git"
    uv.fs_mkdir(main_git_dir, 448)
    
    -- Create worktree with spaces
    local worktree_name = "worktree with spaces"
    local worktree_path = test_dir .. "/" .. worktree_name
    uv.fs_mkdir(worktree_path, 448)
    
    -- Create .git file in worktree
    local git_file_content = "gitdir: " .. main_git_dir .. "/worktrees/" .. worktree_name
    write_file(worktree_path .. "/.git", git_file_content)
    
    -- Change to worktree directory
    vim.cmd("cd " .. worktree_path)
    
    local result = rsync.get_main_repo_name()
    assert.equals(main_repo_name, result)
  end)

  it('should handle cross-platform path separators', function()
    -- Create main repository
    local main_repo_name = "cross-platform-repo"
    local main_repo_path = test_dir .. "/" .. main_repo_name
    uv.fs_mkdir(main_repo_path, 448)
    local main_git_dir = main_repo_path .. "/.git"
    uv.fs_mkdir(main_git_dir, 448)
    
    -- Create worktree
    local worktree_name = "worktree-windows"
    local worktree_path = test_dir .. "/" .. worktree_name
    uv.fs_mkdir(worktree_path, 448)
    
    -- Create .git file with backslashes (Windows style)
    local windows_path = main_git_dir:gsub("/", "\\") .. "\\worktrees\\" .. worktree_name
    local git_file_content = "gitdir: " .. windows_path
    write_file(worktree_path .. "/.git", git_file_content)
    
    -- Change to worktree directory
    vim.cmd("cd " .. worktree_path)
    
    local result = rsync.get_main_repo_name()
    assert.equals(main_repo_name, result)
  end)

  it('should handle alternative .git file format (direct .git reference)', function()
    -- Create main repository
    local main_repo_name = "alternative-format"
    local main_repo_path = test_dir .. "/" .. main_repo_name
    uv.fs_mkdir(main_repo_path, 448)
    local main_git_dir = main_repo_path .. "/.git"
    uv.fs_mkdir(main_git_dir, 448)
    
    -- Create worktree
    local worktree_name = "worktree-alt"
    local worktree_path = test_dir .. "/" .. worktree_name
    uv.fs_mkdir(worktree_path, 448)
    
    -- Create .git file pointing directly to main .git (not worktrees subdirectory)
    local git_file_content = "gitdir: " .. main_git_dir
    write_file(worktree_path .. "/.git", git_file_content)
    
    -- Change to worktree directory
    vim.cmd("cd " .. worktree_path)
    
    local result = rsync.get_main_repo_name()
    assert.equals(main_repo_name, result)
  end)

  it('should handle empty .git file gracefully', function()
    -- Create directory with empty .git file
    local dir_name = "empty-git-file"
    local dir_path = test_dir .. "/" .. dir_name
    uv.fs_mkdir(dir_path, 448)
    
    -- Create empty .git file
    write_file(dir_path .. "/.git", "")
    
    -- Change to directory
    vim.cmd("cd " .. dir_path)
    
    local result = rsync.get_main_repo_name()
    assert.equals(dir_name, result)
  end)

  it('should handle unreadable .git file gracefully', function()
    -- Create directory with .git file
    local dir_name = "unreadable-git"
    local dir_path = test_dir .. "/" .. dir_name
    uv.fs_mkdir(dir_path, 448)
    
    -- Create .git file
    write_file(dir_path .. "/.git", "gitdir: /some/path")
    
    -- Change to directory
    vim.cmd("cd " .. dir_path)
    
    -- Note: We can't easily simulate permission errors in tests,
    -- so we rely on the fallback behavior when file reading fails
    -- The function should handle io.open failure gracefully
    local result = rsync.get_main_repo_name()
    -- Should fall back to directory name
    assert.equals(dir_name, result)
  end)
end)
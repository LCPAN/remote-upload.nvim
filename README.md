# remote-upload.nvim

A Neovim plugin for uploading files to remote servers via rsync.

## Installation

Local clone to `~/.local/share/nvim/plugins/remote-upload.nvim/`

## Configuration

### Global Config
Create `~/.local/share/nvim/plugins/remote-upload.nvim/config.json`:

```json
{
  "host": "your-server",
  "remote_prefix": "/var/www",
  "rsync_flags": "-avz",
  "auto_upload": false,
  "ignore": ["node_modules/**", ".git/**", "*.log"]
}
```

### Project Config
Create `.nvim-upload.json` in your project root:

```json
{
  "remote_prefix": "/var/www/my-project",
  "auto_upload": true
}
```

## Commands

- `:RemoteUpload` - Open Telescope picker to select files
- `:RemoteUploadAll` - Upload all files in project
- `:RemoteUploadCurrent` - Upload current buffer file

## Keymaps

| Key | Command | Description |
|-----|---------|-------------|
| `<leader>up` | `:RemoteUpload` | Select files to upload |
| `<leader>ua` | `:RemoteUploadAll` | Upload all files |
| `<leader>Up` | `:RemoteUploadCurrent` | Upload current file |

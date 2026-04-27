# MCP Server

Pito exposes a Model Context Protocol (MCP) server for AI assistants to interact with the app programmatically.

## Architecture

- **Transport:** stdio (stdin/stdout JSON-RPC 2.0)
- **Process:** `bin/mcp` — boots Rails, runs as standalone process (separate from Puma)
- **Gem:** `mcp` (official Ruby MCP SDK, v0.14.0+)
- **No auth** for local stdio — auth will be added for HTTP transport later

The MCP server loads Rails models, decorators, and services directly (in-process). It does not make HTTP requests to the web app.

## Setup

```bash
# Add to Claude Code (from project root)
claude mcp add pito -- /full/path/to/pito/bin/mcp

# Debug mode (shows Rails boot output on stderr)
MCP_DEBUG=1 bin/mcp
```

## Tools

### Read Tools

| Tool | Description |
|------|-------------|
| `list_channels` | All channels with subscriber/video/view counts |
| `get_channel` | Channel detail + video list (by ID) |
| `list_videos` | All videos with stats, optional channel_id filter and limit |
| `get_video` | Video detail + 30-day stat history (by ID) |
| `get_dashboard` | Analytics: daily views, views by channel, top videos, engagement. Supports ranges: 7d, 30d, 90d, 1y, all |
| `search` | Full-text search across channels and videos via Meilisearch |
| `list_saved_views` | All saved workspace views, optional kind filter |
| `manage_settings` | View current settings (no args) or update max_panes, pane_title_length, theme |

### Write Tools

| Tool | Description |
|------|-------------|
| `create_channel` | Create channel (title required, description optional) |
| `update_channel` | Update channel title/description (by ID) |
| `create_video` | Create video (title + channel_id required, plus description/privacy/tags/category/language) |
| `update_video` | Update video metadata (by ID) |
| `delete_records` | Delete channels or videos by type + IDs array. Channels cascade-delete videos. Marked destructive. |
| `create_saved_view` | Save a pane layout (kind + name + IDs array) |
| `delete_saved_view` | Delete a saved view (by ID). Marked destructive. |

## Resources

| URI | Description |
|-----|-------------|
| `pito://design` | Design system document (docs/design.md) |
| `pito://status` | Live app state: counts, search health, settings |
| `pito://mcp` | This document |

## Data Shapes

### Channel Summary
```json
{
  "id": 1,
  "youtube_channel_id": "UC...",
  "title": "Channel Name",
  "connected": true,
  "subscriber_count": 50000,
  "video_count": 120,
  "view_count": 1000000
}
```

### Video Summary
```json
{
  "id": 1,
  "youtube_video_id": "abc123",
  "title": "Video Title",
  "channel_id": 1,
  "channel_title": "Channel Name",
  "privacy_status": "public",
  "published_at": "2025-01-15T00:00:00Z",
  "duration_seconds": 600,
  "total_views": 5000,
  "total_likes": 200,
  "total_comments": 30,
  "total_watch_time": 1500
}
```

### Video Detail (extends summary)
Adds: `description`, `thumbnail_url`, `tags`, `category_id`, `default_language`, `made_for_kids`, `last_synced_at`, `stats` (array of daily entries with date/views/likes/comments/shares/watch_time_minutes).

### Channel Detail (extends summary)
Adds: `description`, `thumbnail_url`, `last_synced_at`, `videos` (array of video summaries).

## File Structure

```
app/mcp/
  pito_server.rb          # Server builder + stdio launcher
  tools/
    list_channels.rb      # list_channels
    get_channel.rb        # get_channel
    list_videos.rb        # list_videos
    get_video.rb          # get_video
    get_dashboard.rb      # get_dashboard
    search_content.rb     # search
    create_channel.rb     # create_channel
    update_channel.rb     # update_channel
    create_video.rb       # create_video
    update_video.rb       # update_video
    delete_records.rb     # delete_records
    manage_settings.rb    # manage_settings
    list_saved_views.rb   # list_saved_views
    create_saved_view.rb  # create_saved_view
    delete_saved_view.rb  # delete_saved_view
  resources/
    app_status.rb         # pito://status
    design_doc.rb         # pito://design
    mcp_doc.rb            # pito://mcp
bin/mcp                   # Stdio entry point
```

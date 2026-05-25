# AI / DeepSeek skill — pito extensions

## Integration points

- Voyage AI embeddings for game/video similarity search
- DeepSeek API for AI-assisted recommendations (future)

## Configuration

API keys in `Rails.application.credentials` under:
- `voyage.api_key`
- `deepseek.api_key`

## Indexing

- `VoyageReindexJob` — reindexes games for similarity search
- `MeilisearchReindexJob` — reindexes videos/channels for text search
- Both triggerable via `/reindex voyager` or `/reindex meilisearch` commands

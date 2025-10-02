# Contract: Cache Key & Disk Cache

## Purpose
Guarantee deterministic reuse of previously rendered artifacts when and only when all semantically relevant inputs are unchanged.

## Key Composition (Ordered Fields)
1. Extension version
2. content_hash (SHA256 of normalized LaTeX source)
3. format
4. engine
5. preamble_hash
6. ppi (png only else '-')
7. entry_type (block|inline)
8. pipeline_signature_digest
9. tool_versions (stable join `engine:ver;converter:ver;...`)

Hash Function: `SHA256( fields.join("\n") )`

## API
```ruby
class CacheKey
  FIELDS_ORDER = %i[ext_version content_hash format engine preamble_hash ppi entry_type pipeline_sig tool_versions].freeze
  def initialize(ext_version:, content_hash:, format:, engine:, preamble_hash:, ppi:, entry_type:, pipeline_sig:, tool_versions:); end
  def digest; end # => hex string
end

class DiskCache
  # @return [CacheEntry,nil]
  def fetch(key_digest); end
  # Atomically store cache entry + artifact copy
  def store(key_digest, cache_entry, source_file); end
  # Advisory lock for expensive renders
  def with_lock(key_digest); yield; end
end
```

## CacheEntry Serialization
`metadata.json` structure:
```json
{
  "version": 1,
  "key": "<digest>",
  "format": "svg",
  "engine": "pdflatex",
  "content_hash": "...",
  "preamble_hash": "...",
  "ppi": 300,
  "entry_type": "block",
  "pipeline_sig": "...",
  "tool_versions": {"pdflatex": "3.14159265", "dvisvgm": "3.0"},
  "created_at": "2025-10-02T12:34:56Z",
  "checksum": "sha256:...",
  "size_bytes": 1234
}
```

## Atomic Write Protocol
1. Render to temp path: `<cachedir>/tmp-<pid>-<rand>.out`.
2. Verify checksum.
3. Write `metadata.json.tmp`.
4. `File.rename(temp, final)`; `File.rename(metadata.tmp, metadata)`.
5. If conflict (file exists): discard temp (another process won race) after verifying identical checksum.

## Conflict Handling
- If same explicit target basename chosen for differing signatures, raise `TargetConflictError` (integration with ConflictRegistry) BEFORE storing.

## Tests
| Spec | Purpose |
|------|---------|
| `spec/cache/key_uniqueness_spec.rb` | Changing any field modifies digest |
| `spec/cache/hit_miss_spec.rb` | Hit path bypasses renderer execution (stub) |
| `spec/cache/concurrency_spec.rb` | Simulated parallel store leads to single final file |
| `spec/cache/corruption_spec.rb` | Corrupted checksum triggers re-render |

## Non-Goals
- Eviction policies (TTL / size) – deferred (FR-039).
- Cross-version migration tooling – future.


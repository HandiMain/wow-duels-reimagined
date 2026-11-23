# Patch Notes — approved template (visual concept 1)

**Status:** approved visual direction; implemented on `develop`, in-game verification pending. The vertical **Versions** rail and selected version's banner, summary, changes, highlights, and optional related setting are all rendered from **one data owner**: `addon/DuelsReimagined/UI/PatchNotesData.lua`. No release, version, or TOC bump is implied by this mockup.

## Adding a real patch

1. Verify the release really occurred. Put a reviewed record **at the beginning** of `ns.PatchNotesData`; the first record is the latest and controls the unread reminder.
2. Use a **unique, stable** `key` (navigation), `id` (seen/reminder state), and user-facing `version` (release name). Once published, avoid renaming `id`.
3. Set `demo = false` **only for genuine releases**. The existing six demo records deliberately use `demo = true`; they are fictional examples and must never be presented as published changes.
4. Write truthful `title`, `date`, `summary`, optional `overview`, optional `highlights`, and `entries`. Do not invent ranked/multiplayer or untested functionality.
5. A change entry can link to an actual registered setting via `target = "setting:..."`. The link is visible/clickable **only when Search contains that exact target**; omit `target` for ordinary updates.
6. Test the version rail at six and many versions, normal/compact/extra-wide window sizes, mouse wheel, keyboard chat Enter/Escape, Back, Search, peek/fold, /reload, and the latest-version unread reminder. Verify the output in Forever and Retail independently.

### Record schema (example placeholders, not a release)

```lua
{
    key = "release-unique-slug",
    id = "patch-unique-stable-id",
    version = "vX.Y.Z",
    navTitle = "Short update name",
    title = "Clear title for this release",
    date = "Month DD, YYYY",
    demo = false, -- ONLY after the release is real and reviewed
    summary = "One-sentence summary.",
    overview = "A slightly longer overview for the Version Summary panel.",
    highlights = {
        "One verified highlight",
        "Another verified highlight",
    },
    entries = {
        {
            category = "NEW", -- or IMPROVED / POLISHED / FIXED / etc.
            title = "One verified change",
            description = "What changed and why it matters for players.",
            symbol = "scroll", -- scroll / parchment / gear / swords
            -- target = "setting:iconMode", -- only if registered in Search
        },
    },
},
```

If `overview` is omitted, Version Summary uses `summary`. If `highlights` is omitted, the panel uses the first three entry titles. Related Settings is shown only if one entry has an existing Search target; otherwise the panel explains that there is no direct link. With more versions, the vertical rail scrolls rather than creating another horizontal navigation row. All rendering uses the existing `Style`, `Motion`, `Widgets`, `Navigation`, `Search` and `Settings` owners.

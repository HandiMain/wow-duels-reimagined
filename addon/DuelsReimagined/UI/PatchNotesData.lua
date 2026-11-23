local _, ns = ...

-- Prototype-only version catalogue. ONE owner supplies both sidebar navigation
-- and the patch page. These are not addon versions or actual release notes.
-- Add one reviewed record at the front to populate the version rail, Search
-- and all update cards automatically. Set demo=false only for a real release.
-- Optional fields: overview, highlights={...}, entry.target=registered setting.
ns.PatchNotesData = {
    {
        key = "v0-1-2", id = "demo-patch-v0.1.2-interface",
        version = "v0.1.2", navTitle = "Latest Update", demo = true,
        title = "Test Build — Interface Refinement",
        date = "Nov 19, 2026",
        summary = "A more polished home for Duels updates.",
        overview = "A focused update that refines the interface, improves core controls, and polishes key interaction flows based on ongoing testing and feedback.",
        highlights = {
            "Redesigned Patch Notes experience",
            "Clearer update summaries and change types",
            "Improved discoverability of related settings",
        },
        entries = {
            { category = "NEW", title = "A new home for Patch Notes",
              description = "Explore each update by version and discover related settings.",
              symbol = "scroll" },
            { category = "IMPROVED", title = "Minimap button controls",
              description = "Demo preview of the widget size, transparency and compartment options.",
              symbol = "gear", target = "setting:iconMode" },
            { category = "POLISHED", title = "Navigation and search",
              description = "An example of how interface refinements can be presented clearly.",
              symbol = "swords" },
        },
    },
    {
        key = "v0-1-1", id = "demo-patch-v0.1.1-patch-notes",
        version = "v0.1.1", navTitle = "Patch Notes", demo = true,
        title = "Test Build — Patch Notes",
        date = "Nov 18, 2026",
        summary = "A sample changelog from an earlier test iteration.",
        entries = {
            { category = "NEW", title = "Updates have their own page",
              description = "A dedicated changelog keeps the Hall uncluttered.",
              symbol = "scroll" },
            { category = "IMPROVED", title = "Better interface controls",
              description = "Sample notes for Peek, Fold and interface preferences.",
              symbol = "gear", target = "setting:autoPeekMoving" },
            { category = "POLISHED", title = "Shared UI motion",
              description = "An example update about subtle entrance and hover feedback.",
              symbol = "swords" },
        },
    },
    {
        key = "v0-1-0", id = "demo-patch-v0.1.0-foundation",
        version = "v0.1.0", navTitle = "Foundation", demo = true,
        title = "Test Build — The Foundation",
        date = "Nov 17, 2026",
        summary = "A fictional look back at the beginning.",
        entries = {
            { category = "NEW", title = "The Hall",
              description = "An example announcement for the dueling home screen.",
              symbol = "swords" },
            { category = "NEW", title = "Community",
              description = "An example summary of community credits and contributions.",
              symbol = "scroll" },
            { category = "IMPROVED", title = "Appearance options",
              description = "Sample notes about the addon font and color preferences.",
              symbol = "gear", target = "setting:fontChoice" },
        },
    },
    -- Fictional archive examples: exercise the compact, growing Versions rail.
    -- They are explicitly NOT released builds or real changelog evidence.
    {
        key = "v0-0-9", id = "demo-patch-v0.0.9-archive",
        version = "v0.0.9", navTitle = "Early Preview", demo = true,
        title = "Test Build — Early Preview",
        date = "Nov 16, 2026",
        summary = "A fictional preview of an earlier Duels interface.",
        entries = {
            { category = "DEMO", title = "Sample interface polishing",
              description = "An illustrative change for testing the version archive.",
              symbol = "scroll" },
        },
    },
    {
        key = "v0-0-8", id = "demo-patch-v0.0.8-archive",
        version = "v0.0.8", navTitle = "Early Layout", demo = true,
        title = "Test Build — Early Layout",
        date = "Nov 15, 2026",
        summary = "A fictional earlier layout experiment.",
        entries = {
            { category = "DEMO", title = "Sample panel refinement",
              description = "A placeholder demonstrating an older note format.",
              symbol = "gear" },
        },
    },
    {
        key = "v0-0-7", id = "demo-patch-v0.0.7-archive",
        version = "v0.0.7", navTitle = "First Concept", demo = true,
        title = "Test Build — First Concept",
        date = "Nov 14, 2026",
        summary = "A fictional foundation for archive navigation tests.",
        entries = {
            { category = "DEMO", title = "Sample concept changes",
              description = "Demonstration-only notes with no gameplay claims.",
              symbol = "swords" },
        },
    },
}

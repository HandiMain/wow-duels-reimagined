local _, ns = ...

-- Prototype-only version catalogue. ONE owner supplies both sidebar navigation
-- and the patch page. These are not addon versions or actual release notes.
-- Add a reviewed record at the front to create a new version subcategory.
ns.PatchNotesData = {
    {
        key = "v0-1-2", id = "demo-patch-v0.1.2-interface",
        version = "v0.1.2", navTitle = "Latest Update",
        title = "Test Build — Interface Refinement",
        date = "Nov 19, 2026",
        summary = "A more polished home for Duels updates.",
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
        version = "v0.1.1", navTitle = "Patch Notes",
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
        version = "v0.1.0", navTitle = "Foundation",
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
}

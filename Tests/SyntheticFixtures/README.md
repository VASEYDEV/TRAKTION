# Synthetic fixtures

Committed fixture configurations are deterministic inputs to `FixtureForge`. Generated PNGs are produced during tests and CI so the repository does not treat codec bytes as the golden authority; decoded RGBA pixels are compared instead.

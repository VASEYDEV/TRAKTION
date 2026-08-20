# Initial Repository Layout Checklist

Create these targets/packages before feature expansion:

```text
App/TRAKTION
Packages/TraktionDomain
Packages/TraktionCore
Packages/TraktionVision
Packages/TraktionUI
Packages/TraktionAI
Tools/TraktionLab
Tools/FixtureForge
Tests/Golden
Tests/SyntheticFixtures
Tests/RealWorldFixtures
Tests/Performance
Tests/UITests
```

The first end-to-end executable target should be `TraktionLab`, not the polished iOS application.

Example conceptual CLI:

```text
traktion-lab reconstruct --axis vertical --output composite.png capture-001.png capture-002.png capture-003.png
```

Expected sidecars: `composite.reconstruction.json` plus per-joint difference diagnostics.

First supported constraints: PNG, vertical, equal width, known order, static content, translational overlap. Everything else should fail explicitly until implemented.

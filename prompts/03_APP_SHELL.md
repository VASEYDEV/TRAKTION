# Prompt: Build the TRAKTION App Shell

Implement the first native application flow against mocked reconstruction data.

## User flow
Home → Import → Ordered sequence rail → Reconstruction progress → Reconstructed canvas → Joint inspector → Export preview

## Required interactions
- multi-image selection
- numbered sequence
- drag to reorder
- vertical/horizontal selector in UI, with unsupported capability clearly disabled
- zoomable/scrollable long canvas
- visible joint confidence markers
- mock ghost view
- mock difference view
- top/bottom trim handles
- undo/redo controls
- non-destructive state model

## Constraints
Do not place reconstruction math in the UI package. Do not add provider/model UI. Do not imply unsupported reconstruction capabilities are working. Prioritize clarity and state handling over final branding polish.

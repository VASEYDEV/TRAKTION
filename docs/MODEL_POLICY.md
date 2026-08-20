# TRAKTION Semantic Review Policy

## Purpose

TRAKTION may use one optional visual-language model as a semantic adjudicator for rare ambiguous cases. The model is not part of the pixel reconstruction engine.

## Provider neutrality

Application code refers to a `VisualReviewer` capability, not to a vendor or model name. Exactly one production provider may be active at a time. Provider changes should not require modifications to `TraktionCore`, `TraktionVision`, or `TraktionUI`.

## When semantic review is allowed

Only after deterministic analysis has produced a low-confidence case that is semantic rather than geometric, such as sticky-versus-document content, likely reversed sequence, suspected missing capture, preferred source frame for a dynamic region, or transient UI classification.

## When semantic review is not allowed

Do not ask a model to calculate the exact seam coordinate, directly edit final pixels, fabricate missing text, hallucinate unseen content, or override deterministic failure states without validation.

## Runtime policy

```text
1. Reconstruct locally.
2. Validate every joint locally.
3. If all joints pass, finish with zero model calls.
4. If ambiguity is geometric, retry registration or offer manual alignment.
5. If ambiguity is semantic, create one diagnostic request.
6. Validate the model recommendation against deterministic evidence.
7. Apply only validated, non-destructive actions.
8. Otherwise abstain and request review/recapture.
```

## Payload minimization

Prefer low-resolution contact sheets, disputed overlap crops, nearby context, local OCR text, registration scores, masks, and confidence values. Do not upload the full long image by default.

## Evaluation rule

A provider is selected by TRAKTION-specific evaluation, especially false-safe rate. Do not build a cascade merely because multiple providers are available.

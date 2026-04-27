# NexaLife v0.2.0 Feature / UI Synthesis

- Date: 2026-04-05
- Source inputs:
  - `NexaLife_v0.2.0_revise_plan.pdf`
  - new distribution screenshot: `NexaLife/Docs/release/v0.2.0/Unknown Developer.png`
  - additional idea: AI should not only classify content, but also guide unclear users like a mentor

## 1. Overall Direction

`v0.2.0` should move NexaLife from a "local-first life dashboard" to a more guided system:

- For users with clear goals:
  - the product should stay structured, fast, and non-intrusive
  - AI should assist with summarization, categorization, and review acceleration
- For users who feel uncertain about their future:
  - AI should help identify strengths, repeated patterns, possible directions, and next-step experiments
  - the product should feel like a calm mentor, not a generic chatbot

This means the new version should not only improve module UIs, but also add an upper-layer guidance model.

## 2. Product Thesis for v0.2.0

Suggested product thesis:

> Record the present, understand the pattern, and get guided toward the next stage.

Compared with `v0.1.1`, `v0.2.0` should emphasize three upgrades:

1. Better structure:
   stronger Dashboard / Projects / Goals / Vitals organization
2. Better review:
   daily and weekly reflection become first-class flows
3. Better guidance:
   AI becomes a reflection and direction engine, not only a text utility

## 3. Feature Interpretation from the PDF

### 3.1 First-run / storage choice

The PDF suggests a simplified opening flow:

- first screen: choose `本地存储` or `云端存储`
- next step:
  - local: choose a folder or default local workspace
  - cloud:
    - Apple ID: future native Apple path
    - other providers: route users to documentation / setup pages

Recommendation:

- keep the current `Profile` model
- add a new `Storage Setup` step after profile creation
- do not over-complicate cloud options in `v0.2.0`
- practical scope for `v0.2.0`:
  - `Local`
  - `External Folder`
  - `iCloud (Coming Soon)`

### 3.2 Dashboard redesign

The PDF points to a more informative Dashboard:

- greeting with nickname
- clearer top cards
- stronger pending / total / status statistics
- more visual monitoring widgets

Recommendation:

- top section:
  - greeting
  - date
  - one key AI insight card
- middle section:
  - module cards for `Execution / Knowledge / Lifestyle / Vitals`
  - each card shows one main value and 2-4 status chips
- lower section:
  - inbox pending count
  - overdue task alerts
  - recent trend charts
  - daily review entry point

### 3.3 Execution / Projects / To-do logic

The PDF strongly suggests cleaning up task lifecycle and project management:

- clearer `To-do / In Progress / Done` buckets
- stronger add / edit / delete logic
- project creation via popup
- rethink what happens to past tasks

Recommendation:

- keep only three live states:
  - `To-do`
  - `In Progress`
  - `Done`
- after completion:
  - tasks stay visible for the current cycle
  - then move into archive/history instead of disappearing abruptly
- add a dedicated project manager sheet:
  - add project
  - edit project
  - delete project
  - choose project horizon/template

### 3.4 Goals as a real tracking system

The PDF is very clear here: `Goals` should become a structured tracking module, not just a lightweight list.

Recommendation:

- each goal should have:
  - title
  - description
  - start date
  - target date / duration
  - tracking frequency
  - measurement method
  - optional milestones
- UI modes:
  - card view for overview
  - list/detail view for editing
- add goal templates:
  - health
  - career
  - study
  - finance
  - relationship

## 4. Daily Review and Vitals Direction

### 4.1 Daily Review

The PDF suggests a nightly review flow around `10:00 p.m.` with AI assistance.

This should become a core loop in `v0.2.0`:

- trigger time:
  - local reminder at night
- input:
  - what happened today
  - what was completed
  - what felt heavy
  - what felt energizing
- output:
  - AI summary
  - emotional pattern hint
  - next-day suggestion

### 4.2 Vitals redesign

The PDF implies that `Vitals` should be split more clearly:

- `Core Principles`
- emotional / reflective journal
- `VOID / 树洞` style private emotional outlet

Recommendation:

- keep `Core Principles`
- rename or refine the other tracks into:
  - `Reflection`
  - `Emotion Log`
  - `Inspiration`
- present Vitals as a dual-pane reflection system:
  - left: stable principles
  - right: changing internal state

## 5. New AI Layer: Mentor Mode

This is the strongest new idea and should become the signature of `v0.2.0`.

### 5.1 Why it matters

Right now AI in NexaLife is mostly tactical:

- categorize
- suggest tags
- route inbox items

Your new idea moves AI into strategic guidance:

- for clear users:
  - help them review faster
  - spot blind spots
- for uncertain users:
  - help them discover strengths
  - point out repeated interests
  - surface suitable directions and experiments

### 5.2 Recommended framing

Do not position this as "AI tells you who you are".

Better framing:

- `AI Reflection`
- `AI Mentor`
- `Direction Guidance`

The tone should be:

- observational
- hypothesis-driven
- suggestive, not absolute

### 5.3 Recommended product design

Add a new AI guidance card to Dashboard:

- `What seems to energize you recently`
- `Patterns I noticed this week`
- `Possible strengths emerging`
- `A next experiment to try`

Add a weekly reflection output:

- repeated topics
- emotional trend
- task completion pattern
- interest clusters
- suggested direction for next week

### 5.4 Data sources the mentor layer should use

- Inbox captures
- task categories and completion rhythm
- notes topics
- goal progress entries
- vitals logs
- relationship/contact signals when relevant

## 6. Recommended v0.2.0 Scope

To keep the release focused, I would recommend this priority split:

### P0

- Dashboard redesign
- Execution state cleanup
- Goals tracking redesign
- nightly daily review flow
- first version of AI mentor summary

### P1

- new storage setup onboarding
- Vitals information architecture refresh
- weekly AI reflection report

### P2

- deeper adaptive coaching
- richer templates
- more complex cloud onboarding for non-Apple providers

## 7. Distribution Implication

The new screenshot `Unknown Developer.png` is a reminder that the current distribution path still causes trust friction.

For `v0.2.0`, distribution should be upgraded alongside product changes:

- sign with `Developer ID Application`
- notarize the archive
- staple the ticket where applicable
- publish the signed ZIP through GitHub Releases
- add a Homebrew Cask install path

This is not just release engineering work; it directly affects user trust and first-run conversion.

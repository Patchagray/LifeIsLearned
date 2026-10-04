# The illustrated reading room

Handoff 002 design decision, established before implementation. The book and its ideas lead; controls support reading. No invented publisher covers, activity, or rewards.

## Semantic palette

| Role | Light | Dark | Use |
| --- | --- | --- | --- |
| Paper | #F7F3E9 | #151F20 | Main canvas |
| Surface | #FFFCF5 | #202D2E | Raised reading/import surfaces |
| Ink | #203333 | #F3EEE2 | Titles and body |
| Secondary ink | #596966 | #B8C6BF | Metadata; never low-opacity body text |
| Teal | #205C56 | #A2D7C5 | Actions and progress |
| On teal | #FFFFFF | #132D28 | Primary-button text |
| Amber | #855118 | #EAC087 | Reflection and retry |
| Rule | #CFD6CD | #4A5E59 | Separators and borders |

Use system dynamic colors from these tokens. Selected feedback uses text and symbols in addition to tint. Disabled actions retain their shape, use secondary ink, and expose disabled accessibility state.

## Type and spacing

System serif: editorial headlines and narration. System sans: controls, numbers, metadata. Dynamic Type throughout; no body-text shrinking. Title 34 pt, feature 28 pt, section 22 pt, body 20 pt, controls 17 pt, metadata 13 pt at default scale. Long titles wrap.

Spacing: 4, 8, 12, 16, 24, 32, 48 pt. Reading width: 640 pt. Home maximum: 1040 pt. Phone margins: 24 pt (20 in compact controls). Minimum target: 44 pt.

## Surface hierarchy and artwork

Paper canvas; editorial sections separated by fine rules; one featured learning composition; library as an adaptive grid of portrait covers with aligned text below. Book ideas are numbered rows, not nested cards. Restrained 16/24 pt corners for actionable panels; 10 pt covers with a fine spine and typographic attribution. Supplied covers preserve aspect ratio within 3:4; illustrations fit their original aspect ratio, adjacent to the associated title before long prose. Decorative placeholder covers are labeled as such for accessibility.

## Control and motion rules

Primary action: filled teal, rounded rectangle, clear verb. Secondary: outlined or text with a 44 pt target. Pressed state: subtle tint and 0.98 scale, 0.16 s; Reduce Motion removes scale. Reveal and feedback: 0.2 s opacity transition, no delayed interactions. Progress transitions stay subtle. Narration follows actual speech callbacks; animation never drives playback or advances a lesson. Preserve manual scrolling priority and VoiceOver's existing no-auto-follow behavior.

## Review gate

Render home, detail, reader, takeaway, practice/feedback, completion, import, and settings. Inspect iPhone/iPad, narrow/landscape, long titles, missing covers, empty/search states, large text, light/dark. Capture real simulator-hosted views; label synthetic content and injected states. Correct the weakest visual issue before delivery. Build success alone is not design acceptance.

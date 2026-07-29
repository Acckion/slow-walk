# Medicine MVP Demo Fixtures

These fixtures are deterministic integration assets for the Day 1 iOS
Medicine MVP. They are synthetic and must always be presented with:

`DEMO DATA — NOT FOR CLINICAL USE`

## What a JSON fixture is

Each JSON fixture is a **canonical pipeline golden output**. The `response`
object is byte-level meaning-identical to the `MedicineAssessmentResponseDTO`
produced when the same `request` is sent through the real server pipeline
(`makeSlowWalkApplication` with a fixed clock): resolver, health-context
validation, risk engine, action-card factory, medicine pipeline, knowledge
service, and controller response mapping all run in their production form.

`MedicineDemoFixtureGoldenTests` in `server/Tests/SlowWalkServerTests/`
re-runs every fixture request through that live pipeline and asserts full DTO
equality against the stored response. Fixtures must therefore only be
regenerated from a real pipeline run, never edited by hand to match a hoped
for output.

## Frozen IDs

| Fixture ID | File | Coordinator view state | Presentation variant |
| --- | --- | --- | --- |
| `normal` | `medicine-normal.json` | `result` | `normal` |
| `ambiguous` | `medicine-ambiguous.json` | `requiresMedicineConfirmation` | `ambiguous` |
| `healthWarning` | `medicine-health-warning.json` | `result` | `healthWarning` |
| `knowledgeWarning` | `medicine-source-warning.json` | `requiresMedicineConfirmation` | `knowledgeWarning` |
| `redRisk` | `medicine-red-risk.json` | `result` | `redRisk` |
| `timeout` | `medicine-timeout.md` | `failed` | `timeout` |

`knowledgeWarning` lands in `requiresMedicineConfirmation` because the real
pipeline marks stale offline knowledge as requiring user confirmation
(`resolution.requiresUserConfirmation == true`), and
`MedicineAssessmentCoordinator` maps that state to the confirmation page even
though `resolution.status` is `resolved`.

## JSON envelope

Each JSON file contains:

- `fixtureID`: the frozen scenario identifier.
- `disclaimer`: the required demo safety label.
- `request`: a canonical `MedicineAssessmentRequestDTO`.
- `response`: the canonical `MedicineAssessmentResponseDTO` the live server
  pipeline returns for that request.
- `expectation`: stable assertions for presentation and demo narration.

The response is intentionally stored with the request. The integration layer
can decode `response` and return it from `MockMedicineAssessmentRequester`
without starting the server. The server golden tests prove the stored
response equals the live pipeline output, so the mock cannot drift from the
server without a red test.

`expectedViewState` names the existing `MedicineAssessmentViewState` case.
`expectedPresentationVariant` is presentation metadata, not a new Core public
API. No fixture contains supported dosage instructions.

## DEMO DATA responsibilities

The label is carried at two product layers:

- **Fixture payload**: every selected or candidate medicine carries the
  `DEMO DATA — NOT FOR CLINICAL USE` warning, the response `disclaimer`
  field repeats it, and `healthContextValidation.configurationNotices`
  includes `NOT FOR CLINICAL USE` plus the demo data-quality notice.
- **App shell**: the demo UI must render the same label visibly on every
  page. The fixture makes the label available; rendering it is the shell's
  responsibility.

## Why `timeout` is not a JSON response fixture

The timeout scenario is a client transport failure, not an HTTP response.
`MockMedicineAssessmentRequester(.timeout)` throws
`ClientTransportError.timedOut` before any response exists, so there is no
canonical response JSON to record. `medicine-timeout.md` documents the
scenario without fabricating one.

## Canonical strings

Values such as `matcherVersion` (`slowwalk-resolver-v1`), rule identifiers
(for example `allergy-match`, `body-metrics-data-quality`,
`medicine-knowledge-source-safety`), warning codes, messages, and
`sourceDataVersion` (the mock knowledge source version pair) are produced by
production code. They are frozen here by golden test equality, not by
convention.

# Medicine MVP Demo Fixtures

These fixtures are deterministic integration assets for the Day 1 iOS
Medicine MVP. They are synthetic and must always be presented with:

`DEMO DATA — NOT FOR CLINICAL USE`

## Frozen IDs

| Fixture ID | File | Coordinator view state | Presentation variant |
| --- | --- | --- | --- |
| `normal` | `medicine-normal.json` | `result` | `normal` |
| `ambiguous` | `medicine-ambiguous.json` | `requiresMedicineConfirmation` | `ambiguous` |
| `healthWarning` | `medicine-health-warning.json` | `result` | `healthWarning` |
| `knowledgeWarning` | `medicine-source-warning.json` | `result` | `knowledgeWarning` |
| `redRisk` | `medicine-red-risk.json` | `result` | `redRisk` |
| `timeout` | `medicine-timeout.md` | `failed` | `timeout` |

## JSON envelope

Each JSON file contains:

- `fixtureID`: the frozen scenario identifier.
- `disclaimer`: the required demo safety label.
- `request`: a canonical `MedicineAssessmentRequestDTO`.
- `response`: a canonical `MedicineAssessmentResponseDTO`.
- `expectation`: stable assertions for presentation and demo narration.

The response is intentionally stored with the request. The integration layer
can decode `response` and return it from `MockMedicineAssessmentRequester`
without starting the server. Server contract tests decode both canonical DTOs
to prevent fixture drift.

`expectedViewState` names the existing `MedicineAssessmentViewState` case.
`expectedPresentationVariant` is presentation metadata, not a new Core public
API. No fixture contains supported dosage instructions.


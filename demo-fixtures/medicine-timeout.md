# Medicine timeout fixture

## Identity

- Fixture ID: `timeout`
- Disclaimer: `DEMO DATA — NOT FOR CLINICAL USE`
- Endpoint: `POST /api/v1/medicine/assess`
- Mock behavior: `MockMedicineAssessmentBehavior.timeout`

## Input

Use the same canonical `MedicineAssessmentRequestDTO` as `normal`, changing
only `requestID` to `00000000-0000-0000-0000-000000000106`.

The OCR input remains:

```json
{
  "recognizedTexts": ["Acetaminophen"],
  "capturedAt": "2026-07-25T07:59:00Z",
  "languageCode": "en",
  "rawConfidence": 0.98
}
```

## Expected result

- Expected risk level: none; no response was received and the client must not
  invent a risk result.
- Expected page state: `MedicineAssessmentViewState.failed`.
- Expected presentation variant: `timeout`.
- Expected ActionCard: none.
- Ordinary medicine explanation allowed: no.
- Suggest contacting family: no.
- Suggest contacting a healthcare professional: no.
- Retry allowed: yes, only after an explicit user action.

## Simulation boundary

The timeout is a client transport scenario, not an HTTP response fixture.
`MockMedicineAssessmentRequester(.timeout)` throws
`ClientTransportError.timedOut`; `ClientFailureMapper` then creates the stable
recoverable failure state. Do not encode a fabricated `APIErrorDTO`, risk
level, or medicine instruction for this scenario.


# CalPal Smoke Automation Contract

This contract lists the stable accessibility identifiers that release smoke tests may rely on. It is intentionally Simulator-first: automated verification must use iOS Simulator targets only, while owner-run TestFlight checks remain recorded in `AppStore/APP_STORE_PUBLIC_RELEASE_EVIDENCE.md`.

## Home Navigation

- id: `commandHomeSettings`
  purpose: Open Settings from the home screen.
- id: `commandHomeToday`
  purpose: Return agenda focus to today without relying on localized copy.

## Agenda

- id: `agendaTimeline`
  purpose: Confirm the agenda timeline rendered.
- id: `agendaLoadingPlaceholder`
  purpose: Confirm loading uses the skeleton placeholder.
- id: `emptyAgendaManualCreate`
  purpose: Open manual create from an empty day.
- id: `agendaFailurePrimaryAction`
  purpose: Exercise primary agenda recovery.
- id: `agendaFailureSecondaryAction`
  purpose: Exercise secondary agenda recovery.

## Command Processing

- id: `processingCard`
  purpose: Confirm command work is visibly in progress.
- id: `processingCancel`
  purpose: Cancel active parser, speech, or calendar work.
- id: `resultParseRoute`
  purpose: Confirm AI-vs-fallback route evidence appears on results.
- id: `resultOpenInCalendar`
  purpose: Open the saved result in Apple Calendar.

## Text Entry

- id: `calendarCommandTextField`
  purpose: Enter natural-language commands.
- id: `textCommandSend`
  purpose: Submit a typed command from the primary button.
- id: `textCommandToolbarSend`
  purpose: Submit a typed command from the toolbar button.
- id: `textCommandReadinessHint`
  purpose: Confirm send-readiness feedback.

## Manual And Correction Forms

- id: `manualEventSave`
  purpose: Save a manually entered event.
- id: `correctionSaveEvent`
  purpose: Save a corrected parser draft.
- id: `targetCalendarRow`
  purpose: Confirm the pre-save write target is visible.
- id: `draftSaveReadinessHint`
  purpose: Confirm save-readiness feedback.
- id: `correctionParseRoute`
  purpose: Confirm parser-route evidence survives correction.

## Confirmation And Candidate Review

- id: `confirmationPrimaryAction`
  purpose: Apply a confirmed create, update, or delete.
- id: `confirmationParseRoute`
  purpose: Confirm parser-route evidence on confirmation sheets.
- id: `confirmationRecurrenceScopeReview`
  purpose: Confirm recurring-event scope impact copy.
- id: `candidateParseRoute`
  purpose: Confirm parser-route evidence on candidate selection.

## Event Detail

- id: `eventDetailTitle`
  purpose: Confirm the detail sheet opened for the expected event.
- id: `eventDetailTitleField`
  purpose: Edit an event title before review.
- id: `eventDetailReviewUpdate`
  purpose: Open update confirmation from event detail.
- id: `eventDetailReviewHint`
  purpose: Confirm quick-update readiness feedback.

## Settings And Readiness

- id: `settingsSection-language`
  purpose: Target default-calendar settings.
- id: `settingsSection-automation`
  purpose: Target safety-mode settings.
- id: `settingsSection-diagnostics`
  purpose: Target readiness diagnostics.
- id: `settingsSection-privacy`
  purpose: Target local-preferences settings.
- id: `refreshReadiness`
  purpose: Refresh capability diagnostics in place.
- id: `readinessSummary`
  purpose: Confirm aggregate readiness summary.
- id: `safetyModeAutoReview`
  purpose: Confirm the truthful safety-mode row.
- id: `readinessItem-calendar-access`
  purpose: Confirm Calendar access readiness row.
- id: `readinessItem-foundation-models`
  purpose: Confirm Foundation Models route readiness row.
- id: `readinessItem-calendar-open`
  purpose: Confirm Apple Calendar opening manual gate.
- id: `readinessItem-store-assets`
  purpose: Confirm store-materials manual gate.

## Recovery Actions

- id: `unavailableAction-openTextEntry`
  purpose: Open typed fallback.
- id: `unavailableAction-openManualCreate`
  purpose: Open manual create when Calendar access is available.
- id: `unavailableAction-openSettings`
  purpose: Open CalPal diagnostics.
- id: `unavailableAction-openSystemSettings`
  purpose: Open iOS Settings for denied permissions.
- id: `unavailableAction-dismiss`
  purpose: Dismiss an unavailable-state sheet.

## Sheet Dismissal

- id: `textEntryCancel`
  purpose: Dismiss text entry.
- id: `manualEventCancel`
  purpose: Dismiss manual create.
- id: `correctionCancel`
  purpose: Dismiss correction.
- id: `confirmationToolbarCancel`
  purpose: Cancel confirmation from the toolbar.
- id: `confirmationSecondaryCancel`
  purpose: Cancel confirmation from the content action.
- id: `candidateSelectionCancel`
  purpose: Dismiss candidate selection.
- id: `eventDetailDone`
  purpose: Dismiss event detail.
- id: `calendarChooserCancel`
  purpose: Dismiss calendar chooser.
- id: `settingsDone`
  purpose: Dismiss Settings.

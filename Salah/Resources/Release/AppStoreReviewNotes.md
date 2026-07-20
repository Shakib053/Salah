# App Store Review Notes

Salah is a free, account-free, charitable prayer-time and prayer-tracking app.

- Location permission is requested only after the user selects “Use Current Location” from the educational location screen. It is used for a one-shot prayer-time calculation request. Manual Bangladesh district selection and a visibly identified Dhaka fallback remain available when permission is denied.
- Notification permission is requested only after the user enables their first prayer or fasting reminder and continues from the reminder education sheet. All reminders are local notifications and may be disabled independently.
- Prayer completion records are stored locally using SwiftData. No login, advertising, analytics, or tracking SDK is present.
- The app sends the selected coordinate and calculation parameters to AlAdhan to retrieve prayer times.
- A network connection is not required for tracker use; previously cached prayer times remain available offline.
- Prayer timings may vary by calculation settings and local authority. The accuracy disclaimer appears in About and calculation settings.

Suggested review path: complete or skip onboarding, choose Dhaka manually, open Today, mark a prayer complete, then enable a reminder from More > Prayer Reminders.

# App Store Review Notes

Salah is a free, account-free, charitable prayer-time and prayer-tracking app.

- Location permission is requested only after the user selects “Use Current Location” from the educational location screen. One approximate coordinate is used for on-device prayer-time calculation. It is not sent to a prayer-time service. Manual Bangladesh district selection and a visibly identified Dhaka fallback remain available when permission is denied.
- Notification permission is requested only after the user enables their first prayer or fasting reminder and continues from the reminder education sheet. All reminders are local notifications and may be disabled independently.
- Prayer completion records are stored locally using SwiftData. No login, advertising, analytics, or tracking SDK is present.
- Prayer times are calculated locally with the MIT-licensed Adhan Swift library; Hijri dates use Apple's on-device calendar framework.
- A network connection is not required for prayer schedules, reminders, widgets, Qibla, or tracker use.
- Prayer timings may vary by calculation settings and local authority. The accuracy disclaimer appears in About and calculation settings.

Suggested review path: complete or skip onboarding, choose Dhaka manually, open Today, mark a prayer complete, then enable a reminder from More > Prayer Reminders.

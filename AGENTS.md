# ThesisTrack

Flutter app for thesis and capstone students and their advisers. Students upload chapter versions. Advisers review them, comment, set a status, and schedule the defense.

Run and test in Chrome only: `flutter run -d chrome`. Backend is Firebase on the free Spark plan: Authentication (Email/Password) and Cloud Firestore. No Firebase Storage, no Cloud Functions, no billing.

## How to work with me
- The developer is new to Flutter and Firebase and has limited daily hours. Explain things in plain language.
- Build ONE step at a time from "Build order" below. Do not build ahead. After each step, stop and tell me exactly how to test it.
- Keep it simple. Use StatefulWidget, `setState`, and `StreamBuilder` on Firestore streams. No Provider, Bloc, Riverpod, or GetX.
- Allowed packages: `firebase_core`, `firebase_auth`, `cloud_firestore`, `file_picker`, `intl`. Ask before adding any other package.
- Do NOT use `open_filex` or `path_provider`. They do not work in Chrome.
- Do not add screens, features, or notifications that are not listed here.
- Code layout: one file per screen in `lib/screens/`. Put Firestore calls in `lib/services/` so screens stay short.
- Wrap the whole app in a centered box about 480 px wide so it looks like a phone screen in the browser.
- Use the exact messages written below.

## Roles
Two roles, chosen at registration: `student` and `adviser`. The role decides which home screen opens after login. Registration is part of the Login use case.

## Decisions (already approved)
- A student creates a group: group name plus an adviser picked from the list of registered advisers. The app generates a short group code. Other students join with that code. One group per student.
- Chapters 1 to 5 are created automatically when a group is created.
- Chapter status values: `pending` (default), `for_revision`, `approved`.
- Uploading a new version after `for_revision` sets the status back to `pending`.
- An `approved` chapter does not accept new uploads (the Upload Version button is disabled).
- A venue counts as booked when the venue, date, and time all match an existing schedule.

## Business rules and exact messages
**Upload Chapter Version (student)**
- Only DOCX or PDF, under 700 KB. Anything else is rejected, nothing is saved, and the message is: `File must be a DOCX or PDF under 700 KB.`
- Next version number = the chapter's `versionCount` + 1. Save the version record and the file content, then show `Version saved`.
- Earlier versions are always kept.
- On web, `file_picker` has no file path. Use `pickFiles(withData: true)` and read `file.bytes`.

**Review Chapter and Set Status (adviser)**
- The adviser must be assigned to the group and the chapter must have at least one version.
- A status must be chosen. A comment is required when the status is `for_revision`. If it is missing, save nothing and show: `Please add a comment explaining what needs revision.`
- Save the comment (text, author, date) and update the chapter status. The student's screen updates live.

**Schedule Defense (adviser)**
- All fields are required: group, date, time, venue. The date cannot be in the past.
- If the venue is already booked at that date and time, save nothing and show: `This venue is already booked at that time. Please choose another.`
- Build editing and deleting a schedule last. It is optional.

## Firestore data
- `users/{uid}`: name, email, role
- `groups/{groupId}`: name, code, adviserId, memberIds (list of uids)
- `groups/{groupId}/chapters/{chapterId}`: number (1 to 5), status, versionCount
- `groups/{groupId}/chapters/{chapterId}/versions/{versionId}`: versionNumber, fileName, uploaderId, uploadedAt. NO file bytes here, so the version list stays light.
- `fileData/{versionId}`: bytes (Firestore Blob, raw bytes, not base64 text), groupId
- `groups/{groupId}/chapters/{chapterId}/comments/{commentId}`: text, authorId, authorName, status, createdAt
- `defenses/{defenseId}`: groupId, adviserId, venue, venueKey (venue trimmed and lowercase, used for the conflict check), dateTime (Timestamp), createdAt. Top-level because the venue check looks across all groups.

## Screens (9 total)
1. **Login** (both roles): email, password, Login button, Register link.
2. **Register** (both roles): name, email, password, role dropdown, Register button.
3. **Create or Join Group** (student): create form (name, adviser dropdown) and join form (group code).
4. **Student Home** (dashboard): group code, defense schedule card, 5 chapter cards with status labels. Tapping a card opens Chapter Detail.
5. **Chapter Detail** (student, main transaction page): status, Upload Version button, version list with an Open button, adviser comments.
6. **Adviser Home** (dashboard): list of the adviser's groups with a count of chapters waiting for review.
7. **Group Page** (adviser): defense schedule, Add Defense Schedule button, 5 chapter rows with status and a waiting-for-review mark.
8. **Review Chapter** (adviser): latest version with Open File, comment box, For Revision and Approved buttons, comment history.
9. **Defense Form** (adviser): group (read-only), date picker, time picker, venue, Save Schedule.

"Waiting for review" means the chapter has a version and its status is `pending`.

## Opening files in Chrome
The Open button must download the file (or open a PDF in a new tab) through the browser. Do not guess the method. At Build step 3, propose one simple approach and wait for my approval.

## Build order
1. Register, login, and the role-based home screen. (Firebase is already connected.)
2. Groups: create, join with code, auto-create 5 chapters.
3. Chapters, upload, version list, and the Open/Download button. Test opening a file in Chrome FIRST, because it is the riskiest part.
4. Review, comments, and status.
5. Defense schedule and venue check.
6. Polish, empty states ("No versions yet", "No defense scheduled"), Firestore security rules, and testing.

## Firestore rules
The database started in test mode, which stops working about 30 days after creation. In step 6, replace it with real rules: users read their own profile, only group members read and write their group's data, and only the assigned adviser can review chapters and set schedules for that group.

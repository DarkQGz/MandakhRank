# Flutter test fix

Extract this ZIP into C:\Users\dquat\Documents\GitHub\mandakhrank and replace the three matching files. The ZIP begins with frontend/, so do not extract it into the frontend folder itself.

Changed:
- frontend/lib/auth_screen.dart: stable verification-email key; ignore a response after the screen is disposed.
- frontend/test/auth_test.dart: captured requests and controlled response completion; assertions run outside the HTTP callback so application error handling cannot hide their failures; bounded wait for the session; cleanup.
- frontend/test/widget_test.dart: select the Text title rather than matching the EditableText search input as well; cleanup.

Run from project root:
  .\scripts\build-web.ps1

Dart syntax parsing passed. Flutter tests were not run in this environment. The ambiguous navigation finder is corrected; the null-session failure is not confirmed resolved until these tests run. If auth still fails, the updated test reports the request mismatch or screen error instead of only a null session. Do not skip tests.

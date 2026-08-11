/// Firebase Hosting is where the public, no-login Grooming Result page
/// lives (public_hosting/result.html in the repo root, deployed via
/// `firebase deploy --only hosting`) -- a completely separate surface
/// from this Flutter app. `tib-grooming` is this project's real
/// Firebase project ID (see firebase_options.dart); Hosting's default
/// domain for any project is always `https://<project-id>.web.app`,
/// with no extra setup beyond `firebase deploy --only hosting` once
/// (see the Hosting section of the delivery notes for the full
/// one-time setup).
///
/// `/result/<token>` is rewritten to `/result.html` by firebase.json's
/// hosting.rewrites -- the page itself reads the token back out of
/// `location.pathname`.
const String kPublicResultBaseUrl = "https://tib-grooming.web.app/result";

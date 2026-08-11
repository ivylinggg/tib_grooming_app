function doPost(e) {
  try {

    const folderId = "1E4EohTS3iZBvUrS4s3Yj5ymDj5LxCFf8";

    Logger.log("doPost: START");

    const body = JSON.parse(e.postData.contents);

    Logger.log("doPost: body parsed OK");
    Logger.log("doPost: request keys = " + JSON.stringify(Object.keys(body)));

    // ==========================
// Claude AI Analyze
// ==========================
const action = body.action || body.type;
Logger.log("doPost: received action = " + action);

if (action === "analyze") {

  Logger.log("ENTERING ANALYZE BRANCH");

  const result = analyzeImage(
    body.referenceB64,
    body.referenceMime,
    body.todayB64,
    body.todayMime
  );

  Logger.log("LEAVING ANALYZE BRANCH -- analyzeImage() returned, success=" + result.success);

  return ContentService
    .createTextOutput(JSON.stringify(result))
    .setMimeType(ContentService.MimeType.JSON);

}

if (action === "detectPerson") {

  Logger.log("ENTERING DETECT PERSON BRANCH");

  const result = detectPersonImage(body.imageBase64, body.mimeType);

  Logger.log("LEAVING DETECT PERSON BRANCH -- detectPersonImage() returned, success=" + result.success);

  return ContentService
    .createTextOutput(JSON.stringify(result))
    .setMimeType(ContentService.MimeType.JSON);

}

Logger.log("ENTERING IMAGE UPLOAD BRANCH");

    const bytes = Utilities.base64Decode(body.image);

    const blob = Utilities.newBlob(
      bytes,
      body.mimeType || "image/jpeg",
      body.fileName || ("image_" + Date.now() + ".jpg")
    );

    const folder = DriveApp.getFolderById(folderId);

    const file = folder.createFile(blob);

    file.setSharing(
      DriveApp.Access.ANYONE_WITH_LINK,
      DriveApp.Permission.VIEW
    );

    const imageUrl =
  "https://drive.google.com/uc?export=view&id=" + file.getId();

    Logger.log("LEAVING IMAGE UPLOAD BRANCH -- upload succeeded");

    return ContentService
  .createTextOutput(
    JSON.stringify({
  success: true,
  fileId: file.getId(),
  imageUrl: imageUrl
})
  )
  .setMimeType(ContentService.MimeType.JSON);

  } catch (err) {

    // Diagnostic-only addition: err.toString() alone drops the file and
    // line the exception actually came from -- err.stack keeps both, and
    // Apps Script includes the source filename in each stack frame for a
    // multi-file project, so this pinpoints exactly which .gs file threw,
    // even if it's a file that isn't Code.gs or Claude.gs.
    Logger.log("doPost: CAUGHT EXCEPTION");
    Logger.log("doPost: err.toString() = " + err.toString());
    Logger.log("doPost: err.stack = " + err.stack);

    return ContentService
      .createTextOutput(
        JSON.stringify({
          success: false,
          error: err.toString(),
          stack: err.stack
        })
      )
      .setMimeType(ContentService.MimeType.JSON);

  }
}

function doGet() {
  return ContentService
    .createTextOutput(
      JSON.stringify({
        status: "running",
        service: "TiB AI Grooming Upload API"
      })
    )
    .setMimeType(ContentService.MimeType.JSON);
}
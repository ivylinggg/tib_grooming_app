function doPost(e) {
  try {

    const folderId = "1E4EohTS3iZBvUrS4s3Yj5ymDj5LxCFf8";

    const body = JSON.parse(e.postData.contents);

    // ==========================
// Claude AI Analyze
// ==========================
Logger.log("Request Type: " + body.type);

if (body.type === "analyze") {

  Logger.log("Analyze Request Received");

  const result = analyzeImage(
    body.referenceB64,
    body.referenceMime,
    body.todayB64,
    body.todayMime
  );

  return ContentService
    .createTextOutput(JSON.stringify(result))
    .setMimeType(ContentService.MimeType.JSON);

}

Logger.log("Upload Request Received");

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

    return ContentService
      .createTextOutput(
        JSON.stringify({
          success: false,
          error: err.toString()
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
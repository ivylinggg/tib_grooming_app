function _getClaudeKey() {
  const key = PropertiesService.getScriptProperties().getProperty("CLAUDE_KEY");

  if (!key) {
    throw new Error(
      "CLAUDE_KEY not found. Please configure it in Script Properties."
    );
  }

  return key;
}

// Canonical "overall" vocabulary is exactly: Excellent, Good, Needs Work,
// Insufficient -- must match lib/models/overall_result.dart on the
// Flutter side. Claude is instructed to return only these four, but LLM
// output isn't guaranteed, so known natural variations are mapped to
// their canonical value here. Add new aliases as they're observed in
// practice -- this is not meant to be exhaustive up front.
var OVERALL_ALIASES = {
  "excellent": "Excellent",

  "good": "Good",
  "very good": "Good",

  "needs improvement": "Needs Work",
  "need improvement": "Needs Work",
  "needs work": "Needs Work",
  "average": "Needs Work",

  "poor": "Insufficient",
  "bad": "Insufficient",
  "insufficient": "Insufficient"
};

function _normalizeOverall(value) {
  var raw = (value || "")
    .toString()
    .trim()
    .toLowerCase()
    .replace(/[^a-z\s]/g, "") // drop stray punctuation, e.g. "Excellent!"
    .replace(/\s+/g, " ")
    .trim();

  if (Object.prototype.hasOwnProperty.call(OVERALL_ALIASES, raw)) {
    return OVERALL_ALIASES[raw];
  }

  // No alias matched at all.
  return "Insufficient";
}

// Claude routinely answers with its JSON wrapped in a markdown code
// fence -- ```json ... ``` or plain ``` ... ``` -- even when the prompt
// says "Return ONLY valid JSON." That's normal model behavior (markdown
// formatting habit), not a malformed response, so it needs to be
// stripped before JSON.parse rather than surfacing as
// "Claude did not return valid JSON." Falls back to the trimmed original
// text unchanged if there's no fence to strip, so a real parse failure
// still gets reported the same way it always was.
function _stripMarkdownJsonFence(text) {
  var trimmed = (text || "").toString().trim();

  var match = trimmed.match(/^```(?:json)?\s*([\s\S]*?)\s*```$/i);

  if (match) {
    return match[1].trim();
  }

  return trimmed;
}

function analyzeImage(referenceB64, referenceMime, todayB64, todayMime) {

  Logger.log("===== analyzeImage START =====");

  const url = "https://api.anthropic.com/v1/messages";

  const prompt = `You are a senior professional grooming assessor for Batik Air cabin crew. Apply STRICT airline-grade standards.

You are given TWO photos:
- Image 1: REFERENCE photo - approved best-appearance standard
- Image 2: TODAY's check-in photo - score strictly against the reference

STEP 1 - DETECT GENDER:
Look at the reference photo.
Return:
"gender":"male"
or
"gender":"female"

STEP 2 - Score EVERY category independently.

GENERAL RUBRIC:
9-10: Perfect - zero visible flaws
6-8: Meets standard - very minor imperfection
3-5: Borderline - visible issue
2: Clear obvious problem
0-1: Severe violation

SCORING PRINCIPLE:
When uncertain, choose the LOWER score.

────────────────────────
HAIR (FEMALE)
────────────────────────
Major flyaways + unkempt
→ MAX 2

Untidy + flyaways
→ MAX 5

Untidy OR minimal flyaways
→ MAX 7

No issues
→ up to 10

────────────────────────
HAIR (MALE)
────────────────────────
Hair exceeds collar
Hair covers ears
Crown longer than 4 cm
Sideburn exceeds earlobe
Prohibited hairstyle

If ANY above:
→ MAX 3

Otherwise use female hair rules.

────────────────────────
FACIAL GROOMING (MALE)
────────────────────────
Unshaven
→ MAX 3

Visible stubble
→ MAX 5

Minor beard shadow
→ MAX 6

Clean shaven
→ up to 10

────────────────────────
GROOMING (FEMALE)
────────────────────────
No makeup
→ MAX 2

Multiple makeup issues
→ MAX 2

Two makeup issues
→ MAX 4

One makeup issue
→ MAX 7

No issues
→ up to 10

────────────────────────
SKIN CONDITION
────────────────────────
Visible blemishes
→ MAX 5

Minor redness
→ MAX 7

Healthy skin
→ up to 10

────────────────────────
UNIFORM
────────────────────────
Creases or stains
→ MAX 4

Slight creases
→ MAX 6

Perfect uniform
→ up to 10

────────────────────────
SHOES
────────────────────────
Dirty or scuffed
→ MAX 3

Slight dullness
→ MAX 6

Clean and polished
→ up to 10

────────────────────────
BODY WEIGHT
────────────────────────
10 = Excellent
8 = Slim healthy
5 = Borderline
3 = Visible excess weight
1 = Overweight
0 = Severe overweight

────────────────────────
STEP 3 - DETERMINE OVERALL
────────────────────────
Based on the average of all category scores, set "overall" to EXACTLY
one of these four values -- no other text, spelling, or capitalization
is allowed:

"Excellent" - average 9-10
"Good" - average 6-8
"Needs Work" - average 3-5
"Insufficient" - average 0-2

────────────────────────
IMPORTANT
────────────────────────
Return ONLY valid JSON.

The "overall" field MUST be exactly one of: "Excellent", "Good",
"Needs Work", "Insufficient". No other value is allowed.

{
  "gender":"female",
  "overall":"Good",
  "criteria":[
    {
      "label":"Hair",
      "score":7,
      "tip":"..."
    },
    {
      "label":"Grooming",
      "score":7,
      "tip":"..."
    },
    {
      "label":"Skin Condition",
      "score":8,
      "tip":"..."
    },
    {
      "label":"Uniform",
      "score":8,
      "tip":"..."
    },
    {
      "label":"Shoes",
      "score":8,
      "tip":"..."
    },
    {
      "label":"Body Weight",
      "score":7,
      "tip":"..."
    }
  ],
  "summary":"Write a concise 2-3 sentence overall grooming assessment comparing today's appearance with the approved reference photo."
}`;

  const payload = {
    model: "claude-sonnet-4-5",
    max_tokens: 2500,
    messages: [
      {
        role: "user",
        content: [
          {
            type: "image",
            source: {
              type: "base64",
              media_type: referenceMime || "image/jpeg",
              data: referenceB64
            }
          },
          {
            type: "image",
            source: {
              type: "base64",
              media_type: todayMime || "image/jpeg",
              data: todayB64
            }
          },
          {
            type: "text",
            text: prompt
          }
        ]
      }
    ]
  };

  const options = {
    method: "post",
    contentType: "application/json",
    headers: {
      "x-api-key": _getClaudeKey(),
      "anthropic-version": "2023-06-01"
    },
    payload: JSON.stringify(payload),
    muteHttpExceptions: true
  };

  try {

    Logger.log("analyzeImage: BEFORE Claude API request");

    const response = UrlFetchApp.fetch(url, options);

    Logger.log("analyzeImage: AFTER Claude API response");

    const code = response.getResponseCode();
    const body = response.getContentText();

    Logger.log("HTTP Code: " + code);
    Logger.log("Claude Raw Response:");
    Logger.log(body);

    const result = JSON.parse(body);

    Logger.log("Model Used: " + (result.model || "Unknown"));

    if (result.error) {
      Logger.log("analyzeImage: RETURNING -- Claude API error");
      return {
        success: false,
        error: result.error.message
      };
    }

    if (!result.content || result.content.length === 0) {
      Logger.log("analyzeImage: RETURNING -- empty content");
      return {
        success: false,
        error: "Claude returned empty content."
      };
    }

    const aiText = result.content[0].text;

    Logger.log("Claude Response:");
    Logger.log(aiText);

    // Claude often wraps its JSON answer in a markdown code fence
    // (```json ... ``` ) even when asked for "ONLY valid JSON" -- that's
    // normal LLM behavior, not an error, so it has to be stripped before
    // JSON.parse rather than treated as a parse failure.
    const cleanedText = _stripMarkdownJsonFence(aiText);

    try {

      const json = JSON.parse(cleanedText);

      json.overall = _normalizeOverall(json.overall);

      json.success = true;

      Logger.log("analyzeImage: RETURNING -- success");

      return json;

    } catch (e) {

      Logger.log("JSON Parse Error");
      Logger.log(aiText);
      Logger.log("analyzeImage: RETURNING -- JSON parse failure, e.stack = " + e.stack);

      return {
        success: false,
        error: "Claude did not return valid JSON.",
        stack: e.stack,
        raw: aiText
      };

    }

  } catch (e) {

    // Diagnostic-only addition: String(e) alone drops the file/line the
    // exception came from -- e.stack keeps both, pinpointing exactly
    // which statement (and which .gs file) actually threw.
    Logger.log("Analyze Exception:");
    Logger.log("analyzeImage: e.toString() = " + e.toString());
    Logger.log("analyzeImage: e.stack = " + e.stack);
    Logger.log("analyzeImage: RETURNING -- exception caught");

    return {
      success: false,
      error: String(e),
      stack: e.stack
    };

  }
}

function detectPersonImage(imageBase64, mimeType) {

  Logger.log("===== detectPersonImage START =====");

  const url = "https://api.anthropic.com/v1/messages";

  const prompt = `Is this a FULL-BODY standing photo of ONE person?

The photo MUST satisfy ALL conditions:

1. Exactly ONE person.
2. Face clearly visible.
3. Hair clearly visible.
4. Entire uniform visible.
5. Shoes clearly visible.
6. Standing upright.
7. Front facing.
8. Arms visible.
9. Legs visible.
10. No body part cropped.
11. Not sitting.
12. Not selfie.
13. Not side view.
14. Entire body fits inside the image.
15. Suitable for airline grooming assessment.

Reply ONLY:

YES

or

NO`;

  const payload = {
    model: "claude-sonnet-4-5",
    max_tokens: 20,
    messages: [
      {
        role: "user",
        content: [
          {
            type: "image",
            source: {
              type: "base64",
              media_type: mimeType || "image/jpeg",
              data: imageBase64
            }
          },
          {
            type: "text",
            text: prompt
          }
        ]
      }
    ]
  };

  const options = {
    method: "post",
    contentType: "application/json",
    headers: {
      "x-api-key": _getClaudeKey(),
      "anthropic-version": "2023-06-01"
    },
    payload: JSON.stringify(payload),
    muteHttpExceptions: true
  };

  try {

    Logger.log("Calling Claude API...");

    const response = UrlFetchApp.fetch(url, options);

    const code = response.getResponseCode();
    const body = response.getContentText();

    Logger.log("HTTP Code: " + code);
    Logger.log("Claude Raw Response:");
    Logger.log(body);

    const result = JSON.parse(body);

    if (result.error) {
      return {
        success: false,
        error: result.error.message
      };
    }

    if (!result.content || result.content.length === 0) {
      return {
        success: false,
        error: "Claude returned empty content."
      };
    }

    const answer = (result.content[0].text || "").trim().toUpperCase();

    Logger.log("Detect Person Answer: " + answer);

    return {
      success: true,
      isFullBody: answer.indexOf("YES") === 0
    };

  } catch (e) {

    Logger.log("Detect Person Exception:");
    Logger.log(e);

    return {
      success: false,
      error: String(e)
    };

  }
}
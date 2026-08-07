const CLAUDE_KEY =
  PropertiesService.getScriptProperties().getProperty("CLAUDE_KEY");

if (!CLAUDE_KEY) {
  throw new Error(
    "CLAUDE_KEY not found. Please configure it in Script Properties."
  );
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
IMPORTANT
────────────────────────
Return ONLY valid JSON.

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
      "x-api-key": CLAUDE_KEY,
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

    Logger.log("Model Used: " + (result.model || "Unknown"));

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

    const aiText = result.content[0].text;

    Logger.log("Claude Response:");
    Logger.log(aiText);

    try {

      const json = JSON.parse(aiText);

      json.success = true;

      return json;

    } catch (e) {

      Logger.log("JSON Parse Error");
      Logger.log(aiText);

      return {
        success: false,
        error: "Claude did not return valid JSON.",
        raw: aiText
      };

    }

  } catch (e) {

    Logger.log("Analyze Exception:");
    Logger.log(e);

    return {
      success: false,
      error: String(e)
    };

  }
}
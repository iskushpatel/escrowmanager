import { GoogleGenerativeAI } from '@google/generative-ai';

const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY);
const model = genAI.getGenerativeModel({ model: 'gemini-1.5-flash' });

const cleanJson = (text) => {
  const cleaned = text.replace(/```json/g, '').replace(/```/g, '');
  return JSON.parse(cleaned);
};

const decomposeProjectIntoMilestones = async ({ title, description, budget, deadline }) => {
  const prompt = `Decompose this project into milestones:

Title: ${title}
Description: ${description}
Total Budget: $${budget}
Deadline: ${deadline}

Return a JSON object with this exact structure:
{
  "milestones": [
    {
      "order": 1,
      "title": "string (short, max 60 chars)",
      "description": "string (2-3 sentences describing what must be built)",
      "checklist": ["specific acceptance criterion 1", "specific acceptance criterion 2", ...],
      "amount": "number (portion of total budget for this milestone)",
      "estimatedDays": "number"
    }
  ]
}

Rules:
- Generate 3 to 6 milestones depending on project complexity
- Checklist items must be specific and verifiable (not vague)
- Amounts must sum exactly to the total budget
- Order milestones logically (earlier milestones are prerequisites)
- Return ONLY the JSON object, no other text`;

  try {
    const result = await model.generateContent(prompt);
    const response = await result.response;
    const text = response.text();
    const jsonResponse = cleanJson(text);
    return jsonResponse.milestones;
  } catch (error) {
    console.error("Error calling Gemini API for milestone decomposition:", error);
    if (error instanceof SyntaxError) {
      throw new Error('Gemini returned invalid JSON for milestone decomposition');
    }
    throw new Error('AI service temporarily unavailable');
  }
};

const evaluateSubmission = async ({ milestoneTitle, milestoneDescription, checklist, workDescription, repoUrl }) => {
    const checklist_items = checklist.map((item, index) => `${index + 1}. ${item}`).join('\n');
    const repoUrl_line = repoUrl ? `Repository: ${repoUrl}` : '';

    const prompt = `Evaluate this freelance submission:

MILESTONE TITLE: ${milestoneTitle}
MILESTONE DESCRIPTION: ${milestoneDescription}

ACCEPTANCE CHECKLIST:
${checklist_items}

FREELANCER SUBMISSION:
${workDescription}
${repoUrl_line}

Score this submission and return a JSON object with this exact structure:
{
  "score": "number (0-100)",
  "decision": "FULL_PAYOUT" | "PARTIAL_PAYOUT" | "REFUND",
  "feedback": "string (2-4 sentences of actionable feedback for the freelancer)",
  "checklistEvaluation": [
    { "item": "checklist item text", "met": "true|false", "comment": "brief comment" }
  ],
  "summary": "string (1 sentence summary for employer)"
}

Decision rules:
- score >= 85: decision must be FULL_PAYOUT
- score 50-84: decision must be PARTIAL_PAYOUT
- score < 50: decision must be REFUND

Return ONLY the JSON object.`;

    try {
        const result = await model.generateContent(prompt);
        const response = await result.response;
        const text = response.text();
        const jsonResponse = cleanJson(text);
        return jsonResponse;
    } catch (error) {
        console.error("Error calling Gemini API for AQA evaluation:", error);
        if (error instanceof SyntaxError) {
            throw new Error('Gemini returned invalid JSON for AQA evaluation');
        }
        throw new Error('AI service temporarily unavailable');
    }
};


export default {
  decomposeProjectIntoMilestones,
  evaluateSubmission,
};

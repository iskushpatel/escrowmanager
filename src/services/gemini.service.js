import Groq from 'groq-sdk';

const groq = new Groq({ apiKey: process.env.GROQ_API_KEY });

const cleanJson = (text) => {
    return JSON.parse(text.replace(/```json/g, '').replace(/```/g, '').trim());
};

const withRetry = async (fn, maxRetries = 3) => {
    for (let attempt = 1; attempt <= maxRetries; attempt++) {
        try {
            return await fn();
        } catch (err) {
            const isRateLimit = err.status === 429 || err.message?.includes('rate');
            if (isRateLimit && attempt < maxRetries) {
                const delay = Math.pow(2, attempt) * 1000;
                await new Promise(r => setTimeout(r, delay));
            } else { throw err; }
        }
    }
};

const detectProjectType = (title, description) => {
    const text = `${title} ${description}`.toLowerCase();
    if (text.match(/mobile|android|kotlin|flutter|ios/)) return 'mobile_app';
    if (text.match(/design|ui|ux|figma|logo|graphics/)) return 'design';
    if (text.match(/content|blog|article|writing/)) return 'content';
    if (text.match(/api|backend|server|database|sql/)) return 'backend';
    return 'fullstack';
};

const decomposeProjectIntoMilestones = async ({ title, description, budget, deadline }) => {
    const safeDescription = description.substring(0, 1000);
    const projectType = detectProjectType(title, description);

    const systemMessage = `You are a technical project manager. Decompose projects into 3-5 milestones. 
    You MUST assign each milestone one of these exact submissionTypes: 'CODE', 'DESIGN', 'CONTENT', or 'DEPLOYMENT'.`;

    const prompt = `Project: ${title}. Description: ${safeDescription}. Budget: $${budget}. 
    Return ONLY JSON:
    {
      "milestones": [
        {
          "order": 1,
          "title": "string",
          "submissionType": "CODE", 
          "description": "string",
          "checklist": ["verifiable item"],
          "amount": 100,
          "estimatedDays": 5
        }
      ]
    }`;

    try {
        const result = await withRetry(() =>
            groq.chat.completions.create({
                model: 'llama-3.3-70b-versatile',
                messages: [
                    { role: 'system', content: systemMessage },
                    { role: 'user', content: prompt }
                ],
                temperature: 0.2,
                response_format: { type: 'json_object' },
            })
        );
        const parsed = cleanJson(result.choices[0].message.content);
        return parsed.milestones;
    } catch (err) {
        console.error('Groq decomposition failed, using fallback.');
        return [{
            order: 1, title: 'Initial Phase', submissionType: 'CODE',
            description: 'Setup and core logic.', checklist: ['Project initialized'],
            amount: budget, estimatedDays: 7
        }];
    }
};

export default { decomposeProjectIntoMilestones };
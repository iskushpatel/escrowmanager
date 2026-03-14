// // src/services/gemini.service.js
// // Uses Groq (free, fast, unlimited) instead of Gemini
// // Drop-in replacement — same exported function names, same return shapes

// import Groq from 'groq-sdk';

// const groq = new Groq({ apiKey: process.env.GROQ_API_KEY });

// const cleanJson = (text) => {
//   return JSON.parse(text.replace(/```json/g, '').replace(/```/g, '').trim());
// };

// // Retry with exponential backoff on rate limit
// const withRetry = async (fn, maxRetries = 3) => {
//   for (let attempt = 1; attempt <= maxRetries; attempt++) {
//     try {
//       return await fn();
//     } catch (err) {
//       const isRateLimit = err.status === 429 || err.message?.includes('rate');
//       if (isRateLimit && attempt < maxRetries) {
//         const delay = Math.pow(2, attempt) * 1000;
//         console.warn(`Rate limited. Retry ${attempt}/${maxRetries} in ${delay}ms`);
//         await new Promise(r => setTimeout(r, delay));
//       } else {
//         throw err;
//       }
//     }
//   }
// };

// // ─── Called by project.controller.js on project creation ─────────────────────
// const decomposeProjectIntoMilestones = async ({ title, description, budget, deadline }) => {
//   const safeDescription = description.substring(0, 2000);

//   const prompt = `Decompose this freelance project into milestones.
// Title: ${title}
// Description: ${safeDescription}
// Total Budget: $${budget}
// Deadline: ${deadline}

// Return ONLY valid JSON, no markdown, no explanation:
// {
//   "milestones": [
//     {
//       "order": 1,
//       "title": "string (max 60 chars)",
//       "description": "2-3 sentences on what must be built",
//       "checklist": ["specific verifiable criterion 1", "criterion 2"],
//       "amount": 150,
//       "estimatedDays": 5
//     }
//   ]
// }
// Rules: 3-5 milestones, amounts sum exactly to ${budget}, checklist items must be testable.`;

//   try {
//     const result = await withRetry(() =>
//       groq.chat.completions.create({
//         model: 'llama-3.3-70b-versatile',
//         messages: [{ role: 'user', content: prompt }],
//         temperature: 0.2,
//       })
//     );
//     return cleanJson(result.choices[0].message.content).milestones;
//   } catch (err) {
//     console.error('Groq milestone decomposition failed, using fallback:', err.message);
//     return [
//       {
//         order: 1, title: 'Project Setup',
//         description: 'Set up project structure, repository, and development environment.',
//         checklist: ['Repository initialized', 'Folder structure documented', 'Dependencies installed'],
//         amount: Math.round(budget * 0.25), estimatedDays: 3,
//       },
//       {
//         order: 2, title: 'Core Implementation',
//         description: 'Build the main features and core functionality.',
//         checklist: ['Core features implemented', 'Basic tests passing', 'Code reviewed'],
//         amount: Math.round(budget * 0.50), estimatedDays: 10,
//       },
//       {
//         order: 3, title: 'Testing & Delivery',
//         description: 'End-to-end testing, bug fixing, and final delivery.',
//         checklist: ['All features tested', 'Bugs fixed', 'Final build documented'],
//         amount: Math.round(budget * 0.25), estimatedDays: 4,
//       },
//     ];
//   }
// };

// // ─── Fallback only — primary path is the agent in groq.service.js ────────────
// const evaluateSubmission = async ({ milestoneTitle, milestoneDescription, checklist, workDescription, repoUrl }) => {
//   const safeWork = workDescription.substring(0, 800);
//   const checklistText = checklist.map((item, i) => `${i + 1}. ${item}`).join('\n');

//   const prompt = `Evaluate this freelance milestone submission. Return ONLY valid JSON.

// MILESTONE: ${milestoneTitle}
// DESCRIPTION: ${milestoneDescription}
// CHECKLIST:\n${checklistText}
// SUBMISSION:\n${safeWork}
// ${repoUrl ? `REPO: ${repoUrl}` : ''}

// Return:
// {
//   "score": 78,
//   "decision": "PARTIAL_PAYOUT",
//   "feedback": "2-4 sentences of actionable feedback",
//   "checklistEvaluation": [{ "item": "text", "met": true, "comment": "reason" }],
//   "summary": "1 sentence for employer"
// }
// Rules: score 85-100 = FULL_PAYOUT, 50-84 = PARTIAL_PAYOUT, 0-49 = REFUND`;

//   const result = await withRetry(() =>
//     groq.chat.completions.create({
//       model: 'llama-3.3-70b-versatile',
//       messages: [{ role: 'user', content: prompt }],
//       temperature: 0.1,
//     })
//   );
//   return cleanJson(result.choices[0].message.content);
// };

// export default { decomposeProjectIntoMilestones, evaluateSubmission };
// src/services/gemini.service.js
// Groq-powered milestone generation with improved NLP precision

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
        console.warn(`Rate limited. Retry ${attempt}/${maxRetries} in ${delay}ms`);
        await new Promise(r => setTimeout(r, delay));
      } else {
        throw err;
      }
    }
  }
};

// ─────────────────────────────────────────────────────────────────────────────
// IMPROVEMENT 1 — Detect project type from description
// Instead of one generic prompt for everything, we classify first then
// use domain-specific instructions. A mobile app gets different milestones
// than a content writing job or a logo design.
// ─────────────────────────────────────────────────────────────────────────────
const detectProjectType = (title, description) => {
  const text = `${title} ${description}`.toLowerCase();

  if (text.match(/mobile|android|ios|flutter|react native|swift|kotlin/))
    return 'mobile_app';
  if (text.match(/machine learning|ml|ai model|training|dataset|neural|nlp|classification/))
    return 'ml_ai';
  if (text.match(/design|ui|ux|figma|logo|brand|graphic|illustration|wireframe/))
    return 'design';
  if (text.match(/content|blog|article|copywriting|seo|social media|newsletter/))
    return 'content';
  if (text.match(/api|backend|server|database|rest|graphql|microservice|django|flask|express/))
    return 'backend';
  if (text.match(/website|frontend|react|vue|angular|nextjs|landing page|portfolio/))
    return 'frontend';
  if (text.match(/devops|docker|kubernetes|ci\/cd|aws|azure|deployment|infrastructure/))
    return 'devops';
  if (text.match(/smart contract|blockchain|solidity|web3|nft|defi|crypto/))
    return 'blockchain';

  return 'fullstack'; // default
};

// ─────────────────────────────────────────────────────────────────────────────
// IMPROVEMENT 2 — Domain-specific checklist rules per project type
// Each type gets tailored instructions so checklist items are actually
// meaningful for that kind of work, not generic "tests passing" boilerplate.
// ─────────────────────────────────────────────────────────────────────────────
const getTypeInstructions = (projectType) => {
  const instructions = {
    mobile_app: `
- Milestones: UI/UX Screens → Core Features → API Integration → Testing & Store Submission
- Checklist items must reference: specific screens, device compatibility, API endpoints, crash-free rate
- Example checklist: "Login screen implemented on both iOS and Android", "Push notifications working on real device"`,

    ml_ai: `
- Milestones: Data Collection → Preprocessing → Model Training → Evaluation → Deployment
- Checklist items must reference: dataset size, accuracy metrics (e.g. >90% accuracy), specific model architecture
- Example checklist: "Dataset of 10,000 labelled samples collected", "Model achieves >85% F1 score on test set"`,

    design: `
- Milestones: Research & Moodboard → Wireframes → High-Fidelity Designs → Final Assets
- Checklist items must reference: number of screens/assets, file formats, brand guidelines
- Example checklist: "5 high-fidelity screens delivered in Figma", "Logo exported in SVG, PNG, and PDF formats"`,

    content: `
- Milestones: Research & Outline → Draft → Revisions → Final Delivery
- Checklist items must reference: word count, keyword targets, revision rounds, file format
- Example checklist: "1500-word article delivered covering all 5 target keywords", "SEO meta description included"`,

    backend: `
- Milestones: Architecture & DB Schema → Core API Endpoints → Auth & Security → Testing & Docs
- Checklist items must reference: specific endpoints, HTTP methods, response formats, test coverage %
- Example checklist: "GET /api/products returns paginated JSON with 200 status", "JWT auth middleware applied to all protected routes"`,

    frontend: `
- Milestones: Component Architecture → Core Pages → API Integration → Responsive & Testing
- Checklist items must reference: specific pages/components, breakpoints, browser compatibility, Lighthouse score
- Example checklist: "Homepage renders correctly on mobile (375px) and desktop (1440px)", "Lighthouse performance score >80"`,

    devops: `
- Milestones: Infrastructure Setup → CI/CD Pipeline → Monitoring → Documentation
- Checklist items must reference: specific services, uptime targets, pipeline stages, rollback procedure
- Example checklist: "Docker containers deploy to AWS ECS with zero-downtime rolling update", "GitHub Actions pipeline runs tests on every PR"`,

    blockchain: `
- Milestones: Smart Contract Design → Development → Audit & Testing → Deployment
- Checklist items must reference: contract functions, gas optimization, test coverage, network (mainnet/testnet)
- Example checklist: "ERC-721 mint function tested with 100% coverage", "Contract deployed to Goerli testnet with verified source"`,

    fullstack: `
- Milestones: Setup & Architecture → Backend API → Frontend UI → Integration & Testing
- Checklist items must reference: specific features, API endpoints, UI components, test scenarios
- Example checklist: "User registration API endpoint returns JWT on success", "Shopping cart persists across page refreshes"`,
  };

  return instructions[projectType] || instructions.fullstack;
};

// ─────────────────────────────────────────────────────────────────────────────
// IMPROVEMENT 3 — Two-message conversation instead of one giant prompt
// System message sets the role and expertise context.
// User message contains the actual project. This gets better results from
// LLMs because they respond better to role-priming in system messages.
// ─────────────────────────────────────────────────────────────────────────────
const decomposeProjectIntoMilestones = async ({ title, description, budget, deadline }) => {
  const safeDescription = description.substring(0, 2000);
  const projectType = detectProjectType(title, description);
  const typeInstructions = getTypeInstructions(projectType);

  // Calculate days available — helps LLM give realistic time estimates
  const daysAvailable = Math.ceil(
    (new Date(deadline) - new Date()) / (1000 * 60 * 60 * 24)
  );

  const systemMessage = `You are a senior technical project manager with 10 years of experience 
breaking freelance projects into clear, verifiable milestones.

Your milestones must be:
- Independently deliverable (each one produces something the employer can review)
- Time-realistic (total estimatedDays must not exceed ${daysAvailable} days)
- Budget-proportional (harder milestones get more money)
- Objectively verifiable (every checklist item must be something you can check with yes/no)

NEVER write vague checklist items like "good code" or "feature works" or "tests pass".
ALWAYS write specific ones like "POST /api/login returns 200 with JWT token" or "Lighthouse score > 80".`;

  // IMPROVEMENT 4 — Structured few-shot example embedded in prompt
  // Showing the LLM a concrete good example dramatically improves
  // the quality and specificity of checklist items it generates.
  const userMessage = `Project type detected: ${projectType.toUpperCase()}
${typeInstructions}

PROJECT TO DECOMPOSE:
Title: ${title}
Description: ${safeDescription}
Total Budget: $${budget}
Deadline: ${deadline} (${daysAvailable} days from now)

EXAMPLE of good vs bad checklist items:
BAD:  "Authentication implemented"
GOOD: "POST /api/auth/register accepts email+password, creates user in DB, returns JWT"

BAD:  "Frontend looks good on mobile"  
GOOD: "Homepage is fully responsive — tested at 375px, 768px, 1440px breakpoints"

Now generate the milestones. Return ONLY valid JSON:
{
  "projectType": "${projectType}",
  "milestones": [
    {
      "order": 1,
      "title": "string (max 60 chars, action-oriented like 'Build auth system')",
      "description": "2-3 sentences: what must be built and why it matters for the project",
      "checklist": [
        "specific verifiable item — must answer YES or NO",
        "another specific item with concrete numbers or endpoints"
      ],
      "amount": 150,
      "estimatedDays": 5,
      "deliverable": "What the freelancer hands over at the end of this milestone"
    }
  ]
}

Rules:
- 3 to 5 milestones depending on complexity
- All amounts MUST sum exactly to ${budget}
- Each checklist must have 2-4 specific, testable items
- estimatedDays should be realistic — total must be under ${daysAvailable} days
- Order milestones so each one builds on the previous`;

  try {
    const result = await withRetry(() =>
      groq.chat.completions.create({
        model: 'llama-3.3-70b-versatile',
        messages: [
          { role: 'system', content: systemMessage },
          { role: 'user',   content: userMessage },
        ],
        temperature: 0.2,
        // IMPROVEMENT 5 — Response format enforcement
        // Forces the model to output valid JSON, eliminating markdown fences
        // and prose preambles that break cleanJson() parsing.
        response_format: { type: 'json_object' },
      })
    );

    const parsed = cleanJson(result.choices[0].message.content);
    console.log(`[NLP] Project type: ${parsed.projectType || projectType}, generated ${parsed.milestones.length} milestones`);
    return parsed.milestones;

  } catch (err) {
    console.error('Groq milestone decomposition failed, using fallback:', err.message);

    // IMPROVEMENT 6 — Type-aware fallback instead of generic template
    // Even when AI fails, the fallback now uses domain-appropriate milestone names
    const fallbacks = {
      mobile_app: [
        { order:1, title:'UI Screens & Navigation',    checklist:['All screens designed in Figma','Navigation flow implemented'], amount: Math.round(budget*0.25), estimatedDays:5 },
        { order:2, title:'Core Feature Implementation', checklist:['Main features working on device','API calls integrated'],        amount: Math.round(budget*0.50), estimatedDays:12 },
        { order:3, title:'Testing & Store Submission',  checklist:['App tested on iOS and Android','Submitted to app store'],       amount: Math.round(budget*0.25), estimatedDays:4 },
      ],
      design: [
        { order:1, title:'Research & Wireframes', checklist:['Moodboard approved','Wireframes for all screens delivered'], amount: Math.round(budget*0.30), estimatedDays:4 },
        { order:2, title:'High-Fidelity Designs', checklist:['All screens in Figma','Brand guidelines followed'],           amount: Math.round(budget*0.50), estimatedDays:8 },
        { order:3, title:'Final Asset Delivery',  checklist:['Exported in all required formats','Source files delivered'],   amount: Math.round(budget*0.20), estimatedDays:2 },
      ],
      content: [
        { order:1, title:'Research & Outline',  checklist:['Outline approved by client','Keywords researched'],              amount: Math.round(budget*0.20), estimatedDays:2 },
        { order:2, title:'Draft Delivery',      checklist:['Full draft submitted','Word count meets requirement'],           amount: Math.round(budget*0.50), estimatedDays:5 },
        { order:3, title:'Revisions & Final',   checklist:['All feedback addressed','Final file delivered in correct format'], amount: Math.round(budget*0.30), estimatedDays:3 },
      ],
      default: [
        { order:1, title:'Project Setup',         checklist:['Repository initialized','Folder structure documented','Dependencies installed'], amount: Math.round(budget*0.25), estimatedDays:3 },
        { order:2, title:'Core Implementation',   checklist:['Core features implemented','Basic tests passing','Code reviewed'],               amount: Math.round(budget*0.50), estimatedDays:10 },
        { order:3, title:'Testing & Delivery',    checklist:['All features tested','Bugs fixed','Final build documented'],                     amount: Math.round(budget*0.25), estimatedDays:4 },
      ],
    };

    const template = fallbacks[projectType] || fallbacks.default;
    return template.map(m => ({ ...m, description: `${m.title} phase of the project.` }));
  }
};

// ─── Fallback evaluator — used if groq.service.js agent fails ────────────────
const evaluateSubmission = async ({ milestoneTitle, milestoneDescription, checklist, workDescription, repoUrl }) => {
  const safeWork = workDescription.substring(0, 800);
  const checklistText = checklist.map((item, i) => `${i + 1}. ${item}`).join('\n');

  const result = await withRetry(() =>
    groq.chat.completions.create({
      model: 'llama-3.3-70b-versatile',
      messages: [
        {
          role: 'system',
          content: 'You are a strict technical evaluator. Score only what is concretely demonstrated. Return valid JSON only.',
        },
        {
          role: 'user',
          content: `Evaluate this milestone submission.

MILESTONE: ${milestoneTitle}
DESCRIPTION: ${milestoneDescription}
CHECKLIST:
${checklistText}
SUBMISSION:
${safeWork}
${repoUrl ? `REPO: ${repoUrl}` : ''}

Return:
{
  "score": 78,
  "decision": "PARTIAL_PAYOUT",
  "feedback": "2-4 sentences of specific actionable feedback",
  "checklistEvaluation": [{ "item": "text", "met": true, "comment": "specific evidence" }],
  "summary": "1 sentence for employer"
}
Rules: score 85-100 = FULL_PAYOUT, 50-84 = PARTIAL_PAYOUT, 0-49 = REFUND`,
        },
      ],
      temperature: 0.1,
      response_format: { type: 'json_object' },
    })
  );

  return cleanJson(result.choices[0].message.content);
};

export default { decomposeProjectIntoMilestones, evaluateSubmission };
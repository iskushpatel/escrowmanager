import { z } from 'zod';
import prisma from '../lib/prisma.js';
import aqaService from '../services/aqa.service.js';

const submitMilestoneSchema = z.object({
  workDescription: z.string().min(50),
  repoUrl: z.string().url().optional(),
});

const submitMilestone = async (req, res) => {
  const { id: milestoneId } = req.params;
  const { workDescription, repoUrl } = submitMilestoneSchema.parse(req.body);

  const milestone = await prisma.milestone.findUnique({
    where: { id: milestoneId },
  });

  if (!milestone) {
    return res.status(404).json({ error: 'Milestone not found' });
  }
  if (milestone.freelancerId !== req.user.userId) {
    return res.status(403).json({ error: 'You are not assigned to this milestone' });
  }
  if (milestone.status !== 'ASSIGNED') {
      return res.status(400).json({ error: `Milestone cannot be submitted with status: ${milestone.status}`})
  }

  const previousSubmissions = await prisma.submission.count({
      where: { milestoneId }
  });

  const submission = await prisma.submission.create({
    data: {
      milestoneId,
      workDescription,
      repoUrl,
      attemptNumber: previousSubmissions + 1,
    },
  });

  await prisma.milestone.update({
      where: { id: milestoneId },
      data: { status: 'UNDER_REVIEW' }
  });

  // This is a long-running task.
  // In a production app, this should be offloaded to a background job queue.
  // For this project, we run it synchronously.
  aqaService.processSubmission(submission.id).catch(err => {
      // If AQA fails, we need robust error handling.
      // For now, log it and maybe set the milestone to a disputed state.
      console.error(`AQA processing failed for submission ${submission.id}:`, err);
      prisma.milestone.update({
          where: { id: milestoneId },
          data: { status: 'DISPUTED' }
      }).catch(console.error);
  });

  res.status(202).json({ 
      message: 'Submission received and is being evaluated by AI. This may take a few moments.',
      submissionId: submission.id 
  });
};

const getMilestoneResult = async (req, res) => {
    const { id: milestoneId } = req.params;
    const submission = await prisma.submission.findFirst({
        where: { milestoneId },
        orderBy: { createdAt: 'desc' }
    });

    if (!submission) {
        return res.status(404).json({ error: 'No submission found for this milestone yet.' });
    }

    const milestone = await prisma.milestone.findUnique({
        where: { id: milestoneId },
        include: {
            project: { select: { employerId: true }}
        }
    });

    const isEmployer = milestone.project.employerId === req.user.userId;
    const isFreelancer = milestone.freelancerId === req.user.userId;

    if (!isEmployer && !isFreelancer) {
        return res.status(403).json({ error: "You cannot view this milestone's result." });
    }

    res.json({
        status: submission.status,
        aqaScore: submission.aqaScore,
        aqaDecision: submission.aqaDecision,
        aqaFeedback: submission.aqaFeedback,
    });
};

const getMilestoneById = async (req, res) => {
    const { id } = req.params;
    const milestone = await prisma.milestone.findUnique({
        where: { id },
        include: {
            submissions: { orderBy: { createdAt: 'desc' }},
            transactions: { orderBy: { createdAt: 'desc' }},
            project: { select: { title: true, employerId: true }}
        }
    });

    if (!milestone) {
        return res.status(404).json({ error: "Milestone not found" });
    }

    const isEmployer = milestone.project.employerId === req.user.userId;
    const isFreelancer = milestone.freelancerId === req.user.userId;

    if (!isEmployer && !isFreelancer) {
        return res.status(403).json({ error: "You cannot view this milestone." });
    }

    res.json(milestone);
}

export default {
  submitMilestone,
  getMilestoneResult,
  getMilestoneById,
};

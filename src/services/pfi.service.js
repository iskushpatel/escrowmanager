    import prisma from '../lib/prisma.js';

const calculateAndUpdatePFI = async (freelancerId) => {
  const milestones = await prisma.milestone.findMany({
    where: { 
      freelancerId,
      status: { in: ['APPROVED', 'PARTIAL', 'FAILED'] }
    },
    include: { submissions: { orderBy: { createdAt: 'desc' }, take: 1 } }
  });

  if (milestones.length === 0) {
    return null; // Or return a default score object
  }

  const totalMilestones = milestones.length;
  const completedMilestones = milestones.filter(m => m.status === 'APPROVED' || m.status === 'PARTIAL').length;
  const failedMilestones = totalMilestones - completedMilestones;

  const deadlineAdherence = milestones.reduce((acc, m) => {
    if (m.status === 'APPROVED' && m.submissions[0] && m.submissions[0].createdAt <= m.deadline) {
      return acc + 1;
    }
    return acc;
  }, 0) / completedMilestones * 100 || 0;

  const aqaScores = milestones
    .map(m => m.submissions[0]?.aqaScore)
    .filter(score => score != null);
  
  const averageAqaScore = aqaScores.reduce((acc, score) => acc + score, 0) / aqaScores.length || 0;

  const milestoneAccuracy = completedMilestones / totalMilestones * 100;

  // Simple weighted average for overall score
  const overallScore = (milestoneAccuracy * 0.4) + (deadlineAdherence * 0.3) + (averageAqaScore * 0.3);

  const pfiData = {
    freelancerId,
    overallScore: parseFloat(overallScore.toFixed(2)),
    milestoneAccuracy: parseFloat(milestoneAccuracy.toFixed(2)),
    deadlineAdherence: parseFloat(deadlineAdherence.toFixed(2)),
    averageAqaScore: parseFloat(averageAqaScore.toFixed(2)),
    totalMilestones,
    completedMilestones,
    failedMilestones,
    lastCalculatedAt: new Date(),
  };

  const updatedPfi = await prisma.pFIScore.upsert({
    where: { freelancerId },
    update: pfiData,
    create: pfiData,
  });

  return updatedPfi;
};

const getPFIScore = async (freelancerId) => {
  const existingScore = await prisma.pFIScore.findUnique({
    where: { freelancerId },
  });

  const oneHourAgo = new Date(Date.now() - 60 * 60 * 1000);

  if (!existingScore || existingScore.lastCalculatedAt < oneHourAgo) {
    return await calculateAndUpdatePFI(freelancerId);
  }

  return existingScore;
};

export default {
  calculateAndUpdatePFI,
  getPFIScore,
};

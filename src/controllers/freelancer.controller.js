import prisma from '../lib/prisma.js';
import pfiService from '../services/pfi.service.js';

const getAssignedMilestones = async (req, res) => {
  if (req.user.role !== 'FREELANCER') {
    return res.status(403).json({ error: 'Only freelancers can view assigned milestones' });
  }

  const milestones = await prisma.milestone.findMany({
    where: { freelancerId: req.user.userId },
    include: {
      project: {
        select: { title: true, id: true },
      },
      submissions: {
        orderBy: { createdAt: 'desc' },
        take: 1,
      },
    },
    orderBy: { deadline: 'asc' },
  });

  res.json({ milestones });
};

const getMyPfiScore = async (req, res) => {
    if (req.user.role !== 'FREELANCER') {
        return res.status(403).json({ error: 'Only freelancers have a PFI score' });
    }

    const pfi = await pfiService.getPFIScore(req.user.userId);

    if (!pfi) {
        return res.json({ message: "No milestones completed yet. Your PFI score will be calculated after your first completed milestone." });
    }

    const interpretation = pfi.overallScore >= 80 ? 'Excellent' 
        : pfi.overallScore >= 60 ? 'Good' 
        : pfi.overallScore >= 40 ? 'Average' 
        : 'Needs improvement';

    res.json({ pfi, interpretation });
};

export default {
  getAssignedMilestones,
  getMyPfiScore,
};

import { z } from 'zod';
import prisma from '../lib/prisma.js';
import stripeService from '../services/stripe.service.js';

const fundEscrowSchema = z.object({
  projectId: z.string().uuid(),
});

const fundEscrow = async (req, res) => {
  const { projectId } = fundEscrowSchema.parse(req.body);

  const project = await prisma.project.findUnique({
    where: { id: projectId },
    include: { employer: true },
  });

  if (!project) {
    return res.status(404).json({ error: 'Project not found' });
  }
  if (project.employerId !== req.user.userId) {
    return res.status(403).json({ error: 'Only the project employer can fund the escrow' });
  }

  const { clientSecret, paymentIntentId } = await stripeService.createEscrowPaymentIntent({
    projectId,
    amount: project.budget,
    employerEmail: project.employer.email,
  });
  
  // In a real app, the client uses this secret to confirm the payment with Stripe.js
  // For the demo, we can immediately call the confirmation endpoint.
  res.json({ clientSecret, paymentIntentId, message: "PaymentIntent created. Use the clientSecret to confirm payment." });
};

const confirmFundingSchema = z.object({
    projectId: z.string().uuid(),
    paymentIntentId: z.string(),
});

const confirmFunding = async (req, res) => {
    const { projectId, paymentIntentId } = confirmFundingSchema.parse(req.body);

    const project = await prisma.project.findUnique({ where: { id: projectId }});
    if (!project || project.employerId !== req.user.userId) {
        return res.status(403).json({ error: "You cannot confirm funding for this project." });
    }

    const escrowAccount = await stripeService.confirmEscrowFunded({ projectId, paymentIntentId });

    if (escrowAccount) {
        const updatedProject = await prisma.project.update({
            where: { id: projectId },
            data: { status: 'IN_PROGRESS' }
        });
        res.json({ escrowAccount, project: updatedProject, message: "Escrow successfully funded." });
    } else {
        res.status(400).json({ error: "Payment confirmation failed. The payment may not have succeeded." });
    }
};

const getEscrowByProjectId = async (req, res) => {
    const { projectId } = req.params;
    const escrow = await prisma.escrowAccount.findUnique({
        where: { projectId },
        include: { transactions: { orderBy: { createdAt: 'desc' }}}
    });

    if (!escrow) {
        return res.status(404).json({ error: "Escrow account not found for this project." });
    }

    res.json(escrow);
}

export default {
  fundEscrow,
  confirmFunding,
  getEscrowByProjectId,
};

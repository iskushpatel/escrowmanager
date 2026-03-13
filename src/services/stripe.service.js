import prisma from '../lib/prisma.js';

const createEscrowPaymentIntent = async ({ projectId, amount, employerEmail }) => {
  // Simulated - no real Stripe needed
  const fakePaymentIntentId = `pi_simulated_${Date.now()}`;
  const fakeClientSecret = `${fakePaymentIntentId}_secret_simulated`;
  return {
    clientSecret: fakeClientSecret,
    paymentIntentId: fakePaymentIntentId,
  };
};

const confirmEscrowFunded = async ({ projectId, paymentIntentId }) => {
  // Simulate payment always succeeds
  const updatedEscrow = await prisma.$transaction(async (tx) => {
    const project = await tx.project.findUnique({ where: { id: projectId } });

    const escrow = await tx.escrowAccount.update({
      where: { projectId },
      data: {
        status: 'FUNDED',
        stripePaymentIntentId: paymentIntentId,
        heldAmount: project.budget,
      },
    });

    await tx.transaction.create({
      data: {
        escrowAccountId: escrow.id,
        type: 'ESCROW_FUND',
        amount: project.budget,
        description: `Funds secured for project ${projectId}`,
      },
    });

    await tx.project.update({
      where: { id: projectId },
      data: { status: 'FUNDED' },
    });

    return escrow;
  });
  return updatedEscrow;
};

const releaseMilestonePayout = async ({ escrowAccountId, milestoneId, freelancerId, amount, description, type = 'MILESTONE_PAYOUT' }) => {
  console.log(`Simulating payout: $${amount} to freelancer ${freelancerId} for milestone ${milestoneId}`);
  const transaction = await prisma.$transaction(async (tx) => {
    const escrow = await tx.escrowAccount.findUnique({ where: { id: escrowAccountId } });
    if (escrow.heldAmount < amount) throw new Error("Insufficient funds in escrow.");
    await tx.escrowAccount.update({
      where: { id: escrowAccountId },
      data: {
        heldAmount: { decrement: amount },
        releasedAmount: { increment: amount },
      },
    });
    return tx.transaction.create({
      data: { escrowAccountId, milestoneId, userId: freelancerId, type, amount, description },
    });
  });
  return transaction;
};

const releasePartialPayout = async ({ escrowAccountId, milestoneId, freelancerId, fullAmount, score }) => {
  const partialAmount = Math.round((fullAmount * (score / 100)) * 100) / 100;
  const refundAmount = fullAmount - partialAmount;
  await releaseMilestonePayout({
    escrowAccountId, milestoneId, freelancerId,
    amount: partialAmount,
    description: `Partial payout based on AQA score of ${score}`,
    type: 'PARTIAL_PAYOUT',
  });
  if (refundAmount > 0) {
    await triggerRefund({
      escrowAccountId, milestoneId, amount: refundAmount,
      reason: `Partial refund from milestone based on AQA score of ${score}`,
    });
  }
  return { partialAmount, refundAmount };
};

const triggerRefund = async ({ escrowAccountId, milestoneId, amount, reason }) => {
  console.log(`Simulating refund: $${amount} for milestone ${milestoneId}`);
  const transaction = await prisma.$transaction(async (tx) => {
    const escrow = await tx.escrowAccount.findUnique({ where: { id: escrowAccountId } });
    if (escrow.heldAmount < amount) throw new Error("Insufficient funds in escrow for refund.");
    await tx.escrowAccount.update({
      where: { id: escrowAccountId },
      data: {
        heldAmount: { decrement: amount },
        refundedAmount: { increment: amount },
      },
    });
    return tx.transaction.create({
      data: { escrowAccountId, milestoneId, type: 'REFUND_EMPLOYER', amount, description: reason },
    });
  });
  return transaction;
};

export default {
  createEscrowPaymentIntent,
  confirmEscrowFunded,
  releaseMilestonePayout,
  releasePartialPayout,
  triggerRefund,
};

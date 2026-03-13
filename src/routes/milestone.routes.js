import { Router } from 'express';
import milestoneController from '../controllers/milestone.controller.js';
import { authenticateToken } from '../middlewares/auth.middleware.js';

const router = Router();

router.post('/:id/submit', authenticateToken, milestoneController.submitMilestone);
router.get('/:id/result', authenticateToken, milestoneController.getMilestoneResult);
router.get('/:id', authenticateToken, milestoneController.getMilestoneById);


export default router;

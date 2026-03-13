import { Router } from 'express';
import freelancerController from '../controllers/freelancer.controller.js';
import { authenticateToken } from '../middlewares/auth.middleware.js';

const router = Router();

router.get('/milestones', authenticateToken, freelancerController.getAssignedMilestones);
router.get('/pfi', authenticateToken, freelancerController.getMyPfiScore);

export default router;

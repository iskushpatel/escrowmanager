import express from 'express';
import 'express-async-errors';
import helmet from 'helmet';
import cors from 'cors';
import errorMiddleware from './middlewares/error.middleware.js';

// Import routes
import authRoutes from './routes/auth.routes.js';
import projectRoutes from './routes/project.routes.js';
import milestoneRoutes from './routes/milestone.routes.js';
import escrowRoutes from './routes/escrow.routes.js';
import freelancerRoutes from './routes/freelancer.routes.js';

const app = express();

// Middlewares
app.use(helmet());
app.use(cors());
app.use(express.json());

// Mount routes
app.use('/api/auth', authRoutes);
app.use('/api/projects', projectRoutes);
app.use('/api/milestones', milestoneRoutes);
app.use('/api/escrow', escrowRoutes);
app.use('/api/freelancer', freelancerRoutes);

// Error handling middleware
app.use(errorMiddleware);

export default app;

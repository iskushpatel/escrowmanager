import { Prisma } from '@prisma/client';
import { ZodError } from 'zod';

const errorMiddleware = (err, req, res, next) => {
  console.error(err);

  if (err instanceof ZodError) {
    return res.status(400).json({
      error: 'Validation failed',
      details: err.errors.map(e => ({ path: e.path, message: e.message })),
    });
  }

  if (err instanceof Prisma.PrismaClientKnownRequestError) {
    switch (err.code) {
      case 'P2002':
        return res.status(409).json({
          error: `Unique constraint failed on the field(s): ${err.meta.target.join(', ')}`,
        });
      case 'P2025':
        return res.status(404).json({
          error: err.meta.cause || 'Record not found',
        });
      default:
        break;
    }
  }
  
  const statusCode = err.statusCode || 500;
  const message = err.message || 'Internal Server Error';

  res.status(statusCode).json({
    error: message,
    ...(process.env.NODE_ENV === 'development' && { stack: err.stack }),
  });
};

export default errorMiddleware;

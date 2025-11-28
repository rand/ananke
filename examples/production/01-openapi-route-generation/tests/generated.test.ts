import { describe, it, expect, beforeEach } from 'vitest';
import express, { Express } from 'express';
import request from 'supertest';
import generatedRoutes from '../output/generated_routes';

/**
 * Validation tests for generated User Management API routes
 *
 * These tests verify that the generated code:
 * - Implements all OpenAPI endpoints correctly
 * - Validates request parameters properly
 * - Returns correct HTTP status codes
 * - Follows error handling patterns
 * - Matches OpenAPI specification
 */

describe('Generated User Routes', () => {
  let app: Express;

  beforeEach(() => {
    // Create fresh Express app for each test
    app = express();
    app.use(express.json());
    app.use('/api', generatedRoutes);
  });

  describe('GET /api/users/:id', () => {
    it('should return user by valid ID', async () => {
      const response = await request(app)
        .get('/api/users/1')
        .expect(200);

      expect(response.body).toHaveProperty('id', 1);
      expect(response.body).toHaveProperty('email');
      expect(response.body).toHaveProperty('name');
      expect(response.body).toHaveProperty('role');
      expect(response.body).toHaveProperty('createdAt');
    });

    it('should return 404 for non-existent user', async () => {
      const response = await request(app)
        .get('/api/users/999')
        .expect(404);

      expect(response.body).toHaveProperty('error', 'User not found');
      expect(response.body).toHaveProperty('message');
      expect(response.body.message).toContain('999');
    });

    it('should return 400 for invalid ID (non-integer)', async () => {
      const response = await request(app)
        .get('/api/users/abc')
        .expect(400);

      expect(response.body).toHaveProperty('error', 'Validation failed');
      expect(response.body).toHaveProperty('details');
      expect(Array.isArray(response.body.details)).toBe(true);
    });

    it('should return 400 for invalid ID (negative)', async () => {
      const response = await request(app)
        .get('/api/users/-1')
        .expect(400);

      expect(response.body).toHaveProperty('error', 'Validation failed');
    });

    it('should accept optional include query parameter', async () => {
      const response = await request(app)
        .get('/api/users/1?include=profile')
        .expect(200);

      expect(response.body).toHaveProperty('id', 1);
    });
  });

  describe('GET /api/users', () => {
    it('should return paginated list of users with default pagination', async () => {
      const response = await request(app)
        .get('/api/users')
        .expect(200);

      expect(response.body).toHaveProperty('data');
      expect(response.body).toHaveProperty('pagination');
      expect(Array.isArray(response.body.data)).toBe(true);

      expect(response.body.pagination).toHaveProperty('page', 1);
      expect(response.body.pagination).toHaveProperty('limit', 20);
      expect(response.body.pagination).toHaveProperty('total');
      expect(response.body.pagination).toHaveProperty('totalPages');
    });

    it('should support pagination parameters', async () => {
      const response = await request(app)
        .get('/api/users?page=1&limit=10')
        .expect(200);

      expect(response.body.pagination.page).toBe(1);
      expect(response.body.pagination.limit).toBe(10);
      expect(response.body.data.length).toBeLessThanOrEqual(10);
    });

    it('should support role filtering', async () => {
      const response = await request(app)
        .get('/api/users?role=admin')
        .expect(200);

      expect(response.body.data.every((u: any) => u.role === 'admin')).toBe(true);
    });

    it('should support search filtering', async () => {
      const response = await request(app)
        .get('/api/users?search=john')
        .expect(200);

      expect(response.body.data.length).toBeGreaterThan(0);
    });

    it('should support sorting', async () => {
      const response = await request(app)
        .get('/api/users?sort=name:asc')
        .expect(200);

      const names = response.body.data.map((u: any) => u.name);
      const sortedNames = [...names].sort();
      expect(names).toEqual(sortedNames);
    });

    it('should reject invalid pagination values', async () => {
      await request(app)
        .get('/api/users?page=0')
        .expect(400);

      await request(app)
        .get('/api/users?limit=0')
        .expect(400);

      await request(app)
        .get('/api/users?limit=101')
        .expect(400);
    });

    it('should reject invalid role values', async () => {
      const response = await request(app)
        .get('/api/users?role=invalid')
        .expect(400);

      expect(response.body).toHaveProperty('error', 'Validation failed');
    });
  });

  describe('POST /api/users', () => {
    it('should create a new user with valid data', async () => {
      const newUser = {
        email: 'test@example.com',
        name: 'Test User',
        password: 'SecurePass123!',
        role: 'user',
      };

      const response = await request(app)
        .post('/api/users')
        .send(newUser)
        .expect(201);

      expect(response.body).toHaveProperty('id');
      expect(response.body).toHaveProperty('email', newUser.email);
      expect(response.body).toHaveProperty('name', newUser.name);
      expect(response.body).toHaveProperty('role', newUser.role);
      expect(response.headers).toHaveProperty('location');
      expect(response.headers.location).toContain(`/users/${response.body.id}`);
    });

    it('should use default role if not provided', async () => {
      const newUser = {
        email: 'test2@example.com',
        name: 'Test User 2',
        password: 'SecurePass123!',
      };

      const response = await request(app)
        .post('/api/users')
        .send(newUser)
        .expect(201);

      expect(response.body).toHaveProperty('role', 'user');
    });

    it('should return 409 for duplicate email', async () => {
      const newUser = {
        email: 'admin@example.com', // Already exists in mock data
        name: 'Duplicate User',
        password: 'SecurePass123!',
      };

      const response = await request(app)
        .post('/api/users')
        .send(newUser)
        .expect(409);

      expect(response.body).toHaveProperty('error', 'Conflict');
      expect(response.body.message).toContain('admin@example.com');
    });

    it('should return 400 for invalid email', async () => {
      const newUser = {
        email: 'not-an-email',
        name: 'Test User',
        password: 'SecurePass123!',
      };

      const response = await request(app)
        .post('/api/users')
        .send(newUser)
        .expect(400);

      expect(response.body).toHaveProperty('error', 'Validation failed');
    });

    it('should return 400 for missing required fields', async () => {
      const response = await request(app)
        .post('/api/users')
        .send({})
        .expect(400);

      expect(response.body).toHaveProperty('error', 'Validation failed');
      expect(response.body.details.length).toBeGreaterThan(0);
    });

    it('should return 400 for short password', async () => {
      const newUser = {
        email: 'test3@example.com',
        name: 'Test User',
        password: 'short',
      };

      const response = await request(app)
        .post('/api/users')
        .send(newUser)
        .expect(400);

      expect(response.body).toHaveProperty('error', 'Validation failed');
    });

    it('should return 400 for invalid role', async () => {
      const newUser = {
        email: 'test4@example.com',
        name: 'Test User',
        password: 'SecurePass123!',
        role: 'superadmin', // Invalid role
      };

      const response = await request(app)
        .post('/api/users')
        .send(newUser)
        .expect(400);

      expect(response.body).toHaveProperty('error', 'Validation failed');
    });
  });

  describe('PUT /api/users/:id', () => {
    it('should update user with valid data', async () => {
      const updates = {
        name: 'Updated Name',
        email: 'updated@example.com',
      };

      const response = await request(app)
        .put('/api/users/1')
        .send(updates)
        .expect(200);

      expect(response.body).toHaveProperty('id', 1);
      expect(response.body).toHaveProperty('name', updates.name);
      expect(response.body).toHaveProperty('email', updates.email);
    });

    it('should allow partial updates', async () => {
      const updates = {
        name: 'Only Name Updated',
      };

      const response = await request(app)
        .put('/api/users/1')
        .send(updates)
        .expect(200);

      expect(response.body).toHaveProperty('name', updates.name);
    });

    it('should return 404 for non-existent user', async () => {
      const updates = {
        name: 'Updated Name',
      };

      const response = await request(app)
        .put('/api/users/999')
        .send(updates)
        .expect(404);

      expect(response.body).toHaveProperty('error', 'User not found');
    });

    it('should return 409 for duplicate email', async () => {
      const updates = {
        email: 'john@example.com', // Already exists for user 2
      };

      const response = await request(app)
        .put('/api/users/1')
        .send(updates)
        .expect(409);

      expect(response.body).toHaveProperty('error', 'Conflict');
    });

    it('should return 400 for invalid email', async () => {
      const updates = {
        email: 'not-an-email',
      };

      const response = await request(app)
        .put('/api/users/1')
        .send(updates)
        .expect(400);

      expect(response.body).toHaveProperty('error', 'Validation failed');
    });

    it('should return 400 for invalid role', async () => {
      const updates = {
        role: 'superadmin',
      };

      const response = await request(app)
        .put('/api/users/1')
        .send(updates)
        .expect(400);

      expect(response.body).toHaveProperty('error', 'Validation failed');
    });
  });

  describe('DELETE /api/users/:id', () => {
    it('should delete existing user', async () => {
      await request(app)
        .delete('/api/users/1')
        .expect(204);

      // Verify user is gone
      await request(app)
        .get('/api/users/1')
        .expect(404);
    });

    it('should return 404 for non-existent user', async () => {
      const response = await request(app)
        .delete('/api/users/999')
        .expect(404);

      expect(response.body).toHaveProperty('error', 'User not found');
    });

    it('should return 400 for invalid ID', async () => {
      const response = await request(app)
        .delete('/api/users/abc')
        .expect(400);

      expect(response.body).toHaveProperty('error', 'Validation failed');
    });
  });

  describe('Error Handling Consistency', () => {
    it('all error responses should have error and message fields', async () => {
      // Test various error scenarios
      const errorResponses = await Promise.all([
        request(app).get('/api/users/999'), // 404
        request(app).get('/api/users/abc'), // 400
        request(app).post('/api/users').send({}), // 400
        request(app).put('/api/users/999').send({ name: 'Test' }), // 404
      ]);

      errorResponses.forEach(response => {
        if (response.status >= 400) {
          expect(response.body).toHaveProperty('error');
          expect(response.body).toHaveProperty('message');
          expect(typeof response.body.error).toBe('string');
          expect(typeof response.body.message).toBe('string');
        }
      });
    });

    it('validation errors should include details array', async () => {
      const response = await request(app)
        .post('/api/users')
        .send({ email: 'invalid' })
        .expect(400);

      expect(response.body).toHaveProperty('details');
      expect(Array.isArray(response.body.details)).toBe(true);

      if (response.body.details.length > 0) {
        expect(response.body.details[0]).toHaveProperty('field');
        expect(response.body.details[0]).toHaveProperty('issue');
      }
    });
  });
});

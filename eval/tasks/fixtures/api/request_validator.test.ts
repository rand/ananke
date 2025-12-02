import { describe, it, expect } from '@jest/globals';
import { validateRequest, ValidationSchema } from './request_validator';

describe('validateRequest', () => {
  // Basic functionality
  it('should validate a simple valid request', () => {
    const schema: ValidationSchema = {
      username: { type: 'string', required: true },
      age: { type: 'number', required: true },
    };
    const request = { username: 'john', age: 30 };

    const result = validateRequest(request, schema);

    expect(result.valid).toBe(true);
    expect(result.errors).toEqual([]);
  });

  it('should detect missing required field', () => {
    const schema: ValidationSchema = {
      username: { type: 'string', required: true },
      email: { type: 'string', required: true },
    };
    const request = { username: 'john' };

    const result = validateRequest(request, schema);

    expect(result.valid).toBe(false);
    expect(result.errors).toContain("Field 'email' is required");
  });

  it('should detect type mismatch', () => {
    const schema: ValidationSchema = {
      age: { type: 'number', required: true },
    };
    const request = { age: '30' };

    const result = validateRequest(request, schema);

    expect(result.valid).toBe(false);
    expect(result.errors).toContain("Field 'age' must be of type number, got string");
  });

  // Multiple errors
  it('should collect all validation errors', () => {
    const schema: ValidationSchema = {
      username: { type: 'string', required: true },
      age: { type: 'number', required: true },
      active: { type: 'boolean', required: true },
    };
    const request = { username: 123, active: 'yes' };

    const result = validateRequest(request, schema);

    expect(result.valid).toBe(false);
    expect(result.errors).toHaveLength(3);
    expect(result.errors).toContain("Field 'username' must be of type string, got number");
    expect(result.errors).toContain("Field 'age' is required");
    expect(result.errors).toContain("Field 'active' must be of type boolean, got string");
  });

  // Optional fields
  it('should allow missing optional fields', () => {
    const schema: ValidationSchema = {
      username: { type: 'string', required: true },
      nickname: { type: 'string', required: false },
    };
    const request = { username: 'john' };

    const result = validateRequest(request, schema);

    expect(result.valid).toBe(true);
    expect(result.errors).toEqual([]);
  });

  it('should validate optional field when present', () => {
    const schema: ValidationSchema = {
      username: { type: 'string', required: true },
      nickname: { type: 'string', required: false },
    };
    const request = { username: 'john', nickname: 123 };

    const result = validateRequest(request, schema);

    expect(result.valid).toBe(false);
    expect(result.errors).toContain("Field 'nickname' must be of type string, got number");
  });

  // Array type
  it('should validate array type', () => {
    const schema: ValidationSchema = {
      tags: { type: 'array', required: true },
    };
    const request = { tags: ['tag1', 'tag2'] };

    const result = validateRequest(request, schema);

    expect(result.valid).toBe(true);
    expect(result.errors).toEqual([]);
  });

  it('should detect non-array when array expected', () => {
    const schema: ValidationSchema = {
      tags: { type: 'array', required: true },
    };
    const request = { tags: 'tag1,tag2' };

    const result = validateRequest(request, schema);

    expect(result.valid).toBe(false);
    expect(result.errors).toContain("Field 'tags' must be of type array, got string");
  });

  // Boolean type
  it('should validate boolean type', () => {
    const schema: ValidationSchema = {
      active: { type: 'boolean', required: true },
    };
    const request = { active: true };

    const result = validateRequest(request, schema);

    expect(result.valid).toBe(true);
    expect(result.errors).toEqual([]);
  });

  // Nested objects
  it('should validate nested object', () => {
    const schema: ValidationSchema = {
      user: {
        type: 'object',
        required: true,
        properties: {
          name: { type: 'string', required: true },
          age: { type: 'number', required: true },
        },
      },
    };
    const request = {
      user: { name: 'john', age: 30 },
    };

    const result = validateRequest(request, schema);

    expect(result.valid).toBe(true);
    expect(result.errors).toEqual([]);
  });

  it('should detect errors in nested object', () => {
    const schema: ValidationSchema = {
      user: {
        type: 'object',
        required: true,
        properties: {
          name: { type: 'string', required: true },
          age: { type: 'number', required: true },
        },
      },
    };
    const request = {
      user: { name: 'john' },
    };

    const result = validateRequest(request, schema);

    expect(result.valid).toBe(false);
    expect(result.errors).toContain("user.Field 'age' is required");
  });

  it('should detect type errors in nested object', () => {
    const schema: ValidationSchema = {
      user: {
        type: 'object',
        required: true,
        properties: {
          name: { type: 'string', required: true },
          age: { type: 'number', required: true },
        },
      },
    };
    const request = {
      user: { name: 'john', age: '30' },
    };

    const result = validateRequest(request, schema);

    expect(result.valid).toBe(false);
    expect(result.errors).toContain("user.Field 'age' must be of type number, got string");
  });

  // Edge cases
  it('should handle empty schema', () => {
    const schema: ValidationSchema = {};
    const request = { anything: 'value' };

    const result = validateRequest(request, schema);

    expect(result.valid).toBe(true);
    expect(result.errors).toEqual([]);
  });

  it('should handle empty request', () => {
    const schema: ValidationSchema = {
      optional: { type: 'string', required: false },
    };
    const request = {};

    const result = validateRequest(request, schema);

    expect(result.valid).toBe(true);
    expect(result.errors).toEqual([]);
  });

  it('should treat null as missing value', () => {
    const schema: ValidationSchema = {
      username: { type: 'string', required: true },
    };
    const request = { username: null };

    const result = validateRequest(request, schema);

    expect(result.valid).toBe(false);
    expect(result.errors).toContain("Field 'username' is required");
  });

  it('should treat undefined as missing value', () => {
    const schema: ValidationSchema = {
      username: { type: 'string', required: true },
    };
    const request = { username: undefined };

    const result = validateRequest(request, schema);

    expect(result.valid).toBe(false);
    expect(result.errors).toContain("Field 'username' is required");
  });

  // Complex scenario
  it('should validate complex nested structure', () => {
    const schema: ValidationSchema = {
      user: {
        type: 'object',
        required: true,
        properties: {
          profile: {
            type: 'object',
            required: true,
            properties: {
              name: { type: 'string', required: true },
              verified: { type: 'boolean', required: true },
            },
          },
          tags: { type: 'array', required: true },
        },
      },
    };
    const request = {
      user: {
        profile: { name: 'john', verified: true },
        tags: ['admin'],
      },
    };

    const result = validateRequest(request, schema);

    expect(result.valid).toBe(true);
    expect(result.errors).toEqual([]);
  });
});

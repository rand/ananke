import { validateJSON, Schema } from './json_validator';

describe('validateJSON', () => {
  describe('basic validation', () => {
    it('should validate simple object with correct types', () => {
      const data = { name: 'John', age: 30, active: true };
      const schema: Schema = {
        properties: {
          name: { type: 'string' },
          age: { type: 'number' },
          active: { type: 'boolean' }
        }
      };

      const result = validateJSON(data, schema);
      expect(result.valid).toBe(true);
      expect(result.errors).toEqual([]);
    });

    it('should detect type mismatches', () => {
      const data = { name: 123, age: '30' };
      const schema: Schema = {
        properties: {
          name: { type: 'string' },
          age: { type: 'number' }
        }
      };

      const result = validateJSON(data, schema);
      expect(result.valid).toBe(false);
      expect(result.errors.length).toBe(2);
      expect(result.errors[0]).toContain('name');
      expect(result.errors[1]).toContain('age');
    });
  });

  describe('required fields', () => {
    it('should validate all required fields are present', () => {
      const data = { name: 'John', age: 30 };
      const schema: Schema = {
        required: ['name', 'age'],
        properties: {
          name: { type: 'string' },
          age: { type: 'number' }
        }
      };

      const result = validateJSON(data, schema);
      expect(result.valid).toBe(true);
    });

    it('should detect missing required fields', () => {
      const data = { name: 'John' };
      const schema: Schema = {
        required: ['name', 'age', 'email'],
        properties: {
          name: { type: 'string' },
          age: { type: 'number' },
          email: { type: 'string' }
        }
      };

      const result = validateJSON(data, schema);
      expect(result.valid).toBe(false);
      expect(result.errors.length).toBe(2);
      expect(result.errors).toContain('Missing required field: age');
      expect(result.errors).toContain('Missing required field: email');
    });

    it('should allow optional fields to be missing', () => {
      const data = { name: 'John' };
      const schema: Schema = {
        required: ['name'],
        properties: {
          name: { type: 'string' },
          age: { type: 'number' },
          email: { type: 'string' }
        }
      };

      const result = validateJSON(data, schema);
      expect(result.valid).toBe(true);
    });
  });

  describe('type checking', () => {
    it('should validate string type', () => {
      const schema: Schema = {
        properties: { name: { type: 'string' } }
      };

      expect(validateJSON({ name: 'test' }, schema).valid).toBe(true);
      expect(validateJSON({ name: 123 }, schema).valid).toBe(false);
    });

    it('should validate number type', () => {
      const schema: Schema = {
        properties: { age: { type: 'number' } }
      };

      expect(validateJSON({ age: 30 }, schema).valid).toBe(true);
      expect(validateJSON({ age: '30' }, schema).valid).toBe(false);
    });

    it('should validate boolean type', () => {
      const schema: Schema = {
        properties: { active: { type: 'boolean' } }
      };

      expect(validateJSON({ active: true }, schema).valid).toBe(true);
      expect(validateJSON({ active: 'true' }, schema).valid).toBe(false);
    });

    it('should validate array type', () => {
      const schema: Schema = {
        properties: { items: { type: 'array' } }
      };

      expect(validateJSON({ items: [1, 2, 3] }, schema).valid).toBe(true);
      expect(validateJSON({ items: 'not an array' }, schema).valid).toBe(false);
    });

    it('should validate object type', () => {
      const schema: Schema = {
        properties: { config: { type: 'object' } }
      };

      expect(validateJSON({ config: {} }, schema).valid).toBe(true);
      expect(validateJSON({ config: 'not an object' }, schema).valid).toBe(false);
    });
  });

  describe('nested objects', () => {
    it('should validate nested object properties', () => {
      const data = {
        user: {
          name: 'John',
          age: 30
        }
      };

      const schema: Schema = {
        properties: {
          user: {
            type: 'object',
            properties: {
              name: { type: 'string' },
              age: { type: 'number' }
            }
          }
        }
      };

      const result = validateJSON(data, schema);
      expect(result.valid).toBe(true);
    });

    it('should detect type errors in nested objects', () => {
      const data = {
        user: {
          name: 123,
          age: '30'
        }
      };

      const schema: Schema = {
        properties: {
          user: {
            type: 'object',
            properties: {
              name: { type: 'string' },
              age: { type: 'number' }
            }
          }
        }
      };

      const result = validateJSON(data, schema);
      expect(result.valid).toBe(false);
      expect(result.errors.length).toBe(2);
    });

    it('should validate required fields in nested objects', () => {
      const data = {
        user: {
          name: 'John'
        }
      };

      const schema: Schema = {
        properties: {
          user: {
            type: 'object',
            required: ['name', 'age'],
            properties: {
              name: { type: 'string' },
              age: { type: 'number' }
            }
          }
        }
      };

      const result = validateJSON(data, schema);
      expect(result.valid).toBe(false);
      expect(result.errors).toContain("Field 'user.age' is required");
    });
  });

  describe('error collection', () => {
    it('should collect all errors, not just the first one', () => {
      const data = {
        name: 123,
        age: '30',
        active: 'yes',
        count: true
      };

      const schema: Schema = {
        properties: {
          name: { type: 'string' },
          age: { type: 'number' },
          active: { type: 'boolean' },
          count: { type: 'number' }
        }
      };

      const result = validateJSON(data, schema);
      expect(result.valid).toBe(false);
      expect(result.errors.length).toBe(4);
    });
  });

  describe('complex schemas', () => {
    it('should validate complex nested structure', () => {
      const data = {
        id: 1,
        name: 'Product',
        metadata: {
          created: '2023-01-01',
          author: {
            name: 'John',
            email: 'john@example.com'
          }
        }
      };

      const schema: Schema = {
        required: ['id', 'name'],
        properties: {
          id: { type: 'number' },
          name: { type: 'string' },
          metadata: {
            type: 'object',
            properties: {
              created: { type: 'string' },
              author: {
                type: 'object',
                properties: {
                  name: { type: 'string' },
                  email: { type: 'string' }
                }
              }
            }
          }
        }
      };

      const result = validateJSON(data, schema);
      expect(result.valid).toBe(true);
    });
  });
});

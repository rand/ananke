import { validateSchema, validateField, createValidator, Schema } from './chain_validation_2';

describe('Schema Validation', () => {
  describe('validateField', () => {
    it('validates string fields', () => {
      expect(validateField('hello', { type: 'string' }, 'field')).toEqual([]);
      expect(validateField(123, { type: 'string' }, 'field')).toContain('field: expected string, got number');
    });

    it('validates string length constraints', () => {
      expect(validateField('ab', { type: 'string', minLength: 3 }, 'field')).toContain('field: string length 2 is less than minimum 3');
      expect(validateField('abcdef', { type: 'string', maxLength: 3 }, 'field')).toContain('field: string length 6 exceeds maximum 3');
    });

    it('validates number fields', () => {
      expect(validateField(42, { type: 'number' }, 'field')).toEqual([]);
      expect(validateField('42', { type: 'number' }, 'field')).toContain('field: expected number, got string');
    });

    it('validates number range constraints', () => {
      expect(validateField(5, { type: 'number', min: 10 }, 'field')).toContain('field: number 5 is less than minimum 10');
      expect(validateField(15, { type: 'number', max: 10 }, 'field')).toContain('field: number 15 exceeds maximum 10');
    });

    it('validates boolean fields', () => {
      expect(validateField(true, { type: 'boolean' }, 'field')).toEqual([]);
      expect(validateField('true', { type: 'boolean' }, 'field')).toContain('field: expected boolean, got string');
    });

    it('validates array fields', () => {
      expect(validateField([1, 2, 3], { type: 'array', items: { type: 'number' } }, 'field')).toEqual([]);
      expect(validateField('not array', { type: 'array' }, 'field')).toContain('field: expected array, got string');
    });

    it('validates required fields', () => {
      expect(validateField(undefined, { type: 'string', required: true }, 'field')).toContain('field: required field is missing');
      expect(validateField(undefined, { type: 'string' }, 'field')).toEqual([]);
    });
  });

  describe('validateSchema', () => {
    const userSchema: Schema = {
      type: 'object',
      properties: {
        name: { type: 'string', minLength: 1 },
        age: { type: 'number', min: 0 },
        email: { type: 'string', pattern: /^[^\s@]+@[^\s@]+\.[^\s@]+$/ },
        active: { type: 'boolean' }
      },
      required: ['name', 'email']
    };

    it('validates valid objects', () => {
      const result = validateSchema({
        name: 'John',
        age: 30,
        email: 'john@example.com',
        active: true
      }, userSchema);
      expect(result.valid).toBe(true);
      expect(result.errors).toEqual([]);
    });

    it('catches missing required fields', () => {
      const result = validateSchema({ age: 30 }, userSchema);
      expect(result.valid).toBe(false);
      expect(result.errors).toContain('name: required field is missing');
      expect(result.errors).toContain('email: required field is missing');
    });

    it('catches type mismatches', () => {
      const result = validateSchema({
        name: 'John',
        age: 'thirty',
        email: 'john@example.com'
      }, userSchema);
      expect(result.valid).toBe(false);
      expect(result.errors.some(e => e.includes('expected number'))).toBe(true);
    });

    it('catches pattern mismatches', () => {
      const result = validateSchema({
        name: 'John',
        email: 'invalid-email'
      }, userSchema);
      expect(result.valid).toBe(false);
      expect(result.errors.some(e => e.includes('does not match pattern'))).toBe(true);
    });

    it('rejects non-objects', () => {
      expect(validateSchema(null, userSchema).valid).toBe(false);
      expect(validateSchema([], userSchema).valid).toBe(false);
      expect(validateSchema('string', userSchema).valid).toBe(false);
    });
  });

  describe('createValidator', () => {
    it('creates reusable validator function', () => {
      const schema: Schema = {
        type: 'object',
        properties: {
          id: { type: 'number' }
        },
        required: ['id']
      };
      const validator = createValidator(schema);

      expect(validator({ id: 1 }).valid).toBe(true);
      expect(validator({ id: 'string' }).valid).toBe(false);
      expect(validator({}).valid).toBe(false);
    });
  });
});

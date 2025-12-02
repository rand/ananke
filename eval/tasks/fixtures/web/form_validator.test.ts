import { describe, it, expect } from '@jest/globals';
import { validateForm, ValidationRules, FormData } from './form_validator';

describe('validateForm', () => {
  // Basic validation
  it('should validate a simple valid form', () => {
    const formData: FormData = {
      username: 'john',
      email: 'john@example.com',
    };

    const rules: ValidationRules = {
      username: { required: true },
      email: { required: true, email: true },
    };

    const result = validateForm(formData, rules);

    expect(result.isValid).toBe(true);
    expect(result.fieldErrors).toEqual({});
  });

  // Required field validation
  it('should detect missing required field', () => {
    const formData: FormData = {
      username: '',
    };

    const rules: ValidationRules = {
      username: { required: true },
    };

    const result = validateForm(formData, rules);

    expect(result.isValid).toBe(false);
    expect(result.fieldErrors.username).toContain('username is required');
  });

  it('should treat whitespace-only as empty for required fields', () => {
    const formData: FormData = {
      username: '   ',
    };

    const rules: ValidationRules = {
      username: { required: true },
    };

    const result = validateForm(formData, rules);

    expect(result.isValid).toBe(false);
    expect(result.fieldErrors.username).toContain('username is required');
  });

  // MinLength validation
  it('should validate minLength constraint', () => {
    const formData: FormData = {
      password: 'abc',
    };

    const rules: ValidationRules = {
      password: { required: true, minLength: 8 },
    };

    const result = validateForm(formData, rules);

    expect(result.isValid).toBe(false);
    expect(result.fieldErrors.password).toContain(
      'password must be at least 8 characters'
    );
  });

  it('should pass minLength when exactly at minimum', () => {
    const formData: FormData = {
      password: 'abcdefgh',
    };

    const rules: ValidationRules = {
      password: { minLength: 8 },
    };

    const result = validateForm(formData, rules);

    expect(result.isValid).toBe(true);
  });

  // MaxLength validation
  it('should validate maxLength constraint', () => {
    const formData: FormData = {
      username: 'thisisaverylongusername',
    };

    const rules: ValidationRules = {
      username: { maxLength: 10 },
    };

    const result = validateForm(formData, rules);

    expect(result.isValid).toBe(false);
    expect(result.fieldErrors.username).toContain(
      'username must be at most 10 characters'
    );
  });

  it('should pass maxLength when exactly at maximum', () => {
    const formData: FormData = {
      username: 'abcdefghij',
    };

    const rules: ValidationRules = {
      username: { maxLength: 10 },
    };

    const result = validateForm(formData, rules);

    expect(result.isValid).toBe(true);
  });

  // Pattern validation
  it('should validate pattern constraint', () => {
    const formData: FormData = {
      phone: '123-456',
    };

    const rules: ValidationRules = {
      phone: { pattern: /^\d{3}-\d{3}-\d{4}$/ },
    };

    const result = validateForm(formData, rules);

    expect(result.isValid).toBe(false);
    expect(result.fieldErrors.phone).toContain('phone format is invalid');
  });

  it('should pass pattern validation when matching', () => {
    const formData: FormData = {
      phone: '123-456-7890',
    };

    const rules: ValidationRules = {
      phone: { pattern: /^\d{3}-\d{3}-\d{4}$/ },
    };

    const result = validateForm(formData, rules);

    expect(result.isValid).toBe(true);
  });

  // Email validation
  it('should validate email format', () => {
    const formData: FormData = {
      email: 'invalid-email',
    };

    const rules: ValidationRules = {
      email: { email: true },
    };

    const result = validateForm(formData, rules);

    expect(result.isValid).toBe(false);
    expect(result.fieldErrors.email).toContain(
      'email must be a valid email address'
    );
  });

  it('should accept valid email formats', () => {
    const validEmails = [
      'test@example.com',
      'user.name@example.co.uk',
      'user+tag@example.com',
    ];

    for (const email of validEmails) {
      const result = validateForm(
        { email },
        { email: { email: true } }
      );
      expect(result.isValid).toBe(true);
    }
  });

  // Multiple errors for single field
  it('should collect multiple errors for a field', () => {
    const formData: FormData = {
      password: 'abc',
    };

    const rules: ValidationRules = {
      password: { required: true, minLength: 8, pattern: /^(?=.*[A-Z])/ },
    };

    const result = validateForm(formData, rules);

    expect(result.isValid).toBe(false);
    expect(result.fieldErrors.password).toHaveLength(2);
    expect(result.fieldErrors.password).toContain(
      'password must be at least 8 characters'
    );
    expect(result.fieldErrors.password).toContain('password format is invalid');
  });

  // Multiple field errors
  it('should validate multiple fields and collect errors', () => {
    const formData: FormData = {
      username: '',
      email: 'invalid',
      password: '123',
    };

    const rules: ValidationRules = {
      username: { required: true },
      email: { required: true, email: true },
      password: { minLength: 8 },
    };

    const result = validateForm(formData, rules);

    expect(result.isValid).toBe(false);
    expect(Object.keys(result.fieldErrors)).toHaveLength(3);
    expect(result.fieldErrors.username).toBeDefined();
    expect(result.fieldErrors.email).toBeDefined();
    expect(result.fieldErrors.password).toBeDefined();
  });

  // Optional fields
  it('should allow optional fields to be empty', () => {
    const formData: FormData = {
      username: 'john',
      nickname: '',
    };

    const rules: ValidationRules = {
      username: { required: true },
      nickname: { minLength: 3 }, // Not required
    };

    const result = validateForm(formData, rules);

    expect(result.isValid).toBe(true);
    expect(result.fieldErrors).toEqual({});
  });

  it('should validate optional field when present', () => {
    const formData: FormData = {
      username: 'john',
      nickname: 'ab',
    };

    const rules: ValidationRules = {
      username: { required: true },
      nickname: { minLength: 3 }, // Not required but has constraints
    };

    const result = validateForm(formData, rules);

    expect(result.isValid).toBe(false);
    expect(result.fieldErrors.nickname).toContain(
      'nickname must be at least 3 characters'
    );
  });

  // Edge cases
  it('should handle missing fields in formData', () => {
    const formData: FormData = {};

    const rules: ValidationRules = {
      username: { required: true },
    };

    const result = validateForm(formData, rules);

    expect(result.isValid).toBe(false);
    expect(result.fieldErrors.username).toContain('username is required');
  });

  it('should handle empty rules', () => {
    const formData: FormData = {
      username: 'john',
    };

    const rules: ValidationRules = {};

    const result = validateForm(formData, rules);

    expect(result.isValid).toBe(true);
    expect(result.fieldErrors).toEqual({});
  });

  it('should not include fields without errors in fieldErrors', () => {
    const formData: FormData = {
      username: 'john',
      email: 'invalid',
    };

    const rules: ValidationRules = {
      username: { required: true },
      email: { email: true },
    };

    const result = validateForm(formData, rules);

    expect(result.isValid).toBe(false);
    expect('username' in result.fieldErrors).toBe(false);
    expect('email' in result.fieldErrors).toBe(true);
  });

  // Complex scenario
  it('should handle complex validation scenario', () => {
    const formData: FormData = {
      username: 'john_doe',
      email: 'john@example.com',
      password: 'SecurePass123',
      confirmPassword: 'SecurePass123',
      phone: '555-123-4567',
    };

    const rules: ValidationRules = {
      username: {
        required: true,
        minLength: 3,
        maxLength: 20,
        pattern: /^[a-zA-Z0-9_]+$/,
      },
      email: { required: true, email: true },
      password: { required: true, minLength: 8, pattern: /^(?=.*[A-Z])(?=.*\d)/ },
      phone: { pattern: /^\d{3}-\d{3}-\d{4}$/ },
    };

    const result = validateForm(formData, rules);

    expect(result.isValid).toBe(true);
    expect(result.fieldErrors).toEqual({});
  });
});

/**
 * Schema Validation - Chain Validation Level 2
 * Object schema validation with nested fields
 */

export interface ValidationResult {
  valid: boolean;
  errors: string[];
}

export interface FieldSchema {
  type: 'string' | 'number' | 'boolean' | 'array' | 'object';
  required?: boolean;
  minLength?: number;
  maxLength?: number;
  min?: number;
  max?: number;
  pattern?: RegExp;
  items?: FieldSchema;
  properties?: Record<string, FieldSchema>;
}

export interface Schema {
  type: 'object';
  properties: Record<string, FieldSchema>;
  required?: string[];
}

export function validateField(value: unknown, schema: FieldSchema, path: string): string[] {
  const errors: string[] = [];

  if (value === undefined || value === null) {
    if (schema.required) {
      errors.push(`${path}: required field is missing`);
    }
    return errors;
  }

  switch (schema.type) {
    case 'string':
      if (typeof value !== 'string') {
        errors.push(`${path}: expected string, got ${typeof value}`);
      } else {
        if (schema.minLength !== undefined && value.length < schema.minLength) {
          errors.push(`${path}: string length ${value.length} is less than minimum ${schema.minLength}`);
        }
        if (schema.maxLength !== undefined && value.length > schema.maxLength) {
          errors.push(`${path}: string length ${value.length} exceeds maximum ${schema.maxLength}`);
        }
        if (schema.pattern && !schema.pattern.test(value)) {
          errors.push(`${path}: string does not match pattern`);
        }
      }
      break;

    case 'number':
      if (typeof value !== 'number' || isNaN(value)) {
        errors.push(`${path}: expected number, got ${typeof value}`);
      } else {
        if (schema.min !== undefined && value < schema.min) {
          errors.push(`${path}: number ${value} is less than minimum ${schema.min}`);
        }
        if (schema.max !== undefined && value > schema.max) {
          errors.push(`${path}: number ${value} exceeds maximum ${schema.max}`);
        }
      }
      break;

    case 'boolean':
      if (typeof value !== 'boolean') {
        errors.push(`${path}: expected boolean, got ${typeof value}`);
      }
      break;

    case 'array':
      if (!Array.isArray(value)) {
        errors.push(`${path}: expected array, got ${typeof value}`);
      } else if (schema.items) {
        value.forEach((item, index) => {
          errors.push(...validateField(item, schema.items!, `${path}[${index}]`));
        });
      }
      break;

    case 'object':
      if (typeof value !== 'object' || value === null || Array.isArray(value)) {
        errors.push(`${path}: expected object, got ${typeof value}`);
      } else if (schema.properties) {
        for (const [key, fieldSchema] of Object.entries(schema.properties)) {
          errors.push(...validateField((value as Record<string, unknown>)[key], fieldSchema, `${path}.${key}`));
        }
      }
      break;
  }

  return errors;
}

export function validateSchema(data: unknown, schema: Schema): ValidationResult {
  const errors: string[] = [];

  if (typeof data !== 'object' || data === null || Array.isArray(data)) {
    return { valid: false, errors: ['Root value must be an object'] };
  }

  const obj = data as Record<string, unknown>;

  // Check required fields
  if (schema.required) {
    for (const field of schema.required) {
      if (!(field in obj)) {
        errors.push(`${field}: required field is missing`);
      }
    }
  }

  // Validate each property
  for (const [key, fieldSchema] of Object.entries(schema.properties)) {
    errors.push(...validateField(obj[key], fieldSchema, key));
  }

  return { valid: errors.length === 0, errors };
}

export function createValidator(schema: Schema): (data: unknown) => ValidationResult {
  return (data: unknown) => validateSchema(data, schema);
}

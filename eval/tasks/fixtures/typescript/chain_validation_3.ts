/**
 * Cross-Field Validation - Chain Validation Level 3
 * Validation rules that depend on multiple fields
 */

export interface ValidationError {
  field: string;
  message: string;
  code: string;
}

export interface CrossFieldResult {
  valid: boolean;
  errors: ValidationError[];
}

export type CrossFieldRule = (data: Record<string, unknown>) => ValidationError | null;

export interface CrossFieldValidator {
  rules: CrossFieldRule[];
  validate(data: Record<string, unknown>): CrossFieldResult;
  addRule(rule: CrossFieldRule): void;
}

export function createCrossFieldValidator(): CrossFieldValidator {
  const rules: CrossFieldRule[] = [];

  return {
    rules,
    validate(data: Record<string, unknown>): CrossFieldResult {
      const errors: ValidationError[] = [];
      for (const rule of rules) {
        const error = rule(data);
        if (error) {
          errors.push(error);
        }
      }
      return { valid: errors.length === 0, errors };
    },
    addRule(rule: CrossFieldRule) {
      rules.push(rule);
    }
  };
}

// Built-in cross-field rules
export function requireIfPresent(
  triggerField: string,
  requiredField: string,
  message?: string
): CrossFieldRule {
  return (data) => {
    if (data[triggerField] !== undefined && data[requiredField] === undefined) {
      return {
        field: requiredField,
        message: message || `${requiredField} is required when ${triggerField} is present`,
        code: 'REQUIRE_IF_PRESENT'
      };
    }
    return null;
  };
}

export function mutuallyExclusive(
  field1: string,
  field2: string,
  message?: string
): CrossFieldRule {
  return (data) => {
    if (data[field1] !== undefined && data[field2] !== undefined) {
      return {
        field: `${field1}, ${field2}`,
        message: message || `${field1} and ${field2} cannot both be present`,
        code: 'MUTUALLY_EXCLUSIVE'
      };
    }
    return null;
  };
}

export function requireEither(
  field1: string,
  field2: string,
  message?: string
): CrossFieldRule {
  return (data) => {
    if (data[field1] === undefined && data[field2] === undefined) {
      return {
        field: `${field1}, ${field2}`,
        message: message || `Either ${field1} or ${field2} must be present`,
        code: 'REQUIRE_EITHER'
      };
    }
    return null;
  };
}

export function dateRangeValid(
  startField: string,
  endField: string,
  message?: string
): CrossFieldRule {
  return (data) => {
    const start = data[startField];
    const end = data[endField];

    if (start !== undefined && end !== undefined) {
      const startDate = new Date(start as string);
      const endDate = new Date(end as string);

      if (startDate > endDate) {
        return {
          field: `${startField}, ${endField}`,
          message: message || `${startField} must be before ${endField}`,
          code: 'DATE_RANGE_INVALID'
        };
      }
    }
    return null;
  };
}

export function passwordMatch(
  passwordField: string,
  confirmField: string,
  message?: string
): CrossFieldRule {
  return (data) => {
    if (data[passwordField] !== data[confirmField]) {
      return {
        field: confirmField,
        message: message || 'Passwords do not match',
        code: 'PASSWORD_MISMATCH'
      };
    }
    return null;
  };
}

export function sumConstraint(
  fields: string[],
  constraint: { min?: number; max?: number; exact?: number },
  message?: string
): CrossFieldRule {
  return (data) => {
    const sum = fields.reduce((acc, field) => {
      const value = data[field];
      return acc + (typeof value === 'number' ? value : 0);
    }, 0);

    if (constraint.exact !== undefined && sum !== constraint.exact) {
      return {
        field: fields.join(', '),
        message: message || `Sum of ${fields.join(', ')} must equal ${constraint.exact}`,
        code: 'SUM_EXACT_VIOLATED'
      };
    }
    if (constraint.min !== undefined && sum < constraint.min) {
      return {
        field: fields.join(', '),
        message: message || `Sum of ${fields.join(', ')} must be at least ${constraint.min}`,
        code: 'SUM_MIN_VIOLATED'
      };
    }
    if (constraint.max !== undefined && sum > constraint.max) {
      return {
        field: fields.join(', '),
        message: message || `Sum of ${fields.join(', ')} must not exceed ${constraint.max}`,
        code: 'SUM_MAX_VIOLATED'
      };
    }
    return null;
  };
}

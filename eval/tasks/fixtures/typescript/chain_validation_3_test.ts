import {
  createCrossFieldValidator,
  requireIfPresent,
  mutuallyExclusive,
  requireEither,
  dateRangeValid,
  passwordMatch,
  sumConstraint
} from './chain_validation_3';

describe('Cross-Field Validation', () => {
  describe('createCrossFieldValidator', () => {
    it('creates validator with empty rules', () => {
      const validator = createCrossFieldValidator();
      expect(validator.rules).toEqual([]);
      expect(validator.validate({})).toEqual({ valid: true, errors: [] });
    });

    it('allows adding rules', () => {
      const validator = createCrossFieldValidator();
      validator.addRule(() => null);
      expect(validator.rules.length).toBe(1);
    });

    it('collects errors from all rules', () => {
      const validator = createCrossFieldValidator();
      validator.addRule(() => ({ field: 'a', message: 'Error A', code: 'ERR_A' }));
      validator.addRule(() => ({ field: 'b', message: 'Error B', code: 'ERR_B' }));
      validator.addRule(() => null);

      const result = validator.validate({});
      expect(result.valid).toBe(false);
      expect(result.errors.length).toBe(2);
    });
  });

  describe('requireIfPresent', () => {
    it('requires field when trigger is present', () => {
      const rule = requireIfPresent('trigger', 'required');
      expect(rule({ trigger: 'value' })).toEqual({
        field: 'required',
        message: 'required is required when trigger is present',
        code: 'REQUIRE_IF_PRESENT'
      });
    });

    it('passes when trigger is absent', () => {
      const rule = requireIfPresent('trigger', 'required');
      expect(rule({})).toBeNull();
    });

    it('passes when both are present', () => {
      const rule = requireIfPresent('trigger', 'required');
      expect(rule({ trigger: 'a', required: 'b' })).toBeNull();
    });

    it('supports custom message', () => {
      const rule = requireIfPresent('a', 'b', 'Custom message');
      expect(rule({ a: 1 })?.message).toBe('Custom message');
    });
  });

  describe('mutuallyExclusive', () => {
    it('fails when both fields present', () => {
      const rule = mutuallyExclusive('a', 'b');
      expect(rule({ a: 1, b: 2 })).toEqual({
        field: 'a, b',
        message: 'a and b cannot both be present',
        code: 'MUTUALLY_EXCLUSIVE'
      });
    });

    it('passes when only one field present', () => {
      const rule = mutuallyExclusive('a', 'b');
      expect(rule({ a: 1 })).toBeNull();
      expect(rule({ b: 2 })).toBeNull();
    });

    it('passes when neither field present', () => {
      const rule = mutuallyExclusive('a', 'b');
      expect(rule({})).toBeNull();
    });
  });

  describe('requireEither', () => {
    it('fails when neither field present', () => {
      const rule = requireEither('a', 'b');
      expect(rule({})).toEqual({
        field: 'a, b',
        message: 'Either a or b must be present',
        code: 'REQUIRE_EITHER'
      });
    });

    it('passes when one field present', () => {
      const rule = requireEither('a', 'b');
      expect(rule({ a: 1 })).toBeNull();
      expect(rule({ b: 2 })).toBeNull();
    });

    it('passes when both fields present', () => {
      const rule = requireEither('a', 'b');
      expect(rule({ a: 1, b: 2 })).toBeNull();
    });
  });

  describe('dateRangeValid', () => {
    it('fails when start is after end', () => {
      const rule = dateRangeValid('start', 'end');
      expect(rule({ start: '2024-12-31', end: '2024-01-01' })).toEqual({
        field: 'start, end',
        message: 'start must be before end',
        code: 'DATE_RANGE_INVALID'
      });
    });

    it('passes when start is before end', () => {
      const rule = dateRangeValid('start', 'end');
      expect(rule({ start: '2024-01-01', end: '2024-12-31' })).toBeNull();
    });

    it('passes when dates are equal', () => {
      const rule = dateRangeValid('start', 'end');
      expect(rule({ start: '2024-06-15', end: '2024-06-15' })).toBeNull();
    });

    it('passes when either date is missing', () => {
      const rule = dateRangeValid('start', 'end');
      expect(rule({ start: '2024-01-01' })).toBeNull();
      expect(rule({ end: '2024-12-31' })).toBeNull();
      expect(rule({})).toBeNull();
    });
  });

  describe('passwordMatch', () => {
    it('fails when passwords do not match', () => {
      const rule = passwordMatch('password', 'confirm');
      expect(rule({ password: 'abc123', confirm: 'xyz789' })).toEqual({
        field: 'confirm',
        message: 'Passwords do not match',
        code: 'PASSWORD_MISMATCH'
      });
    });

    it('passes when passwords match', () => {
      const rule = passwordMatch('password', 'confirm');
      expect(rule({ password: 'abc123', confirm: 'abc123' })).toBeNull();
    });

    it('fails when one is missing', () => {
      const rule = passwordMatch('password', 'confirm');
      expect(rule({ password: 'abc123' })).not.toBeNull();
    });
  });

  describe('sumConstraint', () => {
    it('enforces exact sum', () => {
      const rule = sumConstraint(['a', 'b', 'c'], { exact: 100 });
      expect(rule({ a: 30, b: 30, c: 30 })).toEqual({
        field: 'a, b, c',
        message: 'Sum of a, b, c must equal 100',
        code: 'SUM_EXACT_VIOLATED'
      });
      expect(rule({ a: 30, b: 30, c: 40 })).toBeNull();
    });

    it('enforces minimum sum', () => {
      const rule = sumConstraint(['a', 'b'], { min: 50 });
      expect(rule({ a: 10, b: 10 })).toEqual({
        field: 'a, b',
        message: 'Sum of a, b must be at least 50',
        code: 'SUM_MIN_VIOLATED'
      });
      expect(rule({ a: 30, b: 30 })).toBeNull();
    });

    it('enforces maximum sum', () => {
      const rule = sumConstraint(['a', 'b'], { max: 50 });
      expect(rule({ a: 30, b: 30 })).toEqual({
        field: 'a, b',
        message: 'Sum of a, b must not exceed 50',
        code: 'SUM_MAX_VIOLATED'
      });
      expect(rule({ a: 20, b: 20 })).toBeNull();
    });

    it('ignores non-numeric values', () => {
      const rule = sumConstraint(['a', 'b', 'c'], { exact: 50 });
      expect(rule({ a: 25, b: 'string', c: 25 })).toBeNull();
    });
  });

  describe('integration', () => {
    it('validates user registration form', () => {
      const validator = createCrossFieldValidator();
      validator.addRule(passwordMatch('password', 'confirmPassword'));
      validator.addRule(requireIfPresent('referralCode', 'referralSource'));
      validator.addRule(mutuallyExclusive('email', 'phone'));

      // Valid: matching passwords, no referral
      expect(validator.validate({
        password: 'secret123',
        confirmPassword: 'secret123',
        email: 'user@example.com'
      }).valid).toBe(true);

      // Invalid: password mismatch
      expect(validator.validate({
        password: 'secret123',
        confirmPassword: 'different',
        email: 'user@example.com'
      }).valid).toBe(false);

      // Invalid: referral code without source
      expect(validator.validate({
        password: 'secret123',
        confirmPassword: 'secret123',
        email: 'user@example.com',
        referralCode: 'ABC123'
      }).valid).toBe(false);
    });

    it('validates budget allocation', () => {
      const validator = createCrossFieldValidator();
      validator.addRule(sumConstraint(['marketing', 'development', 'operations'], { exact: 100 }));

      expect(validator.validate({
        marketing: 30,
        development: 50,
        operations: 20
      }).valid).toBe(true);

      expect(validator.validate({
        marketing: 40,
        development: 40,
        operations: 40
      }).valid).toBe(false);
    });
  });
});

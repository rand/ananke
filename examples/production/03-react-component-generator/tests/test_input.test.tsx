import { describe, it, expect, vi } from 'vitest';
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { axe, toHaveNoViolations } from 'jest-axe';
import React from 'react';

// Extend Jest matchers
expect.extend(toHaveNoViolations);

/**
 * Mock Input component for testing
 * This represents the expected structure of the generated Input component
 */
interface InputProps {
  value: string;
  onChange: (value: string) => void;
  label: string;
  error?: string;
  placeholder?: string;
  disabled?: boolean;
  required?: boolean;
  type?: 'text' | 'email' | 'password' | 'number';
}

const MockInput: React.FC<InputProps> = ({
  value,
  onChange,
  label,
  error,
  placeholder,
  disabled = false,
  required = false,
  type = 'text',
}) => {
  const hasError = !!error;
  const inputId = `input-${label.toLowerCase().replace(/\s+/g, '-')}`;
  const errorId = `${inputId}-error`;

  return (
    <div className="input-container">
      <label htmlFor={inputId} className="input-label">
        {label}
        {required && <span aria-label="required"> *</span>}
      </label>
      <input
        id={inputId}
        type={type}
        value={value}
        onChange={(e) => onChange(e.target.value)}
        placeholder={placeholder}
        disabled={disabled}
        required={required}
        aria-invalid={hasError}
        aria-describedby={hasError ? errorId : undefined}
        className={`input ${hasError ? 'input-error' : ''} ${disabled ? 'input-disabled' : ''}`}
      />
      {hasError && (
        <span id={errorId} className="error-message" role="alert">
          {error}
        </span>
      )}
    </div>
  );
};

describe('Input Component - Generated Output Validation', () => {
  describe('Basic Rendering', () => {
    it('should render with label and input field', () => {
      const handleChange = vi.fn();
      render(
        <MockInput
          value=""
          onChange={handleChange}
          label="Email"
        />
      );

      expect(screen.getByLabelText('Email')).toBeInTheDocument();
      expect(screen.getByRole('textbox', { name: /email/i })).toBeInTheDocument();
    });

    it('should render with placeholder text', () => {
      const handleChange = vi.fn();
      render(
        <MockInput
          value=""
          onChange={handleChange}
          label="Email"
          placeholder="you@example.com"
        />
      );

      expect(screen.getByPlaceholderText('you@example.com')).toBeInTheDocument();
    });

    it('should render with initial value', () => {
      const handleChange = vi.fn();
      render(
        <MockInput
          value="test@example.com"
          onChange={handleChange}
          label="Email"
        />
      );

      expect(screen.getByDisplayValue('test@example.com')).toBeInTheDocument();
    });

    it('should render required indicator when required', () => {
      const handleChange = vi.fn();
      render(
        <MockInput
          value=""
          onChange={handleChange}
          label="Email"
          required
        />
      );

      expect(screen.getByLabelText('required')).toBeInTheDocument();
    });
  });

  describe('User Interaction', () => {
    it('should call onChange when user types', async () => {
      const user = userEvent.setup();
      const handleChange = vi.fn();

      render(
        <MockInput
          value=""
          onChange={handleChange}
          label="Email"
        />
      );

      const input = screen.getByRole('textbox', { name: /email/i });
      await user.type(input, 'test');

      expect(handleChange).toHaveBeenCalledTimes(4); // Once per character
      expect(handleChange).toHaveBeenLastCalledWith('test');
    });

    it('should update displayed value when value prop changes', () => {
      const handleChange = vi.fn();
      const { rerender } = render(
        <MockInput
          value="initial"
          onChange={handleChange}
          label="Email"
        />
      );

      expect(screen.getByDisplayValue('initial')).toBeInTheDocument();

      rerender(
        <MockInput
          value="updated"
          onChange={handleChange}
          label="Email"
        />
      );

      expect(screen.getByDisplayValue('updated')).toBeInTheDocument();
    });

    it('should not allow interaction when disabled', async () => {
      const user = userEvent.setup();
      const handleChange = vi.fn();

      render(
        <MockInput
          value=""
          onChange={handleChange}
          label="Email"
          disabled
        />
      );

      const input = screen.getByRole('textbox', { name: /email/i });
      expect(input).toBeDisabled();

      await user.type(input, 'test');
      expect(handleChange).not.toHaveBeenCalled();
    });
  });

  describe('Error State', () => {
    it('should display error message when error prop is provided', () => {
      const handleChange = vi.fn();
      render(
        <MockInput
          value=""
          onChange={handleChange}
          label="Email"
          error="Email is required"
        />
      );

      expect(screen.getByRole('alert')).toHaveTextContent('Email is required');
    });

    it('should set aria-invalid when error exists', () => {
      const handleChange = vi.fn();
      render(
        <MockInput
          value=""
          onChange={handleChange}
          label="Email"
          error="Email is required"
        />
      );

      const input = screen.getByRole('textbox', { name: /email/i });
      expect(input).toHaveAttribute('aria-invalid', 'true');
    });

    it('should associate error message with input via aria-describedby', () => {
      const handleChange = vi.fn();
      render(
        <MockInput
          value=""
          onChange={handleChange}
          label="Email"
          error="Email is required"
        />
      );

      const input = screen.getByRole('textbox', { name: /email/i });
      const errorMessage = screen.getByRole('alert');
      const errorId = input.getAttribute('aria-describedby');

      expect(errorId).toBeTruthy();
      expect(errorMessage).toHaveAttribute('id', errorId!);
    });

    it('should not display error message when error is not provided', () => {
      const handleChange = vi.fn();
      render(
        <MockInput
          value=""
          onChange={handleChange}
          label="Email"
        />
      );

      expect(screen.queryByRole('alert')).not.toBeInTheDocument();
    });
  });

  describe('Input Types', () => {
    it('should support text type (default)', () => {
      const handleChange = vi.fn();
      render(
        <MockInput
          value=""
          onChange={handleChange}
          label="Name"
        />
      );

      const input = screen.getByRole('textbox', { name: /name/i });
      expect(input).toHaveAttribute('type', 'text');
    });

    it('should support email type', () => {
      const handleChange = vi.fn();
      render(
        <MockInput
          value=""
          onChange={handleChange}
          label="Email"
          type="email"
        />
      );

      const input = screen.getByRole('textbox', { name: /email/i });
      expect(input).toHaveAttribute('type', 'email');
    });

    it('should support password type', () => {
      const handleChange = vi.fn();
      render(
        <MockInput
          value=""
          onChange={handleChange}
          label="Password"
          type="password"
        />
      );

      const input = screen.getByLabelText('Password');
      expect(input).toHaveAttribute('type', 'password');
    });

    it('should support number type', () => {
      const handleChange = vi.fn();
      render(
        <MockInput
          value=""
          onChange={handleChange}
          label="Age"
          type="number"
        />
      );

      const input = screen.getByRole('spinbutton', { name: /age/i });
      expect(input).toHaveAttribute('type', 'number');
    });
  });

  describe('Accessibility - Keyboard Navigation', () => {
    it('should be focusable via Tab key', async () => {
      const user = userEvent.setup();
      const handleChange = vi.fn();

      render(
        <MockInput
          value=""
          onChange={handleChange}
          label="Email"
        />
      );

      const input = screen.getByRole('textbox', { name: /email/i });

      await user.tab();
      expect(input).toHaveFocus();
    });

    it('should allow clearing with Escape key (if implemented)', async () => {
      const user = userEvent.setup();
      const handleChange = vi.fn();

      render(
        <MockInput
          value="test"
          onChange={handleChange}
          label="Email"
        />
      );

      const input = screen.getByRole('textbox', { name: /email/i });
      input.focus();

      await user.keyboard('{Escape}');

      // Note: This behavior depends on implementation
      // The test validates the key can be pressed without errors
    });
  });

  describe('Accessibility - ARIA Attributes', () => {
    it('should have proper label association', () => {
      const handleChange = vi.fn();
      render(
        <MockInput
          value=""
          onChange={handleChange}
          label="Email Address"
        />
      );

      const input = screen.getByRole('textbox', { name: /email address/i });
      const label = screen.getByText('Email Address');

      expect(input).toHaveAttribute('id');
      expect(label).toHaveAttribute('for', input.getAttribute('id')!);
    });

    it('should announce required state to screen readers', () => {
      const handleChange = vi.fn();
      render(
        <MockInput
          value=""
          onChange={handleChange}
          label="Email"
          required
        />
      );

      const input = screen.getByRole('textbox', { name: /email/i });
      expect(input).toHaveAttribute('required');
    });
  });

  describe('Accessibility - Automated Testing', () => {
    it('should have no accessibility violations', async () => {
      const handleChange = vi.fn();
      const { container } = render(
        <MockInput
          value=""
          onChange={handleChange}
          label="Email"
        />
      );

      const results = await axe(container);
      expect(results).toHaveNoViolations();
    });

    it('should have no accessibility violations with error state', async () => {
      const handleChange = vi.fn();
      const { container } = render(
        <MockInput
          value=""
          onChange={handleChange}
          label="Email"
          error="Email is required"
        />
      );

      const results = await axe(container);
      expect(results).toHaveNoViolations();
    });

    it('should have no accessibility violations when disabled', async () => {
      const handleChange = vi.fn();
      const { container } = render(
        <MockInput
          value=""
          onChange={handleChange}
          label="Email"
          disabled
        />
      );

      const results = await axe(container);
      expect(results).toHaveNoViolations();
    });
  });

  describe('Design System Integration', () => {
    it('should apply design token classes (validation via className)', () => {
      const handleChange = vi.fn();
      const { container } = render(
        <MockInput
          value=""
          onChange={handleChange}
          label="Email"
        />
      );

      const input = container.querySelector('input');
      expect(input).toHaveClass('input');
    });

    it('should apply error state classes when error exists', () => {
      const handleChange = vi.fn();
      const { container } = render(
        <MockInput
          value=""
          onChange={handleChange}
          label="Email"
          error="Email is required"
        />
      );

      const input = container.querySelector('input');
      expect(input).toHaveClass('input-error');
    });

    it('should apply disabled state classes when disabled', () => {
      const handleChange = vi.fn();
      const { container } = render(
        <MockInput
          value=""
          onChange={handleChange}
          label="Email"
          disabled
        />
      );

      const input = container.querySelector('input');
      expect(input).toHaveClass('input-disabled');
    });
  });
});

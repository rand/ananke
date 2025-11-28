import React from 'react';

/**
 * Button component props interface
 * Demonstrates TypeScript best practices for React components
 */
interface ButtonProps {
  /** Button text content */
  children: React.ReactNode;

  /** Click handler */
  onClick?: (event: React.MouseEvent<HTMLButtonElement>) => void;

  /** Button variant style */
  variant?: 'primary' | 'secondary' | 'outline' | 'ghost';

  /** Button size */
  size?: 'sm' | 'md' | 'lg';

  /** Disabled state */
  disabled?: boolean;

  /** Loading state - shows spinner and disables interaction */
  loading?: boolean;

  /** Button type attribute */
  type?: 'button' | 'submit' | 'reset';

  /** Accessible label for screen readers (overrides children) */
  ariaLabel?: string;

  /** Additional CSS class name */
  className?: string;

  /** Test ID for testing */
  testId?: string;
}

/**
 * Accessible Button component following WCAG 2.1 AA guidelines
 * Demonstrates:
 * - Design system token usage
 * - Comprehensive accessibility attributes
 * - TypeScript prop validation
 * - Loading and disabled states
 * - Keyboard navigation support
 */
export const Button: React.FC<ButtonProps> = ({
  children,
  onClick,
  variant = 'primary',
  size = 'md',
  disabled = false,
  loading = false,
  type = 'button',
  ariaLabel,
  className = '',
  testId,
}) => {
  // Combine disabled state from prop and loading state
  const isDisabled = disabled || loading;

  // Handle click with disabled check
  const handleClick = (event: React.MouseEvent<HTMLButtonElement>) => {
    if (!isDisabled && onClick) {
      onClick(event);
    }
  };

  // Build CSS classes from design tokens
  const getVariantClasses = (): string => {
    switch (variant) {
      case 'primary':
        return 'bg-primary-600 text-white hover:bg-primary-700 focus:ring-primary-500';
      case 'secondary':
        return 'bg-secondary-600 text-white hover:bg-secondary-700 focus:ring-secondary-500';
      case 'outline':
        return 'bg-transparent text-primary-600 border-2 border-primary-600 hover:bg-primary-50 focus:ring-primary-500';
      case 'ghost':
        return 'bg-transparent text-neutral-700 hover:bg-neutral-100 focus:ring-neutral-400';
      default:
        return '';
    }
  };

  const getSizeClasses = (): string => {
    switch (size) {
      case 'sm':
        return 'px-3 py-1.5 text-sm'; // spacing-3, spacing-1.5, typography-sm
      case 'md':
        return 'px-4 py-2 text-base'; // spacing-4, spacing-2, typography-base
      case 'lg':
        return 'px-6 py-3 text-lg'; // spacing-6, spacing-3, typography-lg
      default:
        return '';
    }
  };

  const baseClasses = 'font-medium rounded-md transition-colors duration-200 focus:outline-none focus:ring-2 focus:ring-offset-2';
  const disabledClasses = isDisabled ? 'opacity-50 cursor-not-allowed' : 'cursor-pointer';

  const classes = `${baseClasses} ${getVariantClasses()} ${getSizeClasses()} ${disabledClasses} ${className}`.trim();

  return (
    <button
      type={type}
      onClick={handleClick}
      disabled={isDisabled}
      aria-label={ariaLabel}
      aria-disabled={isDisabled}
      aria-busy={loading}
      data-testid={testId}
      className={classes}
    >
      {loading && (
        <span
          className="inline-block mr-2 w-4 h-4 border-2 border-current border-t-transparent rounded-full animate-spin"
          role="status"
          aria-label="Loading"
        />
      )}
      {children}
    </button>
  );
};

/**
 * Example usage:
 *
 * <Button variant="primary" size="md" onClick={handleSubmit}>
 *   Submit
 * </Button>
 *
 * <Button variant="outline" size="lg" loading={isLoading}>
 *   Save
 * </Button>
 *
 * <Button variant="ghost" size="sm" disabled>
 *   Cancel
 * </Button>
 */

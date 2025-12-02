import { QueryBuilder } from './query_builder';

describe('QueryBuilder', () => {
  describe('basic select', () => {
    it('should build simple SELECT query', () => {
      const qb = new QueryBuilder();
      const result = qb.select('users').build();

      expect(result.sql).toBe('SELECT * FROM users');
      expect(result.params).toEqual([]);
    });
  });

  describe('WHERE clauses', () => {
    it('should build query with single WHERE clause', () => {
      const qb = new QueryBuilder();
      const result = qb
        .select('users')
        .where('age', '>', 18)
        .build();

      expect(result.sql).toBe('SELECT * FROM users WHERE age > ?');
      expect(result.params).toEqual([18]);
    });

    it('should build query with multiple WHERE clauses', () => {
      const qb = new QueryBuilder();
      const result = qb
        .select('users')
        .where('age', '>', 18)
        .where('status', '=', 'active')
        .build();

      expect(result.sql).toBe('SELECT * FROM users WHERE age > ? AND status = ?');
      expect(result.params).toEqual([18, 'active']);
    });

    it('should support different operators', () => {
      const qb = new QueryBuilder();
      const result = qb
        .select('products')
        .where('price', '>=', 100)
        .where('quantity', '<', 10)
        .build();

      expect(result.sql).toBe('SELECT * FROM products WHERE price >= ? AND quantity < ?');
      expect(result.params).toEqual([100, 10]);
    });

    it('should handle string values', () => {
      const qb = new QueryBuilder();
      const result = qb
        .select('users')
        .where('name', '=', 'John')
        .build();

      expect(result.sql).toBe('SELECT * FROM users WHERE name = ?');
      expect(result.params).toEqual(['John']);
    });
  });

  describe('ORDER BY clause', () => {
    it('should build query with ORDER BY ASC', () => {
      const qb = new QueryBuilder();
      const result = qb
        .select('users')
        .orderBy('created_at', 'ASC')
        .build();

      expect(result.sql).toBe('SELECT * FROM users ORDER BY created_at ASC');
    });

    it('should build query with ORDER BY DESC', () => {
      const qb = new QueryBuilder();
      const result = qb
        .select('users')
        .orderBy('created_at', 'DESC')
        .build();

      expect(result.sql).toBe('SELECT * FROM users ORDER BY created_at DESC');
    });
  });

  describe('LIMIT clause', () => {
    it('should build query with LIMIT', () => {
      const qb = new QueryBuilder();
      const result = qb
        .select('users')
        .limit(10)
        .build();

      expect(result.sql).toBe('SELECT * FROM users LIMIT 10');
    });
  });

  describe('method chaining', () => {
    it('should support fluent interface', () => {
      const qb = new QueryBuilder();
      const result = qb
        .select('users')
        .where('age', '>', 18)
        .where('status', '=', 'active')
        .orderBy('created_at', 'DESC')
        .limit(10)
        .build();

      expect(result.sql).toBe(
        'SELECT * FROM users WHERE age > ? AND status = ? ORDER BY created_at DESC LIMIT 10'
      );
      expect(result.params).toEqual([18, 'active']);
    });

    it('should return this for chaining', () => {
      const qb = new QueryBuilder();

      expect(qb.select('users')).toBe(qb);
      expect(qb.where('id', '=', 1)).toBe(qb);
      expect(qb.orderBy('name', 'ASC')).toBe(qb);
      expect(qb.limit(5)).toBe(qb);
    });
  });

  describe('parameterized queries', () => {
    it('should use ? placeholders for values', () => {
      const qb = new QueryBuilder();
      const result = qb
        .select('users')
        .where('email', '=', 'test@example.com')
        .build();

      expect(result.sql).toContain('?');
      expect(result.sql).not.toContain('test@example.com');
    });

    it('should maintain parameter order', () => {
      const qb = new QueryBuilder();
      const result = qb
        .select('users')
        .where('first_name', '=', 'John')
        .where('last_name', '=', 'Doe')
        .where('age', '>', 25)
        .build();

      expect(result.params).toEqual(['John', 'Doe', 25]);
    });
  });

  describe('complex queries', () => {
    it('should build complex query with all clauses', () => {
      const qb = new QueryBuilder();
      const result = qb
        .select('products')
        .where('category', '=', 'electronics')
        .where('price', '>=', 100)
        .where('price', '<=', 500)
        .where('in_stock', '=', true)
        .orderBy('price', 'ASC')
        .limit(20)
        .build();

      expect(result.sql).toBe(
        'SELECT * FROM products WHERE category = ? AND price >= ? AND price <= ? AND in_stock = ? ORDER BY price ASC LIMIT 20'
      );
      expect(result.params).toEqual(['electronics', 100, 500, true]);
    });
  });

  describe('edge cases', () => {
    it('should throw error when building without table', () => {
      const qb = new QueryBuilder();

      expect(() => qb.build()).toThrow('Table name is required');
    });

    it('should handle queries with only WHERE clause', () => {
      const qb = new QueryBuilder();
      const result = qb
        .select('users')
        .where('active', '=', true)
        .build();

      expect(result.sql).toBe('SELECT * FROM users WHERE active = ?');
    });

    it('should handle queries with only ORDER BY', () => {
      const qb = new QueryBuilder();
      const result = qb
        .select('users')
        .orderBy('name', 'ASC')
        .build();

      expect(result.sql).toBe('SELECT * FROM users ORDER BY name ASC');
    });

    it('should handle queries with only LIMIT', () => {
      const qb = new QueryBuilder();
      const result = qb
        .select('users')
        .limit(5)
        .build();

      expect(result.sql).toBe('SELECT * FROM users LIMIT 5');
    });
  });

  describe('multiple query building', () => {
    it('should create independent query builders', () => {
      const qb1 = new QueryBuilder();
      const qb2 = new QueryBuilder();

      const result1 = qb1.select('users').where('id', '=', 1).build();
      const result2 = qb2.select('products').where('id', '=', 2).build();

      expect(result1.sql).toBe('SELECT * FROM users WHERE id = ?');
      expect(result2.sql).toBe('SELECT * FROM products WHERE id = ?');
      expect(result1.params).toEqual([1]);
      expect(result2.params).toEqual([2]);
    });
  });
});

class QueryBuilder {
  private tableName: string | null = null;
  private whereConditions: Array<{ field: string; operator: string; value: any }> = [];
  private orderByClause: { field: string; direction: 'ASC' | 'DESC' } | null = null;
  private limitValue: number | null = null;

  select(table: string): this {
    this.tableName = table;
    return this;
  }

  where(field: string, operator: string, value: any): this {
    this.whereConditions.push({ field, operator, value });
    return this;
  }

  orderBy(field: string, direction: 'ASC' | 'DESC'): this {
    this.orderByClause = { field, direction };
    return this;
  }

  limit(count: number): this {
    this.limitValue = count;
    return this;
  }

  build(): { sql: string; params: any[] } {
    if (!this.tableName) {
      throw new Error('Table name is required');
    }

    const params: any[] = [];
    let sql = `SELECT * FROM ${this.tableName}`;

    // Add WHERE clauses
    if (this.whereConditions.length > 0) {
      const whereClauses = this.whereConditions.map(condition => {
        params.push(condition.value);
        return `${condition.field} ${condition.operator} ?`;
      });

      sql += ' WHERE ' + whereClauses.join(' AND ');
    }

    // Add ORDER BY clause
    if (this.orderByClause) {
      sql += ` ORDER BY ${this.orderByClause.field} ${this.orderByClause.direction}`;
    }

    // Add LIMIT clause
    if (this.limitValue !== null) {
      sql += ` LIMIT ${this.limitValue}`;
    }

    return { sql, params };
  }
}

export { QueryBuilder };

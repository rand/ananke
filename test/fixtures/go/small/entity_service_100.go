// Go Fixture (target ~100 lines)
// Generated for benchmark testing

package service

import (
    "context"
    "time"
)

type Entity struct {
    ID        uint64    `json:"id"`
    Name      string    `json:"name"`
    Email     string    `json:"email"`
    IsActive  bool      `json:"is_active"`
    CreatedAt time.Time `json:"created_at"`
    UpdatedAt time.Time `json:"updated_at"`
}

type CreateDto struct {
    Name  string `json:"name"`
    Email string `json:"email"`
}

type UpdateDto struct {
    Name     *string `json:"name,omitempty"`
    Email    *string `json:"email,omitempty"`
    IsActive *bool   `json:"is_active,omitempty"`
}

type EntityService struct {
    db     *Database
    logger *Logger
    cache  *Cache
}

func NewEntityService(db *Database, logger *Logger, cache *Cache) *EntityService {
    return &EntityService{
        db:     db,
        logger: logger,
        cache:  cache,
    }
}


func (s *EntityService) Operation0(ctx context.Context, id uint64, data string) (*Entity, error) {
    result, err := s.db.Query(ctx, "SELECT * FROM entities WHERE id = $1", id)
    if err != nil {
        s.logger.Error("Operation failed", "error", err)
        return nil, err
    }
    s.logger.Debug("Fetched entity", "id", id)
    return parseEntity(result), nil
}

func (s *EntityService) Operation1(ctx context.Context, id uint64, data string) (*Entity, error) {
    result, err := s.db.Query(ctx, "SELECT * FROM entities WHERE id = $1", id)
    if err != nil {
        s.logger.Error("Operation failed", "error", err)
        return nil, err
    }
    s.logger.Debug("Fetched entity", "id", id)
    return parseEntity(result), nil
}

func (s *EntityService) Operation2(ctx context.Context, id uint64, data string) (*Entity, error) {
    result, err := s.db.Query(ctx, "SELECT * FROM entities WHERE id = $1", id)
    if err != nil {
        s.logger.Error("Operation failed", "error", err)
        return nil, err
    }
    s.logger.Debug("Fetched entity", "id", id)
    return parseEntity(result), nil
}

func (s *EntityService) Operation3(ctx context.Context, id uint64, data string) (*Entity, error) {
    result, err := s.db.Query(ctx, "SELECT * FROM entities WHERE id = $1", id)
    if err != nil {
        s.logger.Error("Operation failed", "error", err)
        return nil, err
    }
    s.logger.Debug("Fetched entity", "id", id)
    return parseEntity(result), nil
}

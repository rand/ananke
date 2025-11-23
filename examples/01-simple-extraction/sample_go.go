// Sample Go HTTP handler for constraint extraction
// Demonstrates type safety, error handling, and Go idioms

package main

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"log"
	"net/http"
	"regexp"
	"strconv"
	"strings"
	"time"
)

// Type constraint: Explicit error types
var (
	ErrNotFound      = errors.New("resource not found")
	ErrBadRequest    = errors.New("bad request")
	ErrUnauthorized  = errors.New("unauthorized")
	ErrInternalError = errors.New("internal server error")
)

// Type constraint: Structured user model
type User struct {
	ID           uint64    `json:"id"`
	Email        string    `json:"email"`
	Username     string    `json:"username"`
	CreatedAt    time.Time `json:"created_at"`
	IsActive     bool      `json:"is_active"`
	PasswordHash string    `json:"-"` // Security constraint: Never serialize password
}

// Type constraint: Request validation struct
type CreateUserRequest struct {
	Email    string `json:"email"`
	Username string `json:"username"`
	Password string `json:"password"`
}

// Semantic constraint: Validate email format
func (r *CreateUserRequest) ValidateEmail() error {
	if r.Email == "" {
		return fmt.Errorf("email is required")
	}
	// Syntactic constraint: Email regex pattern
	emailRegex := regexp.MustCompile(`^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$`)
	if !emailRegex.MatchString(r.Email) {
		return fmt.Errorf("invalid email format")
	}
	return nil
}

// Semantic constraint: Validate username
func (r *CreateUserRequest) ValidateUsername() error {
	if r.Username == "" {
		return fmt.Errorf("username is required")
	}
	// Semantic constraint: Length bounds
	if len(r.Username) < 3 || len(r.Username) > 50 {
		return fmt.Errorf("username must be 3-50 characters")
	}
	// Semantic constraint: Alphanumeric only
	for _, char := range r.Username {
		if !isAlphanumeric(char) {
			return fmt.Errorf("username must be alphanumeric")
		}
	}
	return nil
}

// Security constraint: Password validation
func (r *CreateUserRequest) ValidatePassword() error {
	if r.Password == "" {
		return fmt.Errorf("password is required")
	}
	// Semantic constraint: Minimum length
	if len(r.Password) < 8 {
		return fmt.Errorf("password must be at least 8 characters")
	}
	// Security constraint: Complexity requirements
	hasUpper := strings.IndexFunc(r.Password, func(r rune) bool { return r >= 'A' && r <= 'Z' }) >= 0
	hasLower := strings.IndexFunc(r.Password, func(r rune) bool { return r >= 'a' && r <= 'z' }) >= 0
	hasDigit := strings.IndexFunc(r.Password, func(r rune) bool { return r >= '0' && r <= '9' }) >= 0

	if !hasUpper || !hasLower || !hasDigit {
		return fmt.Errorf("password must contain uppercase, lowercase, and digit")
	}
	return nil
}

// Type constraint: Pagination parameters
type PaginationQuery struct {
	Page  int
	Limit int
}

// Semantic constraint: Validate pagination bounds
func (p *PaginationQuery) Validate() error {
	// Operational constraint: Default values
	if p.Page == 0 {
		p.Page = 1
	}
	if p.Limit == 0 {
		p.Limit = 10
	}
	// Semantic constraint: Bounds checking
	if p.Page < 1 {
		return fmt.Errorf("page must be >= 1")
	}
	if p.Limit < 1 || p.Limit > 100 {
		return fmt.Errorf("limit must be between 1 and 100")
	}
	return nil
}

// Calculate database offset
func (p *PaginationQuery) Offset() int {
	return (p.Page - 1) * p.Limit
}

// Architectural constraint: Repository pattern
type UserRepository interface {
	Create(ctx context.Context, req CreateUserRequest) (*User, error)
	List(ctx context.Context, pagination PaginationQuery) ([]*User, error)
	Get(ctx context.Context, userID uint64) (*User, error)
	Delete(ctx context.Context, userID uint64) error
}

// Concrete implementation
type InMemoryUserRepo struct {
	users  map[uint64]*User
	nextID uint64
}

// Type constraint: Constructor returns interface
func NewUserRepository() UserRepository {
	return &InMemoryUserRepo{
		users:  make(map[uint64]*User),
		nextID: 1,
	}
}

// Error handling constraint: All methods return error
func (r *InMemoryUserRepo) Create(ctx context.Context, req CreateUserRequest) (*User, error) {
	// Semantic constraint: Check for duplicate email
	for _, user := range r.users {
		if user.Email == req.Email {
			return nil, fmt.Errorf("email already exists: %w", ErrBadRequest)
		}
		if user.Username == req.Username {
			return nil, fmt.Errorf("username already exists: %w", ErrBadRequest)
		}
	}

	// Security constraint: Hash password
	passwordHash, err := hashPassword(req.Password)
	if err != nil {
		return nil, fmt.Errorf("failed to hash password: %w", err)
	}

	user := &User{
		ID:           r.nextID,
		Email:        req.Email,
		Username:     req.Username,
		CreatedAt:    time.Now().UTC(),
		IsActive:     true, // Operational constraint: New users are active
		PasswordHash: passwordHash,
	}

	r.users[r.nextID] = user
	r.nextID++

	return user, nil
}

func (r *InMemoryUserRepo) List(ctx context.Context, pagination PaginationQuery) ([]*User, error) {
	// Error handling constraint: Validate input
	if err := pagination.Validate(); err != nil {
		return nil, fmt.Errorf("invalid pagination: %w", err)
	}

	// Semantic constraint: Return slice, not map
	users := make([]*User, 0, len(r.users))
	for _, user := range r.users {
		users = append(users, user)
	}

	// Apply pagination
	offset := pagination.Offset()
	end := offset + pagination.Limit
	if offset >= len(users) {
		return []*User{}, nil // Return empty slice, not nil
	}
	if end > len(users) {
		end = len(users)
	}

	return users[offset:end], nil
}

func (r *InMemoryUserRepo) Get(ctx context.Context, userID uint64) (*User, error) {
	user, exists := r.users[userID]
	if !exists {
		return nil, fmt.Errorf("user %d: %w", userID, ErrNotFound)
	}
	return user, nil
}

func (r *InMemoryUserRepo) Delete(ctx context.Context, userID uint64) error {
	user, exists := r.users[userID]
	if !exists {
		return fmt.Errorf("user %d: %w", userID, ErrNotFound)
	}
	// Semantic constraint: Soft delete
	user.IsActive = false
	return nil
}

// Architectural constraint: Handler layer
type UserHandler struct {
	repo UserRepository
}

func NewUserHandler(repo UserRepository) *UserHandler {
	return &UserHandler{repo: repo}
}

// HTTP handler: Create user
func (h *UserHandler) CreateUser(w http.ResponseWriter, r *http.Request) {
	// Error handling constraint: Check HTTP method
	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	var req CreateUserRequest
	// Error handling constraint: Validate JSON decode
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "Invalid request body", http.StatusBadRequest)
		return
	}
	defer r.Body.Close()

	// Semantic constraint: Validate all fields
	if err := req.ValidateEmail(); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}
	if err := req.ValidateUsername(); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}
	if err := req.ValidatePassword(); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	// Security constraint: Never log passwords
	log.Printf("Creating user: %s", req.Username)

	// Create user in repository
	user, err := h.repo.Create(r.Context(), req)
	if err != nil {
		// Error handling constraint: Log error, return generic message
		log.Printf("Failed to create user: %v", err)
		if errors.Is(err, ErrBadRequest) {
			http.Error(w, err.Error(), http.StatusBadRequest)
		} else {
			http.Error(w, "Internal server error", http.StatusInternalServerError)
		}
		return
	}

	// Type constraint: Set proper content type
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	json.NewEncoder(w).Encode(user)
}

// HTTP handler: List users
func (h *UserHandler) ListUsers(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	// Parse pagination from query params
	pagination := PaginationQuery{
		Page:  parseIntParam(r.URL.Query().Get("page"), 1),
		Limit: parseIntParam(r.URL.Query().Get("limit"), 10),
	}

	users, err := h.repo.List(r.Context(), pagination)
	if err != nil {
		log.Printf("Failed to list users: %v", err)
		http.Error(w, "Internal server error", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(users)
}

// HTTP handler: Get user by ID
func (h *UserHandler) GetUser(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	// Parse user ID from URL path
	// Semantic constraint: ID must be positive integer
	idStr := strings.TrimPrefix(r.URL.Path, "/users/")
	userID, err := strconv.ParseUint(idStr, 10, 64)
	if err != nil {
		http.Error(w, "Invalid user ID", http.StatusBadRequest)
		return
	}

	user, err := h.repo.Get(r.Context(), userID)
	if err != nil {
		if errors.Is(err, ErrNotFound) {
			http.Error(w, "User not found", http.StatusNotFound)
		} else {
			log.Printf("Failed to get user: %v", err)
			http.Error(w, "Internal server error", http.StatusInternalServerError)
		}
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(user)
}

// Security constraint: Password hashing
func hashPassword(password string) (string, error) {
	// TODO: Use bcrypt or scrypt
	return fmt.Sprintf("hashed_%s", password), nil
}

// Utility: Check if rune is alphanumeric
func isAlphanumeric(r rune) bool {
	return (r >= 'a' && r <= 'z') || (r >= 'A' && r <= 'Z') || (r >= '0' && r <= '9')
}

// Utility: Parse int parameter with default
func parseIntParam(value string, defaultValue int) int {
	if value == "" {
		return defaultValue
	}
	parsed, err := strconv.Atoi(value)
	if err != nil {
		return defaultValue
	}
	return parsed
}

// Main function: Setup HTTP server
func main() {
	// Architectural constraint: Dependency injection
	repo := NewUserRepository()
	handler := NewUserHandler(repo)

	// Register routes
	http.HandleFunc("/users", func(w http.ResponseWriter, r *http.Request) {
		switch r.Method {
		case http.MethodPost:
			handler.CreateUser(w, r)
		case http.MethodGet:
			handler.ListUsers(w, r)
		default:
			http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		}
	})

	// Operational constraint: Configurable port
	port := ":8080"
	log.Printf("Starting server on %s", port)

	// Error handling constraint: Log fatal errors
	if err := http.ListenAndServe(port, nil); err != nil {
		log.Fatalf("Server failed to start: %v", err)
	}
}

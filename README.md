# JetRockets Blog Post Test

A high-performance Ruby on Rails REST API for managing blog posts with ratings and analytics. Built with PostgreSQL, optimized for handling 200k+ posts efficiently.

## Features

- **Post Management**: Create posts with automatic user creation
- **Rating System**: Rate posts with concurrency-safe duplicate prevention
- **Top Posts**: Get top N posts by average rating
- **IP Analytics**: Find IPs used by multiple authors
- **Bulk Operations**: High-performance bulk creation for posts and ratings
- **Performance Optimized**: Database functions, triggers, and bulk inserts

## Requirements

- **Ruby**: 3.4+ (latest stable)
- **Rails**: 8.0.3+ (latest stable)
- **PostgreSQL**: 12+ (with plpgsql extension)
- **Bundler**: Latest version

## Quick Start

### 1. Installation

```bash
# Clone the repository
git clone <repository-url>
cd jetrockets-blog-post-test

# Install dependencies
bundle install

# Setup database
bundle exec rails db:create db:migrate

# Run tests (optional)
bundle exec rspec

# Start server
bundle exec rails server
```

### 2. Database Setup

```bash
# Create and migrate database
bundle exec rails db:create db:migrate

# Generate sample data (200k posts + ratings)
bundle exec rails db:seed
```

**Note**: The seeding process uses hybrid bulk operations and takes ~30-60 seconds to create 200k posts with ratings.

## API Endpoints

### Base URL
```
http://localhost:3000/blog/api
```

### 1. Create Post
```http
POST /posts
Content-Type: application/json

{
  "post": {
    "title": "My Blog Post",
    "body": "Post content here...",
    "login": "user123",
    "ip": "192.168.1.1"
  }
}
```

**Response (201 Created):**
```json
{
  "post": {
    "id": 1,
    "title": "My Blog Post",
    "body": "Post content here...",
    "ip": "192.168.1.1",
    "avg_rating": "0.0",
    "created_at": "2025-09-26T01:00:00.000Z",
    "updated_at": "2025-09-26T01:00:00.000Z"
  },
  "user": {
    "id": 1,
    "login": "user123",
    "created_at": "2025-09-26T01:00:00.000Z",
    "updated_at": "2025-09-26T01:00:00.000Z"
  }
}
```

### 2. Rate Post
```http
POST /ratings
Content-Type: application/json

{
  "rating": {
    "post_id": 1,
    "user_id": 2,
    "value": 5
  }
}
```

**Response (201 Created):**
```json
{
  "rating": {
    "id": 1,
    "post_id": 1,
    "user_id": 2,
    "value": 5,
    "created_at": "2025-09-26T01:00:00.000Z",
    "updated_at": "2025-09-26T01:00:00.000Z"
  },
  "avg_rating": 5.0
}
```

### 3. Get Top Posts
```http
GET /posts/top?limit=10
```

**Response (200 OK):**
```json
[
  {
    "id": 42001,
    "title": "Blog Post #42001 - News Flash",
    "body": "This is the content of blog post number 42001. It contains valuable information about API design..."
  },
  {
    "id": 136600,
    "title": "Blog Post #136600 - Opinion",
    "body": "This is the content of blog post number 136600. It contains valuable information about Ruby on Rails..."
  }
]
```

### 4. Get Multi-Author IPs
```http
GET /ips
```

**Response (200 OK):**
```json
[
  {
    "ip": "192.168.0.0",
    "authors": ["user000", "user001", "user002", "user003", "..."]
  },
  {
    "ip": "192.168.0.1",
    "authors": ["user000", "user001", "user002", "user003", "..."]
  }
]
```

## Bulk Operations (High Performance)

### Bulk Create Posts
```http
POST /posts/bulk_create
Content-Type: application/json

{
  "posts": [
    {
      "title": "Post 1",
      "body": "Content 1",
      "login": "user1",
      "ip": "192.168.1.1"
    },
    {
      "title": "Post 2",
      "body": "Content 2",
      "login": "user2",
      "ip": "192.168.1.2"
    }
  ],
  "batch_size": 1000
}
```

### Bulk Create Ratings
```http
POST /ratings/bulk_create
Content-Type: application/json

{
  "ratings": [
    {
      "post_id": 1,
      "user_id": 2,
      "value": 5
    },
    {
      "post_id": 2,
      "user_id": 1,
      "value": 4
    }
  ],
  "batch_size": 1000
}
```

## Testing

### Run Full Test Suite
```bash
bundle exec rspec
```

### Run Specific Tests
```bash
# Service tests
bundle exec rspec spec/services/

# API endpoint tests
bundle exec rspec spec/requests/

# Run with coverage
bundle exec rspec --format documentation
```

### Test Coverage
- **Services**: Comprehensive unit tests with edge cases
- **Controllers**: API endpoint integration tests
- **Performance**: Bulk operation efficiency tests
- **Concurrency**: Thread-safe rating creation tests


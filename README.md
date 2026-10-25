# BorrowBase

BorrowBase is a JSON API that staff use to manage a collection of items they lend out (currently books).
Staff can use it to:

- add and remove books
- lend a book to a borrower and record when it comes back
- see every book with its current status (`available` / `borrowed`)
- see one book with its full borrowing history (borrow date, due date, return date, borrower)

The borrow period is **30 days**: the due date is set automatically when a book is borrowed.

Borrowers get an email reminder 3 days before the due date and on the due date. `ReturnDateReminderJob`
runs every day at 10am (Solid Queue recurring task, `config/recurring.yml`). Reminders are preview-only:
no real email is sent, the payload is logged (`Email payload: {...}` in the log) and can be viewed at
http://localhost:3000/rails/mailers/borrowing_mailer.

## Tech stack

| Layer           | Technology                         |
|-----------------|------------------------------------|
| Language        | Ruby 4.0 (`4.0.9`)                 |
| Framework       | Rails 8.1 (API-only)               |
| Database        | PostgreSQL 17                      |
| Background jobs | Solid Queue                        |
| Web server      | Puma                               |
| Testing         | RSpec 8, FactoryBot, Faker         |
| Linting         | RuboCop (rails-omakase)            |
| Dev environment | Docker + Docker Compose            |

## Running with Docker

Requirements: Docker with Docker Compose.

```bash
docker compose up --build
```

This starts two containers:

- `db`: PostgreSQL 17. Its data is kept in the `pgdata` volume.
- `web`: the Rails app at **http://localhost:3000**. On every start it runs `db:prepare` and `db:seed`.

**Every start re-seeds the database.** The seeds delete all data and recreate the demo records
(see [Example records](#example-records)), so the ready-to-copy examples below always work after a restart.

To check that the app is up:

```bash
curl http://localhost:3000/up
```

Useful commands:

```bash
docker compose exec web bin/rails console     # Rails console
docker compose exec web bin/rails db:seed     # reset demo data without restarting
docker compose exec web bin/rubocop           # lint
docker compose down                           # stop (add -v to also drop the database volume)
```

### Running the tests

```bash
docker compose exec -e RAILS_ENV=test web bin/rails db:schema:load   # first time / after migrations
docker compose exec -e RAILS_ENV=test web bundle exec rspec
```

Use `db:schema:load`, not `db:prepare`, for the test database. When `db:prepare` creates a new database
it also runs the seeds, and the specs expect an empty database.

## Example records

The seeds always create these records with fixed ids, in addition to randomly generated (Faker) data:

**Users (borrowers)**

| id | Name       | Email                        | Card number  |
|----|------------|------------------------------|--------------|
| 1  | Jane Doe   | `jane.doe@borrowbase.test`   | `DEMO000001` |
| 2  | John Smith | `john.smith@borrowbase.test` | `DEMO000002` |

**Books**

| id | Serial   | Title                                   | Status    | Notes                                         |
|----|----------|-----------------------------------------|-----------|-----------------------------------------------|
| 1  | `900001` | The Pragmatic Programmer                | available | one past borrowing (John), use it to **borrow** |
| 2  | `900002` | Practical Object-Oriented Design in Ruby | borrowed  | borrowed by Jane 10 days ago, plus one past borrowing |
| 3  | `900003` | Eloquent Ruby                           | available | never borrowed, safe to **delete**            |

**Borrowings**

| id | Book | User | State                                     |
|----|------|------|-------------------------------------------|
| 1  | 1    | 2    | returned                                  |
| 2  | 2    | 1    | returned                                  |
| 3  | 2    | 1    | **active**, use it to **return**          |

## API endpoints

All endpoints are under `/api`. They accept and return JSON.

| Action                               | Method   | Path                              |
|--------------------------------------|----------|-----------------------------------|
| List books with status               | `GET`    | `/api/books`                      |
| Book details, status and history     | `GET`    | `/api/books/:book_id/borrowings`  |
| Add a book                           | `POST`   | `/api/books`                      |
| Delete a book                        | `DELETE` | `/api/books/:id`                  |
| Borrow a book                        | `POST`   | `/api/borrowings`                 |
| Return a book                        | `PATCH`  | `/api/borrowings/:id/return`      |

Errors:

- `404 {"error": "Not found"}` when a record doesn't exist.
- `422 {"errors": {"field": ["message"]}}` when validation fails.

### List books with status

```bash
curl http://localhost:3000/api/books
```

```json
[
  {
    "id": 2,
    "serial_number": "900002",
    "title": "Practical Object-Oriented Design in Ruby",
    "author1": "Sandi Metz",
    "author2": null,
    "status": "borrowed",
    "due_date": "2026-11-14"
  }
]
```

`due_date` is set only when the book is currently borrowed.

### Book details with status and borrowing history

```bash
curl http://localhost:3000/api/books/2/borrowings
```

```json
{
  "id": 2,
  "serial_number": "900002",
  "title": "Practical Object-Oriented Design in Ruby",
  "author1": "Sandi Metz",
  "author2": null,
  "status": "borrowed",
  "due_date": "2026-11-14",
  "borrowings": [
    {
      "id": 3, "item_id": 2, "user_id": 1,
      "borrow_date": "2026-10-15", "due_date": "2026-11-14", "return_date": null,
      "borrower": { "first_name": "Jane", "last_name": "Doe", "email": "jane.doe@borrowbase.test", "card_number": "DEMO000001" }
    },
    {
      "id": 2, "item_id": 2, "user_id": 1,
      "borrow_date": "2026-08-16", "due_date": "2026-09-15", "return_date": "2026-09-10",
      "borrower": { "first_name": "Jane", "last_name": "Doe", "email": "jane.doe@borrowbase.test", "card_number": "DEMO000001" }
    }
  ]
}
```

The history is sorted newest first. The dates in these examples depend on the day you seed the database.

### Add a book

`title`, `author1_first_name` and `author1_last_name` are required. The second author is optional.
A unique 6-digit `serial_number` is generated automatically.

```bash
curl -X POST http://localhost:3000/api/books \
  -H "Content-Type: application/json" \
  -d '{"book": {"title": "Refactoring", "author1_first_name": "Martin", "author1_last_name": "Fowler"}}'
```

Returns `201 Created` with the new book.

### Delete a book

```bash
curl -X DELETE http://localhost:3000/api/books/3
```

Returns `204 No Content`. The book's borrowing history is deleted too.

### Borrow a book

```bash
curl -X POST http://localhost:3000/api/borrowings \
  -H "Content-Type: application/json" \
  -d '{"borrowing": {"user_id": 1, "item_id": 1}}'
```

Returns `201 Created`:

```json
{ "id": 204, "item_id": 1, "user_id": 1, "borrow_date": "2026-10-25", "due_date": "2026-11-24", "return_date": null }
```

The borrow date is today and the due date is 30 days later.
Borrowing a book that is already borrowed returns `422` with `{"errors": {"item": ["Item is already borrowed"]}}`.

### Return a book

```bash
curl -X PATCH http://localhost:3000/api/borrowings/3/return
```

Returns `200 OK` with the borrowing, its `return_date` set to today.
Returning a borrowing a second time returns `422` with `{"errors": {"base": ["Borrowing is already returned"]}}`.

## Email previews

Reminder emails are never actually sent. Open them in a browser instead (development only):

| Preview                          | URL                                                                          |
|----------------------------------|------------------------------------------------------------------------------|
| All previews                     | http://localhost:3000/rails/mailers                                          |
| `BorrowingMailer` previews       | http://localhost:3000/rails/mailers/borrowing_mailer                         |
| Reminder 3 days before due date  | http://localhost:3000/rails/mailers/borrowing_mailer/return_reminder_in_3_days |
| Reminder on the due date         | http://localhost:3000/rails/mailers/borrowing_mailer/return_reminder_due_today |

The previews are defined in `spec/mailers/previews/borrowing_mailer_preview.rb` and use sample data.
Reminders sent by `ReturnDateReminderJob` also log their payload (`Email payload: {...}`):

```bash
docker compose logs web | grep "Email payload"
```

# CLAUDE.md — AI Pair Programming Instructions

This file is the single source of truth for AI assistants working on this project.
Read it fully before writing any code. Update it whenever the project structure changes.

---

## Project Overview

**BorrowBase** 

Simple API for borrowing items management system. The API will be used by staff to track and update the status of owned items.
API allows to:
- add new item
- delete item
- borrow item
- retrieve a list of all items together with status information (available, borrowed)
- retrieve information about specific item together with full history of its borrowings (borrow date, return date, borrower data)
The borrower should receive email reminders 3 days before 30 days borrow period end on the due date. Only email preview (no real mail send, logging payload and mailer preview)

---

## Tech Stack

| Layer           | Technology       | Notes                              |
|-----------------|------------------|------------------------------------|
| Language        | Ruby 4.0         |                                    |
| Framework       | Rails 8.1        |                                    |
| Background jobs | Solid Queue      | Built-in Rails 8 job backend       |
| Database        | PostgreSQL       |                                    |
| Testing         | RSpec 3          | FactoryBot (`factory_bot_rails`); factories in `spec/factories/` |

**Do not suggest or introduce** Webpack, Webpacker, Yarn, Devise,
Sidekiq, or any gems not already in the Gemfile unless explicitly asked.

---

## Essential Commands

```bash
# Development
bin/rails server                            # start dev server (Puma + Solid Queue)
bin/rails console                           # open Rails console
bin/rails runner "SomeClass.do_something"   # run arbitrary Ruby in app context

# Database
bin/rails db:create                         # create SQLite database
bin/rails db:migrate                        # run pending migrations
bin/rails db:rollback                       # roll back last migration
bin/rails db:rollback STEP=3               # roll back last 3 migrations
bin/rails db:seed                           # seed the database
bin/rails db:reset                          # drop, create, migrate, seed
bin/rails db:schema:load                    # load schema.rb (fresh installs)

# Code generation
bin/rails generate model SomeModel name:string
bin/rails generate controller SomeModels index show
bin/rails generate migration AddSomeParamToSomeModel some_param:string
bin/rails generate stimulus locale          # Stimulus controller → app/javascript/controllers/locale_controller.js
bin/rails generate mailer ContactMailer     # mailer class
bin/rails generate job SendNotificationJob      # Solid Queue job

# Testing (RSpec)
bundle exec rspec                           # run full suite
bundle exec rspec spec/models/             # model specs only
bundle exec rspec spec/models/user_spec.rb # single spec file
bundle exec rspec spec/controllers/        # controller specs only
bundle exec rspec spec/requests/           # request (integration) specs
bundle exec rspec --format documentation   # verbose output

# Assets / CSS
bin/rails tailwindcss:build                 # compile Tailwind once
bin/rails tailwindcss:watch                 # watch and recompile

# Linting
bin/rubocop                                 # lint Ruby code
bin/rubocop -a                              # auto-correct safe offenses
bin/rubocop --only Style,Layout            # lint specific cops only

# Routes
bin/rails routes                            # list all routes
bin/rails routes -g admin                   # filter routes by pattern

```

---

## Project Structure

```
app/
  controllers/
    application_controller.rb        # base — locale setup, auth helpers
    
  models/
    user.rb                          # borrower
    book.rb                          # borrow item

  presenters/                        # thin decorators

  forms/                            # encapsulate form params + validation

  services/                          # single-responsibility business logic

  mailers/
    application_mailer.rb

    jobs/                          # Solid Queue background jobs

  views/                            # not in use

  helpers/

  javascript/
    controllers/                     # Stimulus controllers
      application_js                 # registers all controllers

  assets/
    stylesheets/
      application.css                # @import "tailwindcss" + custom component classes

config/
  routes.rb
  database.yml
  importmap.rb
  environment.rb
  locales/
    en.yml                           # English strings

db/
  schema.rb                          # auto-generated — do not hand-edit
  migrate/
  seeds.rb

spec/
  models/
  controllers/
  requests/
  mailers/
  factories/                         # FactoryBot factories, one file per model
  support/
    factory_bot.rb                   # includes FactoryBot::Syntax::Methods
    rails_helper.rb
    spec_helper.rb
    shared_examples/

docs/
  architecture.md
  data_model.md
  conventions.md
```

---

## Reading Order for AI

When starting a new task, read in order:

1. `CLAUDE.md` ← you are here
2. `docs/data_model.md` — understand the schema before touching models or migrations
3. `docs/architecture.md` — understand routes and request flow before touching controllers
4. `docs/conventions.md` — read before writing any Ruby, ERB, or CSS
5. Relevant source file(s) — read the actual file before editing it

---

## Hard Rules

- **Never edit `db/schema.rb`** — auto-generated by migrations.
- **Always write a migration** for schema changes; never alter the database directly.
- **Never store secrets in code.** Use `bin/rails credentials:edit` only.
- **All admin controllers** must inherit from `Admin::BaseController` which enforces auth.
- **No public registration** — users are created directly in the database only.
- **No raw SQL** unless ActiveRecord cannot express the query.
- **RSpec Testing Standards**
Every new or modified component must include comprehensive RSpec test coverage:
1. Models: Test all validations, associations, scopes, and custom methods across valid and invalid contexts.
2. Controllers: Test all actions, covering success/failure paths, authorization, and varying parameter scenarios.
3. Service & Form Objects: Test all business logic paths, edge cases, and every permutation of incoming parameters.
4. Contexts: Ensure tests run in diverse contexts (e.g., guest vs. authenticated, valid vs. invalid payloads, existing, not existing and extra/not related records).
- **Lean controllers and lean models** — business logic lives in services, form objects, concerns, and presenters.
- **Follow RESTful conventions** — discuss non-RESTful actions before implementing.

---

## Credentials Structure

Edit with `EDITOR=vim bin/rails credentials:edit --environment <development|staging|production>`.
This app uses **per-environment** credentials (`config/credentials/<env>.yml.enc`), which take
precedence over the base `config/credentials.yml.enc`. 

---
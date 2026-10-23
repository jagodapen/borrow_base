# Conventions

Rules for writing code in this project. AI must follow these in every output.
When a rule here conflicts with a generic best-practice article, **this file wins**.

---

## Ruby Style

- Use 2-space indentation. No tabs.
- Maximum line length: 120 characters.
- Use `frozen_string_literal: true` at the top of every `.rb` file.
- Prefer `do...end` for multi-line blocks, `{ }` for single-line blocks.
- Use keyword arguments for any method with more than two parameters.
- Avoid `unless` with `else`; rewrite as `if/else`.
- Prefer `&.` (safe navigation) over explicit nil checks.
- No trailing whitespace.
- Always use `raise` instead of `fail`.
- Prefer `Integer(str)` over `str.to_i` when the input must be a valid integer.

```ruby
# Good
# frozen_string_literal: true

def update_project(project:, attrs:)
  project.update!(attrs)
end

# Bad — no frozen string literal, positional args
def update_project(project, attrs)
  project.update!(attrs)
end
```

---

## Rails Conventions

### Models

Order of declarations:

1. `serialize` calls
2. Associations (`belongs_to` before `has_many`)
3. Validations
4. Callbacks
5. Scopes
6. Public methods
7. `private` — private methods

Keep callbacks minimal. Anything longer than 3 lines belongs in a private method or service.
Never put business logic in callbacks — use service objects.

```ruby
# frozen_string_literal: true

class Person < ApplicationRecord
  # Serialize
  serialize :role, coder: JSON

  # Associations
  has_one_attached :photo

  # Validations
  validates :first_name, presence: true
  validates :last_name,  presence: true

  # Scopes
  scope :ordered, -> { order(:position) }
  scope :board,   -> { select { |p| p.role["board_position"].present? } }

  # Public methods
  def full_name = "#{first_name} #{last_name}"
  def board_member? = role["board_position"].present?

  private

  # (private helpers)
end
```

### Controllers

- Keep controllers thin — find/build the resource, delegate to services, then render or redirect.
- Use `before_action` for shared setup; always add `only:` or `except:`.
- Permit parameters in a private `_params` method (e.g. `project_params`).
- Use `params.expect(...)` (Rails 8+ strong parameters API).
- Rescue `ActiveRecord::RecordNotFound` in `ApplicationController` → render 404.
- Use `flash[:notice]` for success, `flash[:alert]` for errors.
- Instantiate presenters in the controller, not the view.

```ruby
# frozen_string_literal: true

class Admin::ProjectsController < Admin::BaseController
  before_action :set_project, only: [:show, :edit, :update, :destroy]

  def show
    @project = ProjectPresenter.new(@project)
  end

  def create
    @project = Project.new(project_params)
    if @project.save
      redirect_to admin_projects_path, notice: t("admin.projects.created")
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def set_project
    @project = Project.find(params[:id])
  end

  def project_params
    params.expect(project: [:name, :budget, :institution, :description,
                             :founded_on, :country, :city, :active])
  end
end
```

> **Rails 8.1 note:** Use `params.expect(...)` instead of `params.require(...).permit(...)`.

### Presenters

Presenters are plain Ruby objects that wrap a model for display.
They are the only layer allowed to call view helpers or format data for HTML.

```ruby
# frozen_string_literal: true

class ProjectPresenter
  def initialize(project)
    @project = project
  end

  def budget_formatted
    ActionController::Base.helpers.number_to_currency(@project.budget, unit: "€")
  end

  def founded_year
    @project.founded_on&.year
  end

  def method_missing(method, ...)
    @project.public_send(method, ...)
  end

  def respond_to_missing?(method, include_private = false)
    @project.respond_to?(method, include_private) || super
  end
end
```

- One presenter per model.
- Use `method_missing` + `respond_to_missing?` to delegate plain attribute access to the model.
- Never call presenters from models or services.

### Form Objects

Form objects validate and represent form submissions. They do not persist to the DB directly.

```ruby
# frozen_string_literal: true

class VolunteerForm
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :first_name, :string
  attribute :last_name,  :string
  attribute :email,      :string
  attribute :motivation, :string

  validates :first_name, :last_name, :email, presence: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }

  def to_h
    { first_name:, last_name:, email:, motivation: }
  end
end
```

- Inherit from nothing — include `ActiveModel::Model` and `ActiveModel::Attributes`.
- Every public form on the site has a corresponding form object.
- Form objects are instantiated in the controller and passed to the view.

#### File uploads

Never re-implement upload handling in a form. Include `FormAttachments`
(`app/forms/form_attachments.rb`) and, when the defaults don't fit, declare the limits:

```ruby
class SomeForm
  include ActiveModel::Model
  include ActiveModel::Attributes
  include FormAttachments

  accepts_attachments max_files: 3, max_size: 1.megabyte    # defaults: 5 files, 2 MB, AttachmentPolicy::DEFAULT_TYPES

  def to_h = attributes.merge("attachment_signed_ids" => attachment_signed_ids)
end
```

It gives the form `attachments` / `attachments=`, validates count, size and content type
(sniffed from the file's own bytes, with the extension required to agree), and uploads the
files as blobs via `#attachment_signed_ids` — uploads are not serializable, so a job payload
carries signed ids and the mailer re-attaches the blobs.

- The file field's `accept:` comes from `SomeForm.attachment_policy.accept_attribute` — never
  hand-write a second list in the view.
- Add `too_many`, `too_large` and `invalid_type` under
  `activemodel.errors.models.<form>.attributes.attachments` in both `en.yml` and `nl.yml`.
- Cover it in the form's spec with `it_behaves_like "a form with attachments"`, supplying
  `let(:build_form) { ->(files) { ... } }`. Upload doubles come from `UploadHelper`.

### Service Objects

Services encapsulate a single business operation. Use a class method entry point.

```ruby
# frozen_string_literal: true

class FormMailerService
  def self.deliver(form)
    new(form).call
  end

  def initialize(form)
    @form = form
  end

  def call
    ContactMailer.submission(@form.to_h).deliver_later
  end
end
```

- One public entry point (`self.call` or `self.deliver`).
- Return a meaningful value (`true`/`false`, a result object, the created record).
- Raise exceptions for truly unexpected failures; return falsy for expected failures.

### Views & ERB

- No logic in views beyond simple conditionals and iteration.
- Extract repeated HTML into partials. Name partials with a leading underscore.
- Pass locals explicitly to partials; never read instance variables inside partials.
- All user-facing strings must use `t("key")` — no hard-coded visible text.

```erb
<%# Good — explicit locals, translated string %>
<%= render "shared/project_card", project: project %>
<h1><%= t("projects.index.heading") %></h1>

<%# Bad — reads instance variable, hard-coded English %>
<%= render "shared/project_card" %>
<h1>Our Projects</h1>
```

### Pagination

- Use Pagy (`include Pagy::Method` is in `ApplicationController`).
- Public controllers: `@pagy, @records = pagy(:offset, scope)` — 15 per page (`config/initializers/pagy.rb`).
- Admin controllers: `admin_pagy(scope)` (10 per page); for grouped tables use
  `paginate_groups(scope, by:, keys:)`, which gives each group its own `"<key>_page"` param.
- Always give the scope a deterministic order (add `id` as a tiebreaker).
- Render with `<%= render "shared/pagination", pagy: @pagy %>` (add `admin: true`, and `fragment:` for grouped tables).
  Styles live in `.pagination` / `.pagination-admin` in `application.css`; labels under `pagy:` in `en.yml`/`nl.yml`.

---

## Tailwind CSS 4.x

Tailwind 4 uses a CSS-first configuration — there is no `tailwind.config.js`.

### Configuration

```css
/* app/assets/stylesheets/application.css */
@import "tailwindcss";

@theme {
  --color-brand: #2563eb;
  --color-brand-dark: #1d4ed8;
  --font-sans: "Inter", sans-serif;
}

/* Named component classes — add here when a combination repeats */
.btn-primary {
  @apply px-4 py-2 rounded-lg bg-brand text-white font-medium
         hover:bg-brand-dark transition-colors;
}

.card {
  @apply rounded-2xl bg-white shadow-sm p-6;
}
```

### Rules

- **Minimize one-off class strings.** When the same combination of utilities appears
  more than twice, define a named class in `application.css` and use it.
- **Do not use `@apply` for one-off rules.** Only use `@apply` inside named classes in `application.css`.
- Use `grid` and `flex` for layout. Avoid `float`.
- Use Tailwind pseudo-classes for interactive states instead of JavaScript where possible:
  - `group` / `group-hover` — show/hide elements based on parent hover
  - `peer` / `peer-has-checked` — toggle visibility based on sibling state
  - `data-*` variants — react to Stimulus `data-*` attributes
- Order classes: **layout → spacing → typography → color → state variants**

```erb
<%# Good — ordered, named class for repetitive pattern %>
<article class="card flex flex-col gap-4">
  <h2 class="text-lg font-semibold text-gray-900"><%= project.name %></h2>
</article>

<%# Bad — repetitive inline utilities, wrong order %>
<article class="bg-white text-sm p-6 hover:shadow-md text-gray-700 flex rounded-2xl gap-4 flex-col shadow-sm">
```

- Use `sm:`, `md:`, `lg:` breakpoints for responsive design.
- Theme tokens go in `@theme {}` in `application.css` — never hardcode hex colors inline.

---

## Stimulus

- One Stimulus controller per distinct interactive behavior.
- Controller file name mirrors its `data-controller` value: `locale_controller.js` → `data-controller="locale"`.
- Keep controllers focused — if a controller does more than one thing, split it.
- Use `data-action` attributes in HTML, not `addEventListener` in JS.
- Use `data-*-target` attributes for DOM references, not `querySelector`.

```javascript
// app/javascript/controllers/locale_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["select"]

  change() {
    this.element.requestSubmit()
  }
}
```

---

## I18n

- Every user-visible string is in `config/locales/en.yml` and `config/locales/nl.yml`.
- Use nested keys that mirror the view hierarchy: `pages.about.heading`.
- Flash messages use `flash.notice.*` and `flash.alert.*` namespaces.
- Mailer subjects and bodies are in `config/locales/*.yml` under `mailer.*`.
- Never call `I18n.t` directly in models or services — only in views, helpers, and mailers.

---

## Migrations

- Add a comment explaining the purpose only when the file name is not self-explanatory.
- Add indexes for all foreign keys and columns used in `where` clauses.
- Use `null: false` and `default:` on every column unless null is intentional and documented.
- Never change an existing migration — always create a new one.
- Use `decimal` with `precision:` and `scale:` for monetary columns, never `float`.

```ruby
class AddBudgetToProjects < ActiveRecord::Migration[8.1]
  def change
    add_column :projects, :budget, :decimal, precision: 12, scale: 2,
                                              null: false, default: 0
    add_index  :projects, :active
  end
end
```

---

## Testing (RSpec)

- One spec file per model, one per controller (or one per request spec for integration).
- Use `let` and `let!` for test data; build records with FactoryBot (`create`, `build`) from `spec/factories/`; avoid fixtures.
- Factories set only the attributes required to save (validations and `null: false` columns without defaults).
  Pass other attributes explicitly only when the spec asserts on them or the code under test depends on them.
- Describe behaviour in `it` blocks: `it "does not save without a name"`.
- Every model validation must have a corresponding spec.
- Every controller/request action must have at least one happy-path and one sad-path spec.
- Do not test private methods directly; test them through public interfaces.
- Use `subject` for the object under test in model specs.

```ruby
# frozen_string_literal: true

require "rails_helper"

RSpec.describe Project, type: :model do
  subject(:project) { build(:project) }

  describe "validations" do
    it "requires a name" do
      project.name = ""
      expect(project).not_to be_valid
    end

    it "auto-generates slug from name on create" do
      project = create(:project, name: "Clean Water Initiative")
      expect(project.slug).to eq("clean-water-initiative")
    end
  end
end
```

> **Note:** This project uses RSpec, not Minitest. Do not generate `test/` files.
> All specs live in `spec/`.

---

## Git & Commits

- One logical change per commit.
- Commit message format: `type: short description` (max 72 chars).
- Types: `feat`, `fix`, `refactor`, `test`, `docs`, `chore`.
- Examples:
  - `feat: add Mollie payment integration for donor form`
  - `fix: use correct locale column in page presenter`
  - `chore: add nl.yml translations for project pages`

---

## How to Update This File

- Add a rule when a new convention is agreed.
- Add a Rails version note when upgrading Rails changes an API.
- Do not remove rules without discussion — comment them out with a date note instead.

## Semantic HTML (SEO + accessibility)

- **Exactly one `<h1>` per page** — the page's main topic. The shared footer
  and every other section use `<h2>`/`<h3>`… To keep a lower-level heading
  looking like an h1/h2, add `.heading-xl` (h1 size) or `.heading-lg`
  (h2 size) from `app/assets/tailwind/application.css` instead of picking the
  tag for its looks. `spec/requests/semantic_html_spec.rb` checks every public page.
- **Every `<img>` has `alt`.** Content images describe what they show: the
  project/article/document title for record images, a `t("shared.image_alt.*")`
  translation for stock photos (never a hard-coded English string). Icons and
  background photos next to their own text get `alt: ""`. Brand names and
  logos ("Wings of Support", "ANBI logo") stay as they are.

## Images and performance

- `image_tag` lazy-loads by default (`config.action_view.image_loading = "lazy"`).
  The page's main above-the-fold image (hero, project photo, article cover)
  passes `loading: "eager", fetchpriority: "high"` — one per page.
- Never render an uploaded original. Declare a named WebP variant on the
  model's attachment (`attachable.variant :card, resize_to_limit: [...], format: :webp`,
  about 2x the display size) and render it with
  `image_variant(record.attachment, :name)` (`ApplicationHelper`), which also
  handles unattached and non-resizable files. Existing names: Project photo
  `:card`/`:large`, Project images `:gallery`, Article cover `:card`/`:large`,
  Page cover `:hero`, Person photo `:portrait`, Sponsor logo `:logo`,
  Magazine cover `:card`/`:icon`, Document page_images `:page`,
  InstagramPost image `:thumbnail`. Social sharing (og:image) stays JPEG.
- Static photos go in as AVIF (`app/assets/images/*.avif`).
- Rich text with raw `<img>` (imported articles) goes through `lazy_load_images`.
- Google Fonts are loaded with a single `css2?family=...&family=...` request.


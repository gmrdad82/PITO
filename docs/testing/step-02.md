# Testing — Step 2: Craigslist-Style Layout + Top Nav + Sidekiq Web

## Automated

```bash
bundle exec rspec
# Expected: 16 examples, 0 failures
```

## Manual Verification

### 1. Start the app

```bash
bin/dev
```

### 2. Browser checks

- **http://localhost:3000** — Dashboard page with top nav bar
  - Nav should be plain text links separated by middots: `pito · Dashboard · Channels · Compare · Production · Notes · Settings · Sidekiq`
  - Current page should be bold, not a link
  - White background, black text, blue underlined links
  - No big buttons, no shadows, no rounded corners — Craigslist style

- **Click each nav link** — all should load with placeholder text

- **http://localhost:3000/sidekiq** — should prompt for HTTP basic auth
  - Credentials come from `rails credentials:edit` under `sidekiq.username` and `sidekiq.password`
  - If no credentials set yet, any user/pass will be rejected (empty string comparison)

### 3. Set up Sidekiq credentials

```bash
EDITOR=vim rails credentials:edit
```

Add under existing content:

```yaml
sidekiq:
  username: admin
  password: your-password-here
```

Then visit http://localhost:3000/sidekiq and enter those credentials.

### 4. Verify pry in console

```bash
bundle exec rails console
# Should show pry prompt, not irb
```

### 5. Rails credentials template

Your `rails credentials:edit` should look like this (add what's missing):

```yaml
secret_key_base: (already there)

mysql:
  development:
    database: your_db_name
    username: your_db_user
    password: your_db_password
  test:
    database: your_test_db_name
    username: your_test_db_user
    password: your_test_db_password

sidekiq:
  username: admin
  password: your-sidekiq-password
```

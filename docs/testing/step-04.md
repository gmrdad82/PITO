# Step 4: Settings Page — Testing

## Automated Tests

```bash
bundle exec rspec spec/requests/settings_spec.rb
# 7 examples, 0 failures
```

## Manual Verification

### 1. Browser (http://localhost:3000/settings)

- Form shows three fields: Client ID, Client Secret, Redirect URI
- Fill in values and click Save
- Flash message "Settings saved." appears
- Values persist after page reload
- Client Secret field is masked (password type)
- Leaving a field empty does not blank out a previously saved value

### 2. Console

```ruby
# Verify values are encrypted in the database
AppSetting.get("youtube_client_id")  # returns what you entered
```

# WCAG 2.x contrast audit for all pito themes.
def srgb_to_lin(c)
  c /= 255.0
  c <= 0.03928 ? c / 12.92 : ((c + 0.055) / 1.055)**2.4
end

def luminance(hex)
  h = hex.delete("#")
  r, g, b = [ h[0, 2], h[2, 2], h[4, 2] ].map { |x| x.to_i(16) }
  0.2126 * srgb_to_lin(r) + 0.7152 * srgb_to_lin(g) + 0.0722 * srgb_to_lin(b)
end

def ratio(fg, bg)
  l1 = luminance(fg); l2 = luminance(bg)
  hi, lo = [ l1, l2 ].max, [ l1, l2 ].min
  (hi + 0.05) / (lo + 0.05)
end

TEXT_TOKENS = %i[fg_default fg_dim fg_faded
                 accent_purple accent_blue accent_cyan accent_green
                 accent_yellow accent_orange accent_red brand_pito]
BG_TOKENS = { page: :bg_root, surface: :bg_surface, elevated: :bg_elevated }

AA = 4.5      # WCAG AA normal text
AA_LARGE = 3.0 # WCAG AA large/UI text

def flag(r)
  return "FAIL"  if r < AA_LARGE
  return "warn"  if r < AA
  "ok"
end

defs = Pito::Themes::Registry.all.sort_by { |d| [ d.mode == :light ? 0 : 1, d.slug ] }

failures = []   # [theme, mode, text, bg_name, ratio]
defs.each do |d|
  t = d.tokens
  TEXT_TOKENS.each do |txt|
    next unless t[txt]
    BG_TOKENS.each do |bg_name, bg_key|
      next unless t[bg_key]
      r = ratio(t[txt].to_s, t[bg_key].to_s)
      st = flag(r)
      failures << [ d.slug, d.mode, txt, bg_name, r, st, t[txt], t[bg_key] ] if st != "ok"
    end
  end
end

# Exclude the intentionally-dim placeholder token from the "real text" headline,
# but still report it separately.
real = failures.reject { |f| f[2] == :fg_faded }

puts "# Theme contrast audit (WCAG 2.x)\n\n"
puts "Thresholds: **FAIL** < #{AA_LARGE}:1 (fails even large/UI text) · **warn** < #{AA}:1 (fails AA normal text) · ok ≥ #{AA}:1.\n\n"
puts "Text tokens audited: #{TEXT_TOKENS.join(', ')} against page(bg_root)/surface/elevated.\n\n"

light = defs.select { |d| d.mode == :light }.map(&:slug)
puts "## Headline — real-text failures (excluding the intentionally-faded `fg_faded` placeholder)\n\n"
puts "| theme | mode | text token | on | ratio | status |"
puts "|---|---|---|---|---:|---|"
real.sort_by { |f| [ f[1]==:light ?0:1, f[0], f[4] ] }.each do |slug, mode, txt, bg, r, st, fhex, bhex|
  puts "| #{slug} | #{mode} | `#{txt}` (#{fhex}) | #{bg} (#{bhex}) | #{format('%.2f', r)} | #{st=='FAIL' ? '**FAIL**' : st} |"
end

puts "\n## fg_faded (placeholder/disabled — low contrast partly by design)\n\n"
puts "| theme | mode | on | ratio | status |"
puts "|---|---|---|---:|---|"
failures.select { |f| f[2]==:fg_faded }.sort_by { |f| [ f[1]==:light ?0:1, f[0], f[4] ] }.each do |slug, mode, txt, bg, r, st, *|
  puts "| #{slug} | #{mode} | #{bg} | #{format('%.2f', r)} | #{st} |"
end

# Per-light-theme full matrix
puts "\n## Full matrix — light themes (the ones you flagged)\n"
defs.select { |d| d.mode == :light }.each do |d|
  t = d.tokens
  puts "\n### #{d.slug}  (page #{t[:bg_root]}, surface #{t[:bg_surface]}, elevated #{t[:bg_elevated]})\n"
  puts "| text token | page | surface | elevated |"
  puts "|---|---:|---:|---:|"
  TEXT_TOKENS.each do |txt|
    next unless t[txt]
    cells = BG_TOKENS.map do |bg_name, bg_key|
      r = ratio(t[txt].to_s, t[bg_key].to_s)
      mark = r < AA_LARGE ? "❌" : (r < AA ? "⚠️" : "✅")
      "#{format('%.2f', r)} #{mark}"
    end
    puts "| `#{txt}` #{t[txt]} | #{cells[0]} | #{cells[1]} | #{cells[2]} |"
  end
end

puts "\n## Summary counts\n"
puts "- Themes: #{defs.size} (#{defs.count { |d|d.mode==:light }} light, #{defs.count { |d|d.mode==:dark }} dark)"
puts "- Real-text FAILs (<3.0): #{real.count { |f|f[5]=='FAIL' }}"
puts "- Real-text warns (3.0–4.5): #{real.count { |f|f[5]=='warn' }}"
puts "- Of those, on light themes: FAIL #{real.count { |f|f[1]==:light && f[5]=='FAIL' }}, warn #{real.count { |f|f[1]==:light && f[5]=='warn' }}"

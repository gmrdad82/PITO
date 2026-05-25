# Deprecated: use Pito::ScoreBarComponent.
# Kept as a thin alias for one sweep so existing call sites keep working.
# Drop this file (and its template) once all call sites are migrated.
class Game::RatingHeatBarComponent < Pito::ScoreBarComponent
end

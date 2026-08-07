json.id pipeline.id
json.name pipeline.name
json.is_default pipeline.is_default
json.visibility pipeline.visibility
json.lost_reasons pipeline.lost_reasons || []
json.allowed_team_ids pipeline.allowed_team_ids || []
json.created_at pipeline.created_at
json.updated_at pipeline.updated_at

# `deal_counts` vem de uma unica query agregada no controller. Antes cada etapa
# disparava o seu proprio COUNT, e o menu lateral chama este endpoint em toda
# navegacao.
deal_counts = defined?(@deal_counts) ? (@deal_counts || {}) : {}

json.total_deals_count pipeline.stages.sum { |stage| deal_counts[stage.id] || 0 }

json.stages pipeline.stages do |stage|
  json.id stage.id
  json.name stage.name
  json.position stage.position
  json.win_probability stage.win_probability
  json.rotting_days stage.rotting_days
  json.deals_count deal_counts[stage.id] || 0
  json.color stage.color
  json.stage_type stage.stage_type
end

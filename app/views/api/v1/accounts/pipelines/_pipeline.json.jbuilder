json.id pipeline.id
json.name pipeline.name
json.is_default pipeline.is_default
json.visibility pipeline.visibility
json.lost_reasons pipeline.lost_reasons || []
json.allowed_team_ids pipeline.allowed_team_ids || []
json.total_value pipeline.total_value
json.total_deals_count pipeline.total_deals_count
json.created_at pipeline.created_at
json.updated_at pipeline.updated_at

json.stages pipeline.stages do |stage|
  json.id stage.id
  json.name stage.name
  json.position stage.position
  json.win_probability stage.win_probability
  json.rotting_days stage.rotting_days
  json.deals_count stage.deals_count
  json.total_value stage.total_value
  json.color stage.color
  json.stage_type stage.stage_type
end

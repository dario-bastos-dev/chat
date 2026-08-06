json.pipeline do
  json.id @pipeline.id
  json.name @pipeline.name
end

json.stages @stages do |stage|
  json.id stage.id
  json.name stage.name
  json.position stage.position
  json.win_probability stage.win_probability
  json.rotting_days stage.rotting_days
  json.color stage.color
  json.stage_type stage.stage_type

  # Total real da coluna no banco, independente de quantos vieram nesta pagina.
  json.total_count @total_counts[stage.id] || 0

  json.deals @deals_by_stage[stage] do |deal|
    json.partial! 'api/v1/accounts/deals/deal', deal: deal
  end
end

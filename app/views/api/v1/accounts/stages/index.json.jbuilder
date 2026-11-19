json.array! @stages do |stage|
  json.partial! 'api/v1/accounts/stages/stage', stage: stage
end

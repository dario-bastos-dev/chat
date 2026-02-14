json.data do
  json.array! @deals do |deal|
    json.partial! 'api/v1/accounts/deals/deal', deal: deal
  end
end

json.meta do
  json.current_page @deals.current_page
  json.total_pages @deals.total_pages
  json.total_count @deals.total_count
end

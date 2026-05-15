blob = ActiveStorage::Blob.last
puts "Blob ID: #{blob.id}"
puts "Blob Key: #{blob.key}"
puts "Blob URL: #{blob.url}"
begin
  blob.download
  puts "Download successful!"
rescue => e
  puts "Error: #{e.class} - #{e.message}"
end

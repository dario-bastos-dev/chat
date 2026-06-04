require 'json'

unmerged = `git diff --name-only --diff-filter=U`.split("\n")
json_files = unmerged.select { |f| f.end_with?('.json') }

deep_merge = ->(target, source) do
  target.merge!(source) do |key, target_val, source_val|
    if target_val.is_a?(Hash) && source_val.is_a?(Hash)
      deep_merge.call(target_val, source_val)
    else
      source_val
    end
  end
end

json_files.each do |file|
  ours_content = `git show :2:"#{file}"`
  theirs_content = `git show :3:"#{file}"`
  
  begin
    ours_json = JSON.parse(ours_content)
    theirs_json = JSON.parse(theirs_content)
    
    merged_json = deep_merge.call(theirs_json.dup, ours_json)
    File.write(file, JSON.pretty_generate(merged_json) + "\n")
    `git add "#{file}"`
    puts "Merged JSON: #{file}"
  rescue => e
    puts "Failed to merge JSON #{file}: #{e.message}"
  end
end

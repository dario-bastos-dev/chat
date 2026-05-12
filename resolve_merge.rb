files = `git diff --name-only --diff-filter=U`.split("\n")
files.each do |file|
  content = File.read(file)
  if content.include?("<<<<<<< HEAD")
    # We will keep HEAD, but if we see dashboard_controller, we manually merge
    if file == "app/controllers/dashboard_controller.rb"
      content = content.gsub(/<<<<<<< HEAD\n(.*?)\n=======\n(.*?)\n>>>>>>> default\/develop/m, "\\1,\n\\2")
      File.write(file, content)
    elsif file == "app/controllers/api/v1/accounts/inboxes_controller.rb"
      # Merge both blocks
      content = content.gsub(/<<<<<<< HEAD\n(.*?)\n=======\n(.*?)\n>>>>>>> default\/develop/m, "\\1\n\\2")
      File.write(file, content)
    elsif file == "app/services/whatsapp/oneoff_campaign_service.rb"
      # We just manually fixed this in our previous thought, wait we didn't, the multi replace failed.
      # Let's keep HEAD for now, and I will replace it manually right after.
      system("git checkout --ours '#{file}'")
    else
      # For all others, we keep our changes (HEAD) because they contain the custom Evolution/Kanban features
      system("git checkout --ours '#{file}'")
    end
    system("git add '#{file}'")
  end
end

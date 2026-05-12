import os
import subprocess

files = subprocess.check_output(['git', 'diff', '--name-only', '--diff-filter=U']).decode('utf-8').split('\n')
for file in files:
    if not file:
        continue
    with open(file, 'r') as f:
        content = f.read()
    
    if "<<<<<<< HEAD" in content:
        if file == "app/controllers/dashboard_controller.rb":
            import re
            content = re.sub(r'<<<<<<< HEAD\n(.*?)\n=======\n(.*?)\n>>>>>>> default/develop', r'\1,\n\2', content, flags=re.DOTALL)
            with open(file, 'w') as f:
                f.write(content)
            subprocess.run(['git', 'add', file])
        elif file == "app/controllers/api/v1/accounts/inboxes_controller.rb":
            import re
            content = re.sub(r'<<<<<<< HEAD\n(.*?)\n=======\n(.*?)\n>>>>>>> default/develop', r'\1\n\2', content, flags=re.DOTALL)
            with open(file, 'w') as f:
                f.write(content)
            subprocess.run(['git', 'add', file])
        else:
            subprocess.run(['git', 'checkout', '--ours', file])
            subprocess.run(['git', 'add', file])

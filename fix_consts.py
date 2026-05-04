import os
import re

directories = ['lib/vista', 'lib/widget']

for d in directories:
    for root, _, files in os.walk(d):
        for file in files:
            if file.endswith('.dart'):
                filepath = os.path.join(root, file)
                try:
                    with open(filepath, 'r', encoding='utf-8') as f:
                        content = f.read()

                    new_content = content
                    new_content = re.sub(r'const\s+Icon\s*\([\s\S]*?Theme\.of[\s\S]*?\)', lambda m: m.group(0).replace('const ', ''), new_content)
                    new_content = re.sub(r'const\s+TextStyle\s*\([\s\S]*?Theme\.of[\s\S]*?\)', lambda m: m.group(0).replace('const ', ''), new_content)
                    new_content = new_content.replace('Theme.of(context).cardColor70', 'Theme.of(context).cardColor.withOpacity(0.7)')
                    
                    if new_content != content:
                        with open(filepath, 'w', encoding='utf-8') as f:
                            f.write(new_content)
                        print('Fixed ' + filepath)
                except Exception as e:
                    print('Error in ' + filepath + ': ' + str(e))

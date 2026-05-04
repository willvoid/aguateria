import os
import re

directories = ['lib/vista', 'lib/widget']

replacements = [
    (r'(?<!TextStyle\()color:\s*Colors\.white', r'color: Theme.of(context).cardColor'),
    (r'fillColor:\s*Colors\.white', r'fillColor: Theme.of(context).cardColor'),
    (r'backgroundColor:\s*Colors\.white', r'backgroundColor: Theme.of(context).cardColor'),
    (r'backgroundColor:\s*const\s*Color\(0xFF0085FF\)', r'backgroundColor: Theme.of(context).primaryColor'),
    (r'color:\s*const\s*Color\(0xFF0085FF\)', r'color: Theme.of(context).primaryColor'),
    (r'WidgetStateProperty\.all\(\s*const\s*Color\(0xFFF9FAFB\)\s*\)', r'WidgetStateProperty.all(Theme.of(context).colorScheme.surfaceContainerHighest)'),
    (r'color:\s*Colors\.grey\.shade300', r'color: Theme.of(context).dividerColor'),
    (r'BorderSide\(\s*color:\s*Colors\.grey\.shade300\s*\)', r'BorderSide(color: Theme.of(context).dividerColor)'),
    (r'color:\s*const\s*Color\(0xFFF9FAFB\)', r'color: Theme.of(context).colorScheme.surfaceContainerHighest'),
]

for d in directories:
    for root, _, files in os.walk(d):
        for file in files:
            if file.endswith('.dart'):
                filepath = os.path.join(root, file)
                try:
                    with open(filepath, 'r', encoding='utf-8') as f:
                        content = f.read()

                    new_content = content
                    for old, new in replacements:
                        new_content = re.sub(old, new, new_content)

                    if new_content != content:
                        new_content = re.sub(r'const\s+BoxDecoration\s*\(', r'BoxDecoration(', new_content)
                        new_content = re.sub(r'const\s+InputDecoration\s*\(', r'InputDecoration(', new_content)
                        new_content = re.sub(r'const\s+BorderSide\s*\(', r'BorderSide(', new_content)
                        with open(filepath, 'w', encoding='utf-8') as f:
                            f.write(new_content)
                        print('Updated ' + filepath)
                except Exception as e:
                    print('Error in ' + filepath + ': ' + str(e))

import os

directories = ['lib/vista', 'lib/widget']

for d in directories:
    for root, _, files in os.walk(d):
        for file in files:
            if file.endswith('.dart'):
                filepath = os.path.join(root, file)
                try:
                    with open(filepath, 'r', encoding='utf-8') as f:
                        lines = f.readlines()

                    changed = False
                    for i in range(len(lines)):
                        if 'Theme.of' in lines[i] and 'const ' in lines[i]:
                            lines[i] = lines[i].replace('const ', '')
                            changed = True

                    if changed:
                        with open(filepath, 'w', encoding='utf-8') as f:
                            f.writelines(lines)
                        print('Removed const in ' + filepath)
                except Exception as e:
                    print('Error in ' + filepath + ': ' + str(e))

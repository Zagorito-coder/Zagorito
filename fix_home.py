import re

with open('lib/pages/home_page.dart', 'r', encoding='utf-8') as f:
    content = f.read()

print(f"File size: {len(content)} chars")
lines = content.split('\n')
print(f"Total lines: {len(lines)}")

# Find all body: occurrences
for i, line in enumerate(lines):
    if 'body:' in line:
        print(f"body: at line {i+1}: {repr(line)}")

# Find _buildHomeBody references
for i, line in enumerate(lines):
    if '_buildHomeBody' in line:
        print(f"_buildHomeBody at line {i+1}: {repr(line)}")

# Find the duplicated block that starts with body: RefreshIndicator and ends before DRAWER
# First, let's find what happens around line 200
if len(lines) > 200:
    print(f"Line 200: {repr(lines[199])}")
if len(lines) > 201:
    print(f"Line 201: {repr(lines[200])}")
if len(lines) > 202:
    print(f"Line 202: {repr(lines[201])}")

# Check if there's a line with just 'body: RefreshIndicator('
# It might have different whitespace
dup_start = None
for i, line in enumerate(lines):
    stripped = line.strip()
    if stripped.startswith('body: RefreshIndicator('):
        dup_start = i
        print(f"Dup start at line {i+1}")
        break

if dup_start:
    # Find DRAWER after dup_start
    dup_end = None
    for i in range(dup_start, len(lines)):
        if '//  DRAWER' in lines[i] or 'DRAWER' in lines[i]:
            dup_end = i
            print(f"Dup end at line {i+1}")
            break
    
    if dup_end:
        print(f"Removing lines {dup_start+1} to {dup_end}")
        lines = lines[:dup_start] + lines[dup_end:]
        
        # Now add body: _buildHomeBody to the Scaffold
        for i, line in enumerate(lines):
            if 'drawer: _buildDrawer(context, tc),' in line:
                indent = line[:line.index('drawer')]
                lines.insert(i + 1, indent + 'body: _buildHomeBody(context, tc),')
                print(f"Added body: at line {i+2}")
                break
        
        content = '\n'.join(lines)
        with open('lib/pages/home_page.dart', 'w', encoding='utf-8') as f:
            f.write(content)
        print("File written successfully")
    else:
        print("ERROR: Could not find DRAWER")
else:
    print("ERROR: Could not find duplicated body: RefreshIndicator")

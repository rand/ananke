#!/bin/bash

echo "Validating documentation links in README.md..."
echo ""

# Extract all markdown links (macOS compatible)
grep -E '\[.*\]\(.*\)' README.md | sed 's/.*\[\(.*\)\](\(.*\)).*/\2/' | grep -v "^http" | grep -v "^#" > /tmp/links.txt

broken_links=0
valid_links=0

echo "Checking documentation file links:"
echo ""

while read link; do
  # Skip empty lines
  [ -z "$link" ] && continue
  
  # Remove anchors for file checking
  file_path=${link%#*}
  
  # Check if file exists
  if [ -f "$file_path" ]; then
    echo "✓ $link"
    ((valid_links++))
  else
    echo "✗ BROKEN: $link (file not found: $file_path)"
    ((broken_links++))
  fi
done < /tmp/links.txt

echo ""
echo "Summary: $valid_links valid links, $broken_links broken links"

if [ $broken_links -gt 0 ]; then
  echo ""
  echo "Broken links found:"
fi

rm -f /tmp/links.txt

exit $broken_links

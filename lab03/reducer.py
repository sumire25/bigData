#!/usr/bin/env python3
import sys

current_word = None
current_files = set()

for line in sys.stdin:
    line = line.strip()
    
    try:
        word, filename = line.split('\t', 1)
    except ValueError:
        continue

    # If the word matches the current tracking word, add the filename to the set
    if current_word == word:
        current_files.add(filename)
    else:
        # Output the previous word and its comma-separated list of files
        if current_word:
            files_list = ','.join(sorted(list(current_files)))
            print(f'{current_word}\t{files_list}')
        
        # Reset for the new word
        current_word = word
        current_files = {filename}

# Ensure the last word in the stream is output
if current_word == word:
    files_list = ','.join(sorted(list(current_files)))
    print(f'{current_word}\t{files_list}')
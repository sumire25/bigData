#!/usr/bin/env python3
import sys
import os
import re

# Retrieve the full S3/HDFS path of the current chunk being processed
filepath = os.environ.get('mapreduce_map_input_file', 'unknown_file')
# Extract just the filename (e.g., 'chunk_00')
filename = os.path.basename(filepath)

for line in sys.stdin:
    line = line.strip()
    
    # Tokenize: extract alphanumeric strings and convert to lowercase
    words = re.findall(r'[a-zA-Z0-9]+', line.lower())
    
    for word in words:
        # Emit the word and the chunk it was found in
        print(f'{word}\t{filename}')
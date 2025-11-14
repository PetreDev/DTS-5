#!/usr/bin/env python
"""
Mapper script for Hadoop Streaming.
Filters completed tasks with urgent/high priority and emits user_id,1 pairs.
"""

import csv
import sys

# Skip header line
header_skipped = False

for line in sys.stdin:
    line = line.strip()

    if not header_skipped:
        header_skipped = True
        continue

    if not line:
        continue

    try:
        # Parse CSV line
        reader = csv.reader([line])
        row = next(reader)

        if len(row) < 8:  # Ensure we have all columns
            continue

        # Extract relevant fields
        task_id, title, description, completed, priority, created_at, updated_at, user_id = row[:8]

        # Filter: completed tasks with urgent or high priority
        if completed.lower() == 'true' and priority.lower() in ['urgent', 'high']:
            # Emit user_id as key, count 1 as value
            print('%s\t%d' % (user_id, 1))

    except Exception as e:
        # Skip malformed lines
        continue

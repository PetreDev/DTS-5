#!/usr/bin/env python
"""
Reducer script for Hadoop Streaming.
Aggregates counts by user_id.
"""

import sys

current_user = None
current_count = 0

for line in sys.stdin:
    line = line.strip()

    if not line:
        continue

    try:
        # Parse key-value pair
        user_id, count = line.split('\t', 1)
        count = int(count)

        if current_user == user_id:
            current_count += count
        else:
            if current_user is not None:
                print('%s\t%d' % (current_user, current_count))
            current_user = user_id
            current_count = count

    except ValueError:
        # Skip malformed lines
        continue

# Don't forget the last user
if current_user is not None:
    print('%s\t%d' % (current_user, current_count))

#!/usr/bin/env python3
"""Stream the required allTPreview columns for a supplied hotel-ID list.

The output is CSV on stdout so the R builder never materializes the 12 GB raw
file in memory or writes a research intermediate to the project workspace.
"""
import csv
import sys

source_path, ids_path = sys.argv[1:3]
columns = [
    "location_id", "review_id", "review_published_date", "review_rating",
    "review_text", "review_response_id", "review_response_date",
    "review_response_text", "review_response_author",
]
csv.field_size_limit(sys.maxsize)

with open(ids_path, encoding="utf-8", newline="") as f:
    hotel_ids = {line.strip() for line in f if line.strip()}

writer = csv.writer(sys.stdout, lineterminator="\n")
writer.writerow(columns)
with open(source_path, encoding="utf-8", errors="replace", newline="") as f:
    reader = csv.DictReader(f)
    for row in reader:
        if row.get("location_id") in hotel_ids:
            writer.writerow([row.get(column, "") for column in columns])

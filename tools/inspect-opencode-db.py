import sqlite3


DB = r"C:\Users\salai\.local\share\opencode\opencode.db"
SESSION_ID = "ses_006551586ffes7FQ3v7VnrYv7I"


connection = sqlite3.connect(f"file:{DB.replace(chr(92), '/')}?mode=ro", uri=True)
cursor = connection.cursor()

print("quick_check=", cursor.execute("PRAGMA quick_check(1)").fetchone()[0], flush=True)
print(
    "tables=",
    ",".join(
        row[0]
        for row in cursor.execute(
            "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name"
        )
    ),
)

for table in ("event", "event_sequence", "session"):
    row = cursor.execute(
        "SELECT sql FROM sqlite_master WHERE type='table' AND name=?", (table,)
    ).fetchone()
    print(f"{table}_schema=", row[0] if row else "MISSING")

event_columns = [row[1] for row in cursor.execute("PRAGMA table_info(event)")]
session_columns = [row[1] for row in cursor.execute("PRAGMA table_info(session)")]
sequence_columns = [row[1] for row in cursor.execute("PRAGMA table_info(event_sequence)")]
print("event_columns=", event_columns)
print("sequence_columns=", sequence_columns)
print("session_columns=", session_columns)

print(
    "event_count=",
    cursor.execute(
        "SELECT count(*) FROM event WHERE aggregate_id=?", (SESSION_ID,)
    ).fetchone()[0],
)
print(
    "seq_range=",
    cursor.execute(
        "SELECT min(seq), max(seq) FROM event WHERE aggregate_id=?", (SESSION_ID,)
    ).fetchone(),
)
print(
    "event_sequence=",
    cursor.execute(
        "SELECT * FROM event_sequence WHERE aggregate_id=?", (SESSION_ID,)
    ).fetchall(),
)

if "next_seq" in sequence_columns:
    print(
        "mismatched_sequence_count=",
        cursor.execute(
            """
            SELECT count(*)
            FROM event_sequence s
            LEFT JOIN (
                SELECT aggregate_id, coalesce(max(seq), -1) + 1 AS expected_next_seq
                FROM event GROUP BY aggregate_id
            ) e ON e.aggregate_id = s.aggregate_id
            WHERE s.next_seq != coalesce(e.expected_next_seq, 0)
            """
        ).fetchone()[0],
    )

safe_event_columns = [
    name for name in ("id", "aggregate_id", "seq", "type", "time_created")
    if name in event_columns
]
if safe_event_columns:
    query = (
        f"SELECT {', '.join(safe_event_columns)} FROM event "
        "WHERE aggregate_id=? ORDER BY seq LIMIT 30"
    )
    print("events=", cursor.execute(query, (SESSION_ID,)).fetchall())

safe_session_columns = [
    name
    for name in ("id", "title", "time_created", "time_updated", "time_archived")
    if name in session_columns
]
if safe_session_columns:
    query = f"SELECT {', '.join(safe_session_columns)} FROM session WHERE id=?"
    print("session=", cursor.execute(query, (SESSION_ID,)).fetchall())

connection.close()

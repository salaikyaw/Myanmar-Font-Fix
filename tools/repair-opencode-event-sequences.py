import sqlite3


DB = r"C:\Users\salai\.local\share\opencode\opencode.db"
TARGET_SESSION = "ses_006551586ffes7FQ3v7VnrYv7I"


connection = sqlite3.connect(DB, timeout=30)
connection.execute("PRAGMA foreign_keys=ON")

before = connection.execute(
    """
    SELECT count(*)
    FROM (
        SELECT DISTINCT e.aggregate_id
        FROM event e
        LEFT JOIN event_sequence s ON s.aggregate_id = e.aggregate_id
        WHERE s.aggregate_id IS NULL
    )
    """
).fetchone()[0]

with connection:
    connection.execute(
        """
        INSERT INTO event_sequence (aggregate_id, seq, owner_id)
        SELECT e.aggregate_id, max(e.seq), NULL
        FROM event e
        LEFT JOIN event_sequence s ON s.aggregate_id = e.aggregate_id
        WHERE s.aggregate_id IS NULL
        GROUP BY e.aggregate_id
        """
    )

after = connection.execute(
    """
    SELECT count(*)
    FROM (
        SELECT DISTINCT e.aggregate_id
        FROM event e
        LEFT JOIN event_sequence s ON s.aggregate_id = e.aggregate_id
        WHERE s.aggregate_id IS NULL
    )
    """
).fetchone()[0]
target = connection.execute(
    "SELECT seq FROM event_sequence WHERE aggregate_id=?", (TARGET_SESSION,)
).fetchone()
quick_check = connection.execute("PRAGMA quick_check(1)").fetchone()[0]

print(f"missing_before={before}")
print(f"missing_after={after}")
print(f"target_sequence={target[0] if target else 'MISSING'}")
print(f"quick_check={quick_check}")

connection.close()

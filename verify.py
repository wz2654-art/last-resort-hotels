"""Validate the export, supplied database and eight queries. Standard library only."""
from pathlib import Path
import sqlite3
import re

root = Path(__file__).resolve().parent
rebuilt = sqlite3.connect(':memory:')
rebuilt.executescript((root / 'LastResortHotels_Database.sql').read_text())
shipped = sqlite3.connect((root / 'LastResortHotels.db').as_uri() + '?mode=ro', uri=True)
tables = [r[0] for r in rebuilt.execute("SELECT name FROM sqlite_master WHERE type='table' ORDER BY name")]
assert len(tables) == 33
assert tables == [r[0] for r in shipped.execute("SELECT name FROM sqlite_master WHERE type='table' ORDER BY name")]
for connection in [rebuilt, shipped]:
    assert connection.execute('PRAGMA integrity_check').fetchone()[0] == 'ok'
    assert connection.execute('PRAGMA foreign_key_check').fetchall() == []
    overlaps = connection.execute('''SELECT COUNT(*) FROM room_assignment a JOIN room_assignment b
        ON a.roomId = b.roomId AND a.assignmentId < b.assignmentId
        AND a.scheduledStartAt < b.scheduledEndAt AND b.scheduledStartAt < a.scheduledEndAt
        WHERE a.assignmentStatus <> 'cancelled' AND b.assignmentStatus <> 'cancelled' ''').fetchone()[0]
    assert overlaps == 0, 'Overlapping scheduled room assignments'
for table in tables:
    assert rebuilt.execute(f'SELECT * FROM {table} ORDER BY 1').fetchall() == shipped.execute(f'SELECT * FROM {table} ORDER BY 1').fetchall(), table
queries = re.split(r'(?=-- Q\d+\.)', (root / 'LastResortHotels_Queries.sql').read_text())[1:]
assert len(queries) == 8
for query in queries:
    expected = rebuilt.execute(query).fetchall()
    actual = shipped.execute(query).fetchall()
    assert expected == actual and actual
    print(query.splitlines()[0], f'({len(actual)} result rows)')
print('PASS: 33 tables; all records match the SQL rebuild; integrity OK; no FK violations; no scheduled assignment overlaps; 8 queries match.')

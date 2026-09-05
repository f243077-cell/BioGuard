import sqlite3
c = sqlite3.connect('bioguard.db')
print('alerts columns:', [r[1] for r in c.execute('PRAGMA table_info(alerts)').fetchall()])
print('devices table exists:', c.execute("SELECT name FROM sqlite_master WHERE type='table' AND name='devices'").fetchall())

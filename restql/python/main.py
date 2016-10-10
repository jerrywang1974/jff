#!/usr/bin/python3

from bottle import get, request, response, run
import os
import records

db = records.Database(os.getenv('DB_URL'))

queries = {
    'order': {
        'sql': 'SELECT * FROM order WHERE pay_status IN ({pay_status}) LIMIT {n}',
        'db': db
    }
}

def digitize(s):
    if s.startswith('@@'):
        return s[1:]
    if s.startswith('@'):
        s = s[1:]
        try: return int(s)
        except: return float(s)
    else:
        return s

def normalize(v):
    if len(v) == 1: return repr(digitize(v[0]))
    else: return ', '.join(map(repr, map(digitize, v)))

@get('/q/<q>')
def select(q):
    query = queries[q]
    params = request.query
    params = { k: normalize(params.getall(k)) for k in params.keys() }
    rows = query['db'].query(query['sql'].format(**params))
    response.content_type = 'application/json; charset=utf-8'
    return rows.export('json')

run(host='0.0.0.0', port=8080)


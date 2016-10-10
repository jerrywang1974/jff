const Sequelize = require('sequelize');
const cache = require('apicache').middleware;
const compression = require('compression');
const express = require('express');
const _ = require('lodash');

const db = new Sequelize(process.env.DB, process.env.DB_USER, process.env.DB_PASSWORD, {
    host: process.env.DB_HOST,
    dialect: 'mysql',
    pool: {
        max: 50,
        min: 0,
        idle: 30000,
    }
});

const queries = {
    'order': {
        'sql': 'SELECT * FROM order WHERE pay_status IN (:pay_status) LIMIT :n',
        'db': db
    }
};

const app = express();

app.use(compression());

app.get('/q/:q', cache('30 seconds'), function (req, res) {
    const query = queries[req.params.q];
    query['db'].query(query['sql'], {
        replacements: _.cloneDeepWith(req.query, v =>
                              typeof(v) != 'string' ? undefined :
                              v.startsWith('@@') ? v.substring(1) :
                              v.startsWith('@') ? +v.substring(1) : v),
        type: Sequelize.QueryTypes.SELECT
    }).then(function (rows) {
        res.json(rows);
    });
});

app.listen(process.env.PORT || 8080);


const assert = require('assert');

const parser = require('../index.js');

describe('test1', function() {
    it('should return opa.examples', function() {
        const payload = `
package opa.examples

import data.servers
import data.networks
import data.ports

public_servers[server] {
  some k, m
\tserver := servers[_]
\tserver.ports[_] == ports[k].id
\tports[k].networks[_] == networks[m].id
\tnetworks[m].public == true
}        
        `;
        const pkg = parser(payload)
        assert.strictEqual(pkg, 'opa.examples');
    });

    it('should return opa.examples', function() {
        const payload = `
    package opa.examples

import data.servers
import data.networks
import data.ports

public_servers[server] {
  some k, m
\tserver := servers[_]
\tserver.ports[_] == ports[k].id
\tports[k].networks[_] == networks[m].id
\tnetworks[m].public == true
}        
        `;
        const pkg = parser(payload)
        assert.strictEqual(pkg, 'opa.examples');
    });
});


describe('test2', () => {
    it('should return empty', () => {
        assert.strictEqual(parser(''), '');
    });

    it('should return empty', () => {
        assert.strictEqual(parser('garbage'), '');
    });
});

describe('test3', () => {
    it('should return opa.examples123', () => {
        const payload = `
package opa.examples123
`

        assert.strictEqual(parser(payload), 'opa.examples123');
    });

    it('should return opa', () => {
        const payload = `
package opa 
`

        assert.strictEqual(parser(payload), 'opa');
    });
});


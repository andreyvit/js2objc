assert = require('assert')
js2objc = require('../lib/index')
fs = require('fs')
Path = require('path')

fixturesDir = Path.join(__dirname, 'fixtures')

o = (input, expected) ->
  js2objc.convert { body: input }, (err, output) ->
    throw err if err
    assert.equal output.body.trim(), expected.trim()

describe "js2objc", ->
  it "basics", ->
    o """
      function foo(a, b) {
        var x = [a, b];
        return x;
      }
    """, """
      id foo(id a, id b) {
        id x = [[NSMutableArray alloc] initWithObjects:a, b, nil];
        return x;
      }
    """

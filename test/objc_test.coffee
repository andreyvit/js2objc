assert = require('assert')
objc = require('../lib/objc')
O = objc.types
fs = require('fs')
Path = require('path')

fixturesDir = Path.join(__dirname, 'fixtures/objc')

o = (input, expected) ->
  console.log("input: " + JSON.stringify(input, null, 2))
  output = objc.generate(input)
  console.log("output:\n\n%s\n", output)
  assert.equal output.trim(), expected.trim()


describe 'objc.generate', ->
  it "empty function", ->
    o O.Program([
      O.FunctionDeclaration(
        returnType: O.TypeSuffix(suffix: '*', subtype: 'NSMutableArray')
        name: 'foo',
        arguments: [
          O.ArgumentDeclaration('int', 'a')
          O.ArgumentDeclaration('int', 'b')
        ]
        body: [
        ]
      )
    ]), """
      NSMutableArray *foo(int a, int b) {
      }
    """

  it "VariableDeclaration", ->
    o O.VariableDeclaration(
        varType: O.TypeSuffix(suffix: '*', subtype: 'NSMutableArray')
        name: 'result',
        value: O.call(O.call('NSMutableArray', 'alloc'), 'initWithCapacity:', O.lit(10))
    ), """
      NSMutableArray *result = [[NSMutableArray alloc] initWithCapacity:10];
    """

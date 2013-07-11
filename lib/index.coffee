esprima = require('esprima')
escope = require('escope')
objc = require('./objc')
O = objc.types


exports.convert = (input, callback) ->
  syntax = esprima.parse(input.body)
  scopeManager = escope.analyze(syntax)

  body = []

  console.log("JS AST = %s", JSON.stringify(syntax, null, 2))

  context = new Context()

  console.log 'scopeManager.scopes.length = %s', scopeManager.scopes.length
  for scope, scopeIndex in scopeManager.scopes
    console.log "scopeManager.scopes[#{scopeIndex}].type = #{scope.type}"
    console.log "scopeManager.scopes[#{scopeIndex}].block = #{JSON.stringify(scope.block, null, 2)}"

    if scope.type is 'function'
      fdecl = scope.block

      oargs = []
      for param in fdecl.params
        oargs.push O.ArgumentDeclaration('id', param.name)

      obody = context.convertStatements(fdecl.body.body)

      body.push O.FunctionDeclaration('id', fdecl.id.name, oargs, obody)

  outputSyntax = O.Program(body)

  console.log("ObjC AST = %s", JSON.stringify(outputSyntax, null, 2))

  output = objc.generate(outputSyntax)
  console.log("\n--- output ---\n%s---\n\n", output)

  callback null, {
    body: output
  }

class Context
  constructor: ->

  convert: (node) ->
    if !node
      null
    unless conv = converters[node.type]
      console.error "Don't know how to convert node type '#{node.type}': #{JSON.stringify node}"
      return null

    console.log "Converting #{JSON.stringify node}"
    conv.call(this, node)

  expr: (node) ->
    @convert(node)

  expressions: (nodes) ->
    list = []
    for node in nodes
      if o = @expr(node)
        list.push o
    return list

  convertStatement: (node) ->
    @convert(node)

  convertStatements: (nodes) ->
    subcontext = new BlockContext(this)
    for jstat in nodes
      subcontext.convertStatement(jstat)
    return subcontext.statements

class ChildContext extends Context
  constructor: (@parentContext) ->

class BlockContext extends ChildContext
  constructor: (@parentContext) ->
    super
    @statements = []

  addStatement: (statement) ->
    @statements.push statement


converters =
  BlockStatement: (node) ->
    return O.BlockStatement(@convertStatements(node.body))

  VariableDeclaration: (node) ->
    for decl in node.declarations
      @addStatement O.VariableDeclaration('id', decl.id.name, @expr(decl.init))
    return

  ArrayExpression: (node) ->
    if node.elements.length == 0
      return O.call(O.call('NSMutableArray', 'alloc'), 'init')
    else
      elements = @expressions(node.elements).concat([O.nil])
      return O.call(O.call('NSMutableArray', 'alloc'), 'initWithObjects:', O.ObjcVarArgList(elements))

  Identifier: (node) ->
    return O.Identifier(node.name)

  ReturnStatement: (node) ->
    @addStatement O.ReturnStatement(@expr(node.argument))

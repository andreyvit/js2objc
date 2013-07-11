typeDescriptors =
  Program: 'body[]'
  FunctionDeclaration: 'returnType name$ arguments:ArgumentDeclaration[] body:BlockStatement'
  VariableDeclaration: 'varType name$ value?'
  BinaryOperator: 'lhs op$ rhs'
  BlockStatement: 'body[]'
  ArgumentDeclaration: 'argType name$'
  TypeSuffix: 'suffix$ subtype'
  ObjcCall: 'receiver fragments:ObjcCallFragment[]'
  ObjcCallFragment: 'keyword$ value?'
  Identifier: 'name$'
  NumericLiteral: 'value$'
  StringLiteral: 'value$'

ValueTypes = {}
ValueTypes.string =
  validate: (value, context) ->
    if typeof value is 'number'
      value = "#{value}"
    if typeof value isnt 'string'
      throw new Error "Value of #{context} must be a string, got: #{JSON.stringify(value)}"
    return value

ValueTypes.node = (nodeType) ->
  validate: (value, context) ->
    if typeof value is 'string'
      value = types.Identifier(value)
    else if (nodeType is 'BlockStatement') and Array.isArray(value)
      value = types.BlockStatement(value)
    if typeof value isnt 'object'
      throw new Error "Value of #{context} must be a node, got: #{JSON.stringify(value)}"
    if typeof value.type isnt 'string'
      throw new Error "Value of #{context} must be a node and must have a 'type' key, got: #{JSON.stringify(value)}"
    if (nodeType != 'any') and (value.type != nodeType)
      throw new Error "Value of #{context} must be a node of type #{nodeType}, got: #{JSON.stringify(value)}"
    return value

ValueTypes.array = (itemType) ->
  validate: (value, context) ->
    if !Array.isArray(value)
      throw new Error "Value of #{context} must be an array, got: #{JSON.stringify(value)}"
    for item, itemIndex in value
      itemType.validate(item, "item #{itemIndex} of #{context}")
    return value


exports.node = N = (type, args...) ->
  console.log("N %j", arguments);

  if !type
    throw new Error "Invalid empty type"
  if typeof type is 'string'
    type = types[type] or throw new Error "Unknown type '#{type}'"

  options = {}
  if (args.length > 0) and (lastArg = args[args.length - 1])? and (typeof lastArg is 'object') and !Array.isArray(lastArg) and !('type' of lastArg)
    options = args.pop()

  if args.length > type.positionalKeys.length
    throw new Error "Too many positional args for node type '#{type.typeName}': given #{args.length}, max is #{type.positionalKeys.length}: #{(pk.key for pk in type.positionalKeys).join(', ')}"
  for arg, argIndex in args
    key = type.positionalKeys[argIndex].key
    if options.hasOwnProperty(key)
      throw new Error "Key '#{key}' of node type '#{type.typeName}' specified using both hash and positional arguments"
    options[key] = arg

  node = { type: type.typeName }
  for own k, v of options
    unless k of type.keys
      throw new Error "Unknown key '#{k}' of node type '#{type.typeName}'"

    if !v?
      continue
    v = type.keys[k].valueType.validate(v, k, type.typeName, "key '#{k}' of node type '#{type.typeName}'")
    node[k] = v

  for own k, kinfo of type.keys when kinfo.required
    unless node.hasOwnProperty(k)
      throw new Error "Missing required key '#{k}' of node type '#{type.typeName}'"

  return node


exports.types = types = do ->
  result = {}
  for own typeName, typeDescriptor of typeDescriptors
    type = result[typeName] = N.bind(null, typeName)
    type.typeName = typeName
    type.keys = {}
    type.positionalKeys = []

    keyDescriptors = typeDescriptor.split(/\s+/)
    for key in keyDescriptors
      kinfo = { key, required: yes, valueType: ValueTypes.node('any'), specificType: null }

      if key.match /\?$/
        kinfo.required = no
        key = key.substr(0, key.length - 1)

      isArray = no
      if key.match /\$$/
        kinfo.valueType = ValueTypes.string
        key = key.substr(0, key.length - 1)
      if key.match /\[\]$/
        isArray = yes
        key = key.substr(0, key.length - 2)
      if m = key.match /^(.*):(.*)$/
        valueTypeName = m[2]
        key = m[1]
        unless valueTypeName of typeDescriptors
          throw new Error "Invalid node type '#{valueTypeName}' of key '#{key}' of node type '#{typeName}'"
        kinfo.valueType = ValueTypes.node(valueTypeName)

      if isArray
        kinfo.valueType = ValueTypes.array(kinfo.valueType)

      kinfo.key = key
      type.keys[key] = kinfo
      type.positionalKeys.push(kinfo)

  return result


types.id = types.Identifier

types.call = (receiver, items...) ->
  fragments = []
  while (keyword = items.shift())?
    value = items.shift()
    fragments.push types.ObjcCallFragment(keyword, value)
  types.ObjcCall(receiver, fragments)

types.lit = (literal) ->
  if typeof literal is 'number'
    types.NumericLiteral('' + literal)
  else if typeof literal is 'string'
    types.StringLiteral(literal)
  else
    throw new Error "Unknown literal type: #{typeof literal}"

types.assign = (lhs, rhs) ->
  types.BinaryOperator(lhs, '=', rhs)

types.nil = types.id('nil')

exports.generate = (rootNode) ->
  new ObjcContext().addNode(rootNode).output()


String_repeat = (string, times) -> new Array(times + 1).join(string)

ENDS_WITH_LETTER = /\w$/

SP_DEFAULT = -1
SP_NEVER   = 0
SP_OK      = 1
SP_WANT    = 2
defaultSpace = (char) -> if char.match(/[a-z0-9$_]/i) then SP_WANT else SP_OK
needsSpace = (l, r) ->
  if (l is SP_NEVER) or (r is SP_NEVER)
    no
  else if (l is SP_WANT) or (r is SP_WANT)
    yes
  else
    no

class ObjcContext
  constructor: ->
    @fragments = []

    @indentElement = '    '
    @indentationStrings = {}
    @setIndentation(0)

    @_lineOpen = no
    @_space = SP_NEVER

  addNode: (node) ->
    gen = generators[node.type]
    unless gen
      throw new Error "Don't know how to generate node of type '#{node.type}': #{JSON.stringify node}"
    gen.call(this, node)
    return this

  add: (fragment, lspace=SP_DEFAULT, rspace=SP_DEFAULT) ->
    if !fragment
      #
    else if typeof fragment is 'object'
      @addNode(fragment)
    else
      if lspace is SP_DEFAULT
        lspace = defaultSpace(fragment.charAt(0))
      if rspace is SP_DEFAULT
        rspace = defaultSpace(fragment.charAt(fragment.length - 1))

      @_openLine()

      if needsSpace(@_space, lspace)
        @fragments.push ' '

      @fragments.push fragment
      @_space = rspace
    return this

  addnl: (fragment, lspace) ->
    if fragment
      @add(fragment, lspace)
    @nl()
    return this

  nl: ->
    @_closeLine()
    return this

  indent: (opening, lspace=SP_WANT) ->
    if opening
      @addnl(opening, lspace)
    @_closeLine()
    @setIndentation(@indentationLevel + 1)
    return this

  dedent: (closing) ->
    @_closeLine()
    @setIndentation(@indentationLevel - 1)
    if closing
      @addnl(closing)
    return this

  setIndentation: (@indentationLevel) ->
    @indentationString = (@indentationStrings[@indentationLevel] ?= String_repeat(@indentElement, @indentationLevel))

  output: ->
    @fragments.join('')

  _openLine: ->
    return if @_lineOpen
    @_lineOpen = yes
    @fragments.push @indentationString
    @_space = SP_NEVER

  _closeLine: ->
    return unless @_lineOpen
    @_lineOpen = no
    @fragments.push "\n"
    @_space = SP_NEVER


generators =
  Program: (node) ->
    for child in node.body
      @add(child)

  BlockStatement: (node) ->
    @indent('{')
    for child in node.body
      @add(child)
    @dedent('}')

  FunctionDeclaration: (node) ->
    @add(node.returnType)
    @add(node.name)
    @add('(', SP_NEVER, SP_NEVER)
    for argument, argumentIndex in node.arguments
      if argumentIndex > 0
        @add(',', SP_NEVER, SP_WANT)
      @add(argument)
    @add(')', SP_NEVER)
    @add(node.body)

  TypeSuffix: (node) ->
    @add(node.subtype)
    @add(node.suffix, SP_WANT, SP_NEVER)

  ArgumentDeclaration: (node) ->
    @add(node.argType)
    @add(node.name)

  VariableDeclaration: (node) ->
    @add(node.varType)
    @add(node.name)
    if node.value
      @add('=', SP_WANT, SP_WANT)
      @add(node.value)
    @addnl(';', SP_NEVER)

  Identifier: (node) ->
    @add(node.name)

  NumericLiteral: (node) ->
    @add(node.value)

  StringLiteral: (node) ->
    @add('"', SP_OK, SP_NEVER)
    @add(node.value, SP_NEVER, SP_NEVER)
    @add('"', SP_NEVER, SP_OK)

  ObjcCall: (node) ->
    @add('[', SP_OK, SP_NEVER)
    @add(node.receiver)
    for fragment in node.fragments
      @add(fragment)
    @add(']', SP_NEVER, SP_WANT)

  ObjcCallFragment: (node) ->
    @add(node.keyword, SP_OK, SP_NEVER)
    if node.value?
      @add(node.value)

  BinaryOperator: (node) ->
    @add(node.lhs)
    @add(node.op, SP_WANT, SP_WANT)
    @add(node.rhs)

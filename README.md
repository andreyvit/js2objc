# js2objc

[![Greenkeeper badge](https://badges.greenkeeper.io/andreyvit/js2objc.svg)](https://greenkeeper.io/)

Some day, this is going to be a JavaScript to Objective-C transpiler.

(It doesn't need to convert arbitrarily complex JavaScript code, just something that allows to implement data structure manipulation and file I/O in Node.js and than transpile to Objective-C.)

Right now there's nothing to see here aside from very early beginnings. Basically this project idea kept bugging me, so I decided to write a bit of code to get it off my head.

Done:

* simple AST and code generator for Objective-C (only handles a few node types yet)
* a stub converter that handles a function that creates and returns an array

TODO:

* handle function calls
* handle if statement
* handle for statement
* handle while statement
* handle assignments
* handle binary operators
* handle array indexing
* handle unary operators
* handle string and numeric literals
* local type inferencing (inside functions)
* use TypeScript annotations for types
* recognize and convert classes
* handle method calls on custom classes
* handle anonymous functions and their calls
* handle JavaScript array methods
* handle JavaScript string methods
* handle JavaScript math methods (at least Math.min and Math.max)
* handle dictionary creation
* handle JavaScript dictionary methods
* handle regular expressions
* global type inferencing
* convert multiple files
* convert npm packages with their dependencies
* convert Node.js 'file' and 'path' modules
* convert Mocha tests into XCUnit tests

See, everything is still a TODO. :-)


## License

MIT license.

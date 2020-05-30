import resolve from '@rollup/plugin-node-resolve'
import commonjs from '@rollup/plugin-commonjs'
import coffeescript from 'rollup-plugin-coffee-script'
import {terser} from 'rollup-plugin-terser'

let plugins = [
  // if any (in deps as well): Convert CoffeeScript to JavaScript
  coffeescript(),

  // so Rollup can find externals
  resolve({extensions: ['.js', '.coffee'], preferBuiltins: true}),

  // so Rollup can convert externals to an ES module
  commonjs()
]

// minify only in production mode
if (process.env.NODE_ENV === 'production') {
  plugins.push(
    // minify
    terser({
      ecma: 2018,
      warnings: true,
      compress: {
        drop_console: false
      }
    })
  )
}

export default [
  {
    input: 'lib/main',
    output: [
      {
        dir: 'dist',
        format: 'cjs',
        sourcemap: true
      }
    ],
    // loaded externally
    external: [
      'atom',
      'pathwatcher',
      // node stuff
      'fs',
      'path'
    ],
    plugins: plugins
  }
]

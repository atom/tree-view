const presets = [['@babel/preset-env', { targets: { electron: 5 } }]]

const plugins = []

if (process.env.BABEL_ENV === 'development') {
  plugins.push('@babel/plugin-transform-modules-commonjs')
}

module.exports = {
  presets,
  plugins,
  exclude: 'node_modules/**',
  sourceMaps: 'inline',
}

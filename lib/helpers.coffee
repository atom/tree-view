{Directory} = require "atom"
path = require "path"

module.exports =
  repositoryForPath: (goalPath) ->
    if goalPath
      directory = new Directory goalPath
      return atom.project.repositoryForDirectory directory
    Promise.resolve(null)

  getStyleObject: (el) ->
    styleProperties = window.getComputedStyle(el)
    styleObject = {}
    for property of styleProperties
      value = styleProperties.getPropertyValue property
      camelizedAttr = property.replace /\-([a-z])/g, (a, b) -> b.toUpperCase()
      styleObject[camelizedAttr] = value
    styleObject

  getFullExtension: (filePath) ->
    basename = path.basename(filePath)
    position = basename.indexOf('.')
    if position > 0 then basename[position..] else ''

{Directory} = require "atom"
path = require "path"

module.exports =
  repoForPath: (goalPath) ->
    if goalPath
      return atom.project.repositoryForDirectory(new Directory(goalPath))
    null

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

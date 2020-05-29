'use babel'

import path from "path"


export repoForPath = (goalPath) ->
  for projectPath, i in atom.project.getPaths()
    if goalPath is projectPath or goalPath.indexOf(projectPath + path.sep) is 0
      return atom.project.getRepositories()[i]
  null

export getStyleObject = (el) ->
  styleProperties = window.getComputedStyle(el)
  styleObject = {}
  for property of styleProperties
    value = styleProperties.getPropertyValue property
    camelizedAttr = property.replace /\-([a-z])/g, (a, b) -> b.toUpperCase()
    styleObject[camelizedAttr] = value
  styleObject

export getFullExtension = (filePath) ->
  basename = path.basename(filePath)
  position = basename.indexOf('.')
  if position > 0 then basename[position..] else ''

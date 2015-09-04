path = require "path"

module.exports =
  repoForPath: (goalPath) ->
    for projectPath, i in atom.project.getPaths()
      if goalPath is projectPath or goalPath.indexOf(projectPath + path.sep) is 0
        return atom.project.getRepositories()[i]
    null

  getStyleObject: (el) ->
    styleProperties = window.getComputedStyle(el)
    styleObject = {}
    for property of styleProperties
      value = styleProperties.getPropertyValue property
      camelizedAttr = property.replace /\-([a-z])/g, (a, b) -> b.toUpperCase()
      styleObject[camelizedAttr] = value
    styleObject

  ensureOpaqueBackground: (styleObject) ->
    propName = if styleObject.backgroundColor then 'backgroundColor' else 'background'
    if (match = /((?:rgb|hsl)a\s*\(\s*[0-9.]+\s*,\s*[0-9.%]+\s*,\s*[0-9.%]+\s*,\s*)([0-9.]+)(\s*\).*)/.exec(styleObject[propName]))
      opacity = Number(match[2])
      if opacity < 0.4
        styleObject[propName] = match[1] + 1.0 + match[3]
    styleObject

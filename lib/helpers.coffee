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

  getFullExtension: (filePath) ->
    fullExtension = ''
    while extension = path.extname(filePath)
      fullExtension = extension + fullExtension
      filePath = path.basename(filePath, extension)
    fullExtension

  updateEditorsForPath: (oldPath, newPath) ->
    editors = atom.workspace.getTextEditors()
    for editor in editors
      filePath = editor.getPath()
      if filePath?.startsWith(oldPath)
        editor.getBuffer().setPath(filePath.replace(oldPath, newPath))

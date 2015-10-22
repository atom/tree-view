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

  lowestCommonAncestor: (paths) ->
    basePaths = (thePath.substring(0, thePath.lastIndexOf(path.sep)) for thePath in paths)

    # if we only have one path, then suggest the base directory
    return basePaths[0] + path.sep if basePaths.length is 1

    # split each path into its components
    splits = ((elt for elt in thePath.split(path.sep) when elt) for thePath in basePaths)

    # compute the maximum depth we have to check as the shortest path length
    max_depth = Math.min.apply(null, split.length for split in splits) - 1

    for depth in [0..max_depth]
      level = (split[depth] for split in splits)
      # is every path component on this level the same?
      break unless level.reduce((prev, curr) -> if prev is curr then curr else false)

    # join the paths with a trailing slash
    result = path.join.apply(null, splits[0][0..depth-1]) + path.sep

    # if this isn't windows, then prepend a slash
    if process.platform isnt 'win32'
      result = path.sep + result

    return result

  typeIsArray: Array.isArray or (value) ->
    return {}.toString.call(value) is '[object Array]'

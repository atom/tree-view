path = require "path"
fs = require 'fs-plus'
{GitRepository} = require 'atom'

module.exports =
  repositoryCache: {}
  fakeProjectRoots: []

  getRepoCache: ->
    module.exports.repositoryCache

  isFakeProjectRoot: (checkPath) ->
    path.normalize(checkPath) in module.exports.fakeProjectRoots

  getRepoCacheSize: ->
    Object.keys(module.exports.repositoryCache).length

  resetRepoCache: ->
    module.exports.repositoryCache = {}

  repoForPath: (goalPath) ->
    result = null
    project = null
    projectIndex = null
    _this = module.exports
    for projectPath, i in atom.project.getPaths()
      if goalPath.indexOf(projectPath) is 0
        project = projectPath
        projectIndex = i
    # can't find related projects, so repo can't be assigned
    return null unless project?
    walkUpwards = (startDir, toDir, projectIndex) ->
      if fs.existsSync(startDir + '/.git')
        for provider in atom.project.repositoryProviders
          if _this.repositoryCache[startDir]
            return _this.repositoryCache[startDir]
          for dProvider in atom.project.directoryProviders
            break if directory = dProvider.directoryForURISync(startDir)
          directory ?= atom.project.defaultDirectoryProvider.directoryForURISync(startDir)
          repo = GitRepository.open(startDir, {project: provider.project, \
                                               refreshOnWindowFocus: atom.config.get('tree-view.refreshVcsStatusOnFocusChange') > _this.getRepoCacheSize()})
          return null unless repo
          repo.onDidDestroy( ->
            delete _this.repositoryCache[startDir]
            indexToRemove = null
            for dir, i in atom.project.getDirectories()
              if startDir is dir.getPath()
                indexToRemove = i
                break
            atom.project.rootDirectories.splice(indexToRemove, 1)
            atom.project.repositories.splice(indexToRemove, 1)
          )
          existsInAtom = false
          for dir in atom.project.rootDirectories
            if dir.getRealPathSync() is directory.getRealPathSync()
              existsInAtom = true
              break
          if not existsInAtom
            atom.project.repositories.splice(0, 0, repo)
            atom.project.rootDirectories.splice(0, 0, directory)
            _this.fakeProjectRoots.push(startDir)
          _this.repositoryCache[startDir] = repo
          return repo
      if startDir is toDir
        # top of project
        if atom.project.getRepositories()[projectIndex]
          return atom.project.getRepositories()[projectIndex]
        return null
      dirName = path.dirname(startDir)
      return null if dirName is startDir # reached top
      return walkUpwards(dirName, project, projectIndex)
    return walkUpwards(path.normalize(goalPath), project, projectIndex)

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

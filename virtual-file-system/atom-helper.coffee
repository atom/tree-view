fs = require 'graceful-fs'
CSON = require 'cson'
_path = require 'path'
LocalStorage = window.localStorage
{CompositeDisposable} = require 'atom'

convertEOL = (text) ->
  text.replace(/\r\n|\n|\r/g, '\n')

utilPath = _path.join(__dirname, 'util')

module.exports =
class AtomHelper
  constructor: (@virtualFileSystem) ->
    @addMenu()
    @addKeymaps()
    @addContextMenus()
    @replaceTitleUpdater()
    atom.packages.onDidActivateInitialPackages(@handleEvents)

  handleEvents: =>
    body = document.body
    body.classList.add('learn-ide')

    @disposables = new CompositeDisposable

    @disposables.add atom.commands.add body,
      'learn-ide:save': @onLearnSave
      'learn-ide:save-as': @unimplemented
      'learn-ide:save-all': @unimplemented

    @disposables.add atom.workspace.observeTextEditors (editor) =>
      editor.onDidSave (e) =>
        @onEditorSave(e)
        @updateTitle()

    @disposables.add atom.packages.onDidActivatePackage (pkg) =>
      return unless pkg.name is 'find-and-replace'

      projectFindView = pkg.mainModule.projectFindView
      resultModel = projectFindView.model

      @disposables.add resultModel.onDidReplacePath ({filePath}) =>
        @saveAfterProjectReplace(filePath)

    @disposables.add @package().onDidDeactivate =>
      atom.workspace.updateWindowTitle = LocalStorage.getItem('workspace:updateTitle')
      LocalStorage.removeItem('workspace:updateTitle')
      @disposables.dispose()

  replaceTitleUpdater: ->
    if not LocalStorage.getItem('workspace:updateTitle')
      LocalStorage.setItem('workspace:updateTitle', atom.workspace.updateWindowTitle)
      atom.workspace.updateWindowTitle = @updateTitle

  updateTitle: =>
    itemPath = atom.workspace.getActivePaneItem()?.getPath?()

    node =
      if itemPath?
        @virtualFileSystem.getNode(itemPath)
      else
        @virtualFileSystem.projectNode

    title =
      if node? and node.path?
        "Learn IDE — #{node.path.replace(/^\//, '')}"
      else
        'Learn IDE'

    document.title = title
    atom.applicationDelegate.setRepresentedFilename(node.localPath())

  configPath: ->
    atom.configDirPath

  package: ->
    # todo: update package name
    atom.packages.getActivePackage('tree-view')

  treeView: ->
    @package()?.mainModule.treeView

  token: ->
    atom.config.get('learn-ide.oauthToken')

  addOpener: (opener) ->
    atom.workspace.addOpener(opener)

  projectFindAndReplace: ->
    findAndReplace = atom.packages.getActivePackage('find-and-replace')
    projectFindView = findAndReplace.mainModule.projectFindView
    console.log projectFindView.model
    projectFindView.model

  clearProjects: ->
    # TODO: add these paths to localStorage to replace them on deactivation
    initialProjectPaths = atom.project.getPaths()
    initialProjectPaths.forEach (path) -> atom.project.removePath(path)

  updateProject: (path, directoryExpansionStates) ->
    @clearProjects()
    atom.project.addPath(path)
    @treeView()?.updateRoots(directoryExpansionStates)
    @updateTitle()

  reloadTreeView: (path, pathToSelect) ->
    @treeView()?.entryForPath(path).reload()
    @treeView()?.selectEntryForPath(pathToSelect or path)

  findBuffer: (path) ->
    atom.project.findBufferForPath(path)

  findOrCreateBuffer: (path) ->
    atom.project.bufferForPath(path)

  loading: ->
    atom.notifications.addInfo 'Learn IDE: loading your remote code...',
      detail: """
              This may take a moment, but you likely won't need
              to wait again on this computer.
              """

  unimplemented: ({type}) ->
    command = type.replace(/^learn-ide:/, '').replace(/-/g, ' ')

    atom.notifications.addWarning 'Learn IDE: coming soon!',
      detail: """
              Sorry, '#{command}' is not yet available.
              """

  onLearnSave: ({target}) =>
    textEditor = atom.workspace.getTextEditors().find (editor) ->
      editor.element is target

    if not textEditor.getPath()?
      # TODO: this happens if an untitled editor is saved. need to build a 'Save As' or sorts
      return console.log 'Cannot save file without path'

    text = convertEOL(textEditor.getText())
    content = new Buffer(text).toString('base64')
    @virtualFileSystem.save(textEditor.getPath(), content)

  onEditorSave: ({path}) =>
    node = @virtualFileSystem.getNode(path)

    node.determineSync().then (shouldSync) =>
      if shouldSync
        @findOrCreateBuffer(path).then (textBuffer) =>
          text = convertEOL(textBuffer.getText())
          content = new Buffer(text).toString('base64')
          @virtualFileSystem.save(path, content)

  saveEditorForPath: (path) ->
    textEditor = atom.workspace.getTextEditors().find (editor) ->
      editor.getPath() is path

    return false unless textEditor?

    textEditor.save()
    true

  saveAfterProjectReplace: (path) =>
    fs.readFile path, (err, data) =>
      if err
        return console.error "Project Replace Error", err

      text = convertEOL(data)
      content = new Buffer(text).toString('base64')
      @virtualFileSystem.save(path, content)

  addMenu: ->
    path = _path.join(utilPath, 'menu.cson')

    fs.readFile path, (err, data) ->
      if err?
        return console.error "Unable to add menu:", err

      atom.menu.add CSON.parse(data)

  addKeymaps: ->
    path = _path.join(utilPath, 'keymaps.cson')

    fs.readFile path, (err, data) ->
      if err?
        return console.error "Unable to add keymaps:", err

      atom.keymaps.add path, CSON.parse(data)

  addContextMenus: ->
    path = _path.join(utilPath, 'context-menus.cson')

    fs.readFile path, (err, data) ->
      if err?
        return console.error "Unable to add context-menus:", err

      atom.contextMenu.add CSON.parse(data)


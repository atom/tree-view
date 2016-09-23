fs = require 'graceful-fs'
CSON = require 'cson'
_path = require 'path'
{CompositeDisposable} = require 'atom'

convertEOL = (text) ->
  text.replace(/\r\n|\n|\r/g, '\n')

utilPath = _path.join(__dirname, 'util')

module.exports =
class AtomHelper
  constructor: (@virtualFileSystem) ->
    @addKeymaps()
    @addMenu()
    @addContextMenus()
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
      editor.onDidSave(@onEditorSave)

    @disposables.add atom.packages.onDidActivatePackage (pkg) =>
      return unless pkg.name is 'find-and-replace'

      projectFindView = pkg.mainModule.projectFindView
      resultModel = projectFindView.model

      @disposables.add resultModel.onDidReplacePath ({filePath}) =>
        @saveAfterProjectReplace(filePath)

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

  reloadTreeView: (path, pathToSelect) ->
    @treeView()?.entryForPath(path).reload()
    @treeView()?.selectEntryForPath(pathToSelect or path)

  findBuffer: (path) ->
    atom.project.findBufferForPath(path)

  findOrCreateBuffer: (path) ->
    atom.project.bufferForPath(path)

  reloadTextBuffer: (path) ->
    buffer = @findBuffer(path)

    if buffer?
      buffer.updateCachedDiskContentsSync()
      buffer.reload()

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
    @virtualFileSystem.learnSave(textEditor.getPath(), content)

  onEditorSave: ({path}) =>
    @findOrCreateBuffer(path).then (textBuffer) =>
      text = convertEOL(textBuffer.getText())
      content = new Buffer(text).toString('base64')
      @virtualFileSystem.editorSave(path, content)

  saveEditorForPath: (path) ->
    textEditor = atom.workspace.getTextEditors().find (editor) ->
      editor.getPath() is path

    if textEditor?
      textEditor.save()

  saveAfterProjectReplace: (path) =>
    fs.readFile path, (err, data) =>
      if err
        return console.log "Project Replace Error", err

      text = convertEOL(data)
      content = new Buffer(text).toString('base64')
      @virtualFileSystem.editorSave(path, content)

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


fs = require 'graceful-fs'
CSON = require 'cson'
_path = require 'path'
crypto = require 'crypto'
LocalStorage = window.localStorage
{CompositeDisposable} = require 'atom'
remote = require 'remote'
dialog = remote.require 'dialog'

humanize = (seconds) ->
  minutes = Math.floor(seconds / 60)
  time = if minutes then minutes else seconds
  unit = if minutes then 'minute' else 'second'
  "#{time} #{unit}#{if time is 1 then '' else 's'}"

convertEOL = (text) ->
  text.replace(/\r\n|\n|\r/g, '\n')

digest = (str) ->
  crypto.createHash('md5').update(str, 'utf8').digest('hex')

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
      'learn-ide:import': @onImport
      'learn-ide:file-open': @unimplemented
      'learn-ide:add-project': @unimplemented

    @disposables.add atom.workspace.observeTextEditors (editor) =>
      @disposables.add editor.onDidSave (e) =>
        @onEditorSave(e)
        @updateTitle()

    @disposables.add atom.packages.onDidActivatePackage (pkg) =>
      return unless pkg.name is 'find-and-replace'

      projectFindView = pkg.mainModule.projectFindView
      resultModel = projectFindView.model

      @disposables.add resultModel.onDidReplacePath ({filePath}) =>
        @saveAfterProjectReplace(filePath)

    @disposables.add @package().onDidDeactivate =>
      @disposables.dispose()
      @virtualFileSystem.cache()
      atom.workspace.updateWindowTitle = LocalStorage.getItem('workspace:updateTitle')
      LocalStorage.removeItem('workspace:updateTitle')

  spawn: (modulePath) ->
    {BufferedNodeProcess} = require 'atom'
    new BufferedNodeProcess({command: modulePath})

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

    title = 'Learn IDE'

    if node? and node.path?
      title += " — #{node.path.replace(/^\//, '')}"
      atom.applicationDelegate.setRepresentedFilename(node.localPath())

    document.title = title

  configPath: ->
    atom.configDirPath

  package: ->
    # todo: update package name
    atom.packages.getActivePackage('tree-view')

  treeView: ->
    @package()?.mainModule.treeView

  getToken: ->
    new Promise (resolve) ->
      atom.config.observe 'learn-ide.oauthToken', (token) ->
        if token? and token.length
          resolve(token)

  open: (path) ->
    atom.workspace.open(path)

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

  success: (msg, opts) ->
    atom.notifications.addSuccess(msg, opts)

  info: (msg, opts) ->
    atom.notifications.addInfo(msg, opts)

  warn: (msg, opts) ->
    atom.notifications.addWarning(msg, opts)

  error: (msg, opts) ->
    atom.notifications.addError(msg, opts)

  loading: ->
    @info 'Learn IDE: loading your remote code...',
      detail: """This may take a moment, but will only happen
              very occasionally (maybe just once)"""
      dismissable: true

  unimplemented: ({type}) =>
    command = type.replace(/^learn-ide:/, '').replace(/-/g, ' ')
    @warn 'Learn IDE: coming soon!', {detail: "Sorry, '#{command}' isn't available yet."}

  disconnected: ->
    @error 'Learn IDE: connection lost 😮',
      detail: 'The connection with the remote server has been lost.'
      dismissable: false

  connecting: (seconds) ->
    @warn 'Learn IDE: attempting to connect...', {dismissable: true}

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

    if not textEditor.isModified()
      false
    else
      node = @virtualFileSystem.getNode(path)
      if node.digest is digest(textEditor.getText())
        textEditor.save()
        true
      false

  saveAfterProjectReplace: (path) =>
    fs.readFile path, 'utf8', (err, data) =>
      if err
        return console.error "Project Replace Error", err

      text = convertEOL(data)
      content = new Buffer(text).toString('base64')
      @virtualFileSystem.save(path, content)

  addMenu: ->
    path = _path.join(__dirname, '..', 'menus', 'menu.cson')

    fs.readFile path, (err, data) ->
      if err?
        return console.error "Unable to add menu:", err

      atom.menu.add CSON.parse(data)

  addKeymaps: ->
    path = _path.join(__dirname, '..', 'keymaps', 'keymaps.cson')

    fs.readFile path, (err, data) ->
      if err?
        return console.error "Unable to add keymaps:", err

      atom.keymaps.add path, CSON.parse(data)

  addContextMenus: ->
    path = _path.join(__dirname, '..', 'menus', 'context-menus.cson')

    fs.readFile path, (err, data) ->
      if err?
        return console.error "Unable to add context-menus:", err

      atom.contextMenu.add CSON.parse(data)

  onImport: =>
    dialog.showOpenDialog
      title: 'Import Files',
      properties: ['openFile', 'multiSelections']
    , (paths) => @importLocalPaths(paths)


  importLocalPaths: (localPaths) ->
    localPaths = [localPaths] if typeof localPaths is 'string'
    targetPath = @treeView().selectedPath
    targetNode = @virtualFileSystem.getNode(targetPath)

    localPaths.forEach (path) =>
      fs.readFile path, 'base64', (err, data) =>
        if err?
          return console.error 'Unable to import file:', path, err

        base = _path.basename(path)
        newPath = _path.posix.join(targetNode.path, base)

        if @virtualFileSystem.hasPath(newPath)
          @warn 'Learn IDE: cannot save file',
            detail: """There is already an existing remote file with path:
                    #{newPath}"""
          return

        @virtualFileSystem.save(newPath, data)


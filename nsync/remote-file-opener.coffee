TextBuffer = require 'text-buffer'

ONE_MEGABYTE = 1048576

megabytes = (n) -> n * ONE_MEGABYTE

bufferForPath = (path, options) ->
  atom.project.findBufferForPath(path) or buildBuffer(path)

buildBuffer = (filePath) ->
  buffer = new TextBuffer({filePath})
  atom.project.addBuffer(buffer)

buildEditor = (buffer, largeFileMode, options) ->
  editor = atom.workspace.buildTextEditor(Object.assign({buffer, largeFileMode}, options))
  disposable = atom.textEditors.add(editor)
  editor.onDidDestroy -> disposable.dispose()
  editor

largeFileConfirm = (editor) ->
  proceed = false
  atom.confirm
    message: 'Atom will be unresponsive during the loading of large files.'
    detailedMessage: "Do you still want to load this file?"
    buttons:
      Proceed: -> proceed = true
      Cancel: null
  proceed

displayLoading = (path) ->
  atom.notifications.addInfo "Loading #{path}...", icon: 'cloud-download'

module.exports =
class RemoteFileOpener
  constructor: ({@path, @contents, @size}, @options) ->
    @isLarge = @size > megabytes(5)
    @largeFileMode = @size >= megabytes(2) # defined by TextEditor

  open: ->
    if not @contents?
      @requestOpen()
    else
      @openFile()

  requestOpen: ->
    buffer = bufferForPath(@path)
    editor = buildEditor(buffer, @largeFileMode, @options)

    if not @isLarge or (@isLarge and largeFileConfirm())
      displayLoading(@path) if @isLarge
      learnIDE.remoteFS.open(@path)

    # TODO: this should prevent opening no matter what
    # i.e. only create text editor when contents are present (big files load slow,
    # so an empty editor just hanging out is weird)
    editor


  openFile: ->
    buffer = bufferForPath(@path)
    buffer.setText(@contents) if @contents?
    buildEditor(buffer, @largeFileMode, @options)


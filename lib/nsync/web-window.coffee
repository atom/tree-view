_ = require 'underscore-plus'
shell = require 'shell'
remote = require 'remote'
BrowserWindow = remote.BrowserWindow

module.exports =
class WebWindow
  constructor: (url, options = {}, @openNewWindowExternally = true) ->
    _.defaults options,
      show: false
      width: 400
      height: 600
      skipTaskbar: true
      menuBarVisible: false

    @win = new BrowserWindow(options)
    @webContents = @win.webContents

    @handleEvents()
    @win.loadURL(url) # TODO: handle failed load

  handleEvents: ->
    @webContents.on 'did-finish-load', =>
      @win.show()

    if @openNewWindowExternally
      @webContents.on 'new-window', (e, url) =>
        e.preventDefault()
        @win.destroy()
        shell.openExternal(url)


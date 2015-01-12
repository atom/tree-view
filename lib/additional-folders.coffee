_ = require 'underscore-plus'
path = require 'path'
shell = require 'shell'
fs = require 'fs'
remote = require 'remote'
dialog = remote.require 'dialog'

{BufferedProcess, CompositeDisposable} = require 'atom'
{$, View} = require 'atom-space-pen-views'

Directory = require './directory'
DirectoryView = require './directory-view'
FileView = require './file-view'

# Adding additional folders like..
module.exports =
  class AdditionalFolders

    constructor: (treeview) ->
      # yup
      @treeview = treeview

      @addDirs = []
      @addViews = []

      atom.treeView ||= treeview
      atom.treeView.additionalFolders = @

      # register commands
      @disposables = new CompositeDisposable
      @disposables.add atom.commands.add 'atom-workspace',
        'tree-view:open-another-folder': @openAnotherFolder.bind @

    openAnotherFolder: ->
      console.log 'openAnotherFolder'
      p = dialog.showOpenDialog({ properties: [ 'openDirectory' ]})
      if p
        p = p.toString()
        console.log 'Adding new folder: '+p
        expandedEntries = {}
        dir = new Directory({
          name: path.basename(p)
          fullPath: p
          symlink: false
          isRoot: false
          expandedEntries
          isExpanded: true
          @ignoredPatterns
        })

        view = new DirectoryView()
        view.initialize(dir)

        @addDirs.push dir
        @addViews.push view

        @treeview.list[0].appendChild view
        console.log 'Added: '+p

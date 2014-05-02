{$, View} = require 'atom'

Directory = require './directory'
FileView = require './file-view'
File = require './file'

module.exports =
class DirectoryView extends View
  @content: ->
    @li class: 'directory entry list-nested-item collapsed', =>
      @div outlet: 'header', class: 'header list-item', =>
        @span class: 'name icon', outlet: 'directoryName'
      @ol class: 'entries list-tree', outlet: 'entries'

  initialize: (@directory) ->
    if @directory.symlink
      iconClass = 'icon-file-symlink-directory'
    else
      iconClass = 'icon-file-directory'
      if @directory.isRoot
        iconClass = 'icon-repo' if atom.project.getRepo()?.isProjectAtRoot()
      else
        iconClass = 'icon-file-submodule' if @directory.submodule
    @directoryName.addClass(iconClass)
    @directoryName.text(@directory.name)

    relativeDirectoryPath = atom.project.relativize(@directory.path)
    @directoryName.attr('data-name', @directory.name)
    @directoryName.attr('data-path', relativeDirectoryPath)

    unless @directory.isRoot
      @subscribe @directory.$status.onValue (status) =>
        @removeClass('status-ignored status-modified status-added')
        @addClass("status-#{status}") if status?

    @expand() if @directory.isExpanded

  beforeRemove: ->
    @directory.destroy()

  subscribeToDirectory: ->
    @subscribe @directory, 'entry-added', (entry) =>
      view = @createViewForEntry(entry)
      insertionIndex = entry.indexInParentDirectory
      if insertionIndex < @entries.children().length
        @entries.children().eq(insertionIndex).before(view)
      else
        @entries.append(view)

    @subscribe @directory, 'entry-added entry-removed', =>
      @trigger 'tree-view:directory-modified' if @isExpanded

  getPath: ->
    @directory.path

  createViewForEntry: (entry) ->
    if entry instanceof Directory
      view = new DirectoryView(entry)
    else
      view = new FileView(entry)

    subscription = @subscribe @directory, 'entry-removed', (removedEntry) ->
      if entry is removedEntry
        view.remove()
        subscription.off()

    view

  reload: ->
    @directory.reload() if @isExpanded

  toggleExpansion: ->
    if @isExpanded then @collapse() else @expand()

  expand: ->
    return if @isExpanded
    @addClass('expanded').removeClass('collapsed')
    @subscribeToDirectory()
    @directory.expand()
    @isExpanded = true
    false

  collapse: ->
    @removeClass('expanded').addClass('collapsed')
    @directory.collapse()
    @unsubscribe(@directory)
    @entries.empty()
    @isExpanded = false

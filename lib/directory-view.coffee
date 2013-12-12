{$, $$, View} = require 'atom'

Directory = require './directory'
FileView = require './file-view'
File = require './file'

module.exports =
class DirectoryView extends View
  @content: ->
    @li class: 'directory entry list-nested-item', =>
      @div outlet: 'header', class: 'header list-item', =>
        @span class: 'name icon', outlet: 'directoryName'

  initialize: ({@directory, isExpanded, parent} = {}) ->
    @entries = null

    if isExpanded then @expand() else @collapse()

    if @directory.symlink
      iconClass = 'icon-file-symlink-directory'
    else
      iconClass = 'icon-file-directory'
      if parent?
        iconClass = 'icon-file-submodule' if @directory.submodule
      else
        iconClass = 'icon-repo' if atom.project.getRepo()?.isProjectAtRoot()
    @directoryName.addClass(iconClass)
    @directoryName.text(@directory.name)

    if parent?
      @subscribe @directory.$status.onValue (status) =>
        @removeClass('status-ignored status-modified status-added')
        @addClass("status-#{status}") if status?

  beforeRemove: -> @directory.destroy()

  getPath: ->
    @directory.path

  buildEntries: ->
    @unwatchDescendantEntries()
    @entries?.remove()
    @entries = $$ -> @ol class: 'entries list-tree'
    for entry in @directory.getEntries()
      if entry instanceof Directory
        @entries.append(new DirectoryView(directory: entry, isExpanded: false, parent: @directory))
      else
        @entries.append(new FileView(entry))
    @append(@entries)

  toggleExpansion: ->
    if @isExpanded then @collapse() else @expand()

  expand: ->
    return if @isExpanded
    @addClass('expanded').removeClass('collapsed')
    @buildEntries()
    @watchEntries()
    @deserializeEntryExpansionStates(@entryStates) if @entryStates?
    @isExpanded = true
    false

  collapse: ->
    @entryStates = @serializeEntryExpansionStates()
    @removeClass('expanded').addClass('collapsed')
    @unwatchEntries()
    @entries?.remove()
    @entries = null
    @isExpanded = false

  watchEntries: ->
    @directory.on "contents-changed.tree-view", =>
      @buildEntries()
      @trigger "tree-view:directory-modified"

  unwatchEntries: ->
    @unwatchDescendantEntries()
    @directory.off ".tree-view"

  unwatchDescendantEntries: ->
    @find('.expanded.directory').each ->
      $(this).view().unwatchEntries()

  serializeEntryExpansionStates: ->
    entryStates = {}
    @entries?.find('> .directory.expanded').each ->
      view = $(this).view()
      entryStates[view.directory.getBaseName()] = view.serializeEntryExpansionStates()
    entryStates

  deserializeEntryExpansionStates: (entryStates) ->
    for directoryName, childEntryStates of entryStates
      @entries.find("> .directory:contains('#{directoryName}')").each ->
        view = $(this).view()
        view.entryStates = childEntryStates
        view.expand()

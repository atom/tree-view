{$, $$, Directory, fs, View} = require 'atom'
FileView = require './file-view'

module.exports =
class DirectoryView extends View
  @content: ({directory, isExpanded} = {}) ->
    @li class: "directory entry list-nested-item #{if isExpanded then '' else 'collapsed'}", =>
      @div outlet: 'header', class: 'header list-item', =>
        @span directory.getBaseName(), class: 'name icon', outlet: 'directoryName'

  directory: null
  entries: null
  header: null
  project: null

  initialize: ({@directory, isExpanded, @project, parent} = {}) ->
    @expand() if isExpanded

    if @directory.symlink
      iconClass = 'icon-file-symlink-directory'
    else
      iconClass = 'icon-file-directory'

    repo = project.getRepo()
    if repo?
      path = @directory.getPath()
      if parent
        if repo.isSubmodule(path)
          iconClass = 'icon-file-submodule'
        else
          @subscribe repo, 'status-changed', (path, status) =>
            @updateStatus() if path.indexOf("#{@getPath()}/") is 0
          @subscribe repo, 'statuses-changed', =>
            @updateStatus()
          @updateStatus()
      else
        iconClass = 'icon-repo' if @isRepositoryRoot()

    @directoryName.addClass(iconClass)

  updateStatus: ->
    @removeClass('status-ignored status-modified status-added')
    path = @directory.getPath()
    repo = project.getRepo()
    if repo.isPathIgnored(path)
      @addClass('status-ignored')
    else
      status = repo.getDirectoryStatus(path)
      if repo.isStatusModified(status)
        @addClass('status-modified')
      else if repo.isStatusNew(status)
        @addClass('status-added')

  getPath: ->
    @directory.path

  isRepositoryRoot: ->
    try
      repo = project.getRepo()
      repo? and repo.getWorkingDirectory() is fs.realpathSync(@getPath())
    catch e
      false

  isPathIgnored: (path) ->
    return false unless config.get('tree-view.hideVcsIgnoredFiles')
    repo = project.getRepo()
    repo? and repo.isProjectAtRoot() and repo.isPathIgnored(path)

  buildEntries: ->
    @unwatchDescendantEntries()
    @entries?.remove()
    @entries = $$ -> @ol class: 'entries list-tree'
    for entry in @directory.getEntries()
      continue if @isPathIgnored(entry.path)
      if entry instanceof Directory
        @entries.append(new DirectoryView(directory: entry, isExpanded: false, project: @project, parent: @directory))
      else
        @entries.append(new FileView(file: entry, project: @project))
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
    @entries.remove()
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

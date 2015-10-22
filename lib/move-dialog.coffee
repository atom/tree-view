path = require 'path'
fs = require 'fs-plus'
Dialog = require './dialog'
{repoForPath, lowestCommonAncestor, typeIsArray} = require "./helpers"
_ = require 'underscore-plus'

module.exports =
class MoveDialog extends Dialog
  constructor: (@initialPath) ->
    select = true
    if typeIsArray(@initialPath)
      if @initialPath.length is 1
        @initialPath = @initialPath[0]
      else
        prompt = 'Enter the new path for the files.'
        suggestedPath = lowestCommonAncestor(@initialPath)
        select = false
    suggestedPath ?= @initialPath

    if fs.isDirectorySync(@initialPath)
      prompt ?= 'Enter the new path for the directory.'
    else
      prompt ?= 'Enter the new path for the file.'

    super
      prompt: prompt
      initialPath: atom.project.relativize(suggestedPath)
      select: select
      iconClass: 'icon-arrow-right'

  onConfirm: (newPath) ->
    newPath = newPath.replace(/\s+$/, '') # Remove trailing whitespace
    unless path.isAbsolute(newPath)
      [rootPath] = atom.project.relativizePath(
        if typeIsArray(@initialPath) then @initialPath[0] else @initialPath)
      newPath = path.join(rootPath, newPath)
      return unless newPath

    if not typeIsArray(@initialPath) and @initialPath is newPath
      @close()
      return

    suppliedPaths = if typeIsArray(@initialPath) then @initialPath else [@initialPath]
    filesToMove = {}
    for thePath in suppliedPaths
      destination = if typeIsArray(@initialPath) then path.join(newPath, path.basename(thePath)) else newPath
      unless @isNewPathValid(thePath, destination)
        @showError("'#{destination}' already exists.")
        return
      filesToMove[thePath] = destination

    directoryPath = path.dirname(newPath)
    try
      fs.makeTreeSync(directoryPath) unless fs.existsSync(directoryPath)
      for src, dest of filesToMove
        fs.moveSync(src, dest)
        if repo = repoForPath(dest)
          repo.getPathStatus(src)
          repo.getPathStatus(dest)
      @close()
    catch error
      @showError("#{error.message}.")

  isNewPathValid: (oldPath, newPath) ->
    try
      oldStat = fs.statSync(oldPath)
      newStat = fs.statSync(newPath)

      # New path exists so check if it points to the same file as the initial
      # path to see if the case of the file name is being changed on a on a
      # case insensitive filesystem.
      oldPath.toLowerCase() is newPath.toLowerCase() and
        oldStat.dev is newStat.dev and
        oldStat.ino is newStat.ino
    catch
      true # new path does not exist so it is valid

# this file is lazy loaded by ignored-names-importer
import minimatch from 'minimatch'

export default class IgnoredNames
  constructor: ->
    @ignoredPatterns = []

    ignoredNames = atom.config.get('core.ignoredNames') ? []
    ignoredNames = [ignoredNames] if typeof ignoredNames is 'string'
    for ignoredName in ignoredNames when ignoredName
      try
        @ignoredPatterns.push(new minimatch(ignoredName, matchBase: true, dot: true))
      catch error
        atom.notifications.addWarning("Error parsing ignore pattern (#{ignoredName})", detail: error.message)

  matches: (filePath) ->
    for ignoredPattern in @ignoredPatterns
      return true if ignoredPattern.match(filePath)

    return false

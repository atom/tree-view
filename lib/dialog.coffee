{$, EditorView, View} = require 'atom'
path = require 'path'

module.exports =
class Dialog extends View
  @content: ({prompt} = {}) ->
    @div class: 'tree-view-dialog overlay from-top', =>
      @label prompt, class: 'icon', outlet: 'promptText'
      @subview 'miniEditor', new EditorView(mini: true)
      @div class: 'error-message', outlet: 'errorMessage'

  initialize: ({initialPath, select, iconClass} = {}) ->
    @promptText.addClass(iconClass) if iconClass
    @on 'core:confirm', => @onConfirm(@miniEditor.getText())
    @on 'core:cancel', => @cancel()
    @miniEditor.hiddenInput.on 'focusout', => @remove()
    @miniEditor.getEditor().getBuffer().on 'changed', => @showError()

    @miniEditor.setText(initialPath)

    if select
      extension = path.extname(initialPath)
      baseName = path.basename(initialPath)
      if baseName is extension
        selectionEnd = initialPath.length
      else
        selectionEnd = initialPath.length - extension.length
      range = [[0, initialPath.length - baseName.length], [0, selectionEnd]]
      @miniEditor.getEditor().setSelectedBufferRange(range)

  attach: ->
    atom.workspaceView.append(this)
    @miniEditor.focus()

  close: ->
    @remove()
    atom.workspaceView.focus()

  cancel: ->
    @remove()
    $('.tree-view').focus()

  showError: (message='') ->
    @errorMessage.text(message)
    @flashError() if message

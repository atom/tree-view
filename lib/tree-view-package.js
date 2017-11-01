const {Disposable, CompositeDisposable} = require('atom')
const path = require('path')

const IconServices = require('./icon-services')
const TreeView = require('./tree-view')

module.exports =
class TreeViewPackage {
  activate () {
    this.disposables = new CompositeDisposable()
    this.disposables.add(atom.commands.add('atom-workspace', {
      'tree-view:show': () => this.getTreeViewInstance().show(),
      'tree-view:toggle': () => this.getTreeViewInstance().toggle(),
      'tree-view:toggle-focus': () => this.getTreeViewInstance().toggleFocus(),
      'tree-view:reveal-active-file': () => this.getTreeViewInstance().revealActiveFile(),
      'tree-view:add-file': () => this.getTreeViewInstance().add(true),
      'tree-view:add-folder': () => this.getTreeViewInstance().add(false),
      'tree-view:duplicate': () => this.getTreeViewInstance().copySelectedEntry(),
      'tree-view:remove': () => this.getTreeViewInstance().removeSelectedEntries(),
      'tree-view:rename': () => this.getTreeViewInstance().moveSelectedEntry(),
      'tree-view:show-current-file-in-file-manager': () => this.getTreeViewInstance().showCurrentFileInFileManager()
    }))

    this.disposables.add(atom.project.onDidChangePaths(this.createOrDestroyTreeViewIfNeeded.bind(this)))

    if (this.shouldAttachTreeView()) {
      const treeView = this.getTreeViewInstance()
      const showOnAttach = !atom.workspace.getActivePaneItem()
      this.treeViewOpenPromise = atom.workspace.open(treeView, {
        activatePane: showOnAttach,
        activateItem: showOnAttach
      })
    } else {
      this.treeViewOpenPromise = Promise.resolve()
    }
  }

  deactivate () {
    this.disposables.dispose()
    if (this.treeView) this.treeView.destroy()
    this.treeView = null
  }

  consumeElementIcons (service) {
    IconServices.setElementIcons(service)
    return new Disposable(() => {
      IconServices.resetElementIcons()
    })
  }

  consumeFileIcons (service) {
    IconServices.setFileIcons(service)
    if (this.treeView) this.treeView.updateRoots()
    return new Disposable(() => {
      IconServices.resetFileIcons()
      if (this.treeView) this.treeView.updateRoots()
    })
  }

  provideTreeView () {
    return {
      selectedPaths: () => this.getTreeViewInstance().selectedPaths(),
      entryForPath: (entryPath) => this.getTreeViewInstance().entryForPath(entryPath)
    };
  }

  getTreeViewInstance (state = {}) {
    if (this.treeView == null) {
      this.treeView = new TreeView(state)
      this.treeView.onDidDestroy(() => this.treeView = null)
    }
    return this.treeView
  }

  createOrDestroyTreeViewIfNeeded () {
    if (this.shouldAttachTreeView()) {
      const treeView = this.getTreeViewInstance()
      const paneContainer = atom.workspace.paneContainerForURI(treeView.getURI())
      if (paneContainer) {
        paneContainer.show()
      } else {
        atom.workspace.open(treeView, {
          activatePane: false,
          activateItem: false
        }).then(() => {
          const paneContainer = atom.workspace.paneContainerForURI(treeView.getURI())
          if (paneContainer) paneContainer.show()
        })
      }
    } else {
      if (this.treeView) {
        const pane = atom.workspace.paneForItem(this.treeView)
        if (pane) pane.removeItem(this.treeView)
      }
    }
  }

  shouldAttachTreeView () {
    if (atom.project.getPaths().length === 0) return false

    // Avoid opening the tree view if Atom was opened as the Git editor...
    // Only show it if the .git folder was explicitly opened.
    if (path.basename(atom.project.getPaths()[0]) === '.git') {
      return atom.project.getPaths()[0] === atom.getLoadSettings().pathToOpen
    }

    return true
  }

  shouldShowTreeViewAfterAttaching () {
    if (atom.workspace.getActivePaneItem()) return false
  }
}

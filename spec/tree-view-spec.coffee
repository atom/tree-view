_ = require 'underscore-plus'
{$, $$} = require 'atom-space-pen-views'
fs = require 'fs-plus'
path = require 'path'
temp = require('temp').track()
os = require 'os'

waitsForFileToOpen = (causeFileToOpen) ->
  waitsFor (done) ->
    disposable = atom.workspace.onDidOpen ->
      disposable.dispose()
      done()
    causeFileToOpen()

describe "TreeView", ->
  [treeView, root, sampleJs, sampleTxt, workspaceElement] = []

  beforeEach ->
    fixturesPath = atom.project.getPaths()[0]
    atom.project.setPaths([path.join(fixturesPath, "tree-view")])

    workspaceElement = atom.views.getView(atom.workspace)

    waitsForPromise ->
      atom.packages.activatePackage("tree-view")

    runs ->
      atom.commands.dispatch(workspaceElement, 'tree-view:toggle')
      treeView = $(atom.workspace.getLeftPanels()[0].getItem()).view()

      root = $(treeView.root)
      sampleJs = treeView.find('.file:contains(tree-view.js)')
      sampleTxt = treeView.find('.file:contains(tree-view.txt)')

      expect(treeView.root.directory.watchSubscription).toBeTruthy()

  afterEach ->
    temp.cleanup()

  describe ".initialize(project)", ->
    it "renders the root of the project and its contents alphabetically with subdirectories first in a collapsed state", ->
      expect(root.find('> .header .disclosure-arrow')).not.toHaveClass('expanded')
      expect(root.find('> .header .name')).toHaveText('tree-view')

      rootEntries = root.find('.entries')
      subdir0 = rootEntries.find('> li:eq(0)')
      expect(subdir0).not.toHaveClass('expanded')
      expect(subdir0.find('.name')).toHaveText('dir1')

      subdir2 = rootEntries.find('> li:eq(1)')
      expect(subdir2).not.toHaveClass('expanded')
      expect(subdir2.find('.name')).toHaveText('dir2')

      expect(subdir0.find('[data-name="dir1"]')).toExist()
      expect(subdir2.find('[data-name="dir2"]')).toExist()

      expect(rootEntries.find('> .file:contains(tree-view.js)')).toExist()
      expect(rootEntries.find('> .file:contains(tree-view.txt)')).toExist()

      expect(rootEntries.find('> .file [data-name="tree-view.js"]')).toExist()
      expect(rootEntries.find('> .file [data-name="tree-view.txt"]')).toExist()

    it "selects the root folder", ->
      expect(treeView.selectedEntry()).toEqual treeView.root

    describe "when the project has no path", ->
      beforeEach ->
        atom.project.setPaths([])
        atom.packages.deactivatePackage("tree-view")

        waitsForPromise ->
          atom.packages.activatePackage("tree-view")

        runs ->
          treeView = atom.packages.getActivePackage("tree-view").mainModule.createView()

      it "does not attach to the root view or create a root node when initialized", ->
        expect(treeView.hasParent()).toBeFalsy()
        expect(treeView.root).not.toExist()

      it "does not attach to the root view or create a root node when attach() is called", ->
        treeView.attach()
        expect(treeView.hasParent()).toBeFalsy()
        expect(treeView.root).not.toExist()

      it "serializes without throwing an exception", ->
        expect(-> treeView.serialize()).not.toThrow()

      it "does not throw an exception when files are opened", ->
        filePath = path.join(os.tmpdir(), 'non-project-file.txt')
        fs.writeFileSync(filePath, 'test')

        waitsForPromise ->
          atom.workspace.open(filePath)

      it "does not reveal the active file", ->
        filePath = path.join(os.tmpdir(), 'non-project-file.txt')
        fs.writeFileSync(filePath, 'test')

        waitsForPromise ->
          atom.workspace.open(filePath)

        runs ->
          atom.commands.dispatch(workspaceElement, 'tree-view:reveal-active-file')
          expect(treeView.hasParent()).toBeFalsy()
          expect(treeView.root).not.toExist()

      describe "when the project is assigned a path because a new buffer is saved", ->
        it "creates a root directory view and attaches to the root view", ->
          waitsForPromise ->
            atom.workspace.open()

          runs ->
            projectPath = temp.mkdirSync('atom-project')
            atom.workspace.getActivePaneItem().saveAs(path.join(projectPath, 'test.txt'))
            expect(treeView.hasParent()).toBeTruthy()
            expect(fs.absolute(treeView.root.getPath())).toBe fs.absolute(projectPath)
            expect($(treeView.root).parent()).toMatchSelector(".tree-view")

    describe "when the root view is opened to a file path", ->
      it "does not attach to the root view but does create a root node when initialized", ->
        atom.packages.deactivatePackage("tree-view")
        atom.packages.packageStates = {}

        waitsForPromise ->
          atom.workspace.open('tree-view.js')

        waitsForPromise ->
          atom.packages.activatePackage('tree-view')

        runs ->
          treeView = atom.packages.getActivePackage("tree-view").mainModule.createView()
          expect(treeView.hasParent()).toBeFalsy()
          expect(treeView.root).toBeTruthy()

    describe "when the root view is opened to a directory", ->
      it "attaches to the root view", ->
        waitsForPromise ->
          atom.packages.activatePackage('tree-view')

        runs ->
          treeView = atom.packages.getActivePackage("tree-view").mainModule.createView()
          expect(treeView.hasParent()).toBeTruthy()
          expect(treeView.root).toBeTruthy()

    describe "when the project is a .git folder", ->
      it "does not create the tree view", ->
        dotGit = path.join(temp.mkdirSync('repo'), '.git')
        fs.makeTreeSync(dotGit)
        atom.project.setPaths([dotGit])
        atom.packages.deactivatePackage("tree-view")
        atom.packages.packageStates = {}

        waitsForPromise ->
          atom.packages.activatePackage('tree-view')

        runs ->
          {treeView} = atom.packages.getActivePackage("tree-view").mainModule
          expect(treeView).toBeFalsy()

  describe "serialization", ->
    it "restores the attached/detached state of the tree-view", ->
      jasmine.attachToDOM(workspaceElement)
      atom.commands.dispatch(workspaceElement, 'tree-view:toggle')
      expect(atom.workspace.getLeftPanels().length).toBe(0)

      atom.packages.deactivatePackage("tree-view")

      waitsForPromise ->
        atom.packages.activatePackage("tree-view")

      runs ->
        expect(atom.workspace.getLeftPanels().length).toBe(0)

    it "restores expanded directories and selected file when deserialized", ->
      root.find('.directory:contains(dir1)').click()

      waitsForFileToOpen ->
        sampleJs.click()

      runs ->
        atom.packages.deactivatePackage("tree-view")

      waitsForPromise ->
        atom.packages.activatePackage("tree-view")

      runs ->
        treeView = $(atom.workspace.getLeftPanels()[0].getItem()).view()
        expect(treeView).toExist()
        expect(treeView.selectedEntry()).toMatchSelector(".file:contains(tree-view.js)")
        expect(treeView.find(".directory:contains(dir1)")).toHaveClass("expanded")

    it "restores the focus state of the tree view", ->
      jasmine.attachToDOM(workspaceElement)
      treeView.focus()
      expect(treeView.list).toMatchSelector ':focus'
      atom.packages.deactivatePackage("tree-view")

      waitsForPromise ->
        atom.packages.activatePackage("tree-view")

      runs ->
        treeView = $(atom.workspace.getLeftPanels()[0].getItem()).view()
        expect(treeView.list).toMatchSelector ':focus'

    it "restores the scroll top when toggled", ->
      workspaceElement.style.height = '5px'
      jasmine.attachToDOM(workspaceElement)
      expect(treeView).toBeVisible()
      treeView.focus()

      treeView.scrollTop(10)
      expect(treeView.scrollTop()).toBe(10)

      runs -> atom.commands.dispatch(workspaceElement, 'tree-view:toggle')
      waitsFor -> treeView.is(':hidden')

      runs -> atom.commands.dispatch(workspaceElement, 'tree-view:toggle')
      waitsFor -> treeView.is(':visible')

      runs -> expect(treeView.scrollTop()).toBe(10)

    it "restores the scroll left when toggled", ->
      treeView.width(5)
      jasmine.attachToDOM(workspaceElement)
      expect(treeView).toBeVisible()
      treeView.focus()

      treeView.scroller.scrollLeft(5)
      expect(treeView.scroller.scrollLeft()).toBe(5)

      runs -> atom.commands.dispatch(workspaceElement, 'tree-view:toggle')
      waitsFor -> treeView.is(':hidden')

      runs -> atom.commands.dispatch(workspaceElement, 'tree-view:toggle')
      waitsFor -> treeView.is(':visible')

      runs -> expect(treeView.scroller.scrollLeft()).toBe(5)

  describe "when tree-view:toggle is triggered on the root view", ->
    beforeEach ->
      jasmine.attachToDOM(workspaceElement)

    describe "when the tree view is visible", ->
      beforeEach ->
        expect(treeView).toBeVisible()

      describe "when the tree view is focused", ->
        it "hides the tree view", ->
          treeView.focus()
          atom.commands.dispatch(workspaceElement, 'tree-view:toggle')
          expect(treeView).toBeHidden()

      describe "when the tree view is not focused", ->
        it "hides the tree view", ->
          $(workspaceElement).focus()
          atom.commands.dispatch(workspaceElement, 'tree-view:toggle')
          expect(treeView).toBeHidden()

    describe "when the tree view is hidden", ->
      it "shows and focuses the tree view", ->
        treeView.detach()
        atom.commands.dispatch(workspaceElement, 'tree-view:toggle')
        expect(treeView.hasParent()).toBeTruthy()
        expect(treeView.list).toMatchSelector(':focus')

    describe "when tree-view:toggle-side is triggered on the root view", ->
      describe "when the tree view is on the left", ->
        it "moves the tree view to the right", ->
          expect(treeView).toBeVisible()
          atom.commands.dispatch(workspaceElement, 'tree-view:toggle-side')
          expect(treeView).toMatchSelector('[data-show-on-right-side="true"]')

      describe "when the tree view is on the right", ->
        beforeEach ->
          atom.commands.dispatch(workspaceElement, 'tree-view:toggle-side')

        it "moves the tree view to the left", ->
          expect(treeView).toBeVisible()
          atom.commands.dispatch(workspaceElement, 'tree-view:toggle-side')
          expect(treeView).toMatchSelector('[data-show-on-right-side="false"]')

      describe "when the tree view is hidden", ->
        it "shows the tree view on the other side next time it is opened", ->
          atom.commands.dispatch(workspaceElement, 'tree-view:toggle')
          atom.commands.dispatch(workspaceElement, 'tree-view:toggle-side')
          atom.commands.dispatch(workspaceElement, 'tree-view:toggle')
          expect(atom.workspace.getLeftPanels().length).toBe 0
          treeView = $(atom.workspace.getRightPanels()[0].getItem()).view()
          expect(treeView).toMatchSelector('[data-show-on-right-side="true"]')

  describe "when tree-view:toggle-focus is triggered on the root view", ->
    beforeEach ->
      jasmine.attachToDOM(workspaceElement)

    describe "when the tree view is hidden", ->
      it "shows and focuses the tree view", ->
        treeView.detach()
        atom.commands.dispatch(workspaceElement, 'tree-view:toggle-focus')
        expect(treeView.hasParent()).toBeTruthy()
        expect(treeView.list).toMatchSelector(':focus')

    describe "when the tree view is shown", ->
      it "focuses the tree view", ->
        waitsForPromise ->
          atom.workspace.open() # When we call focus below, we want an editor to become focused

        runs ->
          $(workspaceElement).focus()
          expect(treeView).toBeVisible()
          atom.commands.dispatch(workspaceElement, 'tree-view:toggle-focus')
          expect(treeView).toBeVisible()
          expect(treeView.list).toMatchSelector(':focus')

      describe "when the tree view is focused", ->
        it "unfocuses the tree view", ->
          waitsForPromise ->
            atom.workspace.open() # When we call focus below, we want an editor to become focused

          runs ->
            treeView.focus()
            expect(treeView).toBeVisible()
            atom.commands.dispatch(workspaceElement, 'tree-view:toggle-focus')
            expect(treeView).toBeVisible()
            expect(treeView.list).not.toMatchSelector(':focus')

  describe "when tree-view:reveal-current-file is triggered on the root view", ->
    beforeEach ->
      treeView.detach()
      spyOn(treeView, 'focus')

    describe "if the current file has a path", ->
      it "shows and focuses the tree view and selects the file", ->
        waitsForPromise ->
          atom.workspace.open(path.join('dir1', 'file1'))

        runs ->
          atom.commands.dispatch(workspaceElement, 'tree-view:reveal-active-file')
          expect(treeView.hasParent()).toBeTruthy()
          expect(treeView.focus).toHaveBeenCalled()
          expect(treeView.selectedEntry().getPath()).toMatch new RegExp("dir1#{_.escapeRegExp(path.sep)}file1$")

    describe "if the current file has no path", ->
      it "shows and focuses the tree view, but does not attempt to select a specific file", ->
        waitsForPromise ->
          atom.workspace.open()

        runs ->
          expect(atom.workspace.getActivePaneItem().getPath()).toBeUndefined()
          atom.commands.dispatch(workspaceElement, 'tree-view:reveal-active-file')
          expect(treeView.hasParent()).toBeTruthy()
          expect(treeView.focus).toHaveBeenCalled()

    describe "if there is no editor open", ->
      it "shows and focuses the tree view, but does not attempt to select a specific file", ->
        expect(atom.workspace.getActivePaneItem()).toBeUndefined()
        atom.commands.dispatch(workspaceElement, 'tree-view:reveal-active-file')
        expect(treeView.hasParent()).toBeTruthy()
        expect(treeView.focus).toHaveBeenCalled()

  describe "when tool-panel:unfocus is triggered on the tree view", ->
    it "surrenders focus to the root view but remains open", ->
      waitsForPromise ->
        atom.workspace.open() # When we trigger 'tool-panel:unfocus' below, we want an editor to become focused

      runs ->
        jasmine.attachToDOM(workspaceElement)
        treeView.focus()
        expect(treeView.list).toMatchSelector(':focus')
        atom.commands.dispatch(treeView.element, 'tool-panel:unfocus')
        expect(treeView).toBeVisible()
        expect(treeView.list).not.toMatchSelector(':focus')
        expect(atom.workspace.getActivePane().isActive()).toBe(true)

  describe "copy path commands", ->
    [pathToSelect, relativizedPath] = []

    beforeEach ->
      pathToSelect = path.join(treeView.root.directory.path, 'dir1', 'file1')
      relativizedPath = atom.project.relativize(pathToSelect)
      spyOn(atom.clipboard, 'write')

    describe "when tree-view:copy-full-path is triggered on the tree view", ->
      it "copies the selected path to the clipboard", ->
        treeView.selectedPath = pathToSelect
        atom.commands.dispatch(treeView.element, 'tree-view:copy-full-path')
        expect(atom.clipboard.write).toHaveBeenCalledWith(pathToSelect)

      describe "when there is no selected path", ->
        beforeEach ->
          treeView.selectedPath = null

        it "does nothing", ->
          atom.commands.dispatch(treeView.element, 'tree-view:copy-full-path')
          expect(atom.clipboard.write).not.toHaveBeenCalled()

    describe "when tree-view:copy-project-path is triggered on the tree view", ->
      it "copies the relativized selected path to the clipboard", ->
        treeView.selectedPath = pathToSelect
        atom.commands.dispatch(treeView.element, 'tree-view:copy-project-path')
        expect(atom.clipboard.write).toHaveBeenCalledWith(relativizedPath)

      describe "when there is no selected path", ->
        beforeEach ->
          treeView.selectedPath = null

        it "does nothing", ->
          atom.commands.dispatch(treeView.element, 'tree-view:copy-project-path')
          expect(atom.clipboard.write).not.toHaveBeenCalled()

  describe "when a directory's disclosure arrow is clicked", ->
    it "expands / collapses the associated directory", ->
      subdir = root.find('.entries > li:contains(dir1)')

      expect(subdir).not.toHaveClass('expanded')

      subdir.click()

      expect(subdir).toHaveClass('expanded')

      subdir.click()
      expect(subdir).not.toHaveClass('expanded')

    it "restores the expansion state of descendant directories", ->
      child = root.find('.entries > li:contains(dir1)')
      child.click()

      grandchild = child.find('.entries > li:contains(sub-dir1)')
      grandchild.click()

      root.click()
      expect(treeView.root).not.toHaveClass('expanded')
      root.click()

      # previously expanded descendants remain expanded
      expect(root.find('> .entries > li:contains(dir1) > .entries > li:contains(sub-dir1) > .entries').length).toBe 1

      # collapsed descendants remain collapsed
      expect(root.find('> .entries > li:contains(dir2) > .entries')).not.toHaveClass('expanded')

    it "when collapsing a directory, removes change subscriptions from the collapsed directory and its descendants", ->
      child = root.find('li:contains(dir1)')
      child.click()

      grandchild = child.find('li:contains(sub-dir1)')
      grandchild.click()

      expect(treeView.root.directory.watchSubscription).toBeTruthy()
      expect(child[0].directory.watchSubscription).toBeTruthy()
      expect(grandchild[0].directory.watchSubscription).toBeTruthy()

      root.click()

      expect(treeView.root.directory.watchSubscription).toBeFalsy()
      expect(child[0].directory.watchSubscription).toBeFalsy()
      expect(grandchild[0].directory.watchSubscription).toBeFalsy()

  describe "when mouse down fires on a file or directory", ->
    it "selects the entry", ->
      dir = root.find('li:contains(dir1)')
      expect(dir).not.toHaveClass 'selected'
      dir.mousedown()
      expect(dir).toHaveClass 'selected'

      expect(sampleJs).not.toHaveClass 'selected'
      sampleJs.mousedown()
      expect(sampleJs).toHaveClass 'selected'

  describe "when a file is single-clicked", ->
    beforeEach ->
      jasmine.attachToDOM(workspaceElement)

    it "selects the files and opens it in the active editor, without changing focus", ->
      treeView.focus()

      waitsForFileToOpen ->
        sampleJs.trigger clickEvent(originalEvent: { detail: 1 })

      runs ->
        expect(sampleJs).toHaveClass 'selected'
        expect(atom.workspace.getActivePaneItem().getPath()).toBe atom.project.resolve('tree-view.js')
        expect(treeView.list).toHaveFocus()

      waitsForFileToOpen ->
        sampleTxt.trigger clickEvent(originalEvent: { detail: 1 })

      runs ->
        expect(sampleTxt).toHaveClass 'selected'
        expect(treeView.find('.selected').length).toBe 1
        expect(atom.workspace.getActivePaneItem().getPath()).toBe atom.project.resolve('tree-view.txt')
        expect(treeView.list).toHaveFocus()

  describe "when a file is double-clicked", ->
    beforeEach ->
      jasmine.attachToDOM(workspaceElement)

    it "selects the file and opens it in the active editor on the first click, then changes focus to the active editor on the second", ->
      treeView.focus()

      waitsForFileToOpen ->
        sampleJs.trigger clickEvent(originalEvent: { detail: 1 })

      runs ->
        expect(sampleJs).toHaveClass 'selected'
        item = atom.workspace.getActivePaneItem()
        expect(item.getPath()).toBe atom.project.resolve('tree-view.js')

        sampleJs.trigger clickEvent(originalEvent: { detail: 2 })
        expect(atom.views.getView(item)).toHaveFocus()

  describe "when a directory is single-clicked", ->
    it "is selected", ->
      subdir = root.find('.directory:first')
      subdir.trigger clickEvent(originalEvent: { detail: 1 })
      expect(subdir).toHaveClass 'selected'

  describe "when a directory is double-clicked", ->
    it "toggles the directory expansion state and does not change the focus to the editor", ->
      jasmine.attachToDOM(workspaceElement)
      treeView.focus()

      subdir = null
      waitsForFileToOpen ->
        sampleJs.trigger clickEvent(originalEvent: { detail: 1 })

      runs ->
        subdir = root.find('.directory:first')
        subdir.trigger clickEvent(originalEvent: { detail: 1 })
        expect(subdir).toHaveClass 'selected'
        expect(subdir).toHaveClass 'expanded'
        subdir.trigger clickEvent(originalEvent: { detail: 2 })
        expect(subdir).toHaveClass 'selected'
        expect(subdir).not.toHaveClass 'expanded'
        expect(treeView).toHaveFocus()

  describe "when an directory is alt-clicked", ->
    describe "when the directory is collapsed", ->
      it "recursively expands the directory", ->
        root.click()
        treeView.root.collapse()

        expect(treeView.root).not.toHaveClass 'expanded'
        root.trigger clickEvent({ altKey: true })
        expect(treeView.root).toHaveClass 'expanded'

        children = root.find('.directory')
        expect(children.length).toBeGreaterThan 0
        children.each (index, child) -> expect(child).toHaveClass 'expanded'

    describe "when the directory is expanded", ->
      parent    = null
      children  = null

      beforeEach ->
        parent = root.find('> .entries > .directory').eq(2)
        parent[0].expand()
        children = parent.find('.expanded.directory')
        children.each (index, child) ->
          child.expand()

      it "recursively collapses the directory", ->
        parent.click()
        parent[0].expand()
        expect(parent).toHaveClass 'expanded'
        children.each (index, child) ->
          $(child).click().expand()
          expect($(child)).toHaveClass 'expanded'

        parent.trigger clickEvent({ altKey: true })

        expect(parent).not.toHaveClass 'expanded'
        children.each (index, child) ->
          expect(child).not.toHaveClass 'expanded'
        expect(treeView.root).toHaveClass 'expanded'

  describe "when the active item changes on the active pane", ->
    describe "when the item has a path", ->
      it "selects the entry with that path in the tree view if it is visible", ->
        waitsForFileToOpen ->
          sampleJs.click()

        waitsForPromise ->
          atom.workspace.open(atom.project.resolve('tree-view.txt'))

        runs ->
          expect(sampleTxt).toHaveClass 'selected'
          expect(treeView.find('.selected').length).toBe 1

      it "selects the path's parent dir if its entry is not visible", ->
        waitsForPromise ->
          atom.workspace.open(path.join('dir1', 'sub-dir1', 'sub-file1'))

        runs ->
          dirView = root.find('.directory:contains(dir1)')
          expect(dirView).toHaveClass 'selected'

    describe "when the item has no path", ->
      it "deselects the previously selected entry", ->
        waitsForFileToOpen ->
          sampleJs.click()

        runs ->
          atom.workspace.getActivePane().activateItem(document.createElement("div"))
          expect(treeView.find('.selected')).not.toExist()

  describe "when a different editor becomes active", ->
    beforeEach ->
      jasmine.attachToDOM(workspaceElement)

    it "selects the file in that is open in that editor", ->
      leftEditorPane = null

      waitsForFileToOpen ->
        sampleJs.click()

      runs ->
        leftEditorPane = atom.workspace.getActivePane()
        leftEditorPane.splitRight()

      waitsForFileToOpen ->
        sampleTxt.click()

      runs ->
        expect(sampleTxt).toHaveClass('selected')
        leftEditorPane.activate()
        expect(sampleJs).toHaveClass('selected')

  describe "keyboard navigation", ->
    afterEach ->
      expect(treeView.find('.selected').length).toBeLessThan 2

    describe "core:move-down", ->
      describe "when a collapsed directory is selected", ->
        it "skips to the next directory", ->
          root.find('.directory:eq(0)').click()

          atom.commands.dispatch(treeView.element, 'core:move-down')
          expect(root.find('.directory:eq(1)')).toHaveClass 'selected'

      describe "when an expanded directory is selected", ->
        it "selects the first entry of the directory", ->
          subdir = root.find('.directory:eq(1)')
          subdir.click()

          atom.commands.dispatch(treeView.element, 'core:move-down')

          expect($(subdir[0].entries).find('.entry:first')).toHaveClass 'selected'

      describe "when the last entry of an expanded directory is selected", ->
        it "selects the entry after its parent directory", ->
          subdir1 = root.find('.directory:eq(1)')
          subdir1[0].expand()
          waitsForFileToOpen ->
            $(subdir1[0].entries).find('.entry:last').click()

          runs ->
            atom.commands.dispatch(treeView.element, 'core:move-down')
            expect(root.find('.directory:eq(2)')).toHaveClass 'selected'

      describe "when the last directory of another last directory is selected", ->
        [nested, nested2] = []

        beforeEach ->
          nested = root.find('.directory:eq(2)')
          expect(nested.find('.header').text()).toContain 'nested'
          nested[0].expand()
          nested2 = $(nested[0].entries).find('.entry:last')
          nested2.click()
          nested2[0].collapse()

        describe "when the directory is collapsed", ->
          it "selects the entry after its grandparent directory", ->
            atom.commands.dispatch(treeView.element, 'core:move-down')
            expect(nested.next()).toHaveClass 'selected'

        describe "when the directory is expanded", ->
          it "selects the entry after its grandparent directory", ->
            nested2[0].expand()
            nested2.find('.file').remove() # kill the .gitkeep file, which has to be there but screws the test
            atom.commands.dispatch(treeView.element, 'core:move-down')
            expect(nested.next()).toHaveClass 'selected'

      describe "when the last entry of the last directory is selected", ->
        it "does not change the selection", ->
          lastEntry = root.find('> .entries .entry:last')
          waitsForFileToOpen ->
            lastEntry.click()

          runs ->
            atom.commands.dispatch(treeView.element, 'core:move-down')
            expect(lastEntry).toHaveClass 'selected'

    describe "core:move-up", ->
      describe "when there is an expanded directory before the currently selected entry", ->
        it "selects the last entry in the expanded directory", ->
          lastDir = root.find('.directory:last')
          fileAfterDir = lastDir.next()
          lastDir[0].expand()
          waitsForFileToOpen ->
            fileAfterDir.click()

          runs ->
            atom.commands.dispatch(treeView.element, 'core:move-up')
            expect(lastDir.find('.entry:last')).toHaveClass 'selected'

      describe "when there is an entry before the currently selected entry", ->
        it "selects the previous entry", ->
          lastEntry = root.find('.entry:last')
          waitsForFileToOpen ->
            lastEntry.click()

          runs ->
            atom.commands.dispatch(treeView.element, 'core:move-up')
            expect(lastEntry.prev()).toHaveClass 'selected'

      describe "when there is no entry before the currently selected entry, but there is a parent directory", ->
        it "selects the parent directory", ->
          subdir = root.find('.directory:first')
          subdir[0].expand()
          subdir.find('> .entries > .entry:first').click()

          atom.commands.dispatch(treeView.element, 'core:move-up')

          expect(subdir).toHaveClass 'selected'

      describe "when there is no parent directory or previous entry", ->
        it "does not change the selection", ->
          root.click()
          atom.commands.dispatch(treeView.element, 'core:move-up')
          expect(treeView.root).toHaveClass 'selected'

    describe "core:move-to-top", ->
      it "scrolls to the top", ->
        treeView.height(100)
        jasmine.attachToDOM(treeView.element)
        element.expand() for element in treeView.find('.directory')
        expect(treeView.list.outerHeight()).toBeGreaterThan treeView.scroller.outerHeight()

        expect(treeView.scrollTop()).toBe 0

        entryCount = treeView.find(".entry").length
        _.times entryCount, -> atom.commands.dispatch(treeView.element, 'core:move-down')
        expect(treeView.scrollTop()).toBeGreaterThan 0

        atom.commands.dispatch(treeView.element, 'core:move-to-top')
        expect(treeView.scrollTop()).toBe 0

      it "selects the root entry", ->
        entryCount = treeView.find(".entry").length
        _.times entryCount, -> atom.commands.dispatch(treeView.element, 'core:move-down')

        expect(treeView.root).not.toHaveClass 'selected'
        atom.commands.dispatch(treeView.element, 'core:move-to-top')
        expect(treeView.root).toHaveClass 'selected'

    describe "core:move-to-bottom", ->
      it "scrolls to the bottom", ->
        treeView.height(100)
        jasmine.attachToDOM(treeView.element)
        element.expand() for element in treeView.find('.directory')
        expect(treeView.list.outerHeight()).toBeGreaterThan treeView.scroller.outerHeight()

        expect(treeView.scrollTop()).toBe 0
        atom.commands.dispatch(treeView.element, 'core:move-to-bottom')
        expect(treeView.scrollBottom()).toBe root.outerHeight()

        treeView.root.collapse()
        atom.commands.dispatch(treeView.element, 'core:move-to-bottom')
        expect(treeView.scrollTop()).toBe 0

      it "selects the last entry", ->
        expect(treeView.root).toHaveClass 'selected'
        atom.commands.dispatch(treeView.element, 'core:move-to-bottom')
        expect(root.find('.entry:last')).toHaveClass 'selected'

    describe "core:page-up", ->
      it "scrolls up a page", ->
        treeView.height(5)
        jasmine.attachToDOM(treeView.element)
        element.expand() for element in treeView.find('.directory')
        expect(treeView.list.outerHeight()).toBeGreaterThan treeView.scroller.outerHeight()

        expect(treeView.scrollTop()).toBe 0
        treeView.scrollToBottom()
        scrollTop = treeView.scrollTop()
        expect(scrollTop).toBeGreaterThan 0

        atom.commands.dispatch(treeView.element, 'core:page-up')
        expect(treeView.scrollTop()).toBe scrollTop - treeView.height()

    describe "core:page-down", ->
      it "scrolls down a page", ->
        treeView.height(5)
        jasmine.attachToDOM(treeView.element)
        element.expand() for element in treeView.find('.directory')
        expect(treeView.list.outerHeight()).toBeGreaterThan treeView.scroller.outerHeight()

        expect(treeView.scrollTop()).toBe 0
        atom.commands.dispatch(treeView.element, 'core:page-down')
        expect(treeView.scrollTop()).toBe treeView.height()

    describe "movement outside of viewable region", ->
      it "scrolls the tree view to the selected item", ->
        treeView.height(100)
        jasmine.attachToDOM(treeView.element)
        element.expand() for element in treeView.find('.directory')
        expect(treeView.list.outerHeight()).toBeGreaterThan treeView.scroller.outerHeight()

        atom.commands.dispatch(treeView.element, 'core:move-down')
        expect(treeView.scrollTop()).toBe 0

        entryCount = treeView.find(".entry").length
        entryHeight = treeView.find('.file').height()

        _.times entryCount, -> atom.commands.dispatch(treeView.element, 'core:move-down')
        expect(treeView.scrollBottom()).toBeGreaterThan (entryCount * entryHeight) - 1

        _.times entryCount, -> atom.commands.dispatch(treeView.element, 'core:move-up')
        expect(treeView.scrollTop()).toBe 0

    describe "tree-view:expand-directory", ->
      describe "when a directory entry is selected", ->
        it "expands the current directory", ->
          subdir = root.find('.directory:first')
          subdir.click()
          subdir[0].collapse()

          expect(subdir).not.toHaveClass 'expanded'
          atom.commands.dispatch(treeView.element, 'tree-view:expand-directory')
          expect(subdir).toHaveClass 'expanded'

      describe "when a file entry is selected", ->
        it "does nothing", ->
          waitsForFileToOpen ->
            root.find('.file').click()

          runs ->
            atom.commands.dispatch(treeView.element, 'tree-view:expand-directory')

    describe "tree-view:recursive-expand-directory", ->
      describe "when an collapsed root is recursively expanded", ->
        it "expands the root and all subdirectories", ->
          root.click()
          treeView.root.collapse()

          expect(treeView.root).not.toHaveClass 'expanded'
          atom.commands.dispatch(treeView.element, 'tree-view:recursive-expand-directory')
          expect(treeView.root).toHaveClass 'expanded'

          children = root.find('.directory')
          expect(children.length).toBeGreaterThan 0
          children.each (index, child) ->
            expect(child).toHaveClass 'expanded'

    describe "tree-view:collapse-directory", ->
      subdir = null

      beforeEach ->
        subdir = root.find('> .entries > .directory').eq(0)
        subdir[0].expand()

      describe "when an expanded directory is selected", ->
        it "collapses the selected directory", ->
          subdir.click()
          subdir[0].expand()
          expect(subdir).toHaveClass 'expanded'

          atom.commands.dispatch(treeView.element, 'tree-view:collapse-directory')

          expect(subdir).not.toHaveClass 'expanded'
          expect(treeView.root).toHaveClass 'expanded'

      describe "when a collapsed directory is selected", ->
        it "collapses and selects the selected directory's parent directory", ->
          directories = subdir.find('.directory')
          directories.click()
          directories[0].collapse()
          atom.commands.dispatch(treeView.element, 'tree-view:collapse-directory')

          expect(subdir).not.toHaveClass 'expanded'
          expect(subdir).toHaveClass 'selected'
          expect(treeView.root).toHaveClass 'expanded'

      describe "when collapsed root directory is selected", ->
        it "does not raise an error", ->
          treeView.root.collapse()
          treeView.selectEntry(treeView.root)

          atom.commands.dispatch(treeView.element, 'tree-view:collapse-directory')

      describe "when a file is selected", ->
        it "collapses and selects the selected file's parent directory", ->
          waitsForFileToOpen ->
            subdir.find('.file').click()

          runs ->
            atom.commands.dispatch(treeView.element, 'tree-view:collapse-directory')
            expect(subdir).not.toHaveClass 'expanded'
            expect(subdir).toHaveClass 'selected'
            expect(treeView.root).toHaveClass 'expanded'

    describe "tree-view:recursive-collapse-directory", ->
      parent    = null
      children  = null

      beforeEach ->
        parent = root.find('> .entries > .directory').eq(2)
        parent[0].expand()
        children = parent.find('.expanded.directory')
        children.each (index, child) ->
          child.expand()

      describe "when an expanded directory is recursively collapsed", ->
        it "collapses the directory and all its child directories", ->
          parent.click()
          parent[0].expand()
          expect(parent).toHaveClass 'expanded'
          children.each (index, child) ->
            $(child).click()
            child.expand()
            expect(child).toHaveClass 'expanded'

          atom.commands.dispatch(treeView.element, 'tree-view:recursive-collapse-directory')

          expect(parent).not.toHaveClass 'expanded'
          children.each (index, child) ->
            expect(child).not.toHaveClass 'expanded'
          expect(treeView.root).toHaveClass 'expanded'

    describe "tree-view:open-selected-entry", ->
      describe "when a file is selected", ->
        it "opens the file in the editor and focuses it", ->
          jasmine.attachToDOM(workspaceElement)

          waitsForFileToOpen ->
            root.find('.file:contains(tree-view.js)').click()

          waitsForFileToOpen ->
            atom.commands.dispatch(treeView.element, 'tree-view:open-selected-entry')

          runs ->
            item = atom.workspace.getActivePaneItem()
            expect(item.getPath()).toBe atom.project.resolve('tree-view.js')
            expect(atom.views.getView(item)).toHaveFocus()

      describe "when a directory is selected", ->
        it "expands or collapses the directory", ->
          subdir = root.find('.directory').first()
          subdir.click()
          subdir[0].collapse()

          expect(subdir).not.toHaveClass 'expanded'
          atom.commands.dispatch(treeView.element, 'tree-view:open-selected-entry')
          expect(subdir).toHaveClass 'expanded'
          atom.commands.dispatch(treeView.element, 'tree-view:open-selected-entry')
          expect(subdir).not.toHaveClass 'expanded'

      describe "when nothing is selected", ->
        it "does nothing", ->
          atom.commands.dispatch(treeView.element, 'tree-view:open-selected-entry')
          expect(atom.workspace.getActivePaneItem()).toBeUndefined()

  describe "file modification", ->
    [dirView, fileView, dirView2, fileView2, fileView3, rootDirPath, dirPath, filePath, dirPath2, filePath2, filePath3] = []

    beforeEach ->
      rootDirPath = fs.absolute(temp.mkdirSync('tree-view'))

      dirPath = path.join(rootDirPath, "test-dir")
      filePath = path.join(dirPath, "test-file.txt")

      dirPath2 = path.join(rootDirPath, "test-dir2")
      filePath2 = path.join(dirPath2, "test-file2.txt")
      filePath3 = path.join(dirPath2, "test-file3.txt")

      fs.makeTreeSync(dirPath)
      fs.writeFileSync(filePath, "doesn't matter")

      fs.makeTreeSync(dirPath2)
      fs.writeFileSync(filePath2, "doesn't matter")
      fs.writeFileSync(filePath3, "doesn't matter")

      atom.project.setPaths([rootDirPath])

      root = $(treeView.root)
      dirView = $(treeView.root.entries).find('.directory:contains(test-dir):first')
      dirView[0].expand()
      fileView = treeView.find('.file:contains(test-file.txt)')
      dirView2 = $(treeView.root.entries).find('.directory:contains(test-dir2):last')
      dirView2[0].expand()
      fileView2 = treeView.find('.file:contains(test-file2.txt)')
      fileView3 = treeView.find('.file:contains(test-file3.txt)')

    describe "tree-view:copy", ->
      LocalStorage = window.localStorage
      beforeEach ->
        LocalStorage.clear()

        waitsForFileToOpen ->
          fileView2.click()

        runs ->
          atom.commands.dispatch(treeView.element, "tree-view:copy")

      describe "when a file is selected", ->
        it "saves the selected file/directory path to localStorage['tree-view:copyPath']", ->
          expect(LocalStorage['tree-view:copyPath']).toBeTruthy()

        it "Clears the localStorage['tree-view:cutPath']", ->
          LocalStorage.clear()
          LocalStorage['tree-view:cutPath'] = "I live!"
          atom.commands.dispatch(treeView.element, "tree-view:copy")
          expect(LocalStorage['tree-view:cutPath']).toBeFalsy

      describe 'when multiple files are selected', ->
        it 'saves the selected item paths in localStorage', ->
          fileView3.addClass('selected')
          atom.commands.dispatch(treeView.element, "tree-view:copy")
          storedPaths = JSON.parse(LocalStorage['tree-view:copyPath'])

          expect(storedPaths.length).toBe 2
          expect(storedPaths[0]).toBe fileView2[0].getPath()
          expect(storedPaths[1]).toBe fileView3[0].getPath()

    describe "tree-view:cut", ->
      LocalStorage = window.localStorage

      beforeEach ->
        LocalStorage.clear()

        waitsForFileToOpen ->
          fileView2.click()

        runs ->
          atom.commands.dispatch(treeView.element, "tree-view:cut")

      describe "when a file is selected", ->
        it "saves the selected file/directory path to localStorage['tree-view:cutPath']", ->
          expect(LocalStorage['tree-view:cutPath']).toBeTruthy()

        it "Clears the localStorage['tree-view:copyPath']", ->
          LocalStorage.clear()
          LocalStorage['tree-view:copyPath'] = "I live to CUT!"
          atom.commands.dispatch(treeView.element, "tree-view:cut")
          expect(LocalStorage['tree-view:copyPath']).toBeFalsy()

      describe 'when multiple files are selected', ->
        it 'saves the selected item paths in localStorage', ->
          LocalStorage.clear()
          fileView3.addClass('selected')
          atom.commands.dispatch(treeView.element, "tree-view:cut")
          storedPaths = JSON.parse(LocalStorage['tree-view:cutPath'])

          expect(storedPaths.length).toBe 2
          expect(storedPaths[0]).toBe fileView2[0].getPath()
          expect(storedPaths[1]).toBe fileView3[0].getPath()

    describe "tree-view:paste", ->
      LocalStorage = window.localStorage

      beforeEach ->
        LocalStorage.clear()

      describe "when attempting to paste a directory into itself", ->
        describe "when copied", ->
          it "makes a copy inside itself", ->
            LocalStorage['tree-view:copyPath'] = JSON.stringify([dirPath])

            dirView.click()

            newPath = path.join(dirPath, path.basename(dirPath))
            expect(-> atom.commands.dispatch(treeView.element, "tree-view:paste")).not.toThrow()
            expect(fs.existsSync(newPath)).toBeTruthy()

          it 'does not keep copying recursively', ->
            LocalStorage['tree-view:copyPath'] = JSON.stringify([dirPath])
            dirView.click()

            newPath = path.join(dirPath, path.basename(dirPath))
            expect(-> atom.commands.dispatch(treeView.element, "tree-view:paste")).not.toThrow()
            expect(fs.existsSync(newPath)).toBeTruthy()
            expect(fs.existsSync(path.join(newPath, path.basename(dirPath)))).toBeFalsy()

        describe "when cut", ->
          it "does nothing", ->
            LocalStorage['tree-view:cutPath'] = JSON.stringify([dirPath])
            dirView.click()

            expect(fs.existsSync(dirPath)).toBeTruthy()
            expect(fs.existsSync(path.join(dirPath, path.basename(dirPath)))).toBeFalsy()

      describe "when a file has been copied", ->
        describe "when a file is selected", ->
          it "creates a copy of the original file in the selected file's parent directory", ->
            LocalStorage['tree-view:copyPath'] = JSON.stringify([filePath])

            fileView2.click()
            atom.commands.dispatch(treeView.element, "tree-view:paste")

            expect(fs.existsSync(path.join(dirPath2, path.basename(filePath)))).toBeTruthy()
            expect(fs.existsSync(filePath)).toBeTruthy()

          describe 'when target already exists', ->
            it 'appends a number to the destination name', ->
              LocalStorage['tree-view:copyPath'] = JSON.stringify([filePath])

              fileView.click()
              atom.commands.dispatch(treeView.element, "tree-view:paste")
              atom.commands.dispatch(treeView.element, "tree-view:paste")

              fileArr = filePath.split(path.sep).pop().split('.')
              numberedFileName0 = path.join(dirPath, "#{fileArr[0]}0.#{fileArr[1]}")
              numberedFileName1 = path.join(dirPath, "#{fileArr[0]}1.#{fileArr[1]}")
              expect(fs.existsSync(numberedFileName0)).toBeTruthy()
              expect(fs.existsSync(numberedFileName1)).toBeTruthy()
              expect(fs.existsSync(filePath)).toBeTruthy()

        describe "when a directory is selected", ->
          it "creates a copy of the original file in the selected directory", ->
            LocalStorage['tree-view:copyPath'] = JSON.stringify([filePath])

            dirView2.click()
            atom.commands.dispatch(treeView.element, "tree-view:paste")

            expect(fs.existsSync(path.join(dirPath2, path.basename(filePath)))).toBeTruthy()
            expect(fs.existsSync(filePath)).toBeTruthy()

          describe 'when target already exists', ->
            it 'appends a number to the destination directory name', ->
              LocalStorage['tree-view:copyPath'] = JSON.stringify([filePath])

              dirView.click()
              atom.commands.dispatch(treeView.element, "tree-view:paste")
              atom.commands.dispatch(treeView.element, "tree-view:paste")

              fileArr = filePath.split(path.sep).pop().split('.')
              numberedFileName0 = path.join(dirPath, "#{fileArr[0]}0.#{fileArr[1]}")
              numberedFileName1 = path.join(dirPath, "#{fileArr[0]}1.#{fileArr[1]}")
              expect(fs.existsSync(numberedFileName0)).toBeTruthy()
              expect(fs.existsSync(numberedFileName1)).toBeTruthy()
              expect(fs.existsSync(filePath)).toBeTruthy()

          describe "when nothing has been copied", ->
            it "does not paste anything", ->
              expect(-> atom.commands.dispatch(treeView.element, "tree-view:paste")).not.toThrow()

      describe "when multiple files have been copied", ->
        describe "when a file is selected", ->
          it "copies the selected files to the parent directory of the selected file", ->
            LocalStorage['tree-view:copyPath'] = JSON.stringify([filePath2, filePath3])

            fileView.click()
            atom.commands.dispatch(treeView.element, "tree-view:paste")

            expect(fs.existsSync(path.join(dirPath, path.basename(filePath2)))).toBeTruthy()
            expect(fs.existsSync(path.join(dirPath, path.basename(filePath3)))).toBeTruthy()
            expect(fs.existsSync(filePath2)).toBeTruthy()
            expect(fs.existsSync(filePath3)).toBeTruthy()

          describe 'when the target destination file exists', ->
            it 'appends a number to the duplicate destination target names', ->
              LocalStorage['tree-view:copyPath'] = JSON.stringify([filePath2, filePath3])

              filePath4 = path.join(dirPath, "test-file2.txt")
              filePath5 = path.join(dirPath, "test-file3.txt")
              fs.writeFileSync(filePath4, "doesn't matter")
              fs.writeFileSync(filePath5, "doesn't matter")

              fileView.click()
              atom.commands.dispatch(treeView.element, "tree-view:paste")

              expect(fs.existsSync(path.join(dirPath, "test-file20.txt"))).toBeTruthy()
              expect(fs.existsSync(path.join(dirPath, "test-file30.txt"))).toBeTruthy()

      describe "when a file has been cut", ->
        describe "when a file is selected", ->
          it "creates a copy of the original file in the selected file's parent directory and removes the original", ->
            LocalStorage['tree-view:cutPath'] = JSON.stringify([filePath])

            fileView2.click()
            atom.commands.dispatch(treeView.element, "tree-view:paste")

            expect(fs.existsSync(path.join(dirPath2, path.basename(filePath)))).toBeTruthy()
            expect(fs.existsSync(filePath)).toBeFalsy()

          describe 'when the target destination file exists', ->
            it 'does not move the cut file', ->
              LocalStorage['tree-view:cutPath'] = JSON.stringify([filePath])

              filePath3 = path.join(dirPath2, "test-file.txt")
              fs.writeFileSync(filePath3, "doesn't matter")

              fileView2.click()
              atom.commands.dispatch(treeView.element, "tree-view:paste")

              expect(fs.existsSync(filePath)).toBeTruthy()

        describe "when a directory is selected", ->
          it "creates a copy of the original file in the selected directory and removes the original", ->
            LocalStorage['tree-view:cutPath'] = JSON.stringify([filePath])

            dirView2.click()
            atom.commands.dispatch(treeView.element, "tree-view:paste")

            expect(fs.existsSync(path.join(dirPath2, path.basename(filePath)))).toBeTruthy()
            expect(fs.existsSync(filePath)).toBeFalsy()

      describe "when multiple files have been cut", ->
        describe "when a file is selected", ->
          it "moves the selected files to the parent directory of the selected file", ->
            LocalStorage['tree-view:cutPath'] = JSON.stringify([filePath2, filePath3])

            fileView.click()
            atom.commands.dispatch(treeView.element, "tree-view:paste")

            expect(fs.existsSync(path.join(dirPath, path.basename(filePath2)))).toBeTruthy()
            expect(fs.existsSync(path.join(dirPath, path.basename(filePath3)))).toBeTruthy()
            expect(fs.existsSync(filePath2)).toBeFalsy()
            expect(fs.existsSync(filePath3)).toBeFalsy()

          describe 'when the target destination file exists', ->
            it 'does not move the cut file', ->
              LocalStorage['tree-view:cutPath'] = JSON.stringify([filePath2, filePath3])

              filePath4 = path.join(dirPath, "test-file2.txt")
              filePath5 = path.join(dirPath, "test-file3.txt")
              fs.writeFileSync(filePath4, "doesn't matter")
              fs.writeFileSync(filePath5, "doesn't matter")

              fileView.click()
              atom.commands.dispatch(treeView.element, "tree-view:paste")

              expect(fs.existsSync(filePath2)).toBeTruthy()
              expect(fs.existsSync(filePath3)).toBeTruthy()

        describe "when a directory is selected", ->
          it "creates a copy of the original file in the selected directory and removes the original", ->
            LocalStorage['tree-view:cutPath'] = JSON.stringify([filePath])

            dirView2.click()
            atom.commands.dispatch(treeView.element, "tree-view:paste")

            expect(fs.existsSync(path.join(dirPath2, path.basename(filePath)))).toBeTruthy()
            expect(fs.existsSync(filePath)).toBeFalsy()

    describe "tree-view:add", ->
      [addPanel, addDialog] = []

      beforeEach ->
        jasmine.attachToDOM(workspaceElement)

        waitsForFileToOpen ->
          fileView.click()

        runs ->
          atom.commands.dispatch(treeView.element, "tree-view:add-file")
          [addPanel] = atom.workspace.getModalPanels()
          addDialog = $(addPanel.getItem()).view()

      describe "when a file is selected", ->
        it "opens an add dialog with the file's current directory path populated", ->
          expect(addDialog).toExist()
          expect(addDialog.promptText.text()).toBeTruthy()
          expect(atom.project.relativize(dirPath)).toMatch(/[^\\\/]$/)
          expect(addDialog.miniEditor.getText()).toBe(atom.project.relativize(dirPath) + path.sep)
          expect(addDialog.miniEditor.getModel().getCursorBufferPosition().column).toBe addDialog.miniEditor.getText().length
          expect(addDialog.miniEditor).toHaveFocus()

        describe "when the parent directory of the selected file changes", ->
          it "still shows the active file as selected", ->
            dirView[0].directory.emitter.emit 'did-remove-entries', {'deleted.txt': {}}
            expect(treeView.find('.selected').text()).toBe path.basename(filePath)

        describe "when the path without a trailing '#{path.sep}' is changed and confirmed", ->
          describe "when no file exists at that location", ->
            it "add a file, closes the dialog and selects the file in the tree-view", ->
              newPath = path.join(dirPath, "new-test-file.txt")
              addDialog.miniEditor.getModel().insertText(path.basename(newPath))

              waitsForFileToOpen ->
                atom.commands.dispatch addDialog.element, 'core:confirm'

              runs ->
                expect(fs.isFileSync(newPath)).toBeTruthy()
                expect(atom.workspace.getModalPanels().length).toBe 0
                expect(atom.workspace.getActivePaneItem().getPath()).toBe newPath

              waitsFor "tree view to be updated", ->
                $(dirView[0].entries).find("> .file").length > 1

              runs ->
                expect(treeView.find('.selected').text()).toBe path.basename(newPath)

          describe "when a file already exists at that location", ->
            it "shows an error message and does not close the dialog", ->
              newPath = path.join(dirPath, "new-test-file.txt")
              fs.writeFileSync(newPath, '')
              addDialog.miniEditor.getModel().insertText(path.basename(newPath))
              atom.commands.dispatch addDialog.element, 'core:confirm'

              expect(addDialog.errorMessage.text()).toContain 'already exists'
              expect(addDialog).toHaveClass('error')
              expect(atom.workspace.getModalPanels()[0]).toBe addPanel

          describe "when the project has no path", ->
            it "add a file and closes the dialog", ->
              atom.project.setPaths([])
              addDialog.close()
              atom.commands.dispatch(treeView.element, "tree-view:add-file")
              [addPanel] = atom.workspace.getModalPanels()
              addDialog = $(addPanel.getItem()).view()

              newPath = temp.path()
              addDialog.miniEditor.getModel().insertText(newPath)

              waitsForFileToOpen ->
                atom.commands.dispatch addDialog.element, 'core:confirm'

              runs ->
                expect(fs.isFileSync(newPath)).toBeTruthy()
                expect(atom.workspace.getModalPanels().length).toBe 0
                expect(atom.workspace.getActivePaneItem().getPath()).toBe fs.realpathSync(newPath)

        describe "when the path with a trailing '#{path.sep}' is changed and confirmed", ->
          it "shows an error message and does not close the dialog", ->
            addDialog.miniEditor.getModel().insertText("new-test-file" + path.sep)
            atom.commands.dispatch addDialog.element, 'core:confirm'

            expect(addDialog.errorMessage.text()).toContain 'names must not end with'
            expect(addDialog).toHaveClass('error')
            expect(atom.workspace.getModalPanels()[0]).toBe addPanel

        describe "when 'core:cancel' is triggered on the add dialog", ->
          it "removes the dialog and focuses the tree view", ->
            atom.commands.dispatch addDialog.element, 'core:cancel'
            expect(atom.workspace.getModalPanels().length).toBe 0
            expect(treeView.find(".tree-view")).toMatchSelector(':focus')

        describe "when the add dialog's editor loses focus", ->
          it "removes the dialog and focuses root view", ->
            workspaceElement.focus()
            expect(atom.workspace.getModalPanels().length).toBe 0
            expect(atom.views.getView(atom.workspace.getActivePane())).toHaveFocus()

        describe "when the path ends with whitespace", ->
          it "removes the trailing whitespace before creating the file", ->
            newPath = path.join(dirPath, "new-test-file.txt")
            addDialog.miniEditor.getModel().insertText(path.basename(newPath) + "  ")

            waitsForFileToOpen ->
              atom.commands.dispatch addDialog.element, 'core:confirm'

            runs ->
              expect(fs.isFileSync(newPath)).toBeTruthy()
              expect(atom.workspace.getActivePaneItem().getPath()).toBe newPath

      describe "when a directory is selected", ->
        it "opens an add dialog with the directory's path populated", ->
          addDialog.cancel()
          dirView.click()
          atom.commands.dispatch(treeView.element, "tree-view:add-file")
          addDialog = $(atom.workspace.getModalPanels()[0].getItem()).view()

          expect(addDialog).toExist()
          expect(addDialog.promptText.text()).toBeTruthy()
          expect(atom.project.relativize(dirPath)).toMatch(/[^\\\/]$/)
          expect(addDialog.miniEditor.getText()).toBe(atom.project.relativize(dirPath) + path.sep)
          expect(addDialog.miniEditor.getModel().getCursorBufferPosition().column).toBe addDialog.miniEditor.getText().length
          expect(addDialog.miniEditor).toHaveFocus()

      describe "when the root directory is selected", ->
        it "opens an add dialog with no path populated", ->
          addDialog.cancel()
          root.click()
          atom.commands.dispatch(treeView.element, "tree-view:add-file")
          addDialog = $(atom.workspace.getModalPanels()[0].getItem()).view()

          expect(addDialog.miniEditor.getText().length).toBe 0

      describe "when there is no entry selected", ->
        it "opens an add dialog with no path populated", ->
          addDialog.cancel()
          root.click()
          root.removeClass('selected')
          expect(treeView.selectedEntry()).toBeNull()
          atom.commands.dispatch(treeView.element, "tree-view:add-file")
          addDialog = $(atom.workspace.getModalPanels()[0].getItem()).view()

          expect(addDialog.miniEditor.getText().length).toBe 0

    describe "tree-view:add-folder", ->
      [addPanel, addDialog] = []

      beforeEach ->
        jasmine.attachToDOM(workspaceElement)

        waitsForFileToOpen ->
          fileView.click()

        runs ->
          atom.commands.dispatch(treeView.element, "tree-view:add-folder")
          [addPanel] = atom.workspace.getModalPanels()
          addDialog = $(addPanel.getItem()).view()

      describe "when a file is selected", ->
        it "opens an add dialog with the file's current directory path populated", ->
          expect(addDialog).toExist()
          expect(addDialog.promptText.text()).toBeTruthy()
          expect(atom.project.relativize(dirPath)).toMatch(/[^\\\/]$/)
          expect(addDialog.miniEditor.getText()).toBe(atom.project.relativize(dirPath) + path.sep)
          expect(addDialog.miniEditor.getModel().getCursorBufferPosition().column).toBe addDialog.miniEditor.getText().length
          expect(addDialog.miniEditor).toHaveFocus()

        describe "when the path without a trailing '#{path.sep}' is changed and confirmed", ->
          describe "when no directory exists at the given path", ->
            it "adds a directory and closes the dialog", ->
              newPath = path.join(dirPath, 'new', 'dir')
              addDialog.miniEditor.getModel().insertText("new#{path.sep}dir")
              atom.commands.dispatch addDialog.element, 'core:confirm'
              expect(fs.isDirectorySync(newPath)).toBeTruthy()
              expect(atom.workspace.getModalPanels().length).toBe 0
              expect(atom.workspace.getActivePaneItem().getPath()).not.toBe newPath
              expect(treeView.find(".tree-view")).toMatchSelector(':focus')
              expect(dirView.find('.directory.selected:contains(new)').length).toBe 1

        describe "when the path with a trailing '#{path.sep}' is changed and confirmed", ->
          describe "when no directory exists at the given path", ->
            it "adds a directory and closes the dialog", ->
              newPath = path.join(dirPath, 'new', 'dir')
              addDialog.miniEditor.getModel().insertText("new#{path.sep}dir#{path.sep}")
              atom.commands.dispatch addDialog.element, 'core:confirm'
              expect(fs.isDirectorySync(newPath)).toBeTruthy()
              expect(atom.workspace.getModalPanels().length).toBe 0
              expect(atom.workspace.getActivePaneItem().getPath()).not.toBe newPath
              expect(treeView.find(".tree-view")).toMatchSelector(':focus')
              expect(dirView.find('.directory.selected:contains(new)').length).toBe(1)

            it "selects the created directory and does not change the expansion state of existing directories", ->
              expandedPath = path.join(dirPath, 'expanded-dir')
              fs.makeTreeSync(expandedPath)
              treeView.entryForPath(dirPath).expand()
              treeView.entryForPath(dirPath).reload()
              expandedView = treeView.entryForPath(expandedPath)
              expandedView.expand()

              newPath = path.join(dirPath, "new2") + path.sep
              addDialog.miniEditor.getModel().insertText("new2#{path.sep}")
              atom.commands.dispatch addDialog.element, 'core:confirm'
              expect(fs.isDirectorySync(newPath)).toBeTruthy()
              expect(atom.workspace.getModalPanels().length).toBe 0
              expect(atom.workspace.getActivePaneItem().getPath()).not.toBe newPath
              expect(treeView.find(".tree-view")).toMatchSelector(':focus')
              expect(dirView.find('.directory.selected:contains(new2)').length).toBe(1)
              expect(treeView.entryForPath(expandedPath).isExpanded).toBeTruthy()

            describe "when the project has no path", ->
              it "adds a directory and closes the dialog", ->
                addDialog.close()
                atom.project.setPaths([])
                atom.commands.dispatch(treeView.element, "tree-view:add-folder")
                [addPanel] = atom.workspace.getModalPanels()
                addDialog = $(addPanel.getItem()).view()

                expect(addDialog.miniEditor.getModel().getText()).toBe ''
                newPath = temp.path()
                addDialog.miniEditor.getModel().insertText(newPath)
                atom.commands.dispatch addDialog.element, 'core:confirm'
                expect(fs.isDirectorySync(newPath)).toBeTruthy()
                expect(atom.workspace.getModalPanels().length).toBe 0

          describe "when a directory already exists at the given path", ->
            it "shows an error message and does not close the dialog", ->
              newPath = path.join(dirPath, "new-dir")
              fs.makeTreeSync(newPath)
              addDialog.miniEditor.getModel().insertText("new-dir#{path.sep}")
              atom.commands.dispatch addDialog.element, 'core:confirm'

              expect(addDialog.errorMessage.text()).toContain 'already exists'
              expect(addDialog).toHaveClass('error')
              expect(atom.workspace.getModalPanels()[0]).toBe addPanel

    describe "tree-view:move", ->
      describe "when a file is selected", ->
        moveDialog = null

        beforeEach ->
          jasmine.attachToDOM(workspaceElement)

          waitsForFileToOpen ->
            fileView.click()

          runs ->
            atom.commands.dispatch(treeView.element, "tree-view:move")
            moveDialog = $(atom.workspace.getModalPanels()[0].getItem()).view()

        afterEach ->
          waits 50 # The move specs cause too many false positives because of their async nature, so wait a little bit before we cleanup

        it "opens a move dialog with the file's current path (excluding extension) populated", ->
          extension = path.extname(filePath)
          fileNameWithoutExtension = path.basename(filePath, extension)
          expect(moveDialog).toExist()
          expect(moveDialog.promptText.text()).toBe "Enter the new path for the file."
          expect(moveDialog.miniEditor.getText()).toBe(atom.project.relativize(filePath))
          expect(moveDialog.miniEditor.getModel().getSelectedText()).toBe path.basename(fileNameWithoutExtension)
          expect(moveDialog.miniEditor).toHaveFocus()

        describe "when the path is changed and confirmed", ->
          describe "when all the directories along the new path exist", ->
            it "moves the file, updates the tree view, and closes the dialog", ->
              newPath = path.join(rootDirPath, 'renamed-test-file.txt')
              moveDialog.miniEditor.setText(newPath)

              atom.commands.dispatch moveDialog.element, 'core:confirm'

              expect(fs.existsSync(newPath)).toBeTruthy()
              expect(fs.existsSync(filePath)).toBeFalsy()
              expect(atom.workspace.getModalPanels().length).toBe 0

              waitsFor "tree view to update", ->
                root.find('> .entries > .file:contains(renamed-test-file.txt)').length > 0

              runs ->
                dirView = $(treeView.root.entries).find('.directory:contains(test-dir)')
                dirView[0].expand()
                expect($(dirView[0].entries).children().length).toBe 0

          describe "when the directories along the new path don't exist", ->
            it "creates the target directory before moving the file", ->
              newPath = path.join(rootDirPath, 'new', 'directory', 'renamed-test-file.txt')
              moveDialog.miniEditor.setText(newPath)

              atom.commands.dispatch moveDialog.element, 'core:confirm'

              waitsFor "tree view to update", ->
                root.find('> .entries > .directory:contains(new)').length > 0

              runs ->
                expect(fs.existsSync(newPath)).toBeTruthy()
                expect(fs.existsSync(filePath)).toBeFalsy()

          describe "when a file or directory already exists at the target path", ->
            it "shows an error message and does not close the dialog", ->
              runs ->
                fs.writeFileSync(path.join(rootDirPath, 'target.txt'), '')
                newPath = path.join(rootDirPath, 'target.txt')
                moveDialog.miniEditor.setText(newPath)

                atom.commands.dispatch moveDialog.element, 'core:confirm'

                expect(moveDialog.errorMessage.text()).toContain 'already exists'
                expect(moveDialog).toHaveClass('error')
                expect(moveDialog.hasParent()).toBeTruthy()

        describe "when 'core:cancel' is triggered on the move dialog", ->
          it "removes the dialog and focuses the tree view", ->
            atom.commands.dispatch moveDialog.element, 'core:cancel'
            expect(atom.workspace.getModalPanels().length).toBe 0
            expect(treeView.find(".tree-view")).toMatchSelector(':focus')

        describe "when the move dialog's editor loses focus", ->
          it "removes the dialog and focuses root view", ->
            $(workspaceElement).focus()
            expect(atom.workspace.getModalPanels().length).toBe 0
            expect(atom.views.getView(atom.workspace.getActivePane())).toHaveFocus()

      describe "when a file is selected that's name starts with a '.'", ->
        [dotFilePath, dotFileView, moveDialog] = []

        beforeEach ->
          dotFilePath = path.join(dirPath, ".dotfile")
          fs.writeFileSync(dotFilePath, "dot")
          dirView[0].collapse()
          dirView[0].expand()
          dotFileView = treeView.find('.file:contains(.dotfile)')

          waitsForFileToOpen ->
            dotFileView.click()

          runs ->
            atom.commands.dispatch(treeView.element, "tree-view:move")
            moveDialog = $(atom.workspace.getModalPanels()[0].getItem()).view()

        it "selects the entire file name", ->
          expect(moveDialog).toExist()
          expect(moveDialog.miniEditor.getText()).toBe(atom.project.relativize(dotFilePath))
          expect(moveDialog.miniEditor.getModel().getSelectedText()).toBe '.dotfile'

      describe "when the project is selected", ->
        it "doesn't display the move dialog", ->
          treeView.root.click()
          atom.commands.dispatch(treeView.element, "tree-view:move")
          expect(atom.workspace.getModalPanels().length).toBe(0)

    describe "tree-view:duplicate", ->
      describe "when a file is selected", ->
        copyDialog = null

        beforeEach ->
          jasmine.attachToDOM(workspaceElement)

          waitsForFileToOpen ->
            fileView.click()

          runs ->
            atom.commands.dispatch(treeView.element, "tree-view:duplicate")
            copyDialog = $(atom.workspace.getModalPanels()[0].getItem()).view()

        afterEach ->
          waits 50 # The copy specs cause too many false positives because of their async nature, so wait a little bit before we cleanup

        it "opens a copy dialog to duplicate with the file's current path populated", ->
          extension = path.extname(filePath)
          fileNameWithoutExtension = path.basename(filePath, extension)
          expect(copyDialog).toExist()
          expect(copyDialog.promptText.text()).toBe "Enter the new path for the duplicate."
          expect(copyDialog.miniEditor.getText()).toBe(atom.project.relativize(filePath))
          expect(copyDialog.miniEditor.getModel().getSelectedText()).toBe path.basename(fileNameWithoutExtension)
          expect(copyDialog.miniEditor).toHaveFocus()

        describe "when the path is changed and confirmed", ->
          describe "when all the directories along the new path exist", ->
            it "duplicates the file, updates the tree view, opens the new file and closes the dialog", ->
              newPath = path.join(rootDirPath, 'duplicated-test-file.txt')
              copyDialog.miniEditor.setText(newPath)

              waitsForFileToOpen ->
                atom.commands.dispatch copyDialog.element, 'core:confirm'

              waitsFor "tree view to update", ->
                root.find('> .entries > .file:contains(duplicated-test-file.txt)').length > 0

              runs ->
                expect(fs.existsSync(newPath)).toBeTruthy()
                expect(fs.existsSync(filePath)).toBeTruthy()
                expect(atom.workspace.getModalPanels().length).toBe 0
                dirView = $(treeView.root.entries).find('.directory:contains(test-dir)')
                dirView[0].expand()
                expect($(dirView[0].entries).children().length).toBe 1
                expect(atom.workspace.getActiveTextEditor().getPath()).toBe(newPath)

          describe "when the directories along the new path don't exist", ->
            it "duplicates the tree and opens the new file", ->
              newPath = path.join(rootDirPath, 'new', 'directory', 'duplicated-test-file.txt')
              copyDialog.miniEditor.setText(newPath)

              waitsForFileToOpen ->
                atom.commands.dispatch copyDialog.element, 'core:confirm'

              waitsFor "tree view to update", ->
                root.find('> .entries > .directory:contains(new)').length > 0

              waitsFor "new path to exist", -> fs.existsSync(newPath)

              runs ->
                expect(fs.existsSync(filePath)).toBeTruthy()
                expect(atom.workspace.getActiveTextEditor().getPath()).toBe(newPath)

          describe "when a file or directory already exists at the target path", ->
            it "shows an error message and does not close the dialog", ->
              runs ->
                fs.writeFileSync(path.join(rootDirPath, 'target.txt'), '')
                newPath = path.join(rootDirPath, 'target.txt')
                copyDialog.miniEditor.setText(newPath)

                atom.commands.dispatch copyDialog.element, 'core:confirm'

                expect(copyDialog.errorMessage.text()).toContain 'already exists'
                expect(copyDialog).toHaveClass('error')
                expect(copyDialog.hasParent()).toBeTruthy()

        describe "when 'core:cancel' is triggered on the copy dialog", ->
          it "removes the dialog and focuses the tree view", ->
            jasmine.attachToDOM(treeView.element)
            atom.commands.dispatch copyDialog.element, 'core:cancel'
            expect(atom.workspace.getModalPanels().length).toBe 0
            expect(treeView.find(".tree-view")).toMatchSelector(':focus')

        describe "when the duplicate dialog's editor loses focus", ->
          it "removes the dialog and focuses root view", ->
            workspaceElement.focus()
            expect(atom.workspace.getModalPanels().length).toBe 0
            expect(atom.views.getView(atom.workspace.getActivePane())).toHaveFocus()

      describe "when a file is selected that's name starts with a '.'", ->
        [dotFilePath, dotFileView, copyDialog] = []

        beforeEach ->
          dotFilePath = path.join(dirPath, ".dotfile")
          fs.writeFileSync(dotFilePath, "dot")
          dirView[0].collapse()
          dirView[0].expand()
          dotFileView = treeView.find('.file:contains(.dotfile)')

          waitsForFileToOpen ->
            dotFileView.click()

          runs ->
            atom.commands.dispatch(treeView.element, "tree-view:duplicate")
            copyDialog = $(atom.workspace.getModalPanels()[0].getItem()).view()

        it "selects the entire file name", ->
          expect(copyDialog).toExist()
          expect(copyDialog.miniEditor.getText()).toBe(atom.project.relativize(dotFilePath))
          expect(copyDialog.miniEditor.getModel().getSelectedText()).toBe '.dotfile'

      describe "when the project is selected", ->
        it "doesn't display the copy dialog", ->
          treeView.root.click()
          atom.commands.dispatch(treeView.element, "tree-view:duplicate")
          expect(atom.workspace.getModalPanels().length).toBe(0)

      describe "when the editor has focus", ->
        copyDialog = null

        beforeEach ->
          waitsForPromise ->
            atom.workspace.open('tree-view.js')

          runs ->
            editorElement = atom.views.getView(atom.workspace.getActivePaneItem())
            atom.commands.dispatch(editorElement, "tree-view:duplicate")
            copyDialog = $(atom.workspace.getModalPanels()[0].getItem()).view()

        it "duplicates the current file", ->
          expect(copyDialog.miniEditor.getText()).toBe('tree-view.js')

      describe "when nothing is selected", ->
        it "doesn't display the copy dialog", ->
          jasmine.attachToDOM(workspaceElement)
          treeView.focus()
          treeView.deselect()
          atom.commands.dispatch(treeView.element, "tree-view:duplicate")
          expect(atom.workspace.getModalPanels().length).toBe(0)

    describe "tree-view:remove", ->
      it "won't remove the root directory", ->
        spyOn(atom, 'confirm')
        jasmine.attachToDOM(workspaceElement)
        treeView.focus()
        root.click()
        atom.commands.dispatch(treeView.element, 'tree-view:remove')

        args = atom.confirm.mostRecentCall.args[0]
        expect(args.buttons).toEqual ['OK']

      it "shows the native alert dialog", ->
        spyOn(atom, 'confirm')

        waitsForFileToOpen ->
          fileView.click()

        runs ->
          atom.commands.dispatch(treeView.element, 'tree-view:remove')
          args = atom.confirm.mostRecentCall.args[0]
          expect(Object.keys(args.buttons)).toEqual ['Move to Trash', 'Cancel']

  describe "file system events", ->
    temporaryFilePath = null

    beforeEach ->
      atom.project.setPaths([fs.absolute(temp.mkdirSync('tree-view'))])
      temporaryFilePath = path.join(atom.project.getPaths()[0], 'temporary')

    describe "when a file is added or removed in an expanded directory", ->
      it "updates the directory view to display the directory's new contents", ->
        entriesCountBefore = null

        runs ->
          expect(fs.existsSync(temporaryFilePath)).toBeFalsy()
          entriesCountBefore = $(treeView.root.entries).find('.entry').length
          fs.writeFileSync temporaryFilePath, 'hi'

        waitsFor "directory view contents to refresh", ->
          $(treeView.root.entries).find('.entry').length == entriesCountBefore + 1

        runs ->
          expect($(treeView.root.entries).find('.entry').length).toBe entriesCountBefore + 1
          expect($(treeView.root.entries).find('.file:contains(temporary)')).toExist()
          fs.removeSync(temporaryFilePath)

        waitsFor "directory view contents to refresh", ->
          $(treeView.root.entries).find('.entry').length == entriesCountBefore

  describe "the hideVcsIgnoredFiles config option", ->
    describe "when the project's path is the repository's working directory", ->
      beforeEach ->
        dotGitFixture = path.join(__dirname, 'fixtures', 'git', 'working-dir', 'git.git')
        projectPath = temp.mkdirSync('tree-view-project')
        dotGit = path.join(projectPath, '.git')
        fs.copySync(dotGitFixture, dotGit)
        ignoreFile = path.join(projectPath, '.gitignore')
        fs.writeFileSync(ignoreFile, 'ignored.txt')
        ignoredFile = path.join(projectPath, 'ignored.txt')
        fs.writeFileSync(ignoredFile, 'ignored text')

        atom.project.setPaths([projectPath])
        atom.config.set "tree-view.hideVcsIgnoredFiles", false

      it "hides git-ignored files if the option is set, but otherwise shows them", ->
        expect(treeView.find('.file:contains(ignored.txt)').length).toBe 1

        atom.config.set("tree-view.hideVcsIgnoredFiles", true)
        expect(treeView.find('.file:contains(ignored.txt)').length).toBe 0

        atom.config.set("tree-view.hideVcsIgnoredFiles", false)
        expect(treeView.find('.file:contains(ignored.txt)').length).toBe 1

    describe "when the project's path is a subfolder of the repository's working directory", ->
      beforeEach ->
        fixturePath = path.join(__dirname, 'fixtures', 'tree-view')
        projectPath = temp.mkdirSync('tree-view-project')
        fs.copySync(fixturePath, projectPath)
        ignoreFile = path.join(projectPath, '.gitignore')
        fs.writeFileSync(ignoreFile, 'tree-view.js')

        atom.project.setPaths([projectPath])
        atom.config.set("tree-view.hideVcsIgnoredFiles", true)

      it "does not hide git ignored files", ->
        expect(treeView.find('.file:contains(tree-view.js)').length).toBe 1

  describe "the hideIgnoredNames config option", ->
    beforeEach ->
      atom.config.set('core.ignoredNames', ['.git', '*.js'])
      dotGitFixture = path.join(__dirname, 'fixtures', 'git', 'working-dir', 'git.git')
      projectPath = temp.mkdirSync('tree-view-project')
      dotGit = path.join(projectPath, '.git')
      fs.copySync(dotGitFixture, dotGit)
      fs.writeFileSync(path.join(projectPath, 'test.js'), '')
      fs.writeFileSync(path.join(projectPath, 'test.txt'), '')
      atom.project.setPaths([projectPath])
      atom.config.set "tree-view.hideIgnoredNames", false

    it "hides ignored files if the option is set, but otherwise shows them", ->
      expect(treeView.find('.directory .name:contains(.git)').length).toBe 1
      expect(treeView.find('.directory .name:contains(test.js)').length).toBe 1
      expect(treeView.find('.directory .name:contains(test.txt)').length).toBe 1

      atom.config.set("tree-view.hideIgnoredNames", true)
      expect(treeView.find('.directory .name:contains(.git)').length).toBe 0
      expect(treeView.find('.directory .name:contains(test.js)').length).toBe 0
      expect(treeView.find('.directory .name:contains(test.txt)').length).toBe 1

      atom.config.set("core.ignoredNames", [])
      expect(treeView.find('.directory .name:contains(.git)').length).toBe 1
      expect(treeView.find('.directory .name:contains(test.js)').length).toBe 1
      expect(treeView.find('.directory .name:contains(test.txt)').length).toBe 1

  describe "Git status decorations", ->
    beforeEach ->
      projectPath = fs.realpathSync(temp.mkdirSync('tree-view-project'))
      workingDirFixture = path.join(__dirname, 'fixtures', 'git', 'working-dir')
      fs.copySync(workingDirFixture, projectPath)
      fs.moveSync(path.join(projectPath, 'git.git'), path.join(projectPath, '.git'))
      atom.project.setPaths([projectPath])

      newDir = path.join(projectPath, 'dir2')
      fs.mkdirSync(newDir)

      newFile = path.join(newDir, 'new2')
      fs.writeFileSync(newFile, '')
      atom.project.getRepositories()[0].getPathStatus(newFile)

      ignoreFile = path.join(projectPath, '.gitignore')
      fs.writeFileSync(ignoreFile, 'ignored.txt')
      ignoredFile = path.join(projectPath, 'ignored.txt')
      fs.writeFileSync(ignoredFile, '')

      modifiedFile = path.join(projectPath, 'dir', 'b.txt')
      originalFileContent = fs.readFileSync(modifiedFile, 'utf8')
      fs.writeFileSync modifiedFile, 'ch ch changes'
      atom.project.getRepositories()[0].getPathStatus(modifiedFile)

      treeView.updateRoot()
      $(treeView.root.entries).find('.directory:contains(dir)')[0].expand()

    describe "when the project is the repository root", ->
      it "adds a custom style", ->
        expect(treeView.find('.icon-repo').length).toBe 1

    describe "when a file is modified", ->
      it "adds a custom style", ->
        $(treeView.root.entries).find('.directory:contains(dir)')[0].expand()
        expect(treeView.find('.file:contains(b.txt)')).toHaveClass 'status-modified'

    describe "when a directory if modified", ->
      it "adds a custom style", ->
        expect(treeView.find('.directory:contains(dir)')).toHaveClass 'status-modified'

    describe "when a file is new", ->
      it "adds a custom style", ->
        $(treeView.root.entries).find('.directory:contains(dir2)')[0].expand()
        expect(treeView.find('.file:contains(new2)')).toHaveClass 'status-added'

    describe "when a directory is new", ->
      it "adds a custom style", ->
        expect(treeView.find('.directory:contains(dir2)')).toHaveClass 'status-added'

    describe "when a file is ignored", ->
      it "adds a custom style", ->
        expect(treeView.find('.file:contains(ignored.txt)')).toHaveClass 'status-ignored'

  describe "when the resize handle is double clicked", ->
    beforeEach ->
      treeView.width(10).find('.list-tree').width 100

    it "sets the width of the tree to be the width of the list", ->
      expect(treeView.width()).toBe 10
      treeView.find('.tree-view-resize-handle').trigger 'dblclick'
      expect(treeView.width()).toBeGreaterThan 10

      treeView.width(1000)
      treeView.find('.tree-view-resize-handle').trigger 'dblclick'
      expect(treeView.width()).toBeLessThan 1000

  describe "selecting items", ->
    [dirView, fileView1, fileView2, fileView3, treeView, rootDirPath, dirPath, filePath1, filePath2, filePath3] = []

    beforeEach ->
      rootDirPath = fs.absolute(temp.mkdirSync('tree-view'))

      dirPath = path.join(rootDirPath, "test-dir")
      filePath1 = path.join(dirPath, "test-file1.txt")
      filePath2 = path.join(dirPath, "test-file2.txt")
      filePath3 = path.join(dirPath, "test-file3.txt")

      fs.makeTreeSync(dirPath)
      fs.writeFileSync(filePath1, "doesn't matter")
      fs.writeFileSync(filePath2, "doesn't matter")
      fs.writeFileSync(filePath3, "doesn't matter")

      atom.project.setPaths([rootDirPath])

      dirView = $(treeView.root.entries).find('.directory:contains(test-dir)')
      dirView[0].expand()
      fileView1 = treeView.find('.file:contains(test-file1.txt)')
      fileView2 = treeView.find('.file:contains(test-file2.txt)')
      fileView3 = treeView.find('.file:contains(test-file3.txt)')

    describe 'selecting multiple items', ->
      it 'switches the contextual menu to muli-select mode', ->
        fileView1.click()
        fileView2.trigger($.Event('mousedown', {shiftKey: true}))
        expect(treeView.find('.tree-view')).toHaveClass('multi-select')
        fileView3.trigger($.Event('mousedown'))
        expect(treeView.find('.tree-view')).toHaveClass('full-menu')

    describe 'selecting multiple items', ->
      it 'switches the contextual menu to muli-select mode', ->
        fileView1.click()
        fileView2.trigger($.Event('mousedown', {shiftKey: true}))
        expect(treeView.find('.tree-view')).toHaveClass('multi-select')

      describe 'using the shift key', ->
        it 'selects the items between the already selected item and the shift clicked item', ->
          fileView1.click()
          fileView3.trigger($.Event('mousedown', {shiftKey: true}))
          expect(fileView1).toHaveClass('selected')
          expect(fileView2).toHaveClass('selected')
          expect(fileView3).toHaveClass('selected')

      describe 'using the metakey(cmd) key', ->
        it 'selects the cmd clicked item in addition to the original selected item', ->
          fileView1.click()
          fileView3.trigger($.Event('mousedown', {metaKey: true}))
          expect(fileView1).toHaveClass('selected')
          expect(fileView3).toHaveClass('selected')
          expect(fileView2).not.toHaveClass('selected')

      describe 'non-darwin platform', ->
        originalPlatform = process.platform

        beforeEach ->
          # Stub platform.process so we can test non-darwin behavior
          Object.defineProperty(process, "platform", {__proto__:null, value: 'win32'})

        afterEach ->
          # Ensure that process.platform is set back to it's original value
          Object.defineProperty(process, "platform", {__proto__:null, value: originalPlatform})

        describe 'using the ctrl key', ->
          it 'selects the ctrl clicked item in addition to the original selected item', ->
            fileView1.click()
            fileView3.trigger($.Event('mousedown', {ctrlKey: true}))
            expect(fileView1).toHaveClass('selected')
            expect(fileView3).toHaveClass('selected')
            expect(fileView2).not.toHaveClass('selected')

      describe 'darwin platform', ->
        originalPlatform = process.platform

        beforeEach ->
          # Stub platform.process so we can test non-darwin behavior
          Object.defineProperty(process, "platform", {__proto__:null, value: 'darwin'})

        afterEach ->
          # Ensure that process.platform is set back to it's original value
          Object.defineProperty(process, "platform", {__proto__:null, value: originalPlatform})

        describe 'using the ctrl key', ->
          describe "previous item is selected but the ctrl clicked item is not", ->
            it 'selects the clicked item, but deselects the previous item', ->
              fileView1.click()
              fileView3.trigger($.Event('mousedown', {ctrlKey: true}))
              expect(fileView1).not.toHaveClass('selected')
              expect(fileView3).toHaveClass('selected')
              expect(fileView2).not.toHaveClass('selected')

            it 'displays the full contextual menu', ->
              fileView1.click()
              fileView3.trigger($.Event('mousedown', {ctrlKey: true}))
              expect(treeView.list).toHaveClass('full-menu')
              expect(treeView.list).not.toHaveClass('multi-select')

          describe 'previous item is selected including the ctrl clicked', ->
            it 'displays the multi-select menu', ->
              fileView1.click()
              fileView3.trigger($.Event('mousedown', {metaKey: true}))
              fileView3.trigger($.Event('mousedown', {ctrlKey: true}))
              expect(treeView.list).not.toHaveClass('full-menu')
              expect(treeView.list).toHaveClass('multi-select')

            it 'does not deselect any of the items', ->
              fileView1.click()
              fileView3.trigger($.Event('mousedown', {metaKey: true}))
              fileView3.trigger($.Event('mousedown', {ctrlKey: true}))
              expect(fileView1).toHaveClass('selected')
              expect(fileView3).toHaveClass('selected')

          describe 'when clicked item is the only item selected', ->
            it 'displays the full contextual menu', ->
              fileView1.click()
              fileView3.trigger($.Event('mousedown', {ctrlKey: true}))
              expect(treeView.list).toHaveClass('full-menu')
              expect(treeView.list).not.toHaveClass('multi-select')

          describe 'when no item is selected', ->
            it 'selects the ctrl clicked item', ->
              fileView3.trigger($.Event('mousedown', {ctrlKey: true}))
              expect(fileView3).toHaveClass('selected')

            it 'displays the full context menu', ->
              fileView3.trigger($.Event('mousedown', {ctrlKey: true}))
              expect(treeView.list).toHaveClass('full-menu')
              expect(treeView.list).not.toHaveClass('multi-select')

        describe "right-clicking", ->
          describe 'when multiple items are selected', ->
            it 'displays the multi-select context menu', ->
              fileView1.click()
              fileView3.trigger($.Event('mousedown', {metaKey: true}))
              fileView3.trigger($.Event('mousedown', {button: 2}))
              expect(fileView1).toHaveClass('selected')
              expect(fileView3).toHaveClass('selected')
              expect(treeView.list).not.toHaveClass('full-menu')
              expect(treeView.list).toHaveClass('multi-select')

          describe 'when a single item is selected', ->
            it 'displays the full context menu', ->
              fileView1.click()
              fileView3.trigger($.Event('mousedown', {button: 2}))
              expect(treeView.list).toHaveClass('full-menu')
              expect(treeView.list).not.toHaveClass('multi-select')

            it 'selects right clicked item', ->
              fileView1.click()
              fileView3.trigger($.Event('mousedown', {button: 2}))
              expect(fileView3).toHaveClass('selected')

            it 'de-selects the previously selected item', ->
              fileView1.click()
              fileView3.trigger($.Event('mousedown', {button: 2}))
              expect(fileView1).not.toHaveClass('selected')

          describe 'when no item is selected', ->
            it 'selects the right clicked item', ->
              fileView3.trigger($.Event('mousedown', {button: 2}))
              expect(fileView3).toHaveClass('selected')

            it 'shows the full context menu', ->
              fileView3.trigger($.Event('mousedown', {button: 2}))
              expect(fileView3).toHaveClass('selected')
              expect(treeView.list).toHaveClass('full-menu')
              expect(treeView.list).not.toHaveClass('multi-select')

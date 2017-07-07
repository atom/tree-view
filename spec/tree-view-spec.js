const TreeView = require('../lib/tree-view')

describe('TreeView', () => {
  describe('serialization', () => {
    it('restores the expanded directories and selected file', () => {
      const treeView = new TreeView({})
      treeView.roots[0].expand()
      treeView.roots[0].entries.firstChild.expand()
      treeView.selectEntry(treeView.roots[0].entries.firstChild.entries.firstChild)

      const treeView2 = new TreeView(treeView.serialize())

      expect(treeView2.roots[0].isExpanded).toBe(true)
      expect(treeView2.roots[0].entries.children[0].isExpanded).toBe(true)
      expect(treeView2.roots[0].entries.children[1].isExpanded).toBeUndefined()
      expect(Array.from(treeView2.getSelectedEntries())).toEqual([treeView2.roots[0].entries.firstChild.entries.firstChild])
    })

    it('restores the scroll position', () => {
      const treeView = new TreeView({})
      treeView.roots[0].expand()
      treeView.roots[0].entries.firstChild.expand()
      treeView.element.style.overflow = 'auto'
      treeView.element.style.height = '80px'
      treeView.element.style.width = '80px'
      jasmine.attachToDOM(treeView.element)

      treeView.element.scrollTop = 42
      treeView.element.scrollLeft = 43

      expect(treeView.element.scrollTop).toBe(42)
      expect(treeView.element.scrollLeft).toBe(43)

      const treeView2 = new TreeView(treeView.serialize())
      treeView2.element.style.overflow = 'auto'
      treeView2.element.style.height = '80px'
      treeView2.element.style.width = '80px'
      jasmine.attachToDOM(treeView2.element)

      waitsFor(() =>
        treeView2.element.scrollTop === 42 &&
        treeView2.element.scrollLeft === 43
      )
    })
  })

  describe('clicking', () => {
    it('should leave multiple entries selected on right click', () => {
      const treeView = new TreeView({})
      const entries = treeView.roots[0].entries
      treeView.selectEntry(entries.children[0])
      treeView.selectMultipleEntries(entries.children[1])
      treeView.showMultiSelectMenu()

      let child = entries.children[0];
      while (child.children.length > 0) {
        child = child.firstChild;
      }

      treeView.onMouseDown({
        stopPropagation() {},
        target: child,
        button: 2
      })

      expect(treeView.getSelectedEntries().length).toBe(2);
      expect(treeView.multiSelectEnabled()).toBe(true);
    })
  });
})

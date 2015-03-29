
module.exports =
    class TreeViewService
    
        constructor: () ->
            @fileNameFilterFunctions = []
            @treeView = undefined
            
        deactivate: () -> 
            @fileNameFilterFunctions = []
            @treeView = undefined
            
        reload: () -> @treeView?.reload()
            
        addFileNameFilterFunction: (filterFunc) =>
            if filterFunc? and filterFunc not in @fileNameFilterFunctions
                @fileNameFilterFunctions.push filterFunc
            @
  
        isFileNameFiltered: (filePath) =>
            for filterFunc in @fileNameFilterFunctions
                if filterFunc(filePath) == true
                    return true
            return false

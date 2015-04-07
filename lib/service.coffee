
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
  
        removeFileNameFilterFunction: (filterFunc) =>
            if filterFunc? and filterFunc in @fileNameFilterFunctions
                @fileNameFilterFunctions.splice @fileNameFilterFunctions.indexOf(filterFunc), 1
            @
  
        isFileNameFiltered: (filePath) =>
            for filterFunc in @fileNameFilterFunctions
                if filterFunc(filePath) == true
                    return true
            return false

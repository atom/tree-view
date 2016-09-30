module.exports = init = (virtualFileSystem, {virtualFile}) ->
  virtualFileSystem.setProjectNode(virtualFile)
  virtualFileSystem.ping()


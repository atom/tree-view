/**
 * Spy on an async method and call through
 * @param obj {Record<string, Function> | any}
 * @param method {string}
 * @returns {Jasmine.Spy & {resolvedWith: any, calledWith: Array<any>}}
 */
function spyOnAsyncAndCallThrough (obj, method) {
  const originalMethod = obj[method]
  if (typeof originalMethod !== 'function') {
    throw new Error(`${method} is not a method of ${obj}`)
  }
  let resolvedWith
  let calledWith
  let asyncSpy = spyOn(obj, method)
    .andCallFake((...args) => {
      calledWith = args
      originalMethod(...args)
        .then((returnValue) => {
          resolvedWith = returnValue
          // update spy call information
          asyncSpy.resolvedWith = resolvedWith
          asyncSpy.calledWith = calledWith
        }).catch((err) => {
          throw err
        })
    })
  // initial undefined values
  asyncSpy.resolvedWith = resolvedWith
  asyncSpy.calledWith = calledWith
  return asyncSpy
}
exports.spyOnAsyncAndCallThrough = spyOnAsyncAndCallThrough

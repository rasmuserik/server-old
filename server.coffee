# {{{1 Boilerplate
# predicates that can be optimised away by uglifyjs
if typeof isNodeJs == "undefined" or typeof runTest == "undefined" then do ->
  root = if typeof window == "undefined" then global else window
  root.isNodeJs = (typeof process != "undefined") if typeof isNodeJs == "undefined"
  root.isPhoneGap = typeof document.ondeviceready != "undefined" if typeof isPhoneGap == "undefined"
  root.runTest = true if typeof runTest == "undefined"
# use - require/window.global with non-require name to avoid being processed in firefox plugins
use = if isNodeJs then ((module) -> require module) else ((module) -> window[module]) 
# execute main
onReady = (fn) ->
  if isNodeJs
    process.nextTick fn
  else
    if document.readystate != "complete" then fn() else setTimeout (-> onReady fn), 17 
# {{{1 logging
fs = require "fs"
child_process = require "child_process"
logStream = undefined
logFileName = undefined
logToFile = (arr, cb) ->
  now = (new Date()).toISOString()
  name = "../logs/log-#{now.slice(0,10)}.log"
  if name != logFileName
    if logStream
      oldfile = logFileName
      logStream.on "close", ->
        child_process.exec "xz #{oldfile}"
      logStream.end()
    logStream = fs.createWriteStream name, {flags : "a"}
    logFileName = name
  logStream.write "#{JSON.stringify [now].concat arr}\n", "utf8", cb


# {{{1 server

routes =
  api:
    err: -> throw "error"
    log: (req, res) ->
      data = ""
      req.setEncoding "utf8"
      req.on "data", (chunk) ->
        data += chunk
      req.on "end", ->
        logToFile [req.url, req.headers, data]
        res.writeHead 200,
          connection: "keep-alive"
        res.end "ok"

port = process.env.API_PORT || 4444

http = require "http"
server = http.createServer (req, res) ->
  logToFile [req.url, req.headers]
  console.log req, res
  route = routes
  for part in req.url.split("/").filter((a)->a)
    route = route[part]
    if typeof route == "function"
      return route(req, res)
    if typeof route == "undefined"
      res.writeHead 404, {}
      res.end "404 not found"
      return

server.listen port, "localhost"

onReady ->
  logToFile ["server started"]
  console.log "serving on port #{port}"

quit = ->
  process.exit(1)

process.on "uncaughtException", window.onerror = (args...) ->
  logToFile ["error occured", String(args)], quit

# {{{1 Boilerplate
# predicates that can be optimised away by uglifyjs
if typeof isNodeJs == "undefined" or typeof runTest == "undefined" then do ->
  root = if typeof window == "undefined" then global else window
  root.isNodeJs = (typeof window == "undefined") if typeof isNodeJs == "undefined"
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
# {{{1 Actual code

port = process.env.API_PORT || 4444

http = require "http"
server = http.createServer (req, res) ->
  console.log req
  res.writeHead 200,
    "Content-Type": "text/plain"
  res.end "helo"

server.listen port, "localhost"

onReady ->
  console.log "serving on port #{port}"


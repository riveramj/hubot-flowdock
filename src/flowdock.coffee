{Adapter,TextMessage} = require 'hubot'
flowdock              = require 'flowdock'

class Flowdock extends Adapter
  send: (params, strings...) ->
    user = @userFromParams(params)
    for str in strings
      if str.length > 8096
        str = "** End of Message Truncated **\n" + str
        str = str[0...8096]
      @bot.message user.flow, str

  reply: (params, strings...) ->
    user = @userFromParams(params)
    strings.forEach (str) =>
      @send params, "@#{user.name}: #{str}"

  userFromParams: (params) ->
    # hubot < 2.4.2: params = user
    # hubot >= 2.4.2: params = {user: user, ...}
    if params.user then params.user else params

  connect: ->
    ids = (flow.id for flow in @flows)
    @stream = @bot.stream(ids, active: 'idle')
    @stream.on 'message', (message) =>
      console.log("#{message} and #{message.event}")
      console.log("#{message.content} message content")
      console.log("#{message.content.event} message event")
      console.log("#{message.content.pull_request.url} message url")
      console.log("#{message.content.pull_request.title} message title")
      return unless message.event == ('message'||'vcs')
      author =
        id: message.user
        name: @userForId(message.user).name
        flow: message.flow
      return if @robot.name.toLowerCase() == author.name.toLowerCase()
      # Reformat leading @mention name to be like "name: message" which is
      # what hubot expects
      hubot_msg = ''
      if(message.event == ('vcs'))
        console.log("in event #{message.content} message content")
        hubot_msg = "#{@robot.name} #{message.content}"
      else
        console.log("in else with #{message.content} message content")
        regex = new RegExp("^@#{@robot.name}(,|\\b)", "i")
        hubot_msg = message.content.replace(regex, "#{@robot.name}: ")
      @receive new TextMessage(author, hubot_msg)

  run: ->
    @login_email    = process.env.HUBOT_FLOWDOCK_LOGIN_EMAIL
    @login_password = process.env.HUBOT_FLOWDOCK_LOGIN_PASSWORD
    unless @login_email && @login_password
      console.error "ERROR: No credentials in environment variables HUBOT_FLOWDOCK_LOGIN_EMAIL and HUBOT_FLOWDOCK_LOGIN_PASSWORD"
      @emit "error", "No credentials"

    @bot = new flowdock.Session(@login_email, @login_password)
    @bot.flows (flows) =>
      @flows = flows
      for flow in flows
        for user in flow.users
          data =
            id: user.id
            name: user.nick
          @userForId user.id, data
      @connect()

    @bot

    @emit 'connected'

exports.use = (robot) ->
  new Flowdock robot


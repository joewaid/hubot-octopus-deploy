
# Description:
#   Teach Hubot to Octopus Deploy
#
# Dependencies:
#   "moment": "2.1.0"
#   "async": "0.2.9"
#
# Configuration:
#   HUBOT_OCTOPUS_DEPLOY_API_KEY
#   HUBOT_OCTOPUS_URL
#
# Commands:
#   hubot help me deploy
#   hubot list projects
#   hubot show project <projectName>
#   hubot list <projectName> releases
#   hubot show <projectName> release <releaseVersion>
#   hubot list environments
#   hubot show environment <environmentName>
#   hubot list <projectName> recent deploys
#   hubot deploy <projectName> <releaseVersion> to <environmentName>
#   hubot deploy <projectName> latest to <environmentName>
#
# Notes:
#   none
#
# Author:
#   twaggs

moment = require 'moment'
async = require 'async'

module.exports = (robot) ->

  robot.respond /help me deploy/i, (msg) ->
    commands = [
      'hubot list projects',
      'hubot show project <projectName>',
      'hubot list <projectName> releases',
      'hubot show <projectName> release <releaseVersion>',
      'hubot list environments',
      'hubot show environment <environmentName>',
      'hubot list <projectName> recent deploys',
      'hubot deploy <projectName> <releaseVersion> to <environmentName>',
      'hubot deploy <projectName> latest to <environmentName>'
    ]
    msg.send "Ok, just use one of these commands:"
    message = ""
    message += helpText commands
    msg.send message

  robot.respond /list (.*) recent deploys/i, (msg) ->
    projectName = msg.match[1]
    project = {}
    octo = new OctopusService()
    flow =
      1: (cb) ->
        octo.project msg, projectName, (status, body, success) ->
          if body
            project = body
            cb()
          else
            msg.send "Project with name #{projectName} was not found."
      2: (cb) ->
        octo.deployments msg, project.Id, (status, body, success) ->
          if success is true
            message = "Recent Deployments for #{projectName}:\n\n"
            message += deployText r for r in body
            msg.send  message
          else
            msg.send "Failed to retrieve environments. Status: #{status}"
    async.series flow

  robot.respond /list (.*) releases/i, (msg) ->
    projectName = msg.match[1]
    project = {}
    octo = new OctopusService()
    flow =
      1: (cb) ->
        octo.project msg, projectName, (status, body, success) ->
          if body
            project = body
            cb()
          else
            msg.send "Project with name #{projectName} was not found."
      2: (cb) ->
        octo.releases msg, project.Id, (status, body, success) ->
          if success is true
            message = "Releases:\n\n"
            message += releaseText r for r in body
            msg.send  message
          else
            msg.send "Failed to retrieve environments. Status: #{status}"
    async.series flow

  robot.respond /list projects/i, (msg) ->
    new OctopusService().projects msg, (status, body, success) ->
      if success is true
        message = "Projects:\n\n"
        message += projectText e for e in body
        msg.send  message
      else
        msg.send "Failed to retrieve projects. Status: #{status}"

  robot.respond /show project (.*)/i, (msg) ->
    name = msg.match[1]
    new OctopusService().project msg, name, (status, body, success) ->
      if not body
        msg.send "Project with name #{name} was not found"
        return
      msg.send projectText body

  robot.respond /list environments/i, (msg) ->
    new OctopusService().environments msg, (status, body, success) ->
      if success is true
        message = "Environments:\n\n"
        message += environmentText e for e in body
        msg.send  message
      else
        msg.send "Failed to retrieve environments. Status: #{status}"

  robot.respond /show environment (.*)/i, (msg) ->
    name = msg.match[1]
    new OctopusService().environment msg, name, (status, body, success) ->
      if not body
        msg.send "Environment with name #{name} was not found"
        return
      msg.send environmentText body

  robot.respond /show (.*) release (.*)/i, (msg) ->
    projectName = msg.match[1]
    name = msg.match[2]
    project = {}
    octo = new OctopusService()
    flow =
      1: (cb) ->
        octo.project msg, projectName, (status, body, success) ->
          if body
            project = body
            cb()
          else
            msg.send "Project with name #{projectName} was not found."
      2: (cb) ->
        octo.release msg, project.Id, name, (status, body, success) ->
          if not body
            msg.send "Release with name #{name} was not found"
            return
          msg.send releaseText body
    async.series flow

  robot.respond /deploy (.*) latest to (.*)/i, (msg) ->
    projectName = msg.match[1]
    environmentName = msg.match[2]
    release = {}
    environment = {}
    project = {}
    octo = new OctopusService()
    flow =
      1: (cb) ->
        octo.project msg, projectName, (status, body, success) ->
          if body
            project = body
            cb()
          else
            msg.send "Project with name #{projectName} was not found."
      2: (cb) ->
        octo.environment msg, environmentName, (status, body, success) ->
          if body
            environment = body
            cb()
          else
            msg.send "Environment with name #{environment} was not found."
      3: (cb) ->
        octo.latest_release msg, project.Id, (status, body, success) ->
          if body
            release = body
            cb()
          else
            msg.send "Unable to retrieve latest release."
      4: ->
        octo.deploy msg, project.Id, release.Id, environment.Id, (status, body, success) ->
          if success is true
            msg.send "Deployment for version #{release.Version} to #{environment.Name} has been queued."
          else
            msg.send "There was an issue creating deployment. Status: #{status}. Response: #{body}"
    async.series flow

  robot.respond /deploy (.*) (.*) to (.*)/i, (msg) ->
    projectName = msg.match[1]
    version = msg.match[2]
    environment = msg.match[3]
    if version.toLowerCase() != "latest"
      releaseId = -1
      environmentId = -1
      project = {}
      octo = new OctopusService()
      flow =
        1: (cb) ->
          octo.project msg, projectName, (status, body, success) ->
            if body
              project = body
              cb()
            else
              msg.send "Project with name #{projectName} was not found."
        2: (cb) ->
          octo.environment msg, environment, (status, body, success) ->
            if body
              environmentId = body.Id
              cb()
            else
              msg.send "Environment with name #{environment} was not found."
        3: (cb) ->
          octo.release msg, project.Id, version, (status, body, success) ->
            if body
              releaseId = body.Id
              cb()
            else
              msg.send "Release with version #{version} was not found."
        4: ->
          octo.deploy msg, project.Id, releaseId, environmentId, (status, body, success) ->
            if success is true
              msg.send "Deployment for version #{version} to #{environment} has been queued."
            else
              msg.send "There was an issue creating deployment. Status: #{status}. Response: #{body}"
      async.series flow

projectText = (env) ->
  return displayText { "Id": env.Id, "Name": env.Name }

environmentText = (env) ->
  return displayText { "Id": env.Id, "Name": env.Name }

releaseText = (rel) ->
  return displayText { "Id": rel.Id, "Version": rel.Version, "Created": moment(rel.Assembled).format("MM/DD/YY h:mm a") }

deployText = (dep) ->
  return displayText { "Id": dep.Id, "Desc": dep.Task.Description, "State": dep.Task.State, "Created": moment(dep.Created).format("MM/DD/YY h:mm a")}

displayText = (object) ->
  text = "---------------------\n"
  text += "  #{key}: #{val}\n" for key, val of object
  return text;

helpText = (commands) ->
  message = ""
  message += "#{c}\n" for c in commands
  return message


class OctopusService

  constructor: () ->
    unless process.env.HUBOT_OCTOPUS_DEPLOY_API_KEY
      throw "You must set HUBOT_OCTOPUS_DEPLOY_API_KEY in your environment vairables"
    unless process.env.HUBOT_OCTOPUS_URL
      throw "You must set HUBOT_OCTOPUS_URL in your environment vairables"
    @base_url = process.env.HUBOT_OCTOPUS_URL
    @api_key = process.env.HUBOT_OCTOPUS_DEPLOY_API_KEY

  deployments: (msg, projectId, callback) ->
    this.request(msg).path("/api/projects/#{projectId}/most-recent-deployment").get() (err, res, body) ->
      if 200 <= res.statusCode <= 299
        callback res.statusCode, JSON.parse(body).Items, true
      else
        callback res.statusCode, null, false

  projects: (msg, callback) ->
    this.request(msg).path("/api/projects").get() (err, res, body) ->
      if 200 <= res.statusCode <= 299
        callback res.statusCode, JSON.parse(body).Items, true
      else
        callback res.statusCode, null, false

  project: (msg, name, callback) ->
    this.request(msg).path("/api/projects").get() (err, res, body) ->
      if 200 <= res.statusCode <= 299
        projects = JSON.parse(body).Items
        matches = projects.filter (e) -> e.Name.toLowerCase() == name.toLowerCase()
        callback res.statusCode, matches[0], true
      else
        callback res.statusCode, null, false

  environment: (msg, name, callback) ->
    this.request(msg).path("/api/environments").get() (err, res, body) ->
      if 200 <= res.statusCode <= 299
        environments = JSON.parse(body).Items
        matches = environments.filter (e) -> e.Name.toLowerCase() == name.toLowerCase()
        callback res.statusCode, matches[0], true
      else
        callback res.statusCode, null, false

  environments: (msg, callback) ->
    this.request(msg).path("/api/environments").get() (err, res, body) ->
      if 200 <= res.statusCode <= 299
        callback res.statusCode, JSON.parse(body).Items, true
      else
        callback res.statusCode, null, false

  release: (msg, projectId, version, callback) ->
    this.request(msg).path("/api/projects/#{projectId}/releases").get() (err, res, body) ->
      if 200 <= res.statusCode <= 299
        releases = JSON.parse(body).Items
        matches = releases.filter (r) -> r.Version.toLowerCase() == version.toLowerCase()
        callback res.statusCode, matches[0], true
      else
        callback res.statusCode, null, false

  releases: (msg, projectId, callback) ->
    this.request(msg).path("/api/projects/#{projectId}/releases").get() (err, res, body) ->
      if 200 <= res.statusCode <= 299
        callback res.statusCode, JSON.parse(body).Items, true
      else
        callback res.statusCode, null, false

  latest_release: (msg, projectId, callback) ->
    this.request(msg).path("/api/projects/#{projectId}/releases").get() (err, res, body) ->
      if 200 <= res.statusCode <= 299
        releases = JSON.parse(body).Items
        callback res.statusCode, releases[0], true
      else
        callback res.statusCode, null, false

  deploy: (msg, projectId, releaseId, environmentId, callback) ->
    data =
      projectId: projectId
      releaseId: releaseId
      environmentId: environmentId
    this.request(msg).path("/api/deployments").post(JSON.stringify(data)) (err, res, body) ->
      if 200 <= res.statusCode <= 299
        callback res.statusCode, JSON.parse(body), true
      else
        callback res.statusCode, null, false

  request: (msg) ->
    req = msg
      .http(@base_url)
      .header "X-Octopus-ApiKey", "#{@api_key}"
    return req

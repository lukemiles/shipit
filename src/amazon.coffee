{load} = require 'cheerio'
moment = require 'moment-timezone'
request = require 'request'
{titleCase, upperCaseFirst, lowerCase} = require 'change-case'
{ShipperClient} = require './shipper'

class AmazonClient extends ShipperClient
  STATUS_MAP = {}

  constructor: (@options) ->
    STATUS_MAP[ShipperClient.STATUS_TYPES.DELIVERED] = ['delivered']
    STATUS_MAP[ShipperClient.STATUS_TYPES.EN_ROUTE] = ['on the way']
    STATUS_MAP[ShipperClient.STATUS_TYPES.OUT_FOR_DELIVERY] = ['out for delivery']
    STATUS_MAP[ShipperClient.STATUS_TYPES.SHIPPING] = ['shipping soon']
    super

  validateResponse: (response, cb) ->
    $ = load(response, normalizeWhitespace: true)
    rightNow = /<!-- navp-.* \((.*)\) --?>/.exec(response)?[1]
    cb null, {$, rightNow}

  getService: ->

  getWeight: ->

  getDestination: ->

  getEta: (data) ->

  presentStatus: (details) ->
    status = null
    for statusCode, matchStrings of STATUS_MAP
      for text in matchStrings
        regex = new RegExp(text, 'i')
        if regex.test lowerCase(details)
          status = statusCode
          break
      break if status?
    parseInt(status, 10) if status?

  getActivitiesAndStatus: (data) ->
    activities = []
    status = null
    return {activities, status} unless data?
    {$, rightNow} = data
    status = @presentStatus $(".latest-event-status").text()
    rows = $("div[data-a-expander-name=event-history-list] .a-box")
    for row in rows
      columns = $($(row).find(".a-row")[0]).children '.a-column'
      if columns.length is 2
        timeOfDay = $(columns[0]).text().trim()
        timeOfDay = '12:00 AM' if timeOfDay is '--'
        components = $(columns[1]).children 'span'
        details = if components?[0]? then $(components[0]).text().trim() else ''
        location = if components?[1]? then $(components[1]).text().trim() else ''
        ts = "#{dateStr} #{timeOfDay} +00:00"
        timestamp = moment(ts, 'YYYY-MM-DD H:mm A Z').toDate()
        if timestamp? and details?.length
          activities.push {timestamp, location, details}
      else
        dateStr = $(row).text().trim()
          .replace 'Latest update: ', ''
        if /yesterday/i.test dateStr
          date = moment(rightNow).subtract(1, 'day')
        else if /today/i.test date
          date = moment(rightNow)
        else if /day/.test dateStr
          date = moment "#{dateStr}, #{moment(rightNow).format 'YYYY'}"
        else
          date = moment dateStr
        dateStr = date.format 'YYYY-MM-DD'
    {activities, status}

  requestOptions: ({orderId, shipmentId}) ->
    method: 'GET'
    uri: "https://www.amazon.com/gp/your-account/ship-track" +
      "/ref=st_v1_desktop_redirect?ie=UTF8&orderId=#{orderId}" +
      "&packageIndex=0&shipmentId=#{shipmentId}"

module.exports = {AmazonClient}


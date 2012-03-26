'use strict'

# Templates:
T =
  frontView: '<img alt="<%= slug %>" src="<%= pic %>" />'
  thumbView: '<img alt="" src="<%= thumb %>" class="<%= state %>" />'


class Picture extends Backbone.Model

  defaults:
    slug: ''
    thumb: ''
    pic: ''
    state: ''

  initialize: ->
    slug = @get('pic')
    try
      slug = /([^\.\/]+)\.[^\.]*?$/.exec(slug)[1]
    catch e
      console.error e
    @set 'slug', slug

  getRoute: ->
    "#pic/#{@get('slug')}"

  select: ->
    @set state: 'selected'

  deselect: ->
    @set state: ''


class Pictures extends Backbone.Collection

  url: 'pictures.json'

  model: Picture

  select: (model) ->
    @selected.deselect()  if @selected?
    @selected = model
    model.select()
    @trigger 'pictures:selected', model

  selectedPicture: ->
    @selected


class FrontView extends Backbone.View

  el: $('#front')

  template: _.template(T.frontView)

  render: ->
    $(@el).html @template @model.selectedPicture().toJSON()
    @


class ThumbView extends Backbone.View

  template: _.template(T.thumbView)

  events:
    click: "selectPicture"

  tagName: 'li'

  initialize: ->
    @model.bind 'change', @render, @

  render: ->
    $(@el).html @template @model.toJSON()
    @

  selectPicture: ->
    @trigger 'thumb:selected', @model


class AppView extends Backbone.View

  events:
    "click #front img": "showNextPicture"

  el: $("#container")

  initialize: ->
    @pictures = new Pictures
    @pictures.fetch
      async: false,
      error: (_model, resp) ->
        throw new Error "JSON sux?: " + resp.responseText

    # Used for simple prev / next pic functions:
    @pictures.each (pic, index) -> pic.set 'index', index

    @pictures.select @pictures.at 0
    @frontview = new FrontView(model: @pictures)

  render: ->
    @frontview.render()
    $thumbsEl = @$('#thumbs')
    console.log @pictures
    $thumbsEl.html('')
    @pictures.each (t) =>
      view = new ThumbView(model: t).render()
      view.bind 'thumb:selected', @selectPicture, @
      $thumbsEl.append view.el

  selectPicture: (pic) ->
    @pictures.select pic
    app_router.navigate pic.getRoute()
    @render()

  _incrementPic: (deltaIndex) ->
    i = @pictures.selectedPicture().get 'index'
    l = @pictures.length
    (i + l + deltaIndex) % l

  showNextPicture: =>
    @selectPicture @pictures.at @_incrementPic 1

  showLastPicture: =>
    @selectPicture @pictures.at @_incrementPic -1

  onKeyDown: (e) =>
    switch e.which
      # Left key:
      when 37
        @showLastPicture()
        false
      # Space, Right key:
      when 32, 39
        @showNextPicture()
        false


class AppRouter extends Backbone.Router

  routes:
    "pic/:slug": "showPicture"
    "*args": "defaultAction"

  showPicture: (slug) ->
    pic = app.pictures.find (pic) ->
      slug is pic.get 'slug'
    app.selectPicture pic

  defaultAction: (args) ->
    @navigate app.pictures.selectedPicture().getRoute()


app = new AppView
app.render()
app_router = new AppRouter
Backbone.history.start()

$(window).on
  keydown: app.onKeyDown
  # Let's not forget mobile / tablet users:
  swipeleft: app.showNextPicture
  swiperight: app.showLastPicture


# For convenience while developing:
window.app = app

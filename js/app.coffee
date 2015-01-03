---
---
class Building
  constructor: (@element, @x=0, @y=0) ->
    @size = parseInt(@element.dataset.size, 10) * BaseMap.snap

  setIndex: (index) ->
    @element.dataset.index = index

  pickup: ->
    @element.classList.add('is-dragging')

  drop: ->
    @element.classList.remove('is-dragging', 'notok')

  move: (x, y) ->
    @x = x
    @y = y
    @element.style.left = x + 'px'
    @element.style.top  = y + 'px'

  overlaps: (building) ->
    @x < building.x + building.size &&
    @x + @size > building.x &&
    @y < building.y + building.size &&
    @size + @y > building.y

class BaseMap
  @snap: {{site.grid_square}}

  constructor: (@element) ->
    @grid = @element.querySelector('.grid')
    @sidebar = document.querySelector('.sidebar')
    @buildings = []
    @dragging = false
    @selected = false
    @gridOffsets = @offset(@grid)
    @editMode = true
    @eraseMode = false

    @sidebar.addEventListener 'mousedown', (e) =>
      return if !@editMode or !e.target.classList.contains('building') or e.button isnt 0
      @selectBuilding(e.target)

    @sidebar.addEventListener 'mouseleave', (e) =>
      return unless @selected
      @addBuilding(@selected)
      @grabOffset =
        left: @activeBuilding.size / 2
        top : @activeBuilding.size / 2
      @positionBuilding(e.clientX, e.clientY)
      @startDragging()
      @selected = false

    @grid.addEventListener 'mousedown', (e) =>
      return if !@editMode or e.target is @grid or e.button isnt 0
      @activeBuilding = @buildings[parseInt(e.target.dataset.index, 10)]
      if @eraseMode
        @removeBuilding()
      else
        @setGrabOffset(e)
        @positionBuilding(e.clientX, e.clientY)
        @startDragging()

    document.body.addEventListener 'mouseup', (e) =>
      @stopDragging() if @dragging
      @selected = false

    @element.addEventListener 'mousemove', (e) =>
      @positionBuilding(e.clientX, e.clientY) if @dragging

  toggleEditMode: ->
    @editMode = !@editMode

  toggleEraseMode: ->
    @grid.classList.toggle('erase-mode')
    @eraseMode = !@eraseMode

  selectBuilding: (source) ->
    @selected = source

  addBuilding: (source) ->
    el = document.createElement('span')
    el.setAttribute('title', source.getAttribute('title'))
    el.className = source.className
    el.dataset.size = source.dataset.size
    source.dataset.count = parseInt(source.dataset.count, 10) - 1
    el.dataset.index = @buildings.length
    @grid.appendChild(el)
    @activeBuilding = new Building(el)
    @buildings.push(@activeBuilding)

  removeBuilding: (building=@activeBuilding) ->
    @grid.removeChild(building.element)
    source = @sidebar.querySelector(".#{building.element.className.split(' ').join('.')}")
    source.dataset.count = parseInt(source.dataset.count, 10) + 1
    for b, i in @buildings when b is building
      @buildings.splice(i, 1)
      break

    b.setIndex(i) for b, i in @buildings

  positionBuilding: (x, y) ->
    {x, y} = @grid.convertPointFromNode({x: x, y: y}, document)

    x = x - @grabOffset.left
    y = y - @grabOffset.top

    snapped = for v in [x, y]
      Math.round(v / BaseMap.snap) * BaseMap.snap

    if onMap = @onMap(snapped[0], snapped[1])
      [x, y] = snapped

    @activeBuilding.move(x, y)
    available = onMap && @positionAvailable()
    @activeBuilding.element.classList.toggle('notok', !available)

  onMap: (x=@activeBuilding.x, y=@activeBuilding.y, size=@activeBuilding.size) ->
    (0 <= x <= @gridOffsets.width - size) && (0 <= y <= @gridOffsets.height - size)

  positionAvailable: ->
    return true if @buildings.length < 2
    for b in @buildings when b && b isnt @activeBuilding
      return false if @activeBuilding.overlaps(b)
    true

  startDragging: ->
    @dragging = true
    @activeBuilding.pickup()

  stopDragging: ->
    @dragging = false

    @activeBuilding.drop()

    unless @onMap() && @positionAvailable()
      @removeBuilding()

    @activeBuilding = null
    @grabOffset =
      left: 0
      top : 0

  setGrabOffset: (e) ->
    {x, y} = e.target.convertPointFromNode({x: e.clientX, y: e.clientY}, document)
    @grabOffset =
      left: x
      top : y

  offset: (element) ->
    x = element.offsetLeft
    y = element.offsetTop
    el = element
    while el = el.offsetParent
      x += el.offsetLeft
      y += el.offsetTop
    {
      left   : x
      top    : y
      width  : element.offsetWidth
      height : element.offsetHeight
    }

baseMap = new BaseMap(document.querySelector('.map'))

document.querySelector('.switch-mode').addEventListener 'click', ->
  document.body.classList.toggle('view-mode')
  # baseMap.toggleEditMode()

document.querySelector('.panel button').addEventListener 'click', ->
  document.querySelector('.panel').classList.toggle('open')

document.querySelector('.toggle-erase-mode').addEventListener 'click', ->
  this.classList.toggle('on')
  baseMap.toggleEraseMode()

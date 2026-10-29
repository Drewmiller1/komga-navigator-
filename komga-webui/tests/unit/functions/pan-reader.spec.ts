import {axisStops, clampZoom, nearestStop, panStops} from '@/functions/pan-reader'

describe('axisStops', () => {
  test('given content smaller than viewport then it should return a single centered stop', () => {
    expect(axisStops(300, 400)).toEqual([-50])
  })

  test('given content equal to viewport then it should return a single stop at 0', () => {
    expect(axisStops(400, 400)).toEqual([0])
  })

  test('given larger content then stops should be evenly spaced, overlap by at least 20%, and end flush with the edge', () => {
    expect(axisStops(1000, 400)).toEqual([0, 300, 600])
  })

  test('given content that fits exactly in steps then the last stop should be the edge', () => {
    expect(axisStops(720, 400)).toEqual([0, 320])
  })

  test('given a small remainder then it should not make a tiny last step', () => {
    expect(axisStops(750, 375)).toEqual([0, 187.5, 375])
  })
})

describe('panStops', () => {
  test('given LTR then it should go left to right, then top to bottom', () => {
    expect(panStops(1000, 600, 400, 400)).toEqual([
      {x: 0, y: 0}, {x: 300, y: 0}, {x: 600, y: 0},
      {x: 0, y: 200}, {x: 300, y: 200}, {x: 600, y: 200},
    ])
  })

  test('given RTL then it should go right to left, then top to bottom', () => {
    expect(panStops(720, 600, 400, 400, true)).toEqual([
      {x: 320, y: 0}, {x: 0, y: 0},
      {x: 320, y: 200}, {x: 0, y: 200},
    ])
  })
})

describe('nearestStop', () => {
  test('it should return the index of the closest stop', () => {
    const stops = panStops(1000, 600, 400, 400)
    expect(nearestStop(stops, 310, 190)).toEqual(4)
  })
})

describe('clampZoom', () => {
  test('it should keep zoom within bounds', () => {
    expect(clampZoom(0.5)).toEqual(1)
    expect(clampZoom(2)).toEqual(2)
    expect(clampZoom(10)).toEqual(6)
  })
})

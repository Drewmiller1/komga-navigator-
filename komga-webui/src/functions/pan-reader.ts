// Helpers for the pan reader: the page is shown zoomed in, and the viewport steps through it
// row by row, each step overlapping the previous view by a fixed ratio.

export const PAN_OVERLAP = 0.2
export const PAN_ZOOM_MIN = 1
export const PAN_ZOOM_MAX = 6
export const PanZoomLevels: number[] = [1.5, 2, 2.5, 3, 4]

export interface PanStop {
  x: number,
  y: number,
}

// Offsets along one axis, for content of size `content` seen through a viewport of size `viewport`.
// Content smaller than the viewport is centered (negative offset).
// Stops are evenly spaced, so that each view overlaps the previous one by at least `overlap`,
// without a tiny last step at the edge.
export function axisStops(content: number, viewport: number, overlap: number = PAN_OVERLAP): number[] {
  if (content <= viewport) return [(content - viewport) / 2]
  const max = content - viewport
  const steps = Math.ceil(max / (viewport * (1 - overlap)))
  return Array.from({length: steps + 1}, (_, i) => max * i / steps)
}

// All stops, row by row from the top. Within a row, left to right (or right to left if `rtl`).
export function panStops(width: number, height: number, viewportWidth: number, viewportHeight: number, rtl: boolean = false): PanStop[] {
  const xs = axisStops(width, viewportWidth)
  if (rtl) xs.reverse()
  const ys = axisStops(height, viewportHeight)
  return ys.flatMap(y => xs.map(x => ({x, y})))
}

export function nearestStop(stops: PanStop[], x: number, y: number): number {
  let best = 0
  let bestDistance = Infinity
  stops.forEach((s, i) => {
    const d = (s.x - x) ** 2 + (s.y - y) ** 2
    if (d < bestDistance) {
      best = i
      bestDistance = d
    }
  })
  return best
}

export function clampZoom(zoom: number): number {
  return Math.min(PAN_ZOOM_MAX, Math.max(PAN_ZOOM_MIN, zoom))
}

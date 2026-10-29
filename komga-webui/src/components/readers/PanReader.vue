<template>
  <div class="pan-reader"
       ref="root"
       @click="onClick"
       @touchstart="onTouchStart"
       @touchmove="onTouchMove"
       @touchend="onTouchEnd"
       @touchcancel="onTouchEnd"
  >
    <transition :name="animations ? 'pan-fade' : ''">
      <img v-if="currentPage"
           :key="`pan-${currentPage.number}`"
           :alt="`Page ${currentPage.number}`"
           :src="currentPage.url"
           :style="imageStyle"
           class="pan-image"
           draggable="false"
           @load="onLoad($event, currentPage)"
      />
    </transition>

    <!--  preload neighbours, and capture their dimensions  -->
    <img v-for="p in neighbours"
         :key="`pan-preload-${p.number}`"
         :src="p.url"
         alt=""
         class="pan-preload"
         @load="onLoad($event, p)"
    />

    <!--  minimap: where the viewport is on the page  -->
    <transition name="pan-fade">
      <div v-if="showMinimap && stops.length > 1"
           class="pan-minimap"
           :style="minimapStyle"
      >
        <img :src="currentPage.url" alt="" class="pan-minimap-image"/>
        <div class="pan-minimap-viewport" :style="minimapViewportStyle"/>
      </div>
    </transition>
  </div>
</template>

<script lang="ts">
import Vue from 'vue'
import {ReadingDirection} from '@/types/enum-books'
import {PageDtoWithUrl} from '@/types/komga-books'
import {clampZoom, nearestStop, PanStop, panStops} from '@/functions/pan-reader'
import {shortcutsPanLTR, shortcutsPanRTL} from '@/functions/shortcuts/pan-reader'

// fraction of the screen width on the "back" side that goes to the previous area
const BACK_ZONE = 0.3
// band at the top center that opens the menu
const MENU_ZONE_HEIGHT = 0.15
const ZOOM_STEP = 0.25
const MINIMAP_WIDTH = 96
const MINIMAP_DURATION = 1500
// stopIndex value meaning "the last stop of the page", resolved once the page dimensions are known
const LAST_STOP = -1

interface Size {
  w: number,
  h: number,
}

export default Vue.extend({
  name: 'PanReader',
  data: function () {
    return {
      logger: 'PanReader',
      viewport: {w: window.innerWidth, h: window.innerHeight} as Size,
      naturalSizes: {} as Record<number, Size>,
      localZoom: this.zoom as number,
      stopIndex: 0,
      // where to land when the page changes because of us
      landAtEnd: false,
      // free offset, used while pinching instead of the stops
      free: undefined as PanStop | undefined,
      pinch: undefined as { distance: number, zoom: number, fx: number, fy: number } | undefined,
      wheelTimer: undefined as number | undefined,
      suppressClickUntil: 0,
      showMinimap: false,
      minimapTimer: undefined as number | undefined,
    }
  },
  props: {
    pages: {
      type: Array as () => PageDtoWithUrl[],
      required: true,
    },
    page: {
      type: Number,
      required: true,
    },
    zoom: {
      type: Number,
      required: true,
    },
    animations: {
      type: Boolean,
      required: true,
    },
    readingDirection: {
      type: String as () => ReadingDirection,
      required: true,
    },
  },
  watch: {
    page(val, old) {
      this.$debug('[watch:page]', `old:${old}`, `new:${val}`)
      this.stopIndex = this.landAtEnd ? LAST_STOP : 0
      this.landAtEnd = false
      this.free = undefined
    },
    zoom(val) {
      // zoom changed from outside (settings)
      if (val !== this.localZoom) this.applyZoom(val)
    },
    pages: {
      handler(val: PageDtoWithUrl[]) {
        val.forEach(p => {
          if (p.width && p.height && !this.naturalSizes[p.number])
            this.$set(this.naturalSizes, p.number, {w: p.width, h: p.height})
        })
      },
      immediate: true,
    },
  },
  created() {
    window.addEventListener('keydown', this.keyPressed)
    window.addEventListener('resize', this.onResize)
  },
  mounted() {
    // non-passive, so that ctrl+wheel (trackpad pinch) doesn't zoom the whole page
    (this.$refs.root as HTMLElement).addEventListener('wheel', this.onWheel, {passive: false})
  },
  destroyed() {
    window.removeEventListener('keydown', this.keyPressed)
    window.removeEventListener('resize', this.onResize)
    window.clearTimeout(this.wheelTimer)
    window.clearTimeout(this.minimapTimer)
  },
  computed: {
    shortcuts(): any {
      return this.$_.keyBy(this.rtl ? shortcutsPanRTL : shortcutsPanLTR, x => x.key)
    },
    rtl(): boolean {
      return this.readingDirection === ReadingDirection.RIGHT_TO_LEFT
    },
    currentPage(): PageDtoWithUrl | undefined {
      return this.pages[this.page - 1]
    },
    neighbours(): PageDtoWithUrl[] {
      return [this.pages[this.page - 2], this.pages[this.page]].filter(Boolean)
    },
    // size of the image on screen, at the current zoom
    size(): Size | undefined {
      return this.sizeFor(this.localZoom)
    },
    stops(): PanStop[] {
      if (!this.size) return []
      return panStops(this.size.w, this.size.h, this.viewport.w, this.viewport.h, this.rtl)
    },
    resolvedStopIndex(): number {
      if (this.stops.length === 0) return 0
      if (this.stopIndex === LAST_STOP) return this.stops.length - 1
      return Math.min(this.stopIndex, this.stops.length - 1)
    },
    offset(): PanStop {
      return this.free || this.stops[this.resolvedStopIndex] || {x: 0, y: 0}
    },
    imageStyle(): object {
      if (!this.size) return {opacity: 0}
      return {
        width: `${this.size.w}px`,
        height: `${this.size.h}px`,
        transform: `translate3d(${-this.offset.x}px, ${-this.offset.y}px, 0)`,
        transition: this.free || !this.animations ? 'none' : undefined,
      }
    },
    minimapStyle(): object {
      if (!this.size) return {}
      return {
        width: `${MINIMAP_WIDTH}px`,
        height: `${MINIMAP_WIDTH * this.size.h / this.size.w}px`,
      }
    },
    minimapViewportStyle(): object {
      if (!this.size) return {}
      const left = Math.max(0, this.offset.x / this.size.w)
      const top = Math.max(0, this.offset.y / this.size.h)
      return {
        left: `${left * 100}%`,
        top: `${top * 100}%`,
        width: `${Math.min(1 - left, this.viewport.w / this.size.w) * 100}%`,
        height: `${Math.min(1 - top, this.viewport.h / this.size.h) * 100}%`,
      }
    },
  },
  methods: {
    sizeFor(zoom: number): Size | undefined {
      const natural = this.currentPage && this.naturalSizes[this.currentPage.number]
      if (!natural) return undefined
      // zoom 1 is the whole page fitting the screen
      const fit = Math.min(this.viewport.w / natural.w, this.viewport.h / natural.h)
      return {w: natural.w * fit * zoom, h: natural.h * fit * zoom}
    },
    onLoad(e: Event, page: PageDtoWithUrl) {
      const img = e.target as HTMLImageElement
      const current = this.naturalSizes[page.number]
      if (!current || current.w !== img.naturalWidth || current.h !== img.naturalHeight)
        this.$set(this.naturalSizes, page.number, {w: img.naturalWidth, h: img.naturalHeight})
    },
    keyPressed(e: KeyboardEvent) {
      if (e.ctrlKey || e.altKey || e.metaKey) return
      const shortcut = this.shortcuts[e.key]
      if (shortcut) {
        e.preventDefault()
        shortcut.execute(this)
      }
    },
    onClick(e: MouseEvent) {
      if (Date.now() < this.suppressClickUntil) return
      const fx = e.clientX / this.viewport.w
      const fy = e.clientY / this.viewport.h
      if (fy < MENU_ZONE_HEIGHT && fx > BACK_ZONE && fx < 1 - BACK_ZONE) {
        this.$emit('menu')
        return
      }
      const back = this.rtl ? fx > 1 - BACK_ZONE : fx < BACK_ZONE
      back ? this.prev() : this.next()
    },
    next() {
      this.settle()
      if (this.resolvedStopIndex < this.stops.length - 1) {
        this.stopIndex = this.resolvedStopIndex + 1
        this.flashMinimap()
      } else if (this.page < this.pages.length) {
        this.landAtEnd = false
        this.$emit('update:page', this.page + 1)
      } else {
        this.$emit('jump-next')
      }
    },
    prev() {
      this.settle()
      if (this.resolvedStopIndex > 0) {
        this.stopIndex = this.resolvedStopIndex - 1
        this.flashMinimap()
      } else if (this.page > 1) {
        this.landAtEnd = true
        this.$emit('update:page', this.page - 1)
      } else {
        this.$emit('jump-previous')
      }
    },
    zoomIn() {
      this.applyZoom(this.localZoom + ZOOM_STEP)
      this.$emit('update:zoom', this.localZoom)
    },
    zoomOut() {
      this.applyZoom(this.localZoom - ZOOM_STEP)
      this.$emit('update:zoom', this.localZoom)
    },
    // change zoom, keeping the image point under (ax, ay) in place, then snap to the nearest stop
    applyZoom(zoom: number, ax: number = this.viewport.w / 2, ay: number = this.viewport.h / 2, snap: boolean = true) {
      zoom = Math.round(clampZoom(zoom) * 100) / 100
      const before = this.size
      const offset = this.offset
      this.localZoom = zoom
      const after = this.size
      if (!before || !after) return
      const x = (offset.x + ax) / before.w * after.w - ax
      const y = (offset.y + ay) / before.h * after.h - ay
      if (snap) {
        this.free = undefined
        this.stopIndex = nearestStop(this.stops, x, y)
      } else {
        this.free = {x, y}
      }
      this.flashMinimap()
    },
    // finish a pinch: snap to the nearest stop, and persist the zoom
    settle() {
      if (!this.free) return
      this.stopIndex = nearestStop(this.stops, this.free.x, this.free.y)
      this.free = undefined
      this.$emit('update:zoom', this.localZoom)
    },
    onWheel(e: WheelEvent) {
      if (!e.ctrlKey) return
      e.preventDefault()
      this.applyZoom(this.localZoom * Math.exp(-e.deltaY * 0.01), e.clientX, e.clientY, false)
      window.clearTimeout(this.wheelTimer)
      this.wheelTimer = window.setTimeout(this.settle, 250)
    },
    onTouchStart(e: TouchEvent) {
      if (e.touches.length !== 2) return
      const [a, b] = [e.touches[0], e.touches[1]]
      this.pinch = {
        distance: Math.hypot(a.clientX - b.clientX, a.clientY - b.clientY),
        zoom: this.localZoom,
        fx: (a.clientX + b.clientX) / 2,
        fy: (a.clientY + b.clientY) / 2,
      }
    },
    onTouchMove(e: TouchEvent) {
      if (!this.pinch || e.touches.length !== 2) return
      e.preventDefault()
      const [a, b] = [e.touches[0], e.touches[1]]
      const distance = Math.hypot(a.clientX - b.clientX, a.clientY - b.clientY)
      this.applyZoom(this.pinch.zoom * distance / this.pinch.distance, this.pinch.fx, this.pinch.fy, false)
    },
    onTouchEnd(e: TouchEvent) {
      if (!this.pinch || e.touches.length >= 2) return
      this.pinch = undefined
      this.suppressClickUntil = Date.now() + 400
      this.settle()
    },
    onResize() {
      const before = this.size
      const offset = this.offset
      this.viewport = {w: window.innerWidth, h: window.innerHeight}
      const after = this.size
      if (!before || !after) return
      this.stopIndex = nearestStop(this.stops, offset.x / before.w * after.w, offset.y / before.h * after.h)
    },
    flashMinimap() {
      this.showMinimap = true
      window.clearTimeout(this.minimapTimer)
      this.minimapTimer = window.setTimeout(() => {
        this.showMinimap = false
      }, MINIMAP_DURATION)
    },
  },
})
</script>
<style scoped>
.pan-reader {
  position: relative;
  width: 100vw;
  height: 100vh;
  overflow: hidden;
  touch-action: none;
  user-select: none;
}

.pan-image {
  position: absolute;
  top: 0;
  left: 0;
  max-width: none;
  will-change: transform;
  transition: transform 450ms cubic-bezier(0.45, 0, 0.2, 1);
}

.pan-preload {
  display: none;
}

.pan-minimap {
  position: absolute;
  right: 12px;
  bottom: 12px;
  border: 1px solid rgba(255, 255, 255, 0.6);
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.5);
  pointer-events: none;
}

.pan-minimap-image {
  display: block;
  width: 100%;
  height: 100%;
  opacity: 0.7;
}

.pan-minimap-viewport {
  position: absolute;
  border: 2px solid #ff9800;
  background: rgba(255, 152, 0, 0.15);
  transition: all 450ms cubic-bezier(0.45, 0, 0.2, 1);
}

.pan-fade-enter-active, .pan-fade-leave-active {
  transition: opacity 250ms ease;
}

.pan-fade-enter, .pan-fade-leave-to {
  opacity: 0;
}
</style>

import {Shortcut} from '@/types/shortcuts'

const shortcutsPanCommon = [
  new Shortcut('bookreader.shortcuts.next_area',
    (ctx: any) => {
      ctx.next()
    }, ' ', 'Space'),
  new Shortcut('bookreader.shortcuts.next_area',
    (ctx: any) => {
      ctx.next()
    }, 'ArrowDown', '↓'),
  new Shortcut('bookreader.shortcuts.previous_area',
    (ctx: any) => {
      ctx.prev()
    }, 'ArrowUp', '↑'),
  new Shortcut('bookreader.shortcuts.zoom_in',
    (ctx: any) => {
      ctx.zoomIn()
    }, '+'),
  new Shortcut('bookreader.shortcuts.zoom_in',
    (ctx: any) => {
      ctx.zoomIn()
    }, '='),
  new Shortcut('bookreader.shortcuts.zoom_out',
    (ctx: any) => {
      ctx.zoomOut()
    }, '-'),
]

export const shortcutsPanLTR = [
  new Shortcut('bookreader.shortcuts.previous_area',
    (ctx: any) => {
      ctx.prev()
    }, 'ArrowLeft', '←'),
  new Shortcut('bookreader.shortcuts.next_area',
    (ctx: any) => {
      ctx.next()
    }, 'ArrowRight', '→'),
  ...shortcutsPanCommon,
]

export const shortcutsPanRTL = [
  new Shortcut('bookreader.shortcuts.previous_area',
    (ctx: any) => {
      ctx.prev()
    }, 'ArrowRight', '→'),
  new Shortcut('bookreader.shortcuts.next_area',
    (ctx: any) => {
      ctx.next()
    }, 'ArrowLeft', '←'),
  ...shortcutsPanCommon,
]

export const shortcutsSettingsPan = [
  new Shortcut('bookreader.shortcuts.toggle_pan_mode',
    (ctx: any) => ctx.togglePanMode()
    , 'z'),
]

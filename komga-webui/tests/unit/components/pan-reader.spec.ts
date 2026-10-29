import _ from 'lodash'
import {shallowMount, Wrapper} from '@vue/test-utils'
import PanReader from '@/components/readers/PanReader.vue'
import {PageDtoWithUrl} from '@/types/komga-books'
import {ReadingDirection} from '@/types/enum-books'

// jsdom viewport is 1024x768: at zoom 2 a 1200x1800 page is 1024x1536, so 3 areas from top to bottom
const pages = [1, 2, 3].map(n => ({number: n, width: 1200, height: 1800, url: `${n}.png`} as PageDtoWithUrl))

function mountReader(page = 1): Wrapper<any> {
  return shallowMount(PanReader, {
    propsData: {pages, page, zoom: 2, animations: true, readingDirection: ReadingDirection.LEFT_TO_RIGHT},
    mocks: {$_: _, $debug: () => undefined},
  })
}

function image(wrapper: Wrapper<any>): HTMLElement {
  return wrapper.find('img.pan-image').element as HTMLElement
}

describe('PanReader intro', () => {
  beforeEach(() => jest.useFakeTimers())
  afterEach(() => jest.useRealTimers())

  test('it should show the full page for 1.5s, then glide to the first area in 2.5s', async () => {
    const wrapper = mountReader()
    await wrapper.find('img.pan-image').trigger('load')

    expect(image(wrapper).style.transform).toEqual('translate3d(256px, 0px, 0) scale(0.5)')

    jest.advanceTimersByTime(1499)
    await wrapper.vm.$nextTick()
    expect(image(wrapper).style.transform).toContain('scale(0.5)')

    jest.advanceTimersByTime(1)
    await wrapper.vm.$nextTick()
    expect(image(wrapper).style.transform).toEqual('translate3d(0px, 0px, 0) scale(1)')
    expect(image(wrapper).style.transition).toContain('2500ms')

    jest.advanceTimersByTime(2500)
    await wrapper.vm.$nextTick()
    expect(wrapper.vm.introActive).toBe(false)
    expect(image(wrapper).style.transform).toEqual('translate3d(0px, 0px, 0) scale(1)')
  })

  test('given a tap during the intro then it should skip to the first area without advancing', async () => {
    const wrapper = mountReader()
    await wrapper.find('img.pan-image').trigger('load')

    wrapper.vm.next()
    await wrapper.vm.$nextTick()

    expect(wrapper.vm.introActive).toBe(false)
    expect(wrapper.vm.resolvedStopIndex).toEqual(0)
    expect(image(wrapper).style.transform).toEqual('translate3d(0px, 0px, 0) scale(1)')
  })

  test('given the next page opens then it should replay the intro', async () => {
    const wrapper = mountReader()
    wrapper.vm.finishIntro()
    wrapper.vm.stopIndex = 2

    wrapper.vm.next()
    expect(wrapper.emitted('update:page')![0]).toEqual([2])
    await wrapper.setProps({page: 2})

    expect(wrapper.vm.introActive).toBe(true)
    expect(image(wrapper).style.transform).toContain('scale(0.5)')
  })

  test('given going back to the previous page then it should land on its last area without intro', async () => {
    const wrapper = mountReader(2)
    wrapper.vm.finishIntro()

    wrapper.vm.prev()
    expect(wrapper.emitted('update:page')![0]).toEqual([1])
    await wrapper.setProps({page: 1})

    expect(wrapper.vm.introActive).toBe(false)
    expect(image(wrapper).style.transform).toEqual('translate3d(0px, -768px, 0) scale(1)')
  })
})

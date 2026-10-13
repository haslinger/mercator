// Drag & drop sorting with SortableJS (#62), for flat and nested lists.
//
// Put phx-hook="Sortable" on a container with a unique id. Every element
// inside with [data-sortable-list] becomes a sortable list; lists with the
// same data-group can exchange items (nested trees). Items need data-id,
// lists may carry data-parent-id. After a drop, the hook pushes the event
// named in the container's data-event (default "reorder") with
// {id, parent_id, index}.
import Sortable from "../../vendor/sortable.esm.js"

export const SortableHook = {
  mounted() { this.init() },
  updated() { this.init() },
  destroyed() { this.destroy() },

  init() {
    this.destroy()
    const event = this.el.dataset.event || "reorder"

    this.sortables = [...this.el.querySelectorAll("[data-sortable-list]")].map((list) =>
      Sortable.create(list, {
        group: list.dataset.group || this.el.id,
        handle: "[data-sortable-handle]",
        animation: 150,
        fallbackOnBody: true,
        swapThreshold: 0.65,
        ghostClass: "opacity-40",
        onEnd: (evt) => {
          if (evt.from === evt.to && evt.oldIndex === evt.newIndex) return
          this.pushEvent(event, {
            id: evt.item.dataset.id,
            parent_id: evt.to.dataset.parentId || null,
            index: evt.newIndex,
          })
        },
      })
    )
  },

  destroy() {
    (this.sortables || []).forEach((sortable) => sortable.destroy())
    this.sortables = []
  },
}

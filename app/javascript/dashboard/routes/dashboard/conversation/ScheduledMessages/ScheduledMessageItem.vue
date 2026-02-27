<template>
  <div
    class="flex flex-col gap-2 p-3 bg-n-alpha-1 border border-n-weak rounded-md"
  >
    <div class="flex items-center justify-between">
      <h4 class="text-sm font-semibold text-n-slate-12 m-0">
        {{ message.title }}
      </h4>
      <div class="flex items-center gap-1">
        <button
          v-if="message.status === 'pending'"
          @click="$emit('edit', message)"
          class="p-1 hover:bg-n-alpha-2 rounded text-n-slate-10"
        >
          <span class="i-lucide-pencil" />
        </button>
        <button
          v-if="message.status === 'pending'"
          @click="$emit('delete', message.id)"
          class="p-1 hover:bg-n-blue-10 rounded text-n-slate-10"
        >
          <span class="i-lucide-trash" />
        </button>
      </div>
    </div>
    <p class="text-sm text-n-slate-11 line-clamp-2 m-0">
      {{ message.content }}
    </p>
    <div class="flex items-center justify-between mt-2">
      <span class="text-xs text-n-slate-10">
        {{ new Date(message.scheduled_at * 1000).toLocaleString() }}
      </span>
      <span
        class="text-xs px-2 py-0.5 rounded-full"
        :class="{
          'bg-n-orange-3 text-n-orange-11': message.status === 'pending',
          'bg-n-green-3 text-n-green-11': message.status === 'sent',
          'bg-n-red-3 text-n-red-11': message.status === 'cancelled',
        }"
      >
        {{ message.status }}
      </span>
    </div>
  </div>
</template>

<script>
export default {
  props: {
    message: {
      type: Object,
      required: true,
    },
  },
};
</script>

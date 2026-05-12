<template>
  <div class="flex flex-1 gap-4 p-4 overflow-x-auto">
    <div
      v-for="i in 4"
      :key="i"
      class="min-w-[280px] max-w-[320px] rounded-xl border border-n-weak bg-n-solid-2 p-3"
    >
      <div class="h-5 w-1/2 bg-n-alpha-1 rounded animate-pulse mb-4" />
      <div
        v-for="j in 2"
        :key="j"
        class="h-20 bg-n-alpha-1 rounded-lg animate-pulse mb-2"
      />
    </div>
  </div>
</template>

<script setup>
// Skeleton loader for Kanban board
</script>

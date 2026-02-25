<template>
  <div class="kanban-skeleton">
    <div v-for="i in 3" :key="i" class="column-skeleton">
      <div class="header-skeleton pulse"></div>
      <div v-for="j in 2" :key="j" class="card-skeleton pulse"></div>
    </div>
  </div>
</template>

<script setup>
// Skeleton loader for Kanban board
</script>

<style lang="scss" scoped>
.kanban-skeleton {
  display: flex;
  gap: var(--space-normal);
  padding: var(--space-normal);
  overflow-x: auto;
  flex: 1;
}

.column-skeleton {
  min-width: 300px;
  max-width: 300px;
  background: var(--white);
  border-radius: var(--border-radius-medium);
  padding: var(--space-small);
  border: 1px solid var(--color-border);
}

.header-skeleton {
  height: 20px;
  width: 50%;
  background: var(--s-100);
  border-radius: 4px;
  margin-bottom: var(--space-normal);
}

.card-skeleton {
  height: 80px;
  background: var(--s-50);
  border-radius: var(--border-radius-small);
  margin-bottom: var(--space-smaller);
}

.pulse {
  animation: pulse 1.5s infinite;
}

@keyframes pulse {
  0% {
    opacity: 0.6;
  }
  50% {
    opacity: 1;
  }
  100% {
    opacity: 0.6;
  }
}
</style>

<script lang="ts">
    import { createEventDispatcher } from "svelte";

    export let value = true;

    const dispatch = createEventDispatcher<{value: boolean}>();

    function onClick() {
        value = !value;
        dispatch("value", value);
    }
</script>

<div on:click={onClick}>
    <svg class:active={value} width="16" height="16" viewBox="0 0 16 16" xmlns="http://www.w3.org/2000/svg" fill="currentColor"><path fill-rule="evenodd" clip-rule="evenodd" d="M14.431 3.323l-8.47 10-.79-.036-3.35-4.77.818-.574 2.978 4.24 8.051-9.506.764.646z"/></svg>
</div>

<style>
    div {
        display: inline-flex;
        padding: 2px;
        
        background-color: var(--vscode-settings-checkboxBackground);
        border: var(--vscode-settings-checkboxBorder) 1px solid;
        border-radius: 4px;
    }

    svg {
        color: rgba(0, 0, 0, 0);
    }

    svg.active {
        color: var(--vscode-settings-checkboxForeground);
    }
</style>
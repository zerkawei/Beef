<script lang="ts">
    import { createEventDispatcher } from "svelte";

    export let value = 0;

    const dispatch = createEventDispatcher<{value: number}>();

    function onKeyPress(event: KeyboardEvent) {
        if (event.key !== "-" && (event.key < "0" || event.key > "9")) event.preventDefault();
    }
</script>

<input type="number" step="1" bind:value={value} on:keypress={onKeyPress} on:change={() => dispatch("value", value)}>

<style>
    input {
        padding: 4px;
        min-width: 25rem;
        
        background-color: var(--vscode-settings-numberInputBackground);
        color: var(--vscode-settings-numberInputForeground);
        border: 1px solid var(--vscode-settings-numberInputBorder);
    }

    input:focus {
        outline: none;
    }
</style>
<script lang="ts">
    import { createEventDispatcher } from "svelte";

    export let value = "";
    export let width = "25rem";

    const dispatch = createEventDispatcher<{value: string}>();
</script>

<input type="text" style={"min-width: " + width} bind:value={value} on:change={() => dispatch("value", value)}>

<style>
    input {
        padding: 4px;
        
        background-color: var(--vscode-settings-textInputBackground);
        color: var(--vscode-settings-textInputForeground);
        border: 1px solid var(--vscode-settings-textInputBorder);
    }

    input:focus {
        outline: none;
    }
</style>
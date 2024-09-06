<script lang="ts">
    import { createEventDispatcher } from "svelte";

    const dispatch = createEventDispatcher();
</script>

<input type="button" value="Add" on:click={() => dispatch("click")}>

<style>
    input:focus {
        outline: none;
    }

    input {
        align-self: center;
        padding: 0.25rem;
        cursor: pointer;
        width: 100%;
        
        background-color: var(--vscode-editorWidget-background);
        color: var(--vscode-editorWidget-foreground);
        border: 1px solid var(--vscode-editorWidget-border);
    }

    input:hover {
        background-color: var(--vscode-editorHoverWidget-background);
        color: var(--vscode-editorHoverWidget-foreground);
        border: 1px solid var(--vscode-editorHoverWidget-border);
    }
</style>
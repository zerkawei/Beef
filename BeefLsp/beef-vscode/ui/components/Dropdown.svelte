<script lang="ts">
    import { createEventDispatcher } from "svelte";

    export let values: string[];
    export let value = "";
    export let disabled = false;

    const dispatch = createEventDispatcher<{value: string}>();
</script>

<select bind:value={value} on:change={() => dispatch("value", value)} disabled={disabled}>
    {#each values as value}
        <option>{value}</option>
    {/each}
</select>

<style>
    select {
        padding: 2px 8px;
        cursor: pointer;
        height: 25px;

        background-color: var(--vscode-settings-dropdownBackground);
        color: var(--vscode-settings-dropdownForeground);
        border: 1px solid var(--vscode-settings-dropdownBorder);
    }

    select::after {
        content: "\eab4";
    }

    select:focus {
        outline: none;
    }

    select:disabled {
        color: var(--vscode-settings-dropdownForeground);
        opacity: 0.5;
        cursor: default;
    }
</style>
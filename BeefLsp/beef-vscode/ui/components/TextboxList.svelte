<script lang="ts">
    import ExpandButton from "./ExpandButton.svelte";
    import Textbox from "./Textbox.svelte";
    import AddButton from "./AddButton.svelte";
    import { createEventDispatcher } from "svelte";
    import { equals } from "../utils";

    export let value: string[] = [];
    let expanded = false;

    const disaptch = createEventDispatcher<{value: string[]}>();

    function parseCombined(str: string) {
        const prev = value;

        value = str.split(";");
        value = value.filter(str => str.length > 0);
        
        if (!equals(prev, value)) disaptch("value", value);
    }

    function set(i: number, str: string) {
        const prev = value;

        value[i] = str;
        value = value.filter(str => str.length > 0);

        if (!equals(prev, value)) disaptch("value", value);
    }

    function add() {
        value.push("");
        value = value;
    }
</script>

<div>
    <div class="main">
        <ExpandButton bind:expanded={expanded} />
        <Textbox value={value.join(";")} width="calc(25rem - (16px + 0.5rem))" on:value={event => parseCombined(event.detail)} />
    </div>

    {#if expanded}
        <div class="list">
            {#each value as str, i}
                <Textbox value={str} width="calc(25rem - (16px + 0.5rem))" on:value={event => set(i, event.detail)} />
            {/each}
            
            <AddButton on:click={add} />
        </div>
    {/if}
</div>

<style>
    .main {
        display: flex;
        gap: 0.5rem;
    }

    .list {
        display: flex;
        flex-direction: column;
        align-items: flex-start;
        gap: 0.25rem;
        
        margin-top: 0.5rem;
        margin-left: calc(16px + 0.5rem);
    }
</style>

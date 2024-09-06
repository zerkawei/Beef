<script lang="ts">
    import ExpandButton from "./ExpandButton.svelte";
    import AddButton from "./AddButton.svelte";
    import LocalSetting from "./LocalSetting.svelte";
    import { Setting } from "../settings";
    import { createEventDispatcher } from "svelte";

    export let selfSetting: Setting;
    export let value: any[];

    const dispatch = createEventDispatcher<{value: any[]}>();

    let expanded = false;
    let valueExpanded: boolean[] = [];

    function onValue(i: number, event: CustomEvent<any>) {
        value[i] = event.detail;
        value = value;

        dispatch("value", value);
    }

    function add() {
        const v: any = {};

        for (const key in selfSetting.defaultValues) {
            v[key] = selfSetting.defaultValues[key];
        }

        value.push(v);
        value = value;

        dispatch("value", value);
    }

    function remove(i: number) {
        value.splice(i, 1);
        value = value;

        valueExpanded.splice(i, 1);
        valueExpanded = valueExpanded;

        dispatch("value", value);
    }
</script>

<div>
    <div class="main">
        <ExpandButton bind:expanded={expanded} />
        <span>{value.length} {value.length == 1 ? "value" : "values"}</span>
    </div>

    {#if expanded}
        <div class="list">
            {#each value as v, j}
                <div class="value">
                    <div class="line"></div>

                    <div class="buttons">
                        <ExpandButton bind:expanded={valueExpanded[j]} />

                        <button on:click={() => remove(j)}>
                            <svg width="16" height="16" viewBox="0 0 16 16" xmlns="http://www.w3.org/2000/svg" fill="currentColor"><path fill-rule="evenodd" clip-rule="evenodd" d="M8 8.707l3.646 3.647.708-.707L8.707 8l3.647-3.646-.707-.708L8 7.293 4.354 3.646l-.707.708L7.293 8l-3.646 3.646.707.708L8 8.707z"/></svg>
                        </button>
                    </div>

                    <div class="settings">
                        {#each selfSetting.settings as setting, i}
                            {#if valueExpanded[j] || i === 0}
                                <span>{setting.name}</span>

                                <LocalSetting setting={setting} value={v} on:value={event => onValue(j, event)} />

                                {#if valueExpanded[j] && i < selfSetting.settings.length - 1}
                                    <div class="separator"></div>
                                {/if}
                            {/if}
                        {/each}
                    </div>
                </div>

                {#if j < value.length - 1}
                    <div class="holy">
                        <div class="line" style="margin: 0;"></div>
                        <div class="separator big"></div>
                    </div>
                {/if}
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

    .value {
        display: flex;
    }

    .line {
        width: 1px;
        background-color: var(--vscode-editor-foreground);
        opacity: 0.05;
        
        align-self: stretch;
    }

    .buttons {
        display: flex;
        flex-direction: column;
        align-items: center;
        gap: 0.25rem;

        margin: 0.4rem 0.25rem 0 0.25rem;
    }

    button {
        background-color: #0000;
        color: var(--vscode-editor-foreground);
        border: none;
        cursor: pointer;
        padding: 0;
    }

    .settings {
        display: grid;
        grid-template-columns: auto auto;
        gap: 0.25rem 1rem;
        align-items: center;
    }

    .holy {
        display: flex;
        width: 100%;

        margin: -0.25rem 0;
    }

    .separator {
        width: 100%;
        height: 1px;
        background-color: var(--vscode-editor-foreground);
        opacity: 0.05;

        grid-column-start: 1;
        grid-column-end: 3;
    }

    .big {
        margin: 1rem 0;
    }
</style>
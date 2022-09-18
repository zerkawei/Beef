<script lang="ts">
    import { Setting } from "../settings";
    import ExpandButton from "./ExpandButton.svelte";
    import LocalSetting from "./LocalSetting.svelte";
    import { createEventDispatcher } from "svelte";

    export let settings: Setting[];
    export let value: any;

    const dispatch = createEventDispatcher<{value: any}>();

    let expanded = false;

    function onValue(event: CustomEvent<any>) {
        value = event.detail;
        dispatch("value", value);
    }
</script>

<div>
    <div class="main">
        <ExpandButton bind:expanded={expanded} />
        <span>{settings.length} {settings.length === 1 ? "setting" : "settings"}</span>
    </div>

    {#if expanded}
        <div class="settings">
            {#each settings as setting, i}
                <span>{setting.name}</span>

                <LocalSetting setting={setting} value={value} on:value={onValue} />

                {#if i < settings.length - 1}
                    <div class="separator"></div>
                {/if}
            {/each}
        </div>
    {/if}
</div>

<style>
    .main {
        display: flex;
        gap: 0.5rem;
    }

    .settings {
        display: grid;
        grid-template-columns: auto auto;
        gap: 0.25rem 1rem;
        align-items: center;

        margin-top: 0.5rem;
        margin-left: calc(16px + 0.5rem);
    }

    .separator {
        width: 100%;
        height: 1px;
        background-color: var(--vscode-editor-foreground);
        opacity: 0.05;

        grid-column-start: 1;
        grid-column-end: 3;
    }
</style>
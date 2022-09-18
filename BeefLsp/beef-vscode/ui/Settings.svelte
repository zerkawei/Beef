<script lang="ts">
    import Dropdown from "./components/Dropdown.svelte";
    import GroupTabs from "./components/GroupTabs.svelte";
    import GroupSettings from "./components/GroupSettings.svelte";
    import Modal from "./components/Modal.svelte";

    import { initSettings, schema, currentGroup, setConfiguration, setPlatform, settingValues, Setting } from "./settings";

    initSettings();

    let settings: Setting[];
    $: {
        const group = $currentGroup;
        settings = group ? group.settings : [];
    }
</script>

<div>
    <div class="header">
        <div>
            <span>Configuration:</span>
            <Dropdown values={$schema.configurations} value={$schema.configuration} disabled={$currentGroup && !$currentGroup.configuration} on:value={event => setConfiguration(event.detail)} />
        </div>
        
        <div>
            <span>Platform:</span>
            <Dropdown values={$schema.platforms} value={$schema.platform} disabled={$currentGroup && !$currentGroup.platform} on:value={event => setPlatform(event.detail)} />
        </div>
    </div>

    <div class="groups">
        <GroupTabs />
        <div class="separator"></div>
        <GroupSettings settings={settings} />
    </div>

    {#if $settingValues.hasChanged()}
        <div class="bottomright">
            <input type="button" value="Apply" on:click={() => $settingValues.apply()}>
            <input type="button" value="Reset" on:click={() => $settingValues.reset()}>
        </div>
    {/if}

    <Modal />
</div>

<style>
    .header {
        display: flex;
        gap: 4rem;

        margin-top: 0.5rem;
        margin-bottom: 2rem;
    }

    .header span {
        margin-right: 0.25rem;
    }

    .groups {
        display: flex;
    }

    .separator {
        width: 1px;
        align-self: stretch;
        background-color: var(--vscode-editor-foreground);
        opacity: 0.05;

        margin-right: 2rem;
    }

    .bottomright {
        position: fixed;
        bottom: 1rem;
        right: 1rem;

        display: flex;
        gap: 1rem;
    }

    input {
        padding: 0.5rem;
        cursor: pointer;
        
        background-color: var(--vscode-editorWidget-background);
        color: var(--vscode-editorWidget-foreground);
        border: 1px solid var(--vscode-editorWidget-border);
    }

    input:hover {
        background-color: var(--vscode-editorHoverWidget-background);
        color: var(--vscode-editorHoverWidget-foreground);
        border: 1px solid var(--vscode-editorHoverWidget-border);
    }

    input:focus {
        outline: none;
    }
</style>
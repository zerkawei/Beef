<script lang="ts">
    import { schema, currentGroup, Group } from "../settings";

    let general: Group[];
    let targeted: Group[];

    $: {
        general = [];
        targeted = [];

        $schema.groups.forEach(group => {
            if (group.configuration) targeted.push(group);
            else general.push(group);
        });
    }
</script>

<div class="tabs">
    <div class="section">
        <span>General</span>
        {#each general as group}
            <input type="button" value={group.name} class:selected={group === $currentGroup} on:click={() => currentGroup.set(group)}>
        {/each}
    </div>

    <div class="section">
        <span>Targeted</span>
        {#each targeted as group}
            <input type="button" value={group.name} class:selected={group === $currentGroup} on:click={() => currentGroup.set(group)}>
        {/each}
    </div>
</div>

<style>
    .tabs, .section {
        display: flex;
        flex-direction: column;
        align-items: flex-start;
    }

    .tabs {
        gap: 0.5rem;
    }

    span {
        font-weight: bold;
        padding: 6px;
    }

    input {
        background-color: #0000;
        color: var(--vscode-editor-foreground);
        border: none;
        cursor: pointer;
        padding: 6px;
        width: 100%;
        text-align: left;

        padding-left: 1rem;
        padding-right: 2rem;
    }

    input:hover {
        background-color: var(--vscode-settings-rowHoverBackground);
    }

    .selected {
        background-color: var(--vscode-settings-focusedRowBackground);
    }

    input:focus {
        outline: none;
    }
</style>
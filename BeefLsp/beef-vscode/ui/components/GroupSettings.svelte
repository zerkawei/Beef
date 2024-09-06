<script lang="ts">
    import { currentGroup, Setting, settingValues } from "../settings";
    import GlobalSetting from "./GlobalSetting.svelte";

    export let settings: Setting[];

    type Section = {
        name: string;
        settings: Setting[];
    };

    let sections: Section[];

    function getSection(name: string): Section {
        const result = sections.filter(value => value.name === name);

        if (result.length == 0) {
            const section: Section = {
                name: name,
                settings: []
            };

            sections.push(section);
            return section;
        }

        return result[0];
    }

    $: {
        sections = [];

        settings.forEach(setting => {
            const sectionName = setting.name.includes(";") ? setting.name.substring(0, setting.name.indexOf(";")) : "";
            const section = getSection(sectionName);
    
            section.settings.push(setting);
        });
    }
</script>

<div class="group">
    {#each sections as section}
        <div>
            {#if section.name !== ""}
                <span class="name">{section.name}</span>
            {/if}

            <div class="settings">
                {#each section.settings as setting, i}
                    <div class:indent={section.name !== ""}>
                        {#if $settingValues.isChanged($currentGroup, setting)}
                            <span class="changed">*</span>
                        {/if}
                        <span>{setting.name.includes(";") ? setting.name.substring(setting.name.indexOf(";") + 1) : setting.name}</span>
                    </div>
                    
                    <GlobalSetting group={$currentGroup} setting={setting} />

                    {#if i < section.settings.length - 1}
                        <div class="separator"></div>
                    {/if}
                {/each}
            </div>
        </div>
    {/each}
</div>

<style>
    .group {
        display: flex;
        flex-direction: column;
        align-items: flex-start;
        gap: 1rem;
    }

    .settings {
        display: grid;
        grid-template-columns: auto auto;
        gap: 0.25rem 1rem;
        align-items: center;
    }

    .name {
        font-weight: bold;
    }

    .indent {
        margin-left: 1rem;
    }

    .changed {
        color: var(--vscode-settings-modifiedItemIndicator);
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
<script lang="ts">
    import { settingValues, Setting, Group } from "../settings";
    import Checkbox from "./Checkbox.svelte";
    import Dropdown from "./Dropdown.svelte";
    import IntEdit from "./IntEdit.svelte";
    import Textbox from "./Textbox.svelte";
    import TextboxList from "./TextboxList.svelte";
    import Object from "./Object.svelte";
    import ObjectList from "./ObjectList.svelte";

    export let group: Group;
    export let setting: Setting;

    function onValue(event: CustomEvent<any>) {
        $settingValues.set(group, setting, event.detail);
    }
</script>

<div>
    {#if setting.type === "bool"}
        <Checkbox value={$settingValues.getBool(group, setting)} on:value={onValue} />
    {:else if setting.type === "string"}
        <Textbox value={$settingValues.getString(group, setting)} on:value={onValue} />
    {:else if setting.type === "int"}
        <IntEdit value={$settingValues.getInt(group, setting)} on:value={onValue} />
    {:else if setting.type === "enum"}
        <Dropdown values={setting.values} value={$settingValues.getString(group, setting)} on:value={onValue} />
    {:else if setting.type === "string-list"}
        <TextboxList value={$settingValues.getList(group, setting)} on:value={onValue} />
    {:else if setting.type === "object"}
        <Object settings={setting.settings} value={$settingValues.getObject(group, setting)} on:value={onValue} />
    {:else if setting.type === "object-list"}
        <ObjectList selfSetting={setting} value={$settingValues.getList(group, setting)} on:value={onValue} />
    {:else}
        <span>Not implemented</span>
    {/if}
</div>

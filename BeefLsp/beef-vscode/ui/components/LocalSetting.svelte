<script lang="ts">
    import { createEventDispatcher } from "svelte";
    import { Setting } from "../settings";
    import { clone, equals } from "../utils";

    import Checkbox from "./Checkbox.svelte";
    import Textbox from "./Textbox.svelte";
    import IntEdit from "./IntEdit.svelte";
    import Dropdown from "./Dropdown.svelte";
    import TextboxList from "./TextboxList.svelte";
    import Object from "./Object.svelte";

    export let setting: Setting;
    export let value: any;

    const dispatch = createEventDispatcher<{value: any}>();

    function onValue(setting: Setting, event: CustomEvent<any>) {
        const changed = !equals(value[setting.name], event.detail);

        value[setting.name] = event.detail;
        value = value;

        if (changed) dispatch("value", value);
    }
</script>

<div>
    {#if setting.type === "bool"}
        <Checkbox value={value[setting.name]} on:value={event => onValue(setting, event)} />
    {:else if setting.type === "string"}
        <Textbox value={value[setting.name]} on:value={event => onValue(setting, event)} />
    {:else if setting.type === "int"}
        <IntEdit value={value[setting.name]} on:value={event => onValue(setting, event)} />
    {:else if setting.type === "enum"}
        <Dropdown values={setting.values} value={value[setting.name]} on:value={event => onValue(setting, event)} />
    {:else if setting.type === "string-list"}
        <TextboxList value={value[setting.name]} on:value={event => onValue(setting, event)} />
    {:else if setting.type === "object"}
        <Object settings={setting.settings} value={clone(value[setting.name])} on:value={event => onValue(setting, event)} />
    {:else}
        <span>Not implemented</span>
    {/if}
</div>
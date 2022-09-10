import { h } from "preact";

type Props = {
    values: string[];
    value?: string;

    onChange?: (value: string) => void;
};

export default function(props: Props) {
    function onChange(event: Event) {
        if (props.onChange) props.onChange(props.values[(event.target as HTMLSelectElement).selectedIndex]);
    }

    return <select onChange={onChange}>
        {props.values.map(value =>
            <option selected={value === props.value}>{value}</option>
        )}
    </select>;
};
import { h } from "preact";

type Props = {
    value?: string;

    onChange?: (value: string) => void;
};

export default function(props: Props) {
    function onChange(event: Event) {
        if (props.onChange) props.onChange((event.target as HTMLInputElement).value);
    }

    return <input type="text" value={props.value} onChange={onChange} />
}
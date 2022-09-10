import { h, render } from "preact";
import Dropdown from "./dropdown";
import Textbox from "./textbox";

function Workspace() {
    return <div>
        <Dropdown values={["Omg", "Yoo", "LoL"]} value="Yoo" /><br />
        <Textbox />
    </div>;
}

window.addEventListener("message", event => {
    const message = event.data;

    if (message.command === "data") console.log(JSON.parse(message.data));
});

render(<Workspace />, document.getElementById("app"));
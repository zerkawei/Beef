const fs = require("fs");
const yaml = require("js-yaml");

const name = "beef";

let rawContents = fs.readFileSync("syntaxes/" + name + ".yaml");
let contents = yaml.load(rawContents);

function preprocess(object) {
    for (let name in object) {
        let value = object[name];
        let type = typeof value;

        if (type === "string") {
            while (true) {
                let matches = /_([a-zA-Z]+)_/g.exec(value);

                if (matches) {
                    let replacement = contents["regex"][matches[1]];
                    if (replacement) value = object[name] = value.replace(matches[0], replacement);
                }
                else break;
            }
        }

        if (type === "object") preprocess(value);
    }
}

preprocess(contents);
delete contents["regex"];

fs.writeFileSync("syntaxes/" + name + ".tmLanguage.json", JSON.stringify(contents, null, 4));
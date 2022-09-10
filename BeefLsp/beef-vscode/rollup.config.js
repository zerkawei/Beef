import { defineConfig } from "rollup";
import jsx from "acorn-jsx";
import resolve from "@rollup/plugin-node-resolve";
import commonjs from "@rollup/plugin-commonjs";
import typescript from "rollup-plugin-ts";
import external from "@yelo/rollup-node-external";
import postcss from "rollup-plugin-postcss";

const ext = external();

export default [
    // Extension
    defineConfig({
        input: "src/extension.ts",
        output: {
            file: "out/extension.js",
            format: "cjs",
            sourcemap: true
        },
        external: (id) => {
            if (id === "vscode") return true;
            return ext(id);
        },
        plugins: [
            resolve(),
            commonjs(),
            typescript({
                tsconfig: {}
            })
        ]
    }),

    // UI Workspace
    defineConfig({
        input: "ui/workspace.tsx",
        output: {
            file: "out/ui/workspace.js"
        },
        acornInjectPlugins: [jsx()],
        plugins: [
            resolve(),
            commonjs(),
            typescript({
                tsconfig: {
                    jsx: "react",
                    jsxFactory: "h"
                }
            })
        ]
    }),

    // UI style.css
    defineConfig({
        input: "ui/style.css",
        output: {
            file: "out/ui/style.css"
        },
        plugins: [postcss({
            modules: true,
            extract: true
        })]
    })
];
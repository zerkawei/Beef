import esbuild from "esbuild";
import svelte from "esbuild-svelte";
import preprocess from "svelte-preprocess";
import fs from "fs";
import chokidar from "chokidar";

/**
 * @param {esbuild.BuildOptions} options 
 */
function build(options) {
    let start = new Date();

    esbuild.build(options).then(() => {
        let duration = (new Date() - start) / 1000;
        console.log("Built " + options.entryPoints[0] + " in " + duration + "s");
    });
}

function watch(path, callback) {
    chokidar.watch(path).on("change", callback);
}

fs.rmSync("out", { recursive: true, force: true });

// Extension
function buildExtension() {
    build({
        entryPoints: [ "src/extension.ts" ],
        outdir: "out",
        bundle: true,
        minify: process.argv.includes("-p"),
        external: [ "vscode" ],
        format: "cjs",
        platform: "node"
    });
}

// UI
function buildUI() {
    // Settings
    build({
        entryPoints: [ "ui/settings.js" ],
        mainFields: ["svelte", "browser", "module", "main"],
        outdir: "out",
        bundle: true,
        minify: process.argv.includes("-p"),
        plugins: [
            svelte({
                preprocess: preprocess()
            })
        ]
    });
}

// Build
buildExtension();
buildUI();

// Watch
if (process.argv.includes("-w")) {
    watch("src", buildExtension);
    watch("ui", buildUI);
}
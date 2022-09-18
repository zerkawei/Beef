<script context="module" lang="ts">
    let mOpenModal: { (text: string, buttons: string[], callback: { (value: number): void }): void };

    export function openModal(text: string, buttons: string[], callback: { (value: number): void }) {
        mOpenModal(text, buttons, callback);
    }
</script>

<script lang="ts">
    import { onDestroy } from "svelte";

    let mVisible = false;
    let mCallback: { (value: number): void };
    let div: HTMLDivElement;

    let mText: string = "";
    let mButtons: string[] = [];

    function onKeyPress(event: KeyboardEvent) {
        if (event.key === "Escape") close(-1);
    }

    mOpenModal = (text, buttons, callback) => {
        if (mVisible) return;

        mVisible = true;
        mCallback = callback;
        mText = text;
        mButtons = buttons;

        window.addEventListener("keydown", onKeyPress);
        document.body.style.overflow = "hidden";
        document.body.appendChild(div);
    };

    function close(value: number) {
        if (!mVisible) return;

        mVisible = false;

        window.removeEventListener("keydown", onKeyPress);
        document.body.style.overflow = "";

        mCallback(value);
    }

    onDestroy(() => {
        window.removeEventListener("keydown", onKeyPress);
    });
</script>

<div id="topModal" class:visible={mVisible} bind:this={div} on:click={() => close(-1)}>
	<div id="modal" on:click|stopPropagation={() => {}}>
		<div id="modal-content">
			<p>{mText}</p>

            <div class="buttons">
                {#each mButtons as button, i}
                    <input type="button" value={button} on:click={() => close(i)}>
                {/each}
            </div>
		</div>
	</div>
</div>

<style>
	#topModal {
		visibility: hidden;
		z-index: 9999;
		position: fixed;
		top: 0;
		left: 0;
		right: 0;
		bottom: 0;
		background: #4448;
		display: flex;
		align-items: center;
		justify-content: center;
	}

	#modal {
		position: relative;
		padding: 1em;

        background-color: var(--vscode-panel-background);
        border: 1px solid var(--vscode-panel-border);
        box-shadow: rgb(0 0 0 / 44%) 0px 0px 8px 2px;
	}

	.visible {
		visibility: visible !important;
	}

	#modal-content {
		max-width: calc(100vw - 20px);
		max-height: calc(100vh - 20px);
		overflow: auto;
	}

    p {
        margin: 0;
        margin-bottom: 1rem;
    }

    .buttons {
        display: flex;
        justify-content: space-between;

        gap: 1rem;
    }

    input {
        background-color: var(--vscode-button-secondaryBackground);
        color: var(--vscode-button-secondaryForeground);
        border: 1px solid var(--vscode-button-border);

        padding: 0.5rem;
        cursor: pointer;
    }

    input:hover {
        background-color: var(--vscode-button-secondaryHoverBackground);
    }
</style>
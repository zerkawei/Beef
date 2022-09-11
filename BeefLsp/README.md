# Beef LSP
Language server implementation for Beef.  
Status: WIP

## Implemented Features
 - Initialization
 - Shutdown
 - Diagnostics
 - Folding ranges
 - Completions
 - Document symbols
 - Signature help
 - Hover
 - Go to definition
 - Find references
 - Workspace symbols
 - Renaming
 - Semantic Tokens

## Implemented transports
 - Stdio
 - Tcp

## Using
 - Download latest release and extract the zip file
 - Put the .exe file somewhere on your path
 - Put the .dll file inside \<beef installation folder>/BeefLang/bin, be sure to backup the file that is already there because with the modified file Beef Lsp needs the IDE might crash at certain actions
 - In VS Code under the extensions tab click on the 3 dots and click on "Install from VSIX..." and select the .vsix file from the zip
 - Open a Beef workspace folder and it should work
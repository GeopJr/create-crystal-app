<p align="center">
  <img alt="branding" src="https://i.imgur.com/kSSSree.png">
</p>
<h1 align="center">Create Crystal App</h1>
<h4 align="center">An unopinionated user-friendly crystal init alternative</h4>

## Demo

<p align="center">
  <img width="768" alt="demo gif of create crystal app in action" src="https://i.imgur.com/KiZsMHF.gif">
</p>

## Installation

Grab the latest *static linked* binary from the [releases page](https://github.com/GeopJr/create-crystal-app/releases/latest).

All binaries are being built and pushed by our lovely github actions. Feel free to take a look at them or build it yourself!

## Usage

With the powers of [crystal-term/prompt](https://github.com/crystal-term/prompt), cca comes with a beautiful interactive CLI menu, allowing you to pick between all the available options with ease!

## FaQ

- Why?
- `crystal init` is quite a bit opinionated, for example: it comes with MIT license, assumes you are using github, comes with travis-ci config and so on.
#
- Why is `--ignore-crystal-version` required?
- Many of the shards cca depends on are not updated for 1.0.0 (they work like a charm though).
#
- Why not ecr?
- I needed more control over the file structure which ecr doesn't provide. Thankfully there are many template engines for Crystal like crustache and crinja. For bundling the files into the binary I used baked_file_system.

## X is missing

Feel free to open an issue or a PR!
For the most part everything is automatic and you only need to create the template file under `templates/`.

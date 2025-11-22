# Odin Hot Reload Raylib Template

inpired heavily by [Karl Zylinski](https://github.com/karl-zylinski/odin-raylib-hot-reload-game-template)

## Dependencies

- Odin compiler (dev-2025-11).

yes, only 1 dependency - the compiler of the project's language

## Usage

To print the usage info run:
```sh
odin run .
```

The entire build pipeline is in the `./build.odin` and `./src/engine_*/engine.odin`

All build artifacts will be in the `./.build` directory.

### Example usage:

1. Run `odin run . -- dev run`
2. Wait a few seconds for the program to build the engine and the app
3. Change the `src/app.odin` and hit save
4. Within a second the app will reflect the change
5. Profit.

> [!NOTE]
> Tested on Linux, Windows should be working, but i havent tested there yet.

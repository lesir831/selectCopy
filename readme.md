# SelectCopy

A macOS simple and efficient text copying tool that makes your copy operations more convenient.

## Features

- **Quick Copy**: Hold the left mouse button to select text, then click the right mouse button to copy, without using the traditional Ctrl+C key combination
- **Simple Operation**: No additional keyboard shortcuts needed, just mouse operations
- **Improved Efficiency**: Reduces repetitive actions, making text copying more fluid and natural

## Compilation

To compile the program, use the following command:

```bash
clang -framework ApplicationServices -framework Cocoa -framework Foundation -framework QuartzCore -o select_copy select_copy.m
./select_copy
```

## How to Use

1. Hold down the left mouse button
2. Drag the mouse to select the text you want to copy
3. Click the right mouse button to automatically copy the selected text to the clipboard
4. Now you can paste the copied text anywhere

This project was inspired by the [Quicker](https://getquicker.net/KC/Manual/Doc/leftbuttonplus).


## License

MIT License
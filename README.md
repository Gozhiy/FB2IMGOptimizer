    # FB2IMGOptimizer

**FB2IMGOptimizer** is a command-line utility for optimizing images in FictionBook 2 (FB2) files.

The program identifies groups of images containing identical or nearly identical graphics and replaces references to them with a single representative image — the one that best matches the majority of images in the group.

**The program does not delete unused images from the FB2 file.** This is intentional:

- It allows the user to restore the original image references if a replacement produces an undesirable result.
- It allows the user to review the effect of optimization before deleting unused images.

After processing, unused images can be removed using the cleanup functionality of an FB2 editor, such as FictionBook Editor (FBE).

## Usage

```cmd
FB2IMGOptimizer.exe [InputFile] [-fi <InputFile>] [-fo <OutputFile>] [-fr <ReportFile>] [-D <Distance>] [-p <PercArea>]
```

The input file can be specified either as the first argument or with the `-fi` option.

### Parameters

| Parameter | Description | Default |
|---|---|---|
| `InputFile` | Input FB2 file (can be specified without `-fi`) | — |
| `-fi` | Explicitly specifies the input FB2 file | — |
| `-fo` | Output FB2 file | Input filename with `_optimized` suffix |
| `-fr` | Report file | `Report.txt` |
| `-D` | Maximum distance between image hashes | `14` |
| `-p` | Maximum allowed percentage difference in image area | `40` |

### Examples

Process an FB2 file using default settings:

```cmd
FB2IMGOptimizer.exe Book.fb2
```

The output file will be `Book_optimized.fb2`.

Specify the input file explicitly:

```cmd
FB2IMGOptimizer.exe -fi Book.fb2
```

Specify output and report files:

```cmd
FB2IMGOptimizer.exe Book.fb2 -fo Result.fb2 -fr Analysis.txt
```

Customize image matching parameters:

```cmd
FB2IMGOptimizer.exe Book.fb2 -D 14 -p 40
```

## Report

The program generates a report containing information about the image analysis and replacement results. The report filename can be specified using the `-fr` option.

## Requirements

- Windows 10 or later is recommended.
- No third-party components or additional runtime packages are required.

## License

See [LICENSE](LICENSE) for license information.
# gdc-compressor

Bash script built to efficiently compress Dreamcast GDI images, applying a configurable pipeline to each file in order to reach the maximum compression. The result is packed in a convenient single file.

The compression process is lossless, meaning you always get the exact same file after extraction.

gdc-compressor is actually a generic pipeline executor, so you can build your own configuration and use generic file list instead of a GDI file.

It was tested only on GNU/Linux, but it shouldn't be too hard to make it work on Mac OS or on Cygwin (Windows).

## How does it work?

Except for "store_only", the compression rules packaged in gdc-compressor do:

* ECM + XZ compression on bin files - ECM removes error correction bytes (and reconstruct them during extraction), which improves compression.
* Lossless audio compression to CDDA raw files. Algorithm differs among the available rules:
    * default: Uses flac --best.
    * flac_extreme: Uses flac with parameters that slightly improves compression, but it's incredible slow, so don't use it!
    * monkeys\_audio: Better than flac_extreme and very fast. It's not the default option because although open source, it's not free software.
* Plain XZ otherwise.

The parameters used for each tool is optimized for the highest compression.

## Results

All GDI dumps tested have an uncompressed size of ~1.2gb.

Compression was made on an old Xeon E31230 with 8gb of RAM with the default config.

### Aqua GT

Uses a lot of CDDA, therefore the compression rule chosen makes a considerable difference.


|                            | zip -9     | xz -9 -T 0 | GDC Default (flac --best) | GDC FLAC extreme     | GDC Monkey's audio |
|----------------------------|------------|------------|---------------------------|----------------------|--------------------|
| Compression time           | 1m4,493s   | 1m39,588s  | 4m13,047s                 | 43m28,582s (!)       | 4m33,712s          |
| Size (bytes)               | 334951292  | 274915796  | 189479530                 | 188598680            | 184233458          |
| Compression ratio          | 27.90%     | 22.90%     | 15.78%                    | 15.71%               | 15.35%             |
| Improvement over zip       |  N/A       | 17.92%     | 43.43%                    | 43.69%               | 45.00%             |




### Sonic Adventure

Does not use CDDA, so pipeline selection is irrelevant - most data comes from track01.bin and track03.bin.

|                      | zip -9     | xz -9 -T 0 | GDC Default (flac --best)        | GDC Monkey's audio |
|----------------------|------------|------------|----------------------------------|--------------------|
| Compression time     | 1m0,598s   | 2m32,316s  | 10m0,961s                        | 10m0,912s          |
| Size (bytes)         | 1070474979 | 986635372  | 823244460                        | 823346236          |
| Compression ratio    | 87.59%     | 80.73%     | 67.36%                           | 67.37%             |
| Improvement over zip | N/A        | 7.83%      | 23.10%                           | 23.09%             |



## Usage

### Installing dependencies

On systems with apt-get, the following line should take care of some of the external dependencies:

```
sudo apt install pv flac xz-utils coreutils
```

You also need to build and install libecm and rawaudioutil, which is very easy. Follow the instructions on their repositories:

* [libecm](https://github.com/aefermiano/libecm/)
* [rawaudioutil](https://github.com/aefermiano/rawaudioutil)

If you want to use Monkey's Audio, build and install this linux port:

* [Monkey's Audio](https://github.com/fernandotcl/monkeys-audio/)

and install the included "pipetofiles.sh" script:

```
sudo ./install_pipetofiles.sh
```

### Changing configuration

`config.sh` has some configurations which you may want to change.

The only really useful configuration is "XZ_MEMORY_LIMIT". The higher the memory limit, the better the compression will be. I recommend changing it to match your RAM (don't forget the memory used by the OS!).

### Using the CLI

Compressing a GDI using the default pipeline rule:

```
gdccompressor.sh --compress --gdi <gdi file> output.gdc
```

Compressing a GDI using Monkey's Audio:

```
gdccompressor.sh --compress --gdi <gdi file> --rules monkeys_audio output.gdc
```

Compressing an arbitrary file list into a GDC using the default pipeline:

```
gdccompressor.sh --compress --files psx_dump.bin output.gdc
```

Listing files on a GDC file:

```
gdccompressor.sh --list output.gdc
```

Extracting a GDC file:

```
gdccompressor.sh --extract output.gdc
```

### Installing the script

The easiest way to make the script available in your system is adding its folder to PATH variable in ~/.bashrc.

## Technical details

### Rules and pipelines

Rules are installed in "rules" folder, and specify which pipeline will be used for an specific file, using its filename as filter. For example, the default pipeline is:

```
*.bin;binary_data
*.raw;raw_audio_flac
*;default
```

So for a GDI, "track01.bin" will be compressed using the "binary_data" pipeline, "track02.raw" will be compressed using the "raw_audio_flac" and "game.gdi" will be compressed using the "default" pipeline.

Rules are evaluated in order.

Pipelines are installed in "pipelines" folder and specify which commands will be used for both compression and extraction. For example, the pipeline "raw_audio_flac":

```
compress;cat;_FILE_NAME_
compress;rawaudioutil;--raw2wav _FILE_SIZE_
compress;flac;--totally-silent --stdout --best -

extract;flac;--totally-silent --stdout --decode -
extract;rawaudioutil;--wav2raw 0
```

There are some tokens that may be included in the command (e.g: \_FILE_SIZE\_), please check `utils.sh` for more information on this.

Commands are evaluated in order and form a pipeline. For example, compressing a file using this pipeline would produce the following command line:

```
cat <filename> | rawaudioutil --raw2wav <filesize> | flac --totally-silent --stdout --best - | <command to append to gdc file>
```

However, the script will always add the `PROGRESS_COMMAND` configured in `config.sh` as the second parameter in the pipeline. This is used to show the progress bar. So the real encoding command line will be:

```
cat <filename> | pv --progress --timer --eta --rate --bytes --size <filesize> | rawaudioutil --raw2wav <filesize> | flac --totally-silent --stdout --best - | <command to append to gdc file>
```

Both compression and extraction commands are shown on the screen during the compression, so you can easily check what is happening under the hood.

Please notice that both rules and pipelines are used only in the compression stage. The commands for extraction are built in this stage and embedded into the GDC file.

### GDC format

GDC format is a little strange, but you need to consider it was designed to be used in bash and I wanted to make my life easier.

| Offset         | Content            |
| ---------------| -------------------|
| 0-3            | Magic work "GDC "  |
| 4-13           | Offset pointing header's location. It's formatted as ASCII representing an hexadecimal number.  |
| Starting at 14 | Compressed data of all files, without any framing, in the same order described in header. |
| End of file    | Header.            |

Header is uncompressed text with fields separated by ";". The fields are:

* File name.
* File size before compression.
* File size after compression.
* Hash, which is sha1sum in the default config. Hash is verified for each file during the extraction.
* Command line that should be used for extraction.

First two lines of an example header:

```
track01.bin;1422960;2040;ed54c6f5d2d1d87b3b60f8c4611e92184941e341;dd if=_FILE_NAME_ bs=2M iflag=skip_bytes,count_bytes skip=20 count=2040 status=none | xz -q --decompress | ecm2bin --stdin --stdout | pv --progress --timer --eta --rate --bytes --size _FILE_SIZE_ > 'track01.bin'
track02.raw;13994400;6879781;b643df4def042b6c23f90f54c690ac7df431233f;dd if=_FILE_NAME_ bs=2M iflag=skip_bytes,count_bytes skip=2060 count=6879781 status=none | flac --totally-silent --stdout --decode - | rawaudioutil --wav2raw 0 | pv --progress --timer --eta --rate --bytes --size _FILE_SIZE_ > 'track02.raw'
```

### pipetofiles

Some tools do not support reading from stdin or writing to stdout, either because it was not implemented or because they use fseek which is not supported in a stream.

As the result, they cannot be used in a pipeline right away.

`pipetofiles.sh` is a standalone script which makes this kind of command compatible by using intermediary files.

More information can be found inside the script.

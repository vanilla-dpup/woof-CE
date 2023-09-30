# Persistency Modes (PUPMODE)

* 5: no persistency ("live"); changes to the layered file system at / reside in RAM and a shutdown prompt offers the user to save them.
* 12: full persistency; changes are saved directly to a file system image ("save file") or a directory ("save folder") used as the upper, writable layer of the layered file system at /.
* 13: on-demand persistency; changes to the layered file system at / reside in RAM and can be saved to a file system image ("save file") or a directory ("save folder") using `save2flash` and during shutdown. PUPMODE 13 is activated when `pmedia=usbflash` or when the save partition is a removable drive and `pmedia` is unspecified or `pmedia=cd`.
* 128: used internally until changes in a live session are saved.

# Full PION data

The complete project dataset is stored in GitHub Release `full-data-v1`.

The release contains a split TAR archive because the complete project is larger than ordinary Git/Git-LFS free-plan limits.

To restore under Git Bash:

```bash
cat PION-full.tar.part-* > PION-full.tar
tar -xf PION-full.tar
```

`FULL_DATA_MANIFEST.tsv` records the original file paths and byte sizes.

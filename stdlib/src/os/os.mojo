# ===----------------------------------------------------------------------=== #
#
# This file is Modular Inc proprietary.
#
# ===----------------------------------------------------------------------=== #
"""Implements os methods.

You can import a method from the `os` package. For example:

```mojo
from os import listdir
```
"""

from sys.info import os_is_windows, os_is_linux
from collections import DynamicVector
from memory.unsafe import Pointer, DTypePointer
from .path import isdir
from .pathlike import PathLike

# ===----------------------------------------------------------------------=== #
# Utilities
# ===----------------------------------------------------------------------=== #


@value
@register_passable("trivial")
struct _dirent_linux:
    alias MAX_NAME_SIZE = 256
    var d_ino: Int64
    """File serial number."""
    var d_off: Int64
    """Seek offset value."""
    var d_reclen: Int16
    """Length of the record."""
    var d_type: Int8
    """Type of file."""
    var name: StaticTuple[Self.MAX_NAME_SIZE, Int8]
    """Name of entry."""


@value
@register_passable("trivial")
struct _dirent_macos:
    alias MAX_NAME_SIZE = 1024
    var d_ino: Int64
    """File serial number."""
    var d_off: Int64
    """Seek offset value."""
    var d_reclen: Int16
    """Length of the record."""
    var d_namlen: Int16
    """Length of the name."""
    var d_type: Int8
    """Type of file."""
    var name: StaticTuple[Self.MAX_NAME_SIZE, Int8]
    """Name of entry."""


fn _strnlen(ptr: Pointer[Int8], max: Int) -> Int:
    var len = 0
    while len < max and ptr.load(len):
        len += 1
    return len


struct _DirHandle:
    """Handle to an open directory descriptor opened via opendir."""

    var _handle: Pointer[NoneType]

    fn __init__(inout self, path: String) raises:
        """Construct the _DirHandle using the path provided.

        Args:
          path: The path to open.
        """
        constrained[
            not os_is_windows(), "operation is only available on unix systems"
        ]()

        if not isdir(path):
            raise "the directory '" + path + "' does not exist"

        self._handle = external_call["opendir", Pointer[NoneType]](
            path._as_ptr()
        )

        if not self._handle:
            raise "unable to open the directory '" + path + "'"

    fn __del__(owned self):
        """Closes the handle opened via popen."""
        _ = external_call["closedir", Int32](self._handle)

    fn list(self) -> DynamicVector[String]:
        """Reads all the data from the handle.

        Returns:
          A string containing the output of running the command.
        """

        @parameter
        if os_is_linux():
            return self._list_linux()
        else:
            return self._list_macos()

    fn _list_linux(self) -> DynamicVector[String]:
        """Reads all the data from the handle.

        Returns:
          A string containing the output of running the command.
        """
        var res = DynamicVector[String]()

        while True:
            var ep = external_call["readdir", Pointer[_dirent_linux]](
                self._handle
            )
            if not ep:
                break
            var name = ep.load().name
            var name_ptr = Pointer.address_of(name).bitcast[Int8]()
            var name_str = StringRef(
                name_ptr, _strnlen(name_ptr, _dirent_linux.MAX_NAME_SIZE)
            )
            if name_str == "." or name_str == "..":
                continue
            res.append(name_str)

        return res

    fn _list_macos(self) -> DynamicVector[String]:
        """Reads all the data from the handle.

        Returns:
          A string containing the output of running the command.
        """
        var res = DynamicVector[String]()

        while True:
            var ep = external_call["readdir", Pointer[_dirent_macos]](
                self._handle
            )
            if not ep:
                break
            var name = ep.load().name
            var name_ptr = Pointer.address_of(name).bitcast[Int8]()
            var name_str = StringRef(
                name_ptr, _strnlen(name_ptr, _dirent_macos.MAX_NAME_SIZE)
            )
            if name_str == "." or name_str == "..":
                continue
            res.append(name_str)

        return res


# ===----------------------------------------------------------------------=== #
# listdir
# ===----------------------------------------------------------------------=== #
fn listdir(path: String = "") raises -> DynamicVector[String]:
    """Gets the list of entries contained in the path provided.

    Args:
      path: The path to the directory.

    Returns:
      Returns the list of entries in the path provided.
    """

    var dir = _DirHandle(path)
    return dir.list()


fn listdir[
    pathlike: os.PathLike
](path: pathlike) raises -> DynamicVector[String]:
    """Gets the list of entries contained in the path provided.

    Parameters:
      pathlike: The a type conforming to the os.PathLike trait.

    Args:
      path: The path to the directory.


    Returns:
      Returns the list of entries in the path provided.
    """
    return listdir(path.__fspath__())

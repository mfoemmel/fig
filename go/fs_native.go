package fig

import "io"
import "os"

type nativeFileSystem struct {
}

func NewNativeFileSystem() FileSystem {
	return &nativeFileSystem{}
}

func (fs *nativeFileSystem) Exists(path string) bool {
	_, err := os.Stat(path)
	if err == nil {
		return true
	}
	if pathErr, ok := err.(*os.PathError); ok {
		if pathErr.Error == os.ENOENT {
			return false
		}
	}
	panic(err)
}

func (fs *nativeFileSystem) Size(path string) (int64, os.Error) {
	panic("not implemented")
}

func (fs *nativeFileSystem) OpenReader(path string) (io.ReadCloser, os.Error) {
	return os.Open(path, os.O_RDONLY, 0)
}

func (fs *nativeFileSystem) OpenWriter(path string) (io.WriteCloser, os.Error) {
	return os.Open(path, os.O_CREAT|os.O_WRONLY, 0666)
}

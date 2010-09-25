package fig

import "bytes"
import "fmt"
import "io"
import "os"

type memoryFileSystem struct {
	files map[string] []byte
}

type memoryFileSystemReader struct {
	data *bytes.Buffer
}

type memoryFileSystemWriter struct {
	fs *memoryFileSystem
	path string
	data *bytes.Buffer
}

func NewMemoryFileSystem() FileSystem {
	return &memoryFileSystem{make(map[string] []byte)}
}

func (fs *memoryFileSystem) Exists(path string) bool {
	_, exists := fs.files[path]
	return exists
}

func (fs *memoryFileSystem) Size(path string) (int64, os.Error) {
	if content, ok := fs.files[path]; ok {
		return int64(len(content)), nil
	}
	return -1, os.NewError("file not found")
}

func (fs *memoryFileSystem) OpenReader(path string) (io.ReadCloser, os.Error) {
	data, ok := fs.files[path]
	if !ok {
		return nil, os.NewError(fmt.Sprintf("File not found: %s", path))
	}
	return &memoryFileSystemReader{bytes.NewBuffer(data)}, nil
}

func (r *memoryFileSystemReader) Read(buf []byte) (int, os.Error) {
	return r.data.Read(buf)
}

func (r *memoryFileSystemReader) Close() os.Error {
	return nil
}

func (fs *memoryFileSystem) OpenWriter(path string) (io.WriteCloser, os.Error) {
	return &memoryFileSystemWriter{fs, path, bytes.NewBuffer(nil)}, nil
}

func (w *memoryFileSystemWriter) Write(buf []byte) (int, os.Error) {
	return w.data.Write(buf)
}

func (w *memoryFileSystemWriter) Close() os.Error {
	w.fs.files[w.path] = w.data.Bytes()
	return nil
}


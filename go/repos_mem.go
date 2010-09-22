package fig

import "bytes"
import "io"
import "os"
import "strings"

type memoryPackage struct {
	statements []PackageStatement
	archive *bytes.Buffer
}
type memoryRepository struct {
	packages map[string] *memoryPackage
}

type memoryRepositoryPackageReader struct {
	repo *memoryRepository
	pkg *memoryPackage
}

type memoryRepositoryPackageWriter struct {
	repo *memoryRepository
	pkg *memoryPackage
}

type bufferCloser struct {
	*bytes.Buffer
}

func (*bufferCloser) Close() os.Error {
	return nil
}

type memoryRepositoryResourceWriter struct {
	m *memoryRepositoryPackageWriter
	path string
}

func NewMemoryRepository() Repository {
	return &memoryRepository{make(map[string] *memoryPackage)}
}

func (m *memoryRepository) ListPackages() (<-chan Descriptor) {
	c := make(chan Descriptor, 100)
	go func() {
		for name, _ := range m.packages {
			packageVersion := strings.Split(name, "/", 2)
			c <- NewDescriptor(packageVersion[0], packageVersion[1], "")
		}
		close(c)
	}()
	return c
}

func (m *memoryRepository) NewPackageReader(packageName PackageName, versionName VersionName) PackageReader {
	key := makeKey(packageName, versionName)
	pkg, ok := m.packages[key]
	if !ok {
		return nil//, os.NewError("package not found: " + key)
	}
	return &memoryRepositoryPackageReader{m, pkg}
}

func (r *memoryRepositoryPackageReader) ReadStatements() ([]PackageStatement, os.Error) {
	return r.pkg.statements, nil
}

func (r *memoryRepositoryPackageReader) OpenArchive() (io.ReadCloser, os.Error) {
	return &bufferCloser{r.pkg.archive}, nil
}

func (m *memoryRepositoryPackageReader) Close() {
}

func (m *memoryRepository) NewPackageWriter(packageName PackageName, versionName VersionName) PackageWriter {
	key := makeKey(packageName, versionName)
	pkg, ok := m.packages[key]
	if !ok {
		pkg = &memoryPackage{nil, bytes.NewBuffer(nil)}
		m.packages[key] = pkg
//		return nil//, os.NewError("package not found: " + key)
	}
	return &memoryRepositoryPackageWriter{m, pkg}
}

func (w *memoryRepositoryPackageWriter) WriteStatements(stmts []PackageStatement) {
	w.pkg.statements = stmts
}

func (m *memoryRepositoryPackageWriter) OpenArchive() io.WriteCloser {
	return &bufferCloser{m.pkg.archive}
}

func (m *memoryRepositoryPackageWriter) Commit() {
}

func (m *memoryRepositoryPackageWriter) Close() {
}

func makeKey(packageName PackageName, versionName VersionName) string {
	return string(packageName) + "/" + string(versionName)
}

func (m *memoryRepositoryResourceWriter) Write(bytes []byte) (int,os.Error) {
	return 0, nil
}

func (m *memoryRepositoryResourceWriter) Close() os.Error {
	return nil
}

package fig

import "io"
import "os"
import "strings"

type memoryRepository struct {
	packages map[string] []PackageStatement
}

type memoryRepositoryPackageReader struct {
	repo *memoryRepository
	packageName PackageName
	versionName VersionName
}

type memoryRepositoryPackageWriter struct {
	repo *memoryRepository
	packageName PackageName
	versionName VersionName
}

func NewMemoryRepository() Repository {
	return &memoryRepository{make(map[string] []PackageStatement)}
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
	return &memoryRepositoryPackageReader{m, packageName, versionName}
}

func (r *memoryRepositoryPackageReader) ReadStatements() ([]PackageStatement, os.Error) {
	key := makeKey(r.packageName, r.versionName)
	stmts, ok := r.repo.packages[key]
	if !ok {
		return nil, os.NewError("package not found: " + key)
	}
	return stmts, nil
}

func (m *memoryRepositoryPackageReader) OpenResource(path string) io.ReadCloser {
	return nil
}

func (m *memoryRepositoryPackageReader) Close() {
}

func (m *memoryRepository) NewPackageWriter(packageName PackageName, versionName VersionName) PackageWriter {
	return &memoryRepositoryPackageWriter{m, packageName, versionName}
}

func (w *memoryRepositoryPackageWriter) WriteStatements(stmts []PackageStatement) {
	w.repo.packages[makeKey(w.packageName,w.versionName)] = stmts
}

func (m *memoryRepositoryPackageWriter) OpenResource(path string) io.WriteCloser {
	return nil
}

func (m *memoryRepositoryPackageWriter) Commit() {
}

func (m *memoryRepositoryPackageWriter) Close() {
}

func makeKey(packageName PackageName, versionName VersionName) string {
	return string(packageName) + "/" + string(versionName)
}

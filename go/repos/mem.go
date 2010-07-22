package repos

import "io"

import . "fig/model"

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
	return nil
}

func (m *memoryRepository) NewPackageReader(packageName PackageName, versionName VersionName) PackageReader {
	return &memoryRepositoryPackageReader{m, packageName, versionName}
}

func (r *memoryRepositoryPackageReader) ReadStatements() []PackageStatement {
	return r.repo.packages[string(r.packageName) + "/" + string(r.versionName)]
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
	w.repo.packages[string(w.packageName) + "/" + string(w.versionName)] = stmts
}

func (m *memoryRepositoryPackageWriter) OpenResource(path string) io.WriteCloser {
	return nil
}

func (m *memoryRepositoryPackageWriter) Commit() {
}

func (m *memoryRepositoryPackageWriter) Close() {
}

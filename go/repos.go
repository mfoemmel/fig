package fig

import "io"

type Repository interface {
	ListPackages() (<-chan Descriptor) 
	NewPackageReader(PackageName, VersionName) PackageReader
	NewPackageWriter(PackageName, VersionName) PackageWriter
}

type PackageReader interface {
	ReadStatements() []PackageStatement
	OpenResource(path string) io.ReadCloser
	Close()
}

type PackageWriter interface {
	WriteStatements([]PackageStatement)
	OpenResource(path string) io.WriteCloser
	Commit()
	Close()
}

func ReadPackage(repo Repository, packageName PackageName, versionName VersionName) *Package {
	r := repo.NewPackageReader(packageName, versionName)
	defer r.Close()
	return NewPackage(packageName, versionName, r.ReadStatements())
}

func WritePackage(repo Repository, pkg *Package) {
	w := repo.NewPackageWriter(pkg.PackageName, pkg.VersionName)
	defer w.Close()
	w.WriteStatements(pkg.Statements)
	w.Commit()
}


package repos

import "io"

import . "fig/model"

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

func ReadPackage(repo Repository, packageName PackageName, versionName VersionName) []PackageStatement {
	r := repo.NewPackageReader(packageName, versionName)
	defer r.Close()
	return r.ReadStatements()
}

func WritePackage(repo Repository, packageName PackageName, versionName VersionName, statements []PackageStatement) {
	w := repo.NewPackageWriter(packageName,versionName)
	defer w.Close()
	w.WriteStatements(statements)
	w.Commit()
}


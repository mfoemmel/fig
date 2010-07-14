package repos

import "os"
import "testing"

import . "fig/model"

func TestListPackages(t *testing.T) {
	r := resetRepos()
	r.AddPackage(NewPackage("bar","4.5.6",".",[]*Config{}))
	r.AddPackage(NewPackage("foo","1.2.3",".",[]*Config{}))
	expected := []Descriptor{
		NewDescriptor("bar","4.5.6",""),
		NewDescriptor("foo","1.2.3",""),
	}
	i := 0
	for descriptor := range r.ListPackages() {
		if i == len(expected) {
			t.Fatalf("Unexpected package: %s", descriptor)
		}
		if !descriptor.Equals(expected[i]) {
			t.Errorf("Expected: %s, got: %s",expected[i],descriptor)
		}
		i++
	}
	if i != len(expected) {
		t.Fatalf("Wrong number of packages, expected: %d, got: %d",len(expected),i)
	}
}

func TestAddPackage(t *testing.T) {
	r := resetRepos()
	pkg := NewPackage("baz","7.8.9",".",[]*Config{
		NewConfig("default"),
	})
	r.AddPackage(pkg)
	if ok, msg := ComparePackage(pkg, r.LoadPackage("baz","7.8.9")); !ok {
		t.Error(msg)
	}
}

func resetRepos() *fileRepository {
	path := "testrepos"
	os.RemoveAll(path)
	os.Mkdir(path,0777)
	return &fileRepository{path}
}

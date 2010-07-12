package repos

import "testing"

import . "fig/model"

func TestListPackages(t *testing.T) {
	r := &fileRepository{"test"}
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
	r := &fileRepository{"test"}
	pkg := NewPackage("baz","7.8.9",".",[]*Config{
		NewConfig("default"),
	})
	r.AddPackage(pkg)
	if ok, msg := ComparePackage(pkg, r.LoadPackage("baz","7.8.9")); !ok {
		t.Error(msg)
	}
}

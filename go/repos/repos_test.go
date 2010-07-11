package repos

import "testing"

import . "fig/model"

func TestFoo(t *testing.T) {
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

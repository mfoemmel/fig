package plan

import "testing"

import . "fig/model"
import . "fig/repos"

func TestNoDependencies(t *testing.T) {
	repo := NewMemoryRepository()
	WritePackage(repo, "foo", "1.2.3", []PackageStatement{
		NewConfigBlock(NewConfig("default")),
	})

	planner := NewPlanner(repo)
	configs, err := planner.Plan(NewDescriptor("foo","1.2.3","default"))
	if err != nil {
		t.Fatal(err)
	}
	if len(configs) != 1 {
		t.Errorf("Expected 1 config, got: %d", len(configs))
	}
}

func TestSimpleDependency(t *testing.T) {
	repo := NewMemoryRepository()
	WritePackage(repo, "foo", "1.2.3", []PackageStatement{
		NewConfigBlock(NewConfig("default", NewIncludeStatement(NewDescriptor("bar","4.5.6","default")))),
	})
	WritePackage(repo, "bar", "4.5.6", []PackageStatement{
		NewConfigBlock(NewConfig("default")),
	})
	planner := NewPlanner(repo)
	configs, err := planner.Plan(NewDescriptor("foo","1.2.3","default"))
	if err != nil {
		t.Fatal(err)
	}
	if len(configs) != 2 {
		t.Errorf("Expected 2 configs, got: %d", len(configs))
	}
}

func TestTransitiveDependency(t *testing.T) {
	repo := NewMemoryRepository()
	WritePackage(repo, "foo", "1.2.3", []PackageStatement{
		NewConfigBlock(NewConfig("default", NewIncludeStatement(NewDescriptor("bar","4.5.6","default")))),
	})
	WritePackage(repo, "bar", "4.5.6", []PackageStatement{
		NewConfigBlock(NewConfig("default", NewIncludeStatement(NewDescriptor("baz","7.8.9","default")))),
	})
	WritePackage(repo, "baz", "7.8.9", []PackageStatement{
		NewConfigBlock(NewConfig("default")),
	})
	planner := NewPlanner(repo)
	configs, err := planner.Plan(NewDescriptor("foo","1.2.3","default"))
	if err != nil {
		t.Fatal(err)
	}
	if len(configs) != 3 {
		t.Errorf("Expected 3 configs, got: %d", len(configs))
	}
}

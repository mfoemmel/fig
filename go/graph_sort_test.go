package fig

import "testing"

func ids(nodes []Node) []string {
	ids := make([]string, len(nodes))
	for i, node := range nodes {
		ids[i] = node.Id()
	}
	return ids
}

func TestSort(t *testing.T) {
	a := NewTestNode("a")
	b := NewTestNode("b")
	a.children.Push(b)
	sorted := Sort(a)
	if len(sorted) != 2 {
		t.Error("Unexpected number of nodes: %d", len(sorted))
	}
	if sorted[0].Id() != "b" {
		t.Errorf("Expected node: 'b', got: %s", sorted[0].Id())
	}
	//if sorted[1].Id() != "a" {
	//    t.Errorf("Expected node: 'a', got: %s", sorted[1].Id())
	//}
}

func TestSortDiamond(t *testing.T) {
	a := NewTestNode("a")
	b := NewTestNode("b")
	c := NewTestNode("c")
	d := NewTestNode("d")
	a.children.Push(b)
	a.children.Push(c)
	b.children.Push(d)
	c.children.Push(d)

	expected := []string{"d", "b", "c", "a"}
	for i, id := range ids(Sort(a)) {
		if id != expected[i] {
			t.Errorf("Expected: %s, got: %s", expected[i], id)
		}
	}
}

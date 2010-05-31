package graph

import "container/vector"
import "testing"

type TestNode struct {
	name  string
	children *vector.Vector
}

func NewTestNode(name string) *TestNode {
	return &TestNode{name, new(vector.Vector)}
}

func (tn *TestNode) Id() string {
	return tn.name
}

func (tn *TestNode) EachChild(f func(Node)) {
	for i := 0; i < tn.children.Len(); i++ {
		f(tn.children.At(i).(Node))
	}
}

func TestSingleNode(t *testing.T) {
	cycles := FindCycles(NewTestNode("a"))
	if len(cycles) != 0 { t.Errorf("Unexpected cycle found: %d", len(cycles)) }
}

func TestTwoNodeCycle(t *testing.T) {
	a := NewTestNode("a")
	b := NewTestNode("b")
	a.children.Push(b)
	b.children.Push(a)
	cycles := FindCycles(a)
	if len(cycles) != 1 { t.Errorf("Unexpected cycle found: %d", len(cycles)) }
	if cycles[0].Len() != 2 { t.Errorf("Unexpected cycle size %d", cycles[0].Len()) }
}

func TestThreeNodeCycle(t *testing.T) {
	a := NewTestNode("a")
	b := NewTestNode("b")
	c := NewTestNode("c")
	a.children.Push(b)
	b.children.Push(c)
	c.children.Push(a)
	cycles := FindCycles(a)
	if len(cycles) != 1 { t.Errorf("Unexpected cycle found: %d", len(cycles)) }
	if cycles[0].Len() != 3 { t.Errorf("Unexpected cycle size %d", cycles[0].Len()) }
}

func TestTwoTwoNodeCycles(t *testing.T) {
	a := NewTestNode("a")
	b := NewTestNode("b")
	c := NewTestNode("c")
	d := NewTestNode("d")
	a.children.Push(b)
	b.children.Push(a)
	c.children.Push(d)
	d.children.Push(c)
	a.children.Push(c)
	cycles := FindCycles(a)
	if len(cycles) != 2 { t.Errorf("Unexpected cycle found: %d", len(cycles)) }
	if cycles[0].Len() != 2 { t.Errorf("Unexpected cycle size %d", cycles[0].Len()) }
}

func TestDiamond(t *testing.T) {
	a := NewTestNode("a")
	b := NewTestNode("b")
	c := NewTestNode("c")
	d := NewTestNode("d")
	a.children.Push(b)
	a.children.Push(c)
	b.children.Push(d)
	c.children.Push(d)
	cycles := FindCycles(a)
	if len(cycles) != 0 { t.Errorf("Unexpected cycle found: %d", len(cycles)) }
}

package model

// Backtrace shows the chain of dependencies that 
// led up to a particular error. Implemented as
// a linked list.
type Backtrace struct {
	Parent     *Backtrace
	Descriptor Descriptor
}

// Adds a descriptor to the front of the trace
func (parent *Backtrace) Push(descriptor Descriptor) *Backtrace {
	return &Backtrace{parent, descriptor}
}

// Returns the rest of the trace.
func (child *Backtrace) Pop() *Backtrace {
	return child.Parent
}

// Returns in the number of descriptors in the trace (i.e. the depth)
func (b *Backtrace) Len() int {
	l := 0
	for b != nil {
		l++
		b = b.Parent 
	}
	return l
}

// Converts the list of descriptors to a slice
func (b *Backtrace) Slice() []Descriptor {
	slice := make([]Descriptor, b.Len())
	for i, _ := range slice {
		slice[i] = b.Descriptor
		b = b.Parent
	}
	return slice
}


func (b *Backtrace) String() string {
	s := ""
	for b != nil {
		s += "\n    "
		s += b.Descriptor.String() 
		b = b.Parent
	}
	s += "\n"
	return s
}

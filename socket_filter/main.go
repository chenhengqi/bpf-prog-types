package main

import (
	"bytes"
	"encoding/binary"
	"log"
	"net"
	"syscall"

	"github.com/cilium/ebpf"
	"golang.org/x/sys/unix"
)

const (
	interfaceName = "lo"
	SO_ATTACH_BPF = 50
)

var bpfObj string

func htons(n uint16) uint16 {
	buf := bytes.NewBuffer(nil)
	err := binary.Write(buf, binary.LittleEndian, n)
	if err != nil {
		panic(err)
	}
	return binary.BigEndian.Uint16(buf.Bytes())
}

type bpfObject struct {
	SocketFilter *ebpf.Program `ebpf:"socket_filter"`
}

func main() {
	spec, err := ebpf.LoadCollectionSpec(bpfObj)
	if err != nil {
		panic(err)
	}

	obj := bpfObject{}
	err = spec.LoadAndAssign(&obj, nil)
	if err != nil {
		panic(err)
	}

	fd, err := syscall.Socket(
		syscall.AF_PACKET,
		syscall.SOCK_RAW|syscall.SOCK_NONBLOCK|syscall.SOCK_CLOEXEC,
		int(htons(syscall.ETH_P_ALL)),
	)
	if err != nil {
		panic(err)
	}

	lo, err := net.InterfaceByName(interfaceName)
	if err != nil {
		panic(err)
	}

	addr := &unix.SockaddrLinklayer{
		Ifindex:  lo.Index,
		Protocol: htons(syscall.ETH_P_ALL),
	}
	err = unix.Bind(fd, addr)
	if err != nil {
		panic(err)
	}

	err = syscall.SetsockoptInt(fd, syscall.SOL_SOCKET, SO_ATTACH_BPF, obj.SocketFilter.FD())
	if err != nil {
		panic(err)
	}

	for {
		data := [4096]byte{}
		n, err := syscall.Read(fd, data[:])
		if err != nil {
			// log.Println(err)
			continue
		}
		log.Println(data[:n])
	}
}

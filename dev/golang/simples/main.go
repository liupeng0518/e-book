package main

import "fmt"
import "golang.org/x/sys/unix"

func getMachineArch() (string, error) {
	uname := unix.Utsname{}
	err := unix.Uname(&uname)
	if err != nil {
		return "", err
	}

	return string(uname.Machine[:]), nil
}

func main() {
	arch, _ := getMachineArch()
	fmt.Println(arch)

}

package gosocket

import (
	"encoding/json"
	"fmt"
	"net"
	"os"
	"strings"
)

func handleServerMessage(message string) string {
	fmt.Printf("gogogogogogogo 🔄 Processing message: %s\n", message)

	if strings.HasPrefix(message, "ping") {
		return "pong"
	} else if strings.HasPrefix(message, "paths") {
		paths := []string{
			"/Users/player/projects/sync",
			"/Users/player/projects/test",
			"/Users/player/projects/navicate",
		}
		jsonData, err := json.Marshal(paths)
		if err == nil {
			return string(jsonData)
		}
		return "[]"
	} else {
		var arr []string
		err := json.Unmarshal([]byte(message), &arr)
		if err == nil {
			m := make(map[string]int)
			for _, str := range arr {
				if len(str)%2 == 1 {
					m[str] = 1
				} else {
					m[str] = 0
				}
			}
			jsonData, err := json.Marshal(m)
			if err == nil {
				return string(jsonData)
			}
			fmt.Println("gogogogogogogo xxxxxxxxxxxx message data 22222222222")
			return "{}"
		} else {
			fmt.Printf("gogogogogogogo xxxxxxxxxxxxxxxxxxx decode error： %v\n", err)
		}
		fmt.Println("gogogogogogogo xxxxxxxxxxxx message data 111111111")
		return "{}"
	}
}

func Run(path string) {
	// 删除已存在的socket文件
	if _, err := os.Stat(path); err == nil {
		os.Remove(path)
	}
	ln, err := net.Listen("unix", path)
	if err != nil {
		fmt.Printf("gogogogogogogo Listen error: %v\n", err)
		return
	}
	defer ln.Close()
	fmt.Printf("gogogogogogogo Unix socket server listening at %s\n", path)
	for {
		conn, err := ln.Accept()
		if err != nil {
			fmt.Printf("gogogogogogogo Accept error: %v\n", err)
			continue
		}
		go func(c net.Conn) {
			defer c.Close()
			buf := make([]byte, 4096)
			for {
				n, err := c.Read(buf)
				if n > 0 {
					msg := string(buf[:n])
					resp := handleServerMessage(msg)
					c.Write([]byte(resp + "\n"))
				}
				if err != nil {
					if err.Error() != "EOF" {
						fmt.Printf("gogogogogogogo read error: %v\n", err)
					}
					break
				}
			}
		}(conn)
	}
}

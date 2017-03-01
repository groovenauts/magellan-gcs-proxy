package main

import (
	"fmt"
	"log"
	"sync"
	"time"

	pubsub "google.golang.org/api/pubsub/v1"
)

type (
	JobSustainerConfig struct {
		Delay    float64 `json:"delay,omitempty"`
		Interval float64 `json:"interval,omitempty"`
	}

	JobMessageStatus uint8

	JobMessage struct {
		sub    string
		raw    *pubsub.ReceivedMessage
		config *JobSustainerConfig
		puller Puller
		status JobMessageStatus
		mux    sync.Mutex
	}
)

const (
	running JobMessageStatus = iota
	done
	acked
)

func (m *JobMessage) Validate() error {
	if m.MessageId() == "" {
		return fmt.Errorf("no MessageId is given")
	}
	_, ok := m.raw.Message.Attributes["download_files"]
	if !ok {
		return fmt.Errorf("No download_files given.")
	}
	return nil
}


func (m *JobMessage) MessageId() string {
	return m.raw.Message.MessageId
}

func (m *JobMessage) Attribute(key string) string {
	return m.raw.Message.Attributes[key]
}

func (m *JobMessage) Ack() error {
	m.mux.Lock()
	defer m.mux.Unlock()

	_, err := m.puller.Acknowledge(m.sub, m.raw.AckId)
	if err != nil {
		log.Fatalf("Failed to acknowledge for message: %v cause of %v\n", m.raw, err)
		return err
	}

	m.status = acked

	return nil
}

func (m *JobMessage) Done() {
	if m.status == running {
		m.status = done
	}
}

func (m *JobMessage) running() bool {
	return m.status == running
}

func (m *JobMessage) sendMADPeriodically() error {
	for {
		nextLimit := time.Now().Add(time.Duration(m.config.Interval) * time.Second)
		err := m.waitAndSendMAD(nextLimit)
		if err != nil {
			return err
		}
		if !m.running() {
			return nil
		}
	}
	// return nil
}

func (m *JobMessage) waitAndSendMAD(nextLimit time.Time) error {
	ticker := time.NewTicker(100 * time.Millisecond)
	for now := range ticker.C {
		if !m.running() {
			ticker.Stop()
			return nil
		}
		if now.After(nextLimit) {
			ticker.Stop()
		}
	}

	m.mux.Lock()
	defer m.mux.Unlock()

	// Don't send MAD after sending ACK
	if m.status == acked {
		return nil
	}

	_, err := m.puller.ModifyAckDeadline(m.sub, []string{m.raw.AckId}, int64(m.config.Delay))
	if err != nil {
		log.Fatalf("Failed modifyAckDeadline %v, %v, %v cause of %v\n", m.sub, m.raw.AckId, m.config.Delay, err)
	}
	return nil
}
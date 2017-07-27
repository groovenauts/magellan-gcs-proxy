package main

import (
	"encoding/base64"
	"fmt"
	"os"
	"strconv"

	// "golang.org/x/net/context"

	pubsub "google.golang.org/api/pubsub/v1"

	log "github.com/Sirupsen/logrus"
)

type ProgressNotificationConfig struct {
	Topic    string `json:"topic"`
	LogLevel string `json:"log_level"`
	Hostname string `json:"hostname"`
}

func (c *ProgressNotificationConfig) setup() {
	if c.LogLevel == "" {
		c.LogLevel = log.InfoLevel.String()
	}

	if c.Hostname == "" {
		h, err := os.Hostname()
		if err != nil {
			c.Hostname = "Unknown"
		} else {
			c.Hostname = h
		}
	}
}

type ProgressNotification struct {
	config    *ProgressNotificationConfig
	publisher Publisher
	logLevel  log.Level
}

func (pn *ProgressNotification) wrap(msg_id string, step JobStep, attrs map[string]string, f func() error) func() error {
	return func() error {
		pn.notify(msg_id, step, STARTING, attrs)
		err := f()
		if err != nil {
			pn.notifyWithMessage(msg_id, step, FAILURE, attrs, err.Error())
			return err
		}
		pn.notify(msg_id, step, SUCCESS, attrs)
		return nil
	}
}

func (pn *ProgressNotification) notify(job_msg_id string, step JobStep, st JobStepStatus, attrs map[string]string) error {
	msg := fmt.Sprintf("%v %v", step, st)
	return pn.notifyWithMessage(job_msg_id, step, st, attrs, msg)
}

func (pn *ProgressNotification) notifyWithMessage(job_msg_id string, step JobStep, st JobStepStatus, opts map[string]string, msg string) error {
	attrs := map[string]string{}
	for k, v := range opts {
		attrs[k] = v
	}
	attrs["step"] = step.String()
	attrs["step_status"] = st.String()
	return pn.notifyProgress(job_msg_id, step.progressFor(st), step.completed(st), step.logLevelFor(st), attrs, msg)
}

func (pn *ProgressNotification) notifyProgress(job_msg_id string, progress Progress, completed bool, level log.Level, opts map[string]string, data string) error {
	// https://godoc.org/github.com/sirupsen/logrus#Level
	// log.InfoLevel < log.DebugLevel => true
	if pn.logLevel < level {
		return nil
	}
	attrs := map[string]string{}
	for k, v := range opts {
		attrs[k] = v
	}
	attrs["progress"] = strconv.Itoa(int(progress))
	attrs["completed"] = strconv.FormatBool(completed)
	attrs["job_message_id"] = job_msg_id
	attrs["level"] = level.String()
	attrs["host"] = pn.config.Hostname
	logAttrs := log.Fields{}
	for k, v := range attrs {
		logAttrs[k] = v
	}
	log.WithFields(logAttrs).Debugln("Publishing notification")
	m := &pubsub.PubsubMessage{Data: base64.StdEncoding.EncodeToString([]byte(data)), Attributes: attrs}
	_, err := pn.publisher.Publish(pn.config.Topic, m)
	if err != nil {
		logAttrs["error"] = err
		log.WithFields(logAttrs).Debugln("Failed to publish notification")
		return err
	}
	return nil
}

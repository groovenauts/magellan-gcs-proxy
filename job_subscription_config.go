package main

import (
	"fmt"

	logrus "github.com/sirupsen/logrus"
)

type JobSubscriptionConfig struct {
	Subscription string              `json:"subscription,omitempty"`
	PullInterval int                 `json:"pull_interval,omitempty"`
	Sustainer    *JobSustainerConfig `json:"sustainer,omitempty"`
	NackOnError  bool                `json:"nack_on_error,omitempty"`
}

func (c *JobSubscriptionConfig) setup() *ConfigError {
	if c.Subscription == "" {
		c.Subscription = fmt.Sprintf("projects/%s/subscriptions/%s-job-subscription", GcpProjectId, Pipeline)
	}
	if c.PullInterval == 0 {
		c.PullInterval = 10
	}
	if c.Sustainer == nil {
		c.Sustainer = &JobSustainerConfig{}
	}
	return nil
}

func (c *JobSubscriptionConfig) setupSustainer(puller Puller) error {
	flds := logrus.Fields{"subscription": c.Subscription}
	if c.Sustainer == nil {
		c.Sustainer = &JobSustainerConfig{}
	}
	cs := c.Sustainer
	if cs.Disabled {
		log.WithFields(flds).Infoln("Sustainer is disabled")
		return nil
	}
	if cs.Delay > 0 && cs.Interval > 0 {
		flds["delay"] = cs.Delay
		flds["interval"] = cs.Interval
		log.WithFields(flds).Infoln("Sustainer config OK")
		return nil
	}

	subscription, err := puller.Get(c.Subscription)
	if err != nil {
		flds["error"] = err
		log.WithFields(flds).Errorln("Failed to get subscription")
		return err
	}
	deadline := subscription.AckDeadlineSeconds
	flds["AckDeadline"] = deadline
	log.WithFields(flds).Infoln("AckDeadlineSeconds")

	if cs.Delay == 0 {
		cs.Delay = float64(deadline)
	}
	if cs.Interval == 0 {
		cs.Interval = float64(deadline) * 0.8
	}
	flds["delay"] = cs.Delay
	flds["interval"] = cs.Interval
	log.WithFields(flds).Infoln("Sustainer config OK")
	return nil
}

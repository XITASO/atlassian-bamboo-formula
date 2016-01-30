#!/bin/sh
export CATALINA_OPTS="{{ config.catalina_opts }} ${CATALINA_OPTS}"
export JAVA_HOME={{ config.java_home }}
export BAMBOO_HOME={{ config.dirs.home }}
export CATALINA_PID={{ config.pid }}

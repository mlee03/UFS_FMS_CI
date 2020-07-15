#!/bin/bash

wfile=workflow_status/workflow_status
rm -rf $wfile

mkdir -p workflow_status
echo "FILE MANUALLY UPDATED `date`" > $wfile



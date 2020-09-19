# Copyright 2020 Chaitanya Prakash N <cp@crosslibs.com>
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

#! /bin/sh

COMPUTE_ENGINE_NAME=$(curl -s http://metadata.google.internal/computeMetadata/v1/instance/name -H "Metadata-Flavor: Google")
COMPUTE_ENGINE_ID=$(curl -s http://metadata.google.internal/computeMetadata/v1/instance/id -H "Metadata-Flavor: Google")
UNIQUE_SUBSCRIPTION_NAME="$COMPUTE_ENGINE_NAME-$COMPUTE_ENGINE_ID"

# Validate and exit if the subscription does not exist
SUBSCRIPTION_DETAILS=$(gcloud pubsub subscriptions describe "$UNIQUE_SUBSCRIPTION_NAME" 2>&1)
if echo "$SUBSCRIPTION_DETAILS" | grep -q "NOT_FOUND"
then
    echo "Pub/sub subscription ($UNIQUE_SUBSCRIPTION_NAME) does not exist. Exiting."
    exit -1
fi

# Remove Cloud Pub/Sub subscription
echo "Removing subscription with name: $UNIQUE_SUBSCRIPTION_NAME"
DELETE_OUTPUT=$(gcloud pubsub subscriptions delete "$UNIQUE_SUBSCRIPTION_NAME" 2>&1)
if echo "$DELETE_OUTPUT" | grep -q "^Deleted subscription"
then
    echo "Pub/sub subscription ($UNIQUE_SUBSCRIPTION_NAME) deleted succesfully."
else
    echo "Error occurred while deleting pub/sub subscription ($UNIQUE_SUBSCRIPTION_NAME)."
    echo "Error details: $DELETE_OUTPUT"
    exit -2
fi

echo "Shutdown script finished successfully."
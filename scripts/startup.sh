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

# Retrieve metadata from the instance
URI_SCHEME_KEY=uri-scheme
URI_PATH_KEY=uri-path
PUBSUB_TOPIC_KEY=pubsub-topic
CLOUDFN_ENDPOINT_KEY=cloudfn-endpoint

# Default values for optional metadata attributes
DEFAULT_URI_SCHEME=https
DEFAULT_URI_PATH="/"

PROJECT_ID=$(curl -s http://metadata.google.internal/computeMetadata/v1/project/project-id -H "Metadata-Flavor: Google")
URI_SCHEME=$(curl -s http://metadata.google.internal/computeMetadata/v1/instance/attributes/$URI_SCHEME_KEY -H "Metadata-Flavor: Google")
URI_PATH=$(curl -s http://metadata.google.internal/computeMetadata/v1/instance/attributes/$URI_PATH_KEY -H "Metadata-Flavor: Google")
PUBSUB_TOPIC=$(curl -s http://metadata.google.internal/computeMetadata/v1/instance/attributes/$PUBSUB_TOPIC_KEY -H "Metadata-Flavor: Google")
CLOUDFN_ENDPOINT=$(curl -s http://metadata.google.internal/computeMetadata/v1/instance/attributes/$CLOUDFN_ENDPOINT_KEY -H "Metadata-Flavor: Google")
COMPUTE_ENGINE_NAME=$(curl -s http://metadata.google.internal/computeMetadata/v1/instance/name -H "Metadata-Flavor: Google")
COMPUTE_ENGINE_ID=$(curl -s http://metadata.google.internal/computeMetadata/v1/instance/id -H "Metadata-Flavor: Google")
COMPUTE_ENGINE_IP=$(curl -s http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/ip -H "Metadata-Flavor: Google")
UNIQUE_SUBSCRIPTION_NAME="$COMPUTE_ENGINE_NAME-$COMPUTE_ENGINE_ID"
PUSH_ENDPOINT="$CLOUDFN_ENDPOINT"

# Validate metadata: Returns 0 if the metadata is found otherwise returns non-zero value
metadata_not_found ()
{
    echo "$1" | grep -q "DOCTYPE"
}

# Validate uri-scheme is specified
validate_uri_scheme ()
{
    if metadata_not_found "$URI_SCHEME"
    then
        echo "Instance metadata $URI_SCHEME_KEY is not specified. Setting $URI_SCHEME_KEY value to default: $DEFAULT_URI_SCHEME."
        URI_SCHEME="$DEFAULT_URI_SCHEME"
    fi

    if echo "$URI_SCHEME" | grep -Eqv "^http(s)?$"
    then
        echo "Invalid value specified ($URI_SCHEME) for instance metadata $URI_SCHEME_KEY"
        echo "Instance metadata value for $URI_SCHEME_KEY must be either http or https only."
        exit -1
    fi
}

# Validate uri-path is specified
validate_uri_path ()
{
    if metadata_not_found "$URI_PATH"
    then
        echo "Instance metadata $URI_PATH_KEY is not specified. Setting $URI_PATH_KEY value to default: $DEFAULT_URI_PATH."
        URI_PATH="$DEFAULT_URI_PATH"
    fi

    if echo "$URI_PATH" | grep -Eqv "^(\/[^\/\?\#]+)*(\/)?(\?([^\#\&]+\=[^\#\&]+(\&)?)*)?(\#(.*))?$"
    then
        echo "Invalid value specified ($URI_PATH) for instance metadata $URI_PATH_KEY"
        echo "Instance metadata value for $URI_PATH_KEY must be be a URI path starting with a / (e.g. /users/1 or /users/1?param1=one&param2=2#abc)."
        exit -2
    fi
}

# Validate pubsub topic exists
validate_pubsub_topic ()
{
    if metadata_not_found "$PUBSUB_TOPIC"
    then
        echo "Instance metadata $PUBSUB_TOPIC_KEY is not specified. Exiting."
        exit -3
    fi

    TOPIC_DETAILS=$(gcloud pubsub topics describe "$PUBSUB_TOPIC" 2>&1)
    if echo "$TOPIC_DETAILS" | grep -q "NOT_FOUND"
    then
        echo "Pub/sub topic ($PUBSUB_TOPIC) specified does not exist in the current project. Exiting."
        exit -4
    fi
}

# Validate Cloud Function endpoint
validate_cloudfn_endpoint ()
{
    if metadata_not_found "$CLOUDFN_ENDPOINT"
    then
        echo "Instance metadata $CLOUDFN_ENDPOINT_KEY is not specified. Exiting."
        exit -5
    fi

    if echo "$CLOUDFN_ENDPOINT" | grep -Eqv "^https\:\/\/([a-zA-Z0-9\-\_]+(\.)?)+(\/)?$"
    then
        echo "Cloud Function endpoint specified should start with https:// and must contain only the hostname."
        echo "Invalid Cloud Function endpoint specified ($CLOUDFN_ENDPOINT). Exiting."
        exit -6
    fi
}

# Validate pubsub topic exists
validate_pubsub_subscription ()
{
    SUBSCRIPTION_DETAILS=$(gcloud pubsub subscriptions describe "$UNIQUE_SUBSCRIPTION_NAME" 2>&1)
    if echo "$SUBSCRIPTION_DETAILS" | grep -qv "NOT_FOUND"
    then
        echo "Pub/sub topic ($UNIQUE_SUBSCRIPTION_NAME) specified already exists in the current project. Exiting."
        exit -7
    fi
}

# Prepare final cloud function endpoint
prepare_push_endpoint ()
{
    PUSH_ENDPOINT="$CLOUDFN_ENDPOINT?ip=$COMPUTE_ENGINE_IP"
    
    if [ -z "URI_PATH" ]
    then
        PUSH_ENDPOINT="$PUSH_ENDPOINT&uri-path=$URI_PATH"
    fi
    
    if [ -z "URI_SCHEME" ]
    then
        PUSH_ENDPOINT="$PUSH_ENDPOINT&uri-scheme=$URI_SCHEME"
    fi
}

# Print all config
print_config ()
{
    echo "Startup Script Config: "
    echo "project id = $PROJECT_ID"
    echo "instance name = $COMPUTE_ENGINE_NAME"
    echo "instance id = $COMPUTE_ENGINE_ID"
    echo "instance ip = $COMPUTE_ENGINE_IP"
    echo "cloud function endpoint = $CLOUDFN_ENDPOINT"
    echo "uri scheme = $URI_SCHEME"
    echo "uri path = $URI_PATH"
    echo "pub/sub topic = $PUBSUB_TOPIC"
    echo "pub/sub subscription = $UNIQUE_SUBSCRIPTION_NAME"
    echo "pub/sub subscription push endpoint = $PUSH_ENDPOINT"
}

#Validations
validate_pubsub_subscription
validate_pubsub_topic
validate_uri_scheme
validate_uri_path
validate_cloudfn_endpoint


# Push Endpoint
prepare_push_endpoint

# Print configuration
print_config

# Exit on error
set -e

# Create Cloud Pub/Sub subscription to the specified topic
echo "Creating subscription for topic: $PUBSUB_TOPIC with name: $UNIQUE_SUBSCRIPTION_NAME"
gcloud pubsub subscriptions create "$UNIQUE_SUBSCRIPTION_NAME" --topic "$PUBSUB_TOPIC" --push-endpoint "$PUSH_ENDPOINT"
echo "Creating subscription for topic: $PUBSUB_TOPIC with name: $UNIQUE_SUBSCRIPTION_NAME [DONE]"

echo "Startup script finished successfully."
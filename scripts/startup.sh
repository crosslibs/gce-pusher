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
IP_KEY=ip
URI_SCHEME_KEY=scheme
URI_PATH_KEY=path
URI_PORT=port
URI_METHOD=method
PUBSUB_TOPIC_KEY=pubsub-topic
CLOUDFN_ENDPOINT_KEY=cloudfn-endpoint

# Default values for optional metadata attributes
DEFAULT_URI_SCHEME=https
DEFAULT_URI_PATH="/"
DEFAULT_HTTPS_PORT=443
DEFAULT_HTTP_PORT=80
DEFAULT_URI_METHOD=POST

PROJECT_ID=$(curl -s http://metadata.google.internal/computeMetadata/v1/project/project-id -H "Metadata-Flavor: Google")
URI_SCHEME=$(curl -s http://metadata.google.internal/computeMetadata/v1/instance/attributes/$URI_SCHEME_KEY -H "Metadata-Flavor: Google")
URI_PATH=$(curl -s http://metadata.google.internal/computeMetadata/v1/instance/attributes/$URI_PATH_KEY -H "Metadata-Flavor: Google")
URI_PORT=$(curl -s http://metadata.google.internal/computeMetadata/v1/instance/attributes/$URI_PORT_KEY -H "Metadata-Flavor: Google")
URI_METHOD=$(curl -s http://metadata.google.internal/computeMetadata/v1/instance/attributes/$URI_METHOD_KEY -H "Metadata-Flavor: Google")
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

# Validate uri scheme is specified
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

# Validate uri path is specified
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
        echo "Instance metadata value for $URI_PATH_KEY must be a URI path starting with a / (e.g. /users/1 or /users/1?param1=one&param2=2#abc)."
        exit -2
    fi
}

# Validate port  specified
validate_port ()
{
    if metadata_not_found "$URI_PORT"
    then
        DEFAULT_PORT=DEFAULT_HTTPS_PORT
        if echo "$URI_SCHEME" | grep -Eq "^http$"
        then
            DEFAULT_PORT=DEFAULT_HTTP_PORT
        fi
        echo "Instance metadata $URI_PORT_KEY is not specified. Setting $URI_PORT_KEY value to default: $DEFAULT_PORT."
        URI_PORT="$DEFAULT_PORT"
    fi

    if echo "$URI_PORT" | grep -Eqv "^[1-9][0-9]*$"
    then
        echo "Invalid value specified ($URI_PORT) for instance metadata $URI_PORT_KEY"
        echo "Instance metadata value for $URI_PORT_KEY must be a positive integer."
        exit -3
    fi
}

# Validate method is specified
validate_uri_method ()
{
    if metadata_not_found "$URI_METHOD"
    then
        echo "Instance metadata $URI_METHOD_KEY is not specified. Setting $URI_METHOD_KEY value to default: $DEFAULT_URI_METHOD."
        URI_METHOD="$DEFAULT_URI_METHOD"
    fi

    if echo "$URI_METHOD" | grep -Eqvi "^(post)|(get)$"
    then
        echo "Invalid value specified ($URI_METHOD) for instance metadata $URI_METHOD_KEY"
        echo "Instance metadata value for $URI_METHOD_KEY must be GET or POST only."
        exit -4
    fi
}

# Validate pubsub topic exists
validate_pubsub_topic ()
{
    if metadata_not_found "$PUBSUB_TOPIC"
    then
        echo "Instance metadata $PUBSUB_TOPIC_KEY is not specified. Exiting."
        exit -5
    fi

    TOPIC_DETAILS=$(gcloud pubsub topics describe "$PUBSUB_TOPIC" 2>&1)
    if echo "$TOPIC_DETAILS" | grep -q "NOT_FOUND"
    then
        echo "Pub/sub topic ($PUBSUB_TOPIC) specified does not exist in the current project. Exiting."
        exit -6
    fi
}

# Validate Cloud Function endpoint
validate_cloudfn_endpoint ()
{
    if metadata_not_found "$CLOUDFN_ENDPOINT"
    then
        echo "Instance metadata $CLOUDFN_ENDPOINT_KEY is not specified. Exiting."
        exit -7
    fi

    if echo "$CLOUDFN_ENDPOINT" | grep -Eqv "^https\:\/\/([a-zA-Z0-9\-\_]+(\.)?)+((\/)[^\/]*)?$"
    then
        echo "Cloud Function endpoint specified should start with https:// and must contain only the hostname and the function name and must not contain a trailing forward slash (/)."
        echo "Invalid Cloud Function endpoint specified ($CLOUDFN_ENDPOINT). Exiting."
        exit -8
    fi
}

# Validate pubsub topic exists
validate_pubsub_subscription ()
{
    SUBSCRIPTION_DETAILS=$(gcloud pubsub subscriptions describe "$UNIQUE_SUBSCRIPTION_NAME" 2>&1)
    if echo "$SUBSCRIPTION_DETAILS" | grep -qv "NOT_FOUND"
    then
        echo "Pub/sub topic ($UNIQUE_SUBSCRIPTION_NAME) specified already exists in the current project. Exiting."
        exit -9
    fi
}

# Prepare final cloud function endpoint
prepare_push_endpoint ()
{
    PUSH_ENDPOINT="$CLOUDFN_ENDPOINT?$IP_KEY=$COMPUTE_ENGINE_IP"
    
    if [ ! -z "URI_PATH" ]
    then
        PUSH_ENDPOINT="$PUSH_ENDPOINT&$URI_PATH_KEY=$URI_PATH"
    fi
    
    if [ ! -z "URI_SCHEME" ]
    then
        PUSH_ENDPOINT="$PUSH_ENDPOINT&$URI_SCHEME_KEY=$URI_SCHEME"
    fi

    if [ ! -z "URI_PORT" ]
    then
        PUSH_ENDPOINT="$PUSH_ENDPOINT&$URI_PORT_KEY=$URI_PORT"
    fi

    if [ ! -z "URI_METHOD" ]
    then
        PUSH_ENDPOINT="$PUSH_ENDPOINT&$URI_METHOD=$URI_METHOD"
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
    echo "port = $URI_PORT"
    echo "http method = $URI_METHOD"
    echo "pub/sub topic = $PUBSUB_TOPIC"
    echo "pub/sub subscription = $UNIQUE_SUBSCRIPTION_NAME"
    echo "pub/sub subscription push endpoint = $PUSH_ENDPOINT"
}

# Create subscription to the specified topic
create_pubsub_subscription ()
{
    echo "Creating subscription for topic: $PUBSUB_TOPIC with name: $UNIQUE_SUBSCRIPTION_NAME"
    CREATE_OUTPUT=$(gcloud pubsub subscriptions create "$UNIQUE_SUBSCRIPTION_NAME" --topic "$PUBSUB_TOPIC" --push-endpoint "$PUSH_ENDPOINT" 2>&1)
    if echo "$CREATE_OUTPUT" | grep -q "^Created subscription"
    then
        echo "Pub/sub subscription ($UNIQUE_SUBSCRIPTION_NAME) for topic ($PUBSUB_TOPIC) created succesfully."
    else
        echo "Error occurred while creating pub/sub subscription ($UNIQUE_SUBSCRIPTION_NAME) for topic ($PUBSUB_TOPIC)."
        echo "Error details: $CREATE_OUTPUT"
        exit -10
    fi
}


#Validations
validate_pubsub_subscription
validate_pubsub_topic
validate_uri_scheme
validate_uri_port
validate_uri_path
validate_uri_method
validate_cloudfn_endpoint


# Push Endpoint
prepare_push_endpoint

# Print configuration
print_config

# Create subscription to the specified topic
create_pubsub_subscription

echo "Startup script finished successfully."
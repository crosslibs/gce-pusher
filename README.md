# Leverage Cloud Pub/Sub push for GCE instances without public IP using Serverless VPC Access Connector

The solution provides a workflow for pushing messages from Pub/Sub topic to Google Compute Engine (GCE) instance which do not have a public IP. 

Cloud Pub/Sub does not support non-HTTPS and non-public endpoints for push subscriptions ([source](https://cloud.google.com/pubsub/docs/push)). Often times GCE instances hosting web services are deployed behind a HTTPS/SSL proxy and in a secure VPC with no public IP addresses. In such cases, only pull subscription is a direct option. 

This solution tries to provide a solution for supporting push for such instances using [Cloud Functions](https://cloud.google.com/functions) and [Serverless VPC Access Connector](https://cloud.google.com/vpc/docs/configure-serverless-vpc-access) to deliver the messsage via push to such GCE instances.


## Solution Overview

The solution has three steps:

1. Setup Cloud Function that accepts the internal IP of a GCE instance as a parameter.

2. Setup Serverless VPC Access Connector so that the Cloud Function can invoke the private endpoint in GCE instance.

3. When a GCE instance starts up, it creates a subscription to Cloud Pub/Sub topic with Cloud Function setup above as the push endpoint and the parameter as the IP address of this instance.

4. When a GCE instance terminates, it will remove the subscription to Cloud Pub/Sub topic, so no more push messages need to be sent to the GCE instance.


Here is the pusher workflow (click below to zoom):

[![GCE Notifier - Workflow](https://user-images.githubusercontent.com/20769938/93603120-2dd34600-f9e1-11ea-910a-b4b46285e587.png)](https://user-images.githubusercontent.com/20769938/93603120-2dd34600-f9e1-11ea-910a-b4b46285e587.png)

Here is the solution workflow at the time of creating a GCE instance (click below to zoom):

[![Blank diagram - Creation](https://user-images.githubusercontent.com/20769938/93603361-86a2de80-f9e1-11ea-9a47-acf73134df0d.png)](https://user-images.githubusercontent.com/20769938/93603361-86a2de80-f9e1-11ea-9a47-acf73134df0d.png)

And finally here is the solution workflow at the time of GCE instance shutting down (click below to zoom):

[![GCE Notifier - Teardown](https://user-images.githubusercontent.com/20769938/93603467-acc87e80-f9e1-11ea-862c-b4f67d2298fa.png)](https://user-images.githubusercontent.com/20769938/93603467-acc87e80-f9e1-11ea-862c-b4f67d2298fa.png)



## Steps to implement the solution

### Prerequisites

In a GCP project,

1. Create a VPC in your project in which your GCE instances will be deployed 

1. Setup a [Cloud Pub/Sub](https://cloud.google.com/pubsub) topic

### Step 1: Deploy Cloud Function

Cloud Function takes the IP address of the VM and optionally, URI path as query parameters `ip` and `uri_path` respectively. `ip` is a mandatory query parameter and `uri_path` is optional.

The Cloud Function also looks for a field called `uri_path` in the push message from PubSub. 

If both `uri_path` parameters are specified, then `uri_path` in the PubSub message takes higher precedence. If none are specified, then an error is returned by the Cloud Function.

### Step 2: Setup Serverless VPC Access Connector


### Step 3: Create a GCE instance with appropriate metadata added for startup and shutdown scripts

GCE instance looks for the following metadata on the instances `pubsub-topic` and `cloudfn-endpoint`. Also if optionally `uri_path` is specified, then it will be used to set the `uri_path` in the Cloud Function query parameter.

The script to subscribe to the Cloud Pub/Sub topic will be part of  `startup-script-url`. The script to unsubscribe to the Cloud Pub/Sub topic will be part of `shutdown-script-url`.


### Step 4: Delete a GCE instance

The `shutdown-script-url` will be invoked at the time of shutting down of the GCE instance, which removes the Cloud Pub/Sub subscription.

## Contributions Welcome

Please feel free to contribute to the code base by submitting a pull request.
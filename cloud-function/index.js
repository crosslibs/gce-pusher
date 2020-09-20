/**
 * Copyright 2020, Chaitanya Prakash N <cp@crosslibs.com>
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

'use strict';

import { v4 as uuidv4 } from 'uuid';
import { request } from 'axios';

/**
 * Returns true if the IP address is a valid IPv4 address, false otherwise.
 * @param ip string
 */
export function isValidIP(ip) {
    const octets = ip.match(/^\s*([1-9]\d*)\.(\d+)\.(\d+)\.([1-9]\d*)\s*$/);
    return ( (ip !== null) 
            && octets 
            && parseInt(octets[1]) <= 255
            && parseInt(octets[2]) <= 255 
            && parseInt(octets[3]) <= 255
            && parseInt(octets[4]) <= 255);
}

/**
 * Sent a HTTP request to the URI specified and return the response or error
 * @param invocationID string for tracing purposes
 * @param uri string
 * @param method string
 * @param onSuccess callback to be called on success with the response
 * @param onError callback to be called on error with the error object
 */
export function notifyGCE(invocationID, uri, method, onSuccess, onError) {
    console.log(invocationID, ': Sending request to GCE instance');

    request({
        url: uri,
        method: method.toLowerCase(),
        timeout: 5000 // 5 seconds
    })
    .then(response => onSuccess(response))
    .catch(error => onError(error));

}

/**
 * Notify the GCE instance using the query parameters
 * @param req https://expressjs.com/en/api.html#req
 * @param res https://expressjs.com/en/api.html#res
 */
export function gcePusher(req, res) {

    var invocationID = uuidv4();
    console.log(invocationID, ': Cloud Function invoked: GCE Pusher');

    // Push subscription on Pub/Sub topic always makes a POST. 
    // Thus reject every other HTTP method.
    if( req.method !== 'POST' ) {
        console.log(invocationID, ': Received ' + req.method + ' method in HTTP request. Only POST is allowed.');
        res.status(405).json({
            id: invocationID,
            error: 'Received ' + req.method + ' method in HTTP request. Only POST is allowed.'
        });
        return;
    }

    const HTTPS_SCHEME = 'https';
    const DEFAULT_URI_SCHEME = 'https';
    const DEFAULT_HTTP_METHOD = 'GET';
    const DEFAULT_URI_PATH = '/';
    const DEFAULT_HTTPS_PORT = '443';
    const DEFAULT_HTTP_PORT = '80';

    var ip = req.query.ip || null;
    var scheme = req.query.scheme || DEFAULT_URI_SCHEME;
    var path = req.query.path || DEFAULT_URI_PATH;
    var method = (req.query.method || DEFAULT_HTTP_METHOD).toUpperCase();
    var port = (req.query.port || (scheme === HTTPS_SCHEME ? DEFAULT_HTTPS_PORT : DEFAULT_HTTP_PORT));
    
    // Validate IP
    if(ip === null) {
        console.log(invocationID, ': IP address not specified via query parameter (ip)');
        res.status(400).json({
            id: invocationID,
            error: 'Mandatory query parameter ip is missing'
        });
        return;
    }
    else if (! this.isValidIP(ip) ) {
        console.log(invocationID, ': IP address specified is invalid: ', ip);
        res.status(400).json({
            id: invocationID,
            error: 'IP address specified (' + ip + ') is invalid'
        });
        return;
    }

    // Validate Port
    if ( (!port.match(/^\d+$/)) || (parseInt(port) === 0) ) {
        console.log(invocationID, ': Invalid TCP port specified: ', port);
        res.status(400).json({
            id: invocationID,
            error: 'TCP port specified (' + port + ') is invalid.'
        });
        return;
    }

    // Validate HTTP method
    if (!(method === 'GET' || method === 'POST')) {
        console.log(invocationID, ': Invalid HTTP method specified: ', method);
        res.status(400).json({
            id: invocationID,
            error: 'HTTP method specified (' + method + ') is invalid. Only HTTP GET and POST are allowed.'
        });
        return;
    }

    let uri = ip;
    uri = uri + ((port === DEFAULT_HTTPS_PORT || port === DEFAULT_HTTP_PORT)? '' : (':' + port));
    uri = scheme + '://' + (uri + '/' + path).replace(/\/{2,}/g, '/');

    // Print Config to logs
    console.log(invocationID, ': IP address of GCE instance: ', ip);
    console.log(invocationID, ': TCP Port: ', port);
    console.log(invocationID, ': URI Scheme: ', scheme);
    console.log(invocationID, ': URI Path: ', path);
    console.log(invocationID, ': HTTP Method: ', method);
    console.log(invocationID, ': URI to be invoked: ', uri);

    // Send the request to GCE instance
    this.notifyGCE(
        invocationID, 
        uri, 
        method,
        response => {
            console.log(invocationID, ': GCE notification successful. Response: ' + response);
            res.status(200).json({
                id: invocationID,
                method: method,
                uri: uri,
                response: response
            });
        },
        error => {
            if (error.response) {
                console.log(invocationID, ': Error received in response from GCE instance: ' + error);
                res.status(500).json({
                    id: invocationID,
                    error: {
                        status: error.response.status,
                        data: error.response.data
                    }
                });
            }
            else {
                console.log(invocationID, ': Error in notifying GCE instance: ' + error);
                res.status(500).json({
                    id: invocationID,
                    error: {
                        code: error.code,
                        message: error.message
                    }
                });
            }
        });
}
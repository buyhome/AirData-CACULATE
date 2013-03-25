<?php
/**
 *
 * Copyright (C) 2009 Progress Software, Inc. All rights reserved.
 * http://fusesource.com
 * http://stomp.fusesource.org/documentation/php/book.html
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

// include a library
require_once ("../Stomp.php");
try {
	// make a connection
	$con = new Stomp("tcp://10.124.20.49:61613");
	// connect
	$con -> connect();
	$con -> setReadTimeout(1);
	// subscribe to the queue
	$con -> subscribe("/queue/ticketFare", array('ack' => 'client', 'activemq.prefetchSize' => 1));
	while (true) {
		$messages = array();
		if ($con -> hasFrameToRead()) {
			$frame = $con -> readFrame();
			if ($frame != NULL) {
				//print "Received: " . $frame->body . " - time now is " . date("Y-m-d H:i:s"). "\n";
				array_push($messages, $frame);
				$con -> ack($frame);
			}
			trace_array($messages);
			if ($con -> hasFrameToRead()) {
				continue;
			} else {
				sleep(5);
			}
		} else {
			print "No frames to read\n";
		}
	}
} catch(StompException $e) {
	die('Connection failed: ' . $e -> getMessage());
}
// disconnect
$con -> disconnect();
function trace_array($ary) {
	//$mc = count($ary);
	//echo "Processed messages {\n";
	foreach ($ary as $msg) {
		echo "{$msg->body}\n";
	}
	//echo "}\n";
	//echo "{$mc}\n";
}

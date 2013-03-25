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
require_once("../Stomp.php");
// make a connection
$con = new Stomp("tcp://10.124.20.49:61613");
// connect
$con->connect();
$con->setReadTimeout(1);
// subscribe to the queue
$con->subscribe("/queue/ticketFare", array('ack' => 'client','activemq.prefetchSize' => 1 ));
while (true) {
	// ensure there are messages in the queue
	$msg = $con->readFrame();
	if ($msg === false) {
		echo "No messages in the queue\n";
		sleep(5);
	} else {
		$messages = array();
		//$con->begin($txf);
		// so we need to ack received messages again
		// before we can receive more (prefetch = 1)
		if (count($messages) != 0) {
			foreach($messages as $msg) {
				$con->ack($msg);
			}
		}
		$con->ack($msg);
		array_push($messages, $msg);
		//$con->commit($txf);
		//echo "Processed messages {\n";
		foreach($messages as $msg) {
			echo "{$msg->body}\n";
			postfare($msg->body);
		}
		//echo "}\n";
		sleep(1);
	}
}
// disconnect
$con->disconnect();
function postfare($ary) {
	$ch = curl_init();
	curl_setopt($ch, CURLOPT_URL, 'http://10.124.20.136/data-base');
	curl_setopt($ch, CURLOPT_HTTPHEADERS, array('Content-Type: application/json'));
	curl_setopt($ch, CURLOPT_POST, 1);
	curl_setopt($ch, CURLOPT_POSTFIELDS, $ary);
	curl_exec($ch);
}
?>

<?php
/**
 *
 * Copyright (C) 2009 huangqi. All rights reserved.
 * http://rhomobi.com
 * http://rhomobi.com/topics/116
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
$ch = curl_init(); // create cURL handle (ch)
if (!$ch) {
	die("Couldn't initialize a cURL handle");
 }
// set some cURL options
$ret = curl_setopt($ch, CURLOPT_URL,            		"http://10.124.20.49:8161/demo/message/rhomobile?type=queue&clientId=ngx136&Timeouts=1");
$ret = curl_setopt($ch, CURLOPT_HEADER,         		1);
$ret = curl_setopt($ch, CURLOPT_FOLLOWLOCATION, 		1);
$ret = curl_setopt($ch, CURLOPT_RETURNTRANSFER, 		0);
$ret = curl_setopt($ch, CURLOPT_TIMEOUT,        		2);
$ret = curl_setopt($ch, CURLINFO_STARTTRANSFER_TIME,	2);

// execute
$ret = curl_exec($ch);
if (empty($ret)) {
	// some kind of an error happened
	die(curl_error($ch));
	curl_close($ch); // close cURL handler
} else {
	$info = curl_getinfo($ch);
	curl_close($ch); // close cURL handler
	if (empty($info['http_code'])) {
		die("No HTTP code was returned");
	} else {
		// load the HTTP codes
		$http_codes = parse_ini_file("/data/huangqi/stomp/php/examples/faredb/code.ini");
		// echo results
		echo "\nThe server responded: ";
		//echo $ret;
		//echo "<br/>";
		echo $info['http_code'] . " " . $http_codes[$info['http_code']];
	}

}
?>

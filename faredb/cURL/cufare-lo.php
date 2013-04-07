<?php
require_once 'post.php';
$mqurl = "http://10.124.20.49:8161/demo/message/ifl_ticket?type=queue&clientId=ngx136&Timeouts=1";
$posturl = 'http://10.124.20.136/data-base';

while (true) {
	$post_string = '';
	$ret = httpRequest($mqurl, $post_string, FALSE);
	if ($ret === false) {
		// close cURL handler
		echo "Connect error.\n";
		sleep(5);
	} elseif (empty($ret)) {
		echo "No messages in the queue.\n";
		sleep(5);
	} else {
		$ret_post = httpRequest($mqurl, $ret, TRUE);
		if ($ret_post !== FALSE) {
			echo "The server responded: \n";
			echo $ret_post . "\n";

			$ret_post = iconv('UTF-8', 'ISO-8859-1//IGNORE', $ret_post);
			echo "The iconv string: \n";
			echo $ret_post . "\n";
		}
		sleep(1);
	}
	echo "--------------------------------------------------\n\n";
}

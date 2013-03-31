<?php
define('CONNECT_TIMEOUT', 10);
define('READ_TIMEOUT', 10);

/**
 * http post
 */
function httpRequest($url, $post_string, $connectTimeout = CONNECT_TIMEOUT, $readTimeout = READ_TIMEOUT) {
	$result = "";
	if (function_exists('curl_init')) {
		$timeout = $connectTimeout + $readTimeout;
		// Use CURL if installed...
		$ch = curl_init();
		curl_setopt($ch, CURLOPT_URL, $url);
		curl_setopt($ch, CURLOPT_CONNECTTIMEOUT, $connectTimeout);
		curl_setopt($ch, CURLOPT_TIMEOUT, $timeout);
		curl_setopt($ch, CURLOPT_HTTP_VERSION, CURL_HTTP_VERSION_1_0);
		curl_setopt($ch, CURLOPT_POST, true);
		curl_setopt($ch, CURLOPT_POSTFIELDS, $post_string);
		curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
		curl_setopt($ch, CURLOPT_USERAGENT, 'rhomobi.com API PHP5 Client 1.0 (curl) ' . phpversion());
		$result = curl_exec($ch);
		curl_close($ch);
	} else {
		// Non-CURL based version...
		$result = socketPost($url, $post_string, $connectTimeout = CONNECT_TIMEOUT, $readTimeout = READ_TIMEOUT);
	}
	echo "url:$url <br /> post_data:$post_string <br /> ret:$result";
//	echo "<pre>";
//	print_r(htmlentities($post_string) . "<br />");
//	print_r(htmlentities($result));
//	echo "</pre>";
	return $result;
}

/**
 * http post
 */
function socketPost($url, $post_string, $connectTimeout = CONNECT_TIMEOUT, $readTimeout = READ_TIMEOUT){
	$urlInfo = parse_url($url);
	$urlInfo["path"] = ($urlInfo["path"] == "" ? "/" : $urlInfo["path"]);
	$urlInfo["port"] = ($urlInfo["port"] == "" ? 80 : $urlInfo["port"]);
	$hostIp = gethostbyname($urlInfo["host"]);

	$urlInfo["request"] =  $urlInfo["path"]	.
		(empty($urlInfo["query"]) ? "" : "?" . $urlInfo["query"]) .
		(empty($urlInfo["fragment"]) ? "" : "#" . $urlInfo["fragment"]);

	$fsock = fsockopen($hostIp, $urlInfo["port"], $errno, $errstr, $connectTimeout);
	if (false == $fsock) {
		return false;
	}
	/* begin send data */
	$in = "POST " . $urlInfo["request"] . " HTTP/1.0\r\n";
	$in .= "Accept: */*\r\n";
	$in .= "User-Agent: 139.com API PHP5 Client 1.1 (non-curl)\r\n";
	$in .= "Host: " . $urlInfo["host"] . "\r\n";
	$in .= "Content-type: application/x-www-form-urlencoded\r\n";
	$in .= "Content-Length: " . strlen($post_string) . "\r\n";
	$in .= "Connection: Close\r\n\r\n";
	$in .= $post_string . "\r\n\r\n";

	stream_set_timeout($fsock, $readTimeout);
	if (!fwrite($fsock, $in, strlen($in))) {
		fclose($fsock);
		return false;
	}
	unset($in);

	//process response
	$out = "";
	while ($buff = fgets($fsock, 2048)) {
		$out .= $buff;
	}
	//finish socket
	fclose($fsock);
	$pos = strpos($out, "\r\n\r\n");
	$head = substr($out, 0, $pos);		//http head
	$status = substr($head, 0, strpos($head, "\r\n"));		//http status line
	$body = substr($out, $pos + 4, strlen($out) - ($pos + 4));		//page body
	if (preg_match("/^HTTP\/\d\.\d\s([\d]+)\s.*$/", $status, $matches)) {
		if (intval($matches[1]) / 100 == 2) {//return http get body
			return $body;
		} else {
			return false;
		}
	} else {
		return false;
	}
}

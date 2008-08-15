### Tests for directives altering how a request is handled

# SecArgumentSeparator
{
	type => "config",
	comment => "SecArgumentSeparator (get-pos)",
	conf => q(
		SecRuleEngine On
		SecArgumentSeparator ";"
		SecRule ARGS:a "@streq 1" "phase:1,deny,chain"
		SecRule ARGS:b "@streq 2"
	),
	match_log => {
		error => [ qr/Access denied with code 403 \(phase 1\)\. String match "2" at ARGS:b\./, 1 ],
	},
	match_response => {
		status => qr/^403$/,
	},
	request => new HTTP::Request(
		GET => "http://$ENV{SERVER_NAME}:$ENV{SERVER_PORT}/test.txt?a=1;b=2",
	),
},
{
	type => "config",
	comment => "SecArgumentSeparator (get-neg)",
	conf => q(
		SecRuleEngine On
		SecRule ARGS:a "@streq 1" "phase:1,deny,chain"
		SecRule ARGS:b "@streq 2"
	),
	match_log => {
		-error => [ qr/Access denied/, 1 ],
	},
	match_response => {
		status => qr/^200$/,
	},
	request => new HTTP::Request(
		GET => "http://$ENV{SERVER_NAME}:$ENV{SERVER_PORT}/test.txt?a=1;b=2",
	),
},
{
	type => "config",
	comment => "SecArgumentSeparator (post-pos)",
	conf => q(
		SecRuleEngine On
		SecRequestBodyAccess On
		SecArgumentSeparator ";"
		SecRule ARGS:a "@streq 1" "phase:2,deny,chain"
		SecRule ARGS:b "@streq 2"
	),
	match_log => {
		error => [ qr/Access denied with code 403 \(phase 2\)\. String match "2" at ARGS:b\./, 1 ],
	},
	match_response => {
		status => qr/^403$/,
	},
	request => new HTTP::Request(
		POST => "http://$ENV{SERVER_NAME}:$ENV{SERVER_PORT}/test.txt",
		[
			"Content-Type" => "application/x-www-form-urlencoded",
		],
		"a=1;b=2",
	),
},
{
	type => "config",
	comment => "SecArgumentSeparator (post-neg)",
	conf => q(
		SecRuleEngine On
		SecRequestBodyAccess On
		SecRule ARGS:a "@streq 1" "phase:2,deny"
		SecRule ARGS:b "@streq 2" "phase:2,deny"
	),
	match_log => {
		-error => [ qr/Access denied/, 1 ],
	},
	match_response => {
		status => qr/^200$/,
	},
	request => new HTTP::Request(
		POST => "http://$ENV{SERVER_NAME}:$ENV{SERVER_PORT}/test.txt",
		[
			"Content-Type" => "application/x-www-form-urlencoded",
		],
		"a=1;b=2",
	),
},

# SecRequestBodyAccess
{
	type => "config",
	comment => "SecRequestBodyAccess (pos)",
	conf => qq(
		SecRuleEngine On
		SecRequestBodyAccess On
		SecRule ARGS:a "\@streq 1" "phase:2,deny,chain"
		SecRule ARGS:b "\@streq 2"
	),
	match_log => {
		error => [ qr/Access denied with code 403 \(phase 2\)\. String match "2" at ARGS:b\./, 1 ],
	},
	match_response => {
		status => qr/^403$/,
	},
	request => new HTTP::Request(
		POST => "http://$ENV{SERVER_NAME}:$ENV{SERVER_PORT}/test.txt",
		[
			"Content-Type" => "application/x-www-form-urlencoded",
		],
		"a=1&b=2",
	),
},
{
	type => "config",
	comment => "SecRequestBodyAccess (neg)",
	conf => qq(
		SecRuleEngine On
		SecRequestBodyAccess Off
		SecRule ARGS:a "\@streq 1" "phase:2,deny"
		SecRule ARGS:b "\@streq 2" "phase:2,deny"
	),
	match_log => {
		-error => [ qr/Access denied/, 1 ],
	},
	match_response => {
		status => qr/^200$/,
	},
	request => new HTTP::Request(
		POST => "http://$ENV{SERVER_NAME}:$ENV{SERVER_PORT}/test.txt",
		[
			"Content-Type" => "application/x-www-form-urlencoded",
		],
		"a=1&b=2",
	),
},

# SecRequestBodyLimit
{
	type => "config",
	comment => "SecRequestBodyLimit (equal)",
	conf => qq(
		SecRuleEngine On
		SecRequestBodyAccess On
		SecRequestBodyLimit 7
	),
	match_log => {
		-error => [ qr/Request body is larger than the configured limit/, 1 ],
	},
	match_response => {
		status => qr/^200$/,
	},
	request => new HTTP::Request(
		POST => "http://$ENV{SERVER_NAME}:$ENV{SERVER_PORT}/test.txt",
		[
			"Content-Type" => "application/x-www-form-urlencoded",
		],
		"a=1&b=2",
	),
},
{
	type => "config",
	comment => "SecRequestBodyLimit (greater)",
	conf => qq(
		SecRuleEngine On
		SecRequestBodyAccess On
		SecRequestBodyLimit 5
	),
	match_log => {
		error => [ qr/Request body .*is larger than the configured limit \(5\)\./, 1 ],
	},
	match_response => {
		status => qr/^413$/,
	},
	request => new HTTP::Request(
		POST => "http://$ENV{SERVER_NAME}:$ENV{SERVER_PORT}/test.txt",
		[
			"Content-Type" => "application/x-www-form-urlencoded",
		],
		"a=1&b=2",
	),
},

# SecRequestBodyInMemoryLimit
{
	type => "config",
	comment => "SecRequestBodyInMemoryLimit (equal)",
	conf => qq(
		SecRuleEngine On
		SecDebugLog $ENV{DEBUG_LOG}
		SecDebugLogLevel 9
		SecRequestBodyAccess On
		SecRequestBodyLimit 1000
		SecRequestBodyInMemoryLimit 276
	),
	match_log => {
		-debug => [ qr/Input filter: Request too large to store in memory, switching to disk\./, 1 ],
	},
	match_response => {
		status => qr/^200$/,
	},
	request => normalize_raw_request_data(
		qq(
			POST /test.txt HTTP/1.1
			Host: $ENV{SERVER_NAME}:$ENV{SERVER_PORT}
			User-Agent: $ENV{USER_AGENT}
			Content-Type: multipart/form-data; boundary=---------------------------69343412719991675451336310646
			Transfer-Encoding: chunked

		),
	)
	.encode_chunked(
		normalize_raw_request_data(
			q(
				-----------------------------69343412719991675451336310646
				Content-Disposition: form-data; name="a"

				1
				-----------------------------69343412719991675451336310646
				Content-Disposition: form-data; name="b"

				2
				-----------------------------69343412719991675451336310646--
			)
		),
		1024
	),
},
{
	type => "config",
	comment => "SecRequestBodyInMemoryLimit (greater)",
	conf => qq(
		SecRuleEngine On
		SecDebugLog $ENV{DEBUG_LOG}
		SecDebugLogLevel 9
		SecRequestBodyAccess On
		SecRequestBodyLimit 1000
		SecRequestBodyInMemoryLimit 16
	),
	match_log => {
		debug => [ qr/Input filter: Request too large to store in memory, switching to disk\./, 1 ],
	},
	match_response => {
		status => qr/^200$/,
	},
	request => normalize_raw_request_data(
		qq(
			POST /test.txt HTTP/1.1
			Host: $ENV{SERVER_NAME}:$ENV{SERVER_PORT}
			User-Agent: $ENV{USER_AGENT}
			Content-Type: multipart/form-data; boundary=---------------------------69343412719991675451336310646
			Transfer-Encoding: chunked

		),
	)
	.encode_chunked(
		normalize_raw_request_data(
			q(
				-----------------------------69343412719991675451336310646
				Content-Disposition: form-data; name="a"

				1
				-----------------------------69343412719991675451336310646
				Content-Disposition: form-data; name="b"

				2
				-----------------------------69343412719991675451336310646--
			)
		),
		1024
	),
},

# SecCookieFormat
{
	type => "config",
	comment => "SecCookieFormat (pos)",
	conf => qq(
		SecRuleEngine On
		SecDebugLog $ENV{DEBUG_LOG}
		SecDebugLogLevel 5
		SecCookieFormat 1
		SecRule REQUEST_COOKIES_NAMES "\@streq SESSIONID" "phase:1,deny,chain"
		SecRule REQUEST_COOKIES:\$SESSIONID_PATH "\@streq /" "chain"
		SecRule REQUEST_COOKIES:SESSIONID "\@streq cookieval"
	),
	match_log => {
		error => [ qr/Access denied with code 403 \(phase 1\)\. String match "cookieval" at REQUEST_COOKIES:SESSIONID\./, 1 ],
		debug => [ qr(Adding request cookie: name "\$SESSIONID_PATH", value "/"), 1 ],
	},
	match_response => {
		status => qr/^403$/,
	},
	request => new HTTP::Request(
		GET => "http://$ENV{SERVER_NAME}:$ENV{SERVER_PORT}/test.txt",
		[
			"Cookie" => q($Version="1"; SESSIONID="cookieval"; $PATH="/"),
		],
		undef,
	),
},
{
	type => "config",
	comment => "SecCookieFormat (neg)",
	conf => qq(
		SecRuleEngine On
		SecDebugLog $ENV{DEBUG_LOG}
		SecDebugLogLevel 5
		SecCookieFormat 0
		SecRule REQUEST_COOKIES_NAMES "\@streq SESSIONID" "phase:1,deny,chain"
		SecRule REQUEST_COOKIES:\$SESSIONID_PATH "\@streq /" "chain"
		SecRule REQUEST_COOKIES:SESSIONID "\@streq cookieval"
	),
	match_log => {
		-error => [ qr/Access denied/, 1 ],
		-debug => [ qr(Adding request cookie: name "\$SESSIONID_PATH", value "/"), 1 ],
	},
	match_response => {
		status => qr/^200$/,
	},
	request => new HTTP::Request(
		GET => "http://$ENV{SERVER_NAME}:$ENV{SERVER_PORT}/test.txt",
		[
			"Cookie" => q($Version="1"; SESSIONID="cookieval"; $PATH="/"),
		],
		undef,
	),
},


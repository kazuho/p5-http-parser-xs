#include <stdio.h>
#include <string.h>
#include "picohttpparser.h"

void tests(int num)
{
  printf("1..%d\n", num);
}

void ok(int ok, const char* msg)
{
  static int testnum = 0;
  printf("%s %d - %s\n", ok ? "ok" : "ng", ++testnum, msg);
}

int strrcmp(const char* s, size_t l, const char* t)
{
  return strlen(t) == l && memcmp(s, t, l) == 0;
}

int main(void)
{
  const char* method;
  size_t method_len;
  const char* path;
  size_t path_len;
  int minor_version;
  struct phr_header headers[4];
  
  tests(15);
  
#define PARSE(s, last_len)					    \
  phr_parse_request(s, strlen(s), &method, &method_len, &path,	    \
		    &path_len,	&minor_version, headers,	    \
		    sizeof(headers) / sizeof(headers[0]), last_len)
  
  ok(PARSE("GET / HTTP/1.0\r\n\r\n", 0) == 0, "simple");
  ok(strrcmp(method, method_len, "GET"), "method");
  ok(strrcmp(path, path_len, "/"), "path");
  ok(minor_version == 0, "minor version");
  
  ok(PARSE("GET / HTTP/1.0\r\n\r", 0) == -2, "partial");
  
  ok(PARSE("GET /hoge HTTP/1.1\r\nHost: example.com\r\nCookie: \r\n\r\n", 0)
     == 2,
     "parse headers");
  ok(strrcmp(method, method_len, "GET"), "method");
  ok(strrcmp(path, path_len, "/hoge"), "path");
  ok(minor_version == 1, "minor version");
  ok(strrcmp(headers[0].name, headers[0].name_len, "Host"), "host");
  ok(strrcmp(headers[0].value, headers[0].value_len, "example.com"),
     "host value");
  ok(strrcmp(headers[1].name, headers[1].name_len, "Cookie"), "cookie");
  ok(strrcmp(headers[1].value, headers[1].value_len, ""), "cookie value");
  
  ok(PARSE("GET /hoge HTTP/1.0\r\n\r",
	   strlen("GET /hoge HTTP/1.0\r\n\r") - 1)
     == -2,
     "slowloris (incomplete)");
  ok(PARSE("GET /hoge HTTP/1.0\r\n\r\n",
	   strlen("GET /hoge HTTP/1.0\r\n\r\n") - 1)
     == 0,
     "slowloris (complete)");
  
#undef PARSE
  
  return 0;
}

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include "picohttpparser/picohttpparser.c"

#define MAX_HEADERS 128

__inline char tou(char ch)
{
  if ('a' <= ch && ch <= 'z')
    ch -= 'a' - 'A';
  return ch;
}

static int header_is(const struct phr_header* header, const char* name,
		     size_t len)
{
  const char* x, * y;
  if (header->name_len != len)
    return 0;
  for (x = header->name, y = name; len != 0; --len, ++x, ++y)
    if (tou(*x) != *y)
      return 0;
  return 1;
}

MODULE = HTTP::Parser::XS    PACKAGE = HTTP::Parser::XS

SV* parse_http_request(SV* buf, SV* envref)
PROTOTYPE: $$
CODE:
{
  const char* buf_str;
  STRLEN buf_len;
  const char* method;
  size_t method_len;
  const char* path;
  size_t path_len;
  int minor_version;
  struct phr_header headers[MAX_HEADERS];
  size_t num_headers;
  int ret, i;
  HV* env;
  SV* last_value;
  char tmp[1024];
  
  buf_str = SvPV(buf, buf_len);
  num_headers = MAX_HEADERS;
  ret = phr_parse_request(buf_str, buf_len, &method, &method_len, &path,
			  &path_len, &minor_version, headers, &num_headers, 0);
  if (ret < 0)
    goto done;
  
  env = (HV*)SvRV(envref);
  assert(SvTYPE(env) == SVt_PVHV); /* TODO use die, but how? */
  
  hv_clear(env);
  hv_store(env, "REQUEST_METHOD", sizeof("REQUEST_METHOD") - 1,
           newSVpvn(method, method_len), 0);
  hv_store(env, "SCRIPT_NAME", sizeof("SCRIPT_NAME") - 1, newSVpvn("", 0), 0);
  hv_store(env, "PATH_INFO", sizeof("PATH_INFO") - 1, newSVpvn(path, path_len),
           0);
  sprintf(tmp, "HTTP/1.%d", minor_version);
  hv_store(env, "SERVER_PROTOCOL", sizeof("SERVER_PROTOCOL") - 1,
           newSVpv(tmp, 0), 0);
  last_value = NULL;
  for (i = 0; i < num_headers; ++i) {
    if (headers[i].name != NULL) {
      const char* name;
      size_t name_len;
      SV** slot;
      if (header_is(headers + i, "CONTENT-TYPE", sizeof("CONTENT-TYPE") - 1)) {
	name = "CONTENT_TYPE";
	name_len = sizeof("CONTENT_TYPE") - 1;
      } else if (header_is(headers + i, "CONTENT-LENGTH",
			   sizeof("CONTENT-LENGTH") - 1)) {
	name = "CONTENT_LENGTH";
	name_len = sizeof("CONTENT_LENGTH") - 1;
      } else {
	const char* s;
	char* d;
	size_t n;
        if (sizeof(tmp) - 5 < headers[i].name_len) {
	  hv_clear(env);
          ret = -1;
          goto done;
        }
        strcpy(tmp, "HTTP_");
        for (s = headers[i].name, n = headers[i].name_len, d = tmp + 5;
	     n != 0;
	     s++, --n, d++) {
            if (*s == '-') {
              *d = '_';
          } else {
	    *d = tou(*s);
          }
        }
        name = tmp;
        name_len = headers[i].name_len + 5;
      }
      slot = hv_fetch(env, name, name_len, 1);
      if (SvOK(*slot)) {
        sv_catpvn(*slot, ", ", 2);
        sv_catpvn(*slot, headers[i].value, headers[i].value_len);
      } else {
        *slot = newSVpvn(headers[i].value, headers[i].value_len);
      }
      last_value = *slot;
    } else {
      /* continuing lines of a mulitiline header */
      sv_catpvn(last_value, headers[i].value, headers[i].value_len);
    }
  }
  
 done:
  RETVAL = newSViv(ret);
}
OUTPUT:
  RETVAL

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include "picohttpparser/picohttpparser.c"

#define MAX_HEADERS 128

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
           newSVpv(method, method_len), 0);
  hv_store(env, "SCRIPT_NAME", sizeof("SCRIPT_NAME") - 1, newSVpv("", 0), 0);
  hv_store(env, "PATH_INFO", sizeof("PATH_INFO") - 1, newSVpv(path, path_len),
           0);
  sprintf(tmp, "HTTP/1.%d", minor_version);
  hv_store(env, "SERVER_PROTOCOL", sizeof("SERVER_PROTOCOL") - 1,
           newSVpv(tmp, 0), 0);
  last_value = NULL;
  for (i = 0; i < num_headers; ++i) {
    if (headers[i].name != NULL) {
      const char* s;
      char* d;
      size_t n;
      if (headers[i].name_len > sizeof(tmp) - 5) {
	hv_clear(env);
        ret = -1;
	goto done;
      }
      strcpy(tmp, "HTTP_");
      for (s = headers[i].name, n = headers[i].name_len, d = tmp + 5;
	   n != 0;
	   --n) {
	*d++ = toupper(*s++);
      }
      last_value = newSVpv(headers[i].value, headers[i].value_len);
      hv_store(env, tmp, headers[i].name_len + 5, last_value, 0);
    } else {
      /* contiuing lines of a mulitiline header */
	if (headers[i].value_len != 0) {
	  /* should be optimized, but multiline headers aren't used anyway */
	  sv_catpvn(last_value, " ", 1);
	  sv_catpvn(last_value, headers[i].value, headers[i].value_len);
	}
    }
  }
  
 done:
  RETVAL = newSViv(ret);
}
OUTPUT:
  RETVAL

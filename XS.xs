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

__inline char tol(char ch)
{
  if ('A' <= ch && ch <= 'Z')
    ch -= 'A' - 'a';
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

static size_t find_ch(const char* s, size_t len, char ch)
{
  size_t i;
  for (i = 0; i != len; ++i, ++s)
    if (*s == ch)
      break;
  return i;
}

__inline int hex_decode(const char ch)
{
  int r;
  if ('0' <= ch && ch <= '9')
    r = ch - '0';
  else if ('A' <= ch && ch <= 'F')
    r = ch - 'A' + 0xa;
  else if ('a' <= ch && ch <= 'f')
    r = ch - 'a' + 0xa;
  else
    r = -1;
  return r;
}

static char* url_decode(const char* s, size_t len)
{
  char* dbuf, * d;
  size_t i;
  
  for (i = 0; i < len; ++i)
    if (s[i] == '%')
      goto NEEDS_DECODE;
  return (char*)s;
  
 NEEDS_DECODE:
  dbuf = malloc(len - 1);
  assert(dbuf != NULL);
  memcpy(dbuf, s, i);
  d = dbuf + i;
  while (i < len) {
    if (s[i] == '%') {
      int hi, lo;
      if ((hi = hex_decode(s[i + 1])) == -1
	  || (lo = hex_decode(s[i + 2])) == -1) {
        free(dbuf);
    	return NULL;
      }
      *d++ = hi * 16 + lo;
      i += 3;
    } else
      *d++ = s[i++];
  }
  *d = '\0';
  return dbuf;
}

__inline int store_url_decoded(HV* env, const char* name, size_t name_len,
			       const char* value, size_t value_len)
{
  char* decoded = url_decode(value, value_len);
  if (decoded == NULL)
    return -1;
  
  if (decoded == value)
    hv_store(env, name, name_len, newSVpvn(value, value_len), 0);
  else {
    hv_store(env, name, name_len, newSVpv(decoded, 0), 0);
    free(decoded);
  }
  return 0;
}

MODULE = HTTP::Parser::XS    PACKAGE = HTTP::Parser::XS

int parse_http_request(SV* buf, SV* envref)
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
  size_t num_headers, question_at;
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
  
  if (!SvROK(envref))
    Perl_croak(aTHX_ "second param to parse_http_request should be a hashref");

  env = (HV*)SvRV(envref);
  if (SvTYPE(env) != SVt_PVHV)
    Perl_croak(aTHX_ "second param to parse_http_request should be a hashref");
  
  hv_store(env, "REQUEST_METHOD", sizeof("REQUEST_METHOD") - 1,
           newSVpvn(method, method_len), 0);
  hv_store(env, "REQUEST_URI", sizeof("REQUEST_URI") - 1,
	   newSVpvn(path, path_len), 0);
  hv_store(env, "SCRIPT_NAME", sizeof("SCRIPT_NAME") - 1, newSVpvn("", 0), 0);
  question_at = find_ch(path, path_len, '?');
  if (store_url_decoded(env, "PATH_INFO", sizeof("PATH_INFO") - 1, path,
			question_at)
      != 0) {
    hv_clear(env);
    ret = -1;
    goto done;
  }
  if (question_at != path_len)
    ++question_at;
  hv_store(env, "QUERY_STRING", sizeof("QUERY_STRING") - 1,
	   newSVpvn(path + question_at, path_len - question_at), 0);
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
	     s++, --n, d++)
          *d = *s == '-' ? '_' : tou(*s);
        name = tmp;
        name_len = headers[i].name_len + 5;
      }
      slot = hv_fetch(env, name, name_len, 1);
      if ( !slot )
        croak("failed to create hash entry");
      if (SvOK(*slot)) {
        sv_catpvn(*slot, ", ", 2);
        sv_catpvn(*slot, headers[i].value, headers[i].value_len);
      } else
        sv_setpvn(*slot, headers[i].value, headers[i].value_len);
      last_value = *slot;
    } else {
      /* continuing lines of a mulitiline header */
      sv_catpvn(last_value, headers[i].value, headers[i].value_len);
    }
  }
  
 done:
  RETVAL = ret;
}
OUTPUT:
  RETVAL

int parse_http_response(SV* buf, SV* resref)
PROTOTYPE: $$
CODE:
{
  const char* buf_str;
  STRLEN buf_len;
  const char* msg;
  size_t msg_len;
  int minor_version, status;
  struct phr_header headers[MAX_HEADERS];
  size_t num_headers, question_at;
  int ret, i;
  HV* res;
  SV* last_value;
  char tmp[1024];
  
  buf_str = SvPV(buf, buf_len);
  num_headers = MAX_HEADERS;
 
  ret = phr_parse_response(buf_str, buf_len, &minor_version, &status, &msg, &msg_len, headers, &num_headers, 0);
  if (ret < 0)
    goto done;
  
  if (!SvROK(resref))
    Perl_croak(aTHX_ "second param to parse_http_response should be a hashref");

  res = (HV*)SvRV(resref);
  if (SvTYPE(res) != SVt_PVHV)
    Perl_croak(aTHX_ "second param to parse_http_response should be a hashref");
  
  hv_store(res, "_msg", sizeof("_msg") - 1, newSVpvn(msg, msg_len), 0);
  hv_store(res, "_rc", sizeof("_rc") - 1, newSViv(status), 0);
  sprintf(tmp, "HTTP/1.%d", minor_version);
  hv_store(res, "_protocol", sizeof("_protocol") - 1, newSVpv(tmp, 0), 0);

  last_value = NULL;

  HV* h_headers = newHV();
  SV* ref = (SV*)newRV_noinc( (SV*)h_headers );
  hv_store(res, "_headers", sizeof("_headers") - 1, ref, 0);

  for (i = 0; i < num_headers; ++i) {
    if (headers[i].name != NULL) {
      const char* name;
      size_t name_len;
      SV** slot;
      if (1) {
	const char* s;
	char* d;
	size_t n;
	// too large field name
        if (sizeof(tmp) < headers[i].name_len) {
      	  hv_clear(res);
          ret = -1;
          goto done;
        }
        for (s = headers[i].name, n = headers[i].name_len, d = tmp;
	     n != 0;
	     s++, --n, d++)
          *d = *s == '_' ? '-' : tol(*s);
        name = tmp;
        name_len = headers[i].name_len;
      }

      slot = hv_fetch(h_headers, name, name_len, 1);
      if ( !slot )
        croak("failed to create hash entry");
      if (SvOK(*slot)) {
        
	if (SvROK(*slot)) {
	  AV* values = (AV*)SvRV(*slot);
          SV* newval = newSVpvn(headers[i].value, headers[i].value_len);
          av_push(values, newval);
          last_value = newval;
	} else {
	  AV* values = newAV();
	  SV* old_val = *slot;
	  SvREFCNT_inc(old_val);
          SV* newval = newSVpvn(headers[i].value, headers[i].value_len);

          av_push(values, old_val);
          av_push(values, newval);
          SV* values_ref = (SV*)newRV_noinc( (SV*)values );

          slot = hv_store(h_headers, name, name_len, values_ref, 0);
          last_value = newval;
	}
      } else {
        sv_setpvn(*slot, headers[i].value, headers[i].value_len);
        last_value = *slot;
      }
    } else {
      /* continuing lines of a mulitiline header */
      sv_catpvn(last_value, "\n", 1);
      sv_catpvn(last_value, headers[i].value, headers[i].value_len);
    }
  }
  
 done:
  RETVAL = ret;
}
OUTPUT:
  RETVAL

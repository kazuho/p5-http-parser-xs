#define PERL_NO_GET_CONTEXT
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#define NEED_newRV_noinc
#define NEED_newSVpvn_flags
#define NEED_sv_2pv_flags
#include "ppport.h"
#include "picohttpparser/picohttpparser.c"

#ifndef STATIC_INLINE /* a public perl API from 5.13.4 */
#   if defined(__GNUC__) || defined(__cplusplus) || (defined(__STDC_VERSION__) && (__STDC_VERSION__ >= 199901L))
#       define STATIC_INLINE static inline
#   else
#       define STATIC_INLINE static
#   endif
#endif /* STATIC_INLINE */

#define MAX_HEADER_NAME_LEN 1024
#define MAX_HEADERS         128

#define HEADERS_NONE        0
#define HEADERS_AS_HASHREF  1
#define HEADERS_AS_ARRAYREF 2

STATIC_INLINE
char tou(char ch)
{
  if ('a' <= ch && ch <= 'z')
    ch -= 'a' - 'A';
  return ch;
}

STATIC_INLINE char tol(char const ch)
{
  return ('A' <= ch && ch <= 'Z')
    ? ch - ('A' - 'a')
    : ch;
}

/* copy src to dest with normalization.
   dest must have enough size for src */
STATIC_INLINE
void normalize_response_header_name(pTHX_
        char* const dest,
        const char* const src, STRLEN const len) {
    STRLEN i;
    for(i = 0; i < len; i++) {
        dest[i] = tol(src[i]);
    }
}

STATIC_INLINE
void concat_multiline_header(pTHX_ SV * val, const char * const cont, size_t const cont_len) {
    sv_catpvs(val, "\n"); /* XXX: is it collect? */
    sv_catpvn(val, cont, cont_len);
}

static
int header_is(const struct phr_header* header, const char* name,
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

static
size_t find_ch(const char* s, size_t len, char ch)
{
  size_t i;
  for (i = 0; i != len; ++i, ++s)
    if (*s == ch)
      break;
  return i;
}

STATIC_INLINE
int hex_decode(const char ch)
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

static
char* url_decode(const char* s, size_t len)
{
  dTHX;
  char* dbuf, * d;
  size_t i;
  
  for (i = 0; i < len; ++i)
    if (s[i] == '%')
      goto NEEDS_DECODE;
  return (char*)s;
  
 NEEDS_DECODE:
  dbuf = (char*)malloc(len - 1);
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

STATIC_INLINE
int store_url_decoded(HV* env, const char* name, size_t name_len,
			       const char* value, size_t value_len)
{
  dTHX;
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
  size_t i;
  int ret;
  HV* env;
  SV* last_value;
  char tmp[MAX_HEADER_NAME_LEN + sizeof("HTTP_") - 1];
  
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
  path_len = find_ch(path, path_len, '#'); /* strip off all text after # after storing request_uri */
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

void
parse_http_response(SV* buf, int header_format, HV* special_headers = NULL)
PPCODE:
{
  int minor_version, status;
  const char* msg;
  size_t msg_len;
  struct phr_header headers[MAX_HEADERS];
  size_t num_headers = MAX_HEADERS;
  STRLEN buf_len;
  const char* const buf_str = SvPV_const(buf, buf_len);
  size_t last_len = 0;
  int const ret             = phr_parse_response(buf_str, buf_len,
    &minor_version, &status, &msg, &msg_len, headers, &num_headers, last_len);
  SV* last_special_headers_value_sv = NULL;
  SV* last_element_value_sv         = NULL;
  size_t i;
  SV *res_headers;
  char name[MAX_HEADER_NAME_LEN]; /* temp buffer for normalized names */

  if (header_format == HEADERS_AS_HASHREF) {
    res_headers = sv_2mortal((SV*)newHV());
  } else if (header_format == HEADERS_AS_ARRAYREF) {
    res_headers = sv_2mortal((SV*)newAV());
    av_extend((AV*)res_headers, (num_headers * 2) - 1);
  } else if (header_format == HEADERS_NONE) {
    res_headers = NULL;
  }

  for (i = 0; i < num_headers; i++) {
    struct phr_header const h = headers[i];
    if (h.name != NULL) {
      SV* namesv;
      SV* valuesv;
      if(h.name_len > sizeof(name)) {
          /* skip if name_len is too long */
          continue;
      }

      normalize_response_header_name(aTHX_
        name, h.name, h.name_len);

      if(special_headers) {
          SV** const slot = hv_fetch(special_headers,
            name, h.name_len, FALSE);
          if (slot) {
            SV* const hash_value = *slot;
            sv_setpvn_mg(hash_value, h.value, h.value_len);
            last_special_headers_value_sv = hash_value;
          }
          else {
            last_special_headers_value_sv = NULL;
          }
      }

      if(header_format == HEADERS_NONE) {
          continue;
      }

      namesv  = sv_2mortal(newSVpvn_share(name, h.name_len, 0U));
      valuesv = newSVpvn_flags(
        h.value, h.value_len, SVs_TEMP);

      if (header_format == HEADERS_AS_HASHREF) {
        HE* const slot = hv_fetch_ent((HV*)res_headers, namesv, FALSE, 0U);
        if(!slot) { /* first time */
            (void)hv_store_ent((HV*)res_headers, namesv,
                SvREFCNT_inc_simple_NN(valuesv), 0U);
        }
        else { /* second time; the header has multiple values */
            SV* sv = hv_iterval((HV*)res_headers, slot);
            if(!( SvROK(sv) && SvTYPE(SvRV(sv)) == SVt_PVAV )) {
                /* make $value to [$value] and restore it to $res_header */
                AV* const av    = newAV();
                SV* const avref = newRV_noinc((SV*)av);
                (void)av_store(av, 0, SvREFCNT_inc_simple_NN(sv));
                (void)hv_store_ent((HV*)res_headers, namesv, avref, 0U);
                sv = avref;
            }
            av_push((AV*)SvRV(sv), SvREFCNT_inc_simple_NN(valuesv));
        }
        last_element_value_sv = valuesv;
      } else if (header_format == HEADERS_AS_ARRAYREF) {
            av_push((AV*)res_headers, SvREFCNT_inc_simple_NN(namesv));
            av_push((AV*)res_headers, SvREFCNT_inc_simple_NN(valuesv));
            last_element_value_sv = valuesv;
      }
    } else {
      /* continuing lines of a mulitiline header */
      if (special_headers && last_special_headers_value_sv) {
        concat_multiline_header(aTHX_ last_special_headers_value_sv, h.value, h.value_len);
      }
      if ((header_format == HEADERS_AS_HASHREF || header_format == HEADERS_AS_ARRAYREF) && last_element_value_sv) {
        concat_multiline_header(aTHX_ last_element_value_sv, h.value, h.value_len);
      }
    }
  }
  
  if(ret > 0) {
    EXTEND(SP, 5);
    mPUSHi(ret);
    mPUSHi(minor_version);
    mPUSHi(status);
    mPUSHp(msg, msg_len);
    if (res_headers) {
      mPUSHs(newRV_inc(res_headers));
    } else {
      mPUSHs(&PL_sv_undef);
    }
  }
  else {
    EXTEND(SP, 1);
    mPUSHi(ret);
  }
}


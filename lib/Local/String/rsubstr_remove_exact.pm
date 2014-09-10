package Local::String::rsubstr_remove_exact;

use Inline C => <<'END_C';
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <alloca.h>

static inline _Bool check_char_in_word_class(const char c)
{
   return c == '_' ||
          ('A' <= c && c <= 'Z') ||
          ('a' <= c && c <= 'z') ||
          ('0' <= c && c <= '9');
}

struct position {
   const char *b;
   const char *e;
};

static inline struct position strrstr_exact(const char *s, size_t sl, const char *p, size_t pl)
{
	register const char *sb  = s;
	const char *se = s + sl - 1;
	register const char *si  = se;
	register const char *pb  = p;
	const char *pe = p + pl - 1;
	register const char *pi  = pe;

	do {
		if (pi == pb) {
         if (!check_char_in_word_class(*(si - 1)) && !check_char_in_word_class(*(se + 1))) {
   			return (struct position) { si, se };
         } else {
            goto RESTART;
         }
		}
		if (*pi == *si) {
			--pi;
			--si;
		} else {
RESTART:
			pi = pe;
			if (sb == si) {
				return (struct position) { (const char *) -1, (const char *) -1 };
			}
			si = --se;
		}
	} while (1);
}

void rsubstr_remove_exact(SV *s, SV *p)
{
   if (SvPOK(s) && SvPOK(p)) {
      STRLEN sl;
      STRLEN pl;
      char *string  = SvPV(s, sl);
      char *pattern = SvPV(p, pl);
      struct position ps = strrstr_exact(string, sl, pattern, pl);

      if (ps.b == ps.e && ps.b == (const char *) -1) {
         return;
      }

      memmove((char *) ps.b, ps.e + 1, sl - (ps.e - string));
      SvCUR_set(s, sl - pl);
   }
}
END_C

use Exporter qw/import/;

our @EXPORT = qw/rsubstr_remove_exact/;

1;

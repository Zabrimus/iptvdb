select x1.id x1, x2.id x2
from xmltvid x1, xmltvid x2
where upper(x1.name) = upper(x2.name)
  and x1.country = x2.country
  and x1.xmltv_id <> x2.xmltv_id;

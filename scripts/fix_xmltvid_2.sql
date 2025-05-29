select distinct IIF(x1.id  < x2.id, x1.id, x2.id) x1,
                IIF(x1.id  > x2.id, x1.id, x2.id) x2,
                IIF(x1.id  < x2.id, x1.xmltv_id, x2.xmltv_id) xmltv_id1,
                IIF(x1.id  > x2.id, x1.xmltv_id, x2.xmltv_id) xmltv_id2
from xmltvid x1, xmltvid x2
where upper(x1.name) = upper(x2.name)
  and coalesce(x1.country, '-') = coalesce(x2.country, '-')
  and x1.xmltv_id <> x2.xmltv_id

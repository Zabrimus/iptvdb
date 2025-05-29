select distinct IIF(x1.id  < x2.id, x1.id, x2.id) x1,
                IIF(x1.id  > x2.id, x1.id, x2.id) x2,
                IIF(x1.id  < x2.id, x1.xmltv_id, x2.xmltv_id) xmltv_id1,
                IIF(x1.id  > x2.id, x1.xmltv_id, x2.xmltv_id) xmltv_id2
from xmltvid x1, xmltvid x2
where x1.name = x2.name
  and x1.country = x2.country
  and x1.xmltv_id <> x2.xmltv_id

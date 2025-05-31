select IIF(instr(x1.xmltv_id, '--') > 0, x2.id, x1.id),
       IIF(instr(x1.xmltv_id, '--') > 0, x1.id, x2.id)
from xmltvid x1, xmltvid x2
where upper(x1.name) = upper(x2.name)
  and x1.country = x2.country
  and x1.xmltv_id <> x2.xmltv_id
  and (x2.xmltv_id like '--%' or x1.xmltv_id like '--%')
  and x1.id < x2.id

union

select x2.id, x1.id
 from xmltvid x1, xmltvid x2
where x1.xmltv_id = x2.xmltv_id
  and x1.name = x2.name
  and (x1.country is null and x2.country is not null)

union

select distinct IIF(x1.id  > x2.id, x1.id, x2.id) x2,
                IIF(x1.id  < x2.id, x1.id, x2.id) x1
from xmltvid x1, xmltvid x2
where upper(x1.name) = upper(x2.name)
  and x1.country = x2.country
  and x1.xmltv_id <> x2.xmltv_id
  and instr(x1.xmltv_id, '--') > 0

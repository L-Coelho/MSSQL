SELECT items.subject ,
       items.recipients ,
       items.copy_recipients ,
       items.blind_copy_recipients ,
       items.last_mod_date ,
       l.description
FROM   msdb.dbo.sysmail_faileditems AS items
       LEFT OUTER JOIN msdb.dbo.sysmail_event_log AS l 
                    ON items.mailitem_id = l.mailitem_id
--WHERE  items.last_mod_date > DATEADD(DAY, -100,GETDATE())
order by last_mod_date
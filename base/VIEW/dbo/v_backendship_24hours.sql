SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

CREATE VIEW [dbo].[v_BACKENDSHIP_24HOURS] as
select substring(convert(char(14),effectivedate,120),3,8) DATESHIP,
       substring(convert(char(14),effectivedate,120),12,2) HOUR24,
sum(CASE  WHEN ShipCounter >= '1' THEN 1 ELSE 0 END) AS BACKEND,
sum(CASE ShipCounter WHEN  NULL THEN 1 WHEN ' ' THEN 1  ELSE 0 END) AS FRONTEND,
count(*) TOTAL from mbol (nolock) 
where effectivedate > getdate()-1  and status ='9' 
group by substring(convert(char(14),effectivedate,120),3,8) ,
         substring(convert(char(14),effectivedate,120),12,2)



GO
SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
--https://jiralfl.atlassian.net/browse/WMS-14416
CREATE VIEW [BI].[V_JRPT_MHAP_MHDC_PackingSlip_TLBNo]
AS
SELECT DISTINCT O.LoadKey,
       O.MBOLKey,
       REPLACE(LTRIM(REPLACE(O.ExternOrderKey,'0',' ')),' ','0') AS TLBNo,
       ExternOrderKey
FROM dbo.ORDERS O WITH (NOLOCK)
WHERE O.StorerKey in ('MHAP')
--and O.loadkey in ('0001352071') 
--and O.loadkey in ('0001386661')
--GROUP BY O.LoadKey,
--O.MBOLKey,
--O.ExternOrderKey

GO
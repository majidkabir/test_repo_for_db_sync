SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
--https://jiralfl.atlassian.net/browse/WMS-14416
CREATE VIEW [BI].[V_JRPT_MHAP_MHDC_PackingSlip_Container]
AS
SELECT DISTINCT O.LoadKey,
       O.MBOLKey,
       C.ETA AS DATE, 
       C.ETADestination AS ETASH, 
       C.BookingReference AS ContainerNo, 
       C.Seal01 AS SealNo
FROM dbo.ORDERS O WITH (NOLOCK)
LEFT OUTER JOIN dbo.CONTAINER C WITH (NOLOCK) ON C.MBOLKey = O.MBOLKey
WHERE O.StorerKey in ('MHAP')
--and O.loadkey in ('0001352071') 
--and O.loadkey in ('0001386661')
--GROUP BY O.LoadKey,
--         O.MBOLKey,
--         C.ETA, 
--         C.ETADestination, 
--         C.BookingReference, 
--         C.Seal01

GO
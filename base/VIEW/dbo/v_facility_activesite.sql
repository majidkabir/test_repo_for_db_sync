SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE   VIEW [dbo].[V_FACILITY_ActiveSite]
AS 
SELECT DbName = DB_NAME()
     , F.SiteID
     , F.Facility
     , F.Descr
     , F.[Type]
     , F.ISOCntryCode
     , F.SqFeet
     , F.Longitude
     , F.Latitude
     , F.LeaseType
     , F.FacilityFor
     , F.AddDate
     , F.EditDate
     , O.OrdersAddDate
     , I.ItrnAddDate
FROM dbo.FACILITY AS F WITH (NOLOCK)
OUTER APPLY (  SELECT OrdersAddDate = MAX(O.AddDate) 
               FROM dbo.ORDERS AS O WITH (NOLOCK)
               WHERE F.Facility = O.Facility ) AS O

OUTER APPLY (  SELECT ItrnAddDate = MAX(I.AddDate)
               FROM dbo.ITRN AS I WITH (NOLOCK) JOIN dbo.STORER AS S WITH (NOLOCK) ON S.StorerKey = I.StorerKey
               WHERE F.Facility = S.Facility ) AS I
WHERE NOT ([Type] = 'Obsolete'
   OR  SiteID = 'NA' )

GO
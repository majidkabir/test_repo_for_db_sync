SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

CREATE   VIEW [dbo].[V_ExternOrder_SamePlatform]
 AS
   WITH
      tab2(MAXExternOrdersKey, ExternOrderKey,PlatformOrderNo, count1, Maxdate)
      AS
      (
         SELECT MAX(ExternOrdersKey), ExternOrderKey,PlatformOrderNo, COUNT(1) as count1, MAX(shippeddate) as MaxDate
         FROM Externorders(NOLOCK)
         WHERE PlatformOrderNo <>'' AND Status='9'
         GROUP BY ExternOrderKey, PlatformOrderNo
         HAVING COUNT(1)>1
      )
SELECT tab1.ExternOrdersKey,tab1.ExternOrderKey, tab1.PlatformOrderNo, tab1.ShippedDate, tab2.Maxdate
FROM externorders tab1, tab2
WHERE tab1.ExternOrderKey= tab2.ExternOrderKey
AND tab1.PlatformOrderNo=tab2.PlatformOrderNo
AND tab1.ExternOrdersKey < tab2.MAXExternOrdersKey

GO
SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

CREATE   VIEW [BI].[V_TH_DSG_OnTime_Submission_POD] AS
SELECT
   O.StorerKey ,
   ST.Company,
   O.Route,
   COUNT (DISTINCT O.OrderKey) AS 'NoOfOrders',
   MAX( dateadd(d, 1 - datepart(dw, O.EditDate), convert(char(8), O.EditDate, 112)) ) AS 'DateFrom',
   MAX( dateadd(d, 7 - datepart(dw, O.EditDate), convert(char(8), O.EditDate, 112)) ) AS 'DateTo',
   convert(datetime, convert(char(8), P.ActualDeliveryDate, 112)) AS 'Actualdeliverydate',
   convert(datetime, convert(char(8), P.PodReceivedDate, 112)) AS 'PodreceiveDate',
   P.Status,
   convert(datetime, convert(char(8), P.ActualDeliveryDate, 112)) AS 'Deliverydate',
   COUNT(DISTINCT
   CASE
      WHEN
         Datediff(d, P.InvDespatchDate, P.ActualDeliveryDate) <= 0
      THEN
         P.OrderKey
   END
)AS 'OnTime', convert(datetime, convert(char(8), O.EditDate, 112)) AS 'ShipDate',
   CASE
      WHEN
         substring(O.Route, 1, 1 ) = 'A'
      THEN
         'BKK'
      ELSE
         CASE
            WHEN
               substring(O.Route, 1, 1 ) = 'M'
            THEN
               'MT'
            ELSE
               CASE
                  WHEN
                     substring(O.Route, 1, 1 ) = 'C'
                  THEN
                     'Central'
                  ELSE
                     'UPC'
               END
         END
   END AS 'BKKUPC'
,
   CASE
      WHEN
         substring(O.Route, 1, 1 ) = 'A'
      THEN
(P.ActualDeliveryDate + 3 )
      ELSE
         CASE
            WHEN
               substring(O.Route, 1, 1 ) = 'M'
            THEN
(P.ActualDeliveryDate + 3 )
            ELSE
               CASE
                  WHEN
                     substring(O.Route, 1, 1 ) = 'C'
                  THEN
(P.ActualDeliveryDate + 4 )
                  ELSE
(P.ActualDeliveryDate + 5 )
               END
         END
   END AS 'ESTOnTimePOD'
, COUNT(
   CASE
      WHEN
         Datediff(d,
         (
            CASE
               WHEN
                  substring(O.Route, 1, 1 ) = 'A'
               THEN
(P.ActualDeliveryDate + 3 )
               ELSE
                  CASE
                     WHEN
                        substring(O.Route, 1, 1 ) = 'M'
                     THEN
(P.ActualDeliveryDate + 3 )
                     ELSE
                        CASE
                           WHEN
                              substring(O.Route, 1, 1 ) = 'C'
                           THEN
(P.ActualDeliveryDate + 4 )
                           ELSE
(P.ActualDeliveryDate + 5 )
                        END
                  END
            END
         )
, P.PodReceivedDate) <= 0
      THEN
         P.OrderKey
   END
) AS 'PODOnTime'
FROM dbo.POD P with (nolock)
JOIN dbo.STORER ST with (nolock) ON P.Storerkey = ST.StorerKey
JOIN dbo.ORDERS O with (nolock) ON P.OrderKey = O.OrderKey
WHERE O.StorerKey = 'DSGTH'
      AND O.Status = '9'
      AND O.EditDate >= convert(varchar(10), getdate() - 30, 120)
      AND O.EditDate < convert(varchar(10), getdate() - 1, 120)
GROUP BY
   O.StorerKey, ST.Company, O.Route, convert(datetime, convert(char(8), P.ActualDeliveryDate, 112)), convert(datetime, convert(char(8), P.PodReceivedDate, 112)), P.Status, convert(datetime, convert(char(8), P.ActualDeliveryDate, 112)), convert(datetime, convert(char(8), O.EditDate, 112)),
   CASE
      WHEN
         substring(O.Route, 1, 1 ) = 'A'
      THEN
         'BKK'
      ELSE
         CASE
            WHEN
               substring(O.Route, 1, 1 ) = 'M'
            THEN
               'MT'
            ELSE
               CASE
                  WHEN
                     substring(O.Route, 1, 1 ) = 'C'
                  THEN
                     'Central'
                  ELSE
                     'UPC'
               END
         END
   END
,
   CASE
      WHEN
         substring(O.Route, 1, 1 ) = 'A'
      THEN
(P.ActualDeliveryDate + 3 )
      ELSE
         CASE
            WHEN
               substring(O.Route, 1, 1 ) = 'M'
            THEN
(P.ActualDeliveryDate + 3 )
            ELSE
               CASE
                  WHEN
                     substring(O.Route, 1, 1 ) = 'C'
                  THEN
(P.ActualDeliveryDate + 4 )
                  ELSE
(P.ActualDeliveryDate + 5 )
               END
         END
   END

GO
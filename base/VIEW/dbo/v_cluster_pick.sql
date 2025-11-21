SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

CREATE   VIEW [dbo].[V_Cluster_Pick]
AS
SELECT  CASE WHEN SUBSTRING(Remarks, 2, 1) = '1' OR SUBSTRING(Remarks, 2, 1) = '2'
                THEN 'Get TotalPickQty'
             WHEN SUBSTRING(Remarks, 2, 1) = '3'
                THEN 'B4 ActQty'
             WHEN SUBSTRING(Remarks, 2, 1) = '4'
                THEN 'After ActQty'
             WHEN SUBSTRING(Remarks, 2, 1) = '5'
                THEN 'Compare'
             WHEN SUBSTRING(Remarks, 2, 2) = '6A'
                THEN 'B4 Upd PickQty'
             WHEN SUBSTRING(Remarks, 2, 2) = '6B'
                THEN 'After Upd PickQty'
             WHEN SUBSTRING(Remarks, 2, 1) = 'E'
                THEN 'Error'
        END AS [Remarks]
      , ISNULL(RTRIM(WaveKey),'')     AS [WaveKey]
      , ISNULL(RTRIM(LoadKey),'')     AS [LoadKey]
      , ISNULL(RTRIM(OrderKey),'')    AS [OrderKey]
      , ISNULL(RTRIM(PutAwayZone),'') AS [PutAwayZone]
      , ISNULL(RTRIM(PickZone),'')    AS [PickZone]
      , ISNULL(RTRIM(PickMethod),'')  AS [PickMethod]
      , ISNULL(RTRIM(StorerKey),'')   AS [StorerKey]
      , ISNULL(RTRIM(Sku),'')         AS [Sku]
      , ISNULL(RTRIM(Loc),'')         AS [Loc]
      , ISNULL(RTRIM(Lot),'')         AS [Lot]
      , ISNULL(Descr, '0')            AS [UserInputQty]
      , ActQty
      , PickLockQty
      , PickQty
      , TotalPickQty
      , ISNULL(RTRIM(AddWho),'')      AS [UserId]
      , ISNULL(RTRIM(DropId),'')      AS [DropId]
      , Mobile
      , AddDate
      , RowRef
FROM rdt.rdtPickLog WITH (NOLOCK)

GO
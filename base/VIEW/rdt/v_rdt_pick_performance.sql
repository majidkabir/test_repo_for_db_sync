SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

CREATE VIEW [RDT].[V_RDT_Pick_Performance]
AS 
SELECT L.UserID, 
      -- L.functionid, 
       CONVERT(CHAR(10), L1.EventDateTime, 103) AS StartDate,
       SUBSTRING(CONVERT(CHAR( 5), L1.EventDateTime, 108),1,5) AS StartTime,
       SUBSTRING(CONVERT(CHAR( 5), L2.EventDatetime, 108),1,5) AS EndTime,
       DATEDIFF(hh, L1.EventDateTime, L2.EventDatetime) AS Time_On_Picking_Hour,
       SUM(L.QTY / (CASE WHEN L.UOM = PK.PACKUOM1 THEN PK.CaseCNT
                         WHEN L.UOM = PK.PACKUOM2 THEN PK.InnerPack
                         WHEN L.UOM = PK.PACKUOM3 THEN PK.QTY
                         WHEN L.UOM = PK.PACKUOM4 THEN PK.Pallet
                         WHEN L.UOM = PK.PACKUOM8 THEN PK.OtherUnit1
                         WHEN L.UOM = PK.PACKUOM9 THEN PK.OtherUnit2
                         WHEN L.UOM = 2 THEN PK.Pallet
                         WHEN L.UOM = 3 THEN PK.InnerPack
                         WHEN L.UOM = 6 THEN PK.QTY
                         WHEN L.UOM = 1 THEN PK.Pallet
                         WHEN L.UOM = 4 THEN PK.OtherUnit1
                         WHEN L.UOM = 5 THEN PK.OtherUnit2
                      END)) AS Total_Picked_QTY,
        (CASE WHEN DATEDIFF(hh, L1.EventDateTime, L2.EventDatetime) < 1 THEN 0
        ELSE CONVERT(DECIMAL(10,2),(SUM(L.QTY / (CASE WHEN L.UOM = PK.PACKUOM1 THEN PK.CaseCNT
                                 WHEN L.UOM = PK.PACKUOM2 THEN PK.InnerPack
                                 WHEN L.UOM = PK.PACKUOM3 THEN PK.QTY
                                 WHEN L.UOM = PK.PACKUOM4 THEN PK.Pallet
                                 WHEN L.UOM = PK.PACKUOM8 THEN PK.OtherUnit1
                                 WHEN L.UOM = PK.PACKUOM9 THEN PK.OtherUnit2
                                 WHEN L.UOM = 2 THEN PK.Pallet
                                 WHEN L.UOM = 3 THEN PK.InnerPack
                                 WHEN L.UOM = 6 THEN PK.QTY
                                 WHEN L.UOM = 1 THEN PK.Pallet
                                 WHEN L.UOM = 4 THEN PK.OtherUnit1
                                 WHEN L.UOM = 5 THEN PK.OtherUnit2
                              END)) / DATEDIFF(hh, L1.EventDateTime, L2.EventDatetime)))
          END)  AS Average_PerHour
FROM rdt.rdtSTDEventLog L WITH (NOLOCK)
JOIN rdt.rdtSTDEventLog L1 WITH (NOLOCK) ON (L1.Rowref = L.Rowref and L1.ActionType = 1)
JOIN rdt.rdtSTDEventLog L2 WITH (NOLOCK) ON (L2.Rowref = L.Rowref and L2.ActionType = 9)
JOIN dbo.SKU SKU WITH (NOLOCK) ON (SKU.Storerkey = L.Storerkey and SKU.SKU = L.SKU)
JOIN dbo.Pack PK WITH (NOLOCK) ON (SKU.Packkey = PK.Packkey)
WHERE L.Actiontype = 3 -- WD
AND L.Eventtype = 3 -- Picking
GROUP BY L.UserID, 
         --L.functionid, 
         L1.Eventdatetime, 
         L2.EventDatetime,
         L.RowRef



GO
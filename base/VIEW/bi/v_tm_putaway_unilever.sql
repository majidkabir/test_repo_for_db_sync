SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************/
--MYS–UNILEVER–Create new datasource for Task Manager Putaway Dashboard https://jiralfl.atlassian.net/browse/BI-309
/* Updates:                                                                */
/* Date          Author      Ver.  Purposes                                */
/* 01-Nov-2021   NicoleWong  1.0   Created Ticket                          */
/* 11-Nov-2021   JarekLim    1.0   Created View                            */
/***************************************************************************/
CREATE    VIEW [BI].[V_TM_Putaway_UNILEVER]
AS
SELECT t.Storerkey
, l.Facility
, t.TaskDetailKey
, t.TaskType
, TMStatus = t.Status
, t.Sku
, s.Descr
, t.Lot
, t.UOM
, t.UOMQty
, t.Qty
, t.SystemQty
, t.PendingMoveIn
, t.QtyReplen
, t.AreaKey
, t.FromLoc
, t.ToLoc
, t.LogicalFromLoc
, t.LogicalToLoc
, t.FromID
, t.ToID
, t.CaseID
, t.DropID
, t.DeviceID
, t.PickMethod
, t.StatusMsg
, t.Priority
, t.SourcePriority
, t.Holdkey
, t.UserKey
, t.UserPosition
, t.UserKeyOverRide
, t.StartTime
, t.EndTime
, t.SourceType
, t.SourceKey
, t.LoadKey
, t.OrderKey
, t.OrderLineNumber
, t.ListKey
, t.WaveKey
, t.ReasonKey
, t.Message01
, t.Message02
, t.Message03
, t.AddDate
, t.AddWho
, t.EditDate
, t.EditWho
, t.FinalID
, t.FinalLOC
, t.Groupkey
, ASNStatus = r.Status
, ASNExternStatus = r.ASNStatus
, r.ExternReceiptKey
, r.WarehouseReference
, r.CarrierKey
, r.CarrierName
, l.LocationType
, l.PALogicalLoc
, d.Lottable01
, d.Lottable02
, d.Lottable03
, d.Lottable04
, d.Lottable05
, ToLoc2 = COUNT(d.ToLoc)
, [Start_Date] = CAST(t.StartTime AS DATE)
, [Start_Time] = CONVERT(VARCHAR, t.StartTime, 108)
, [Date] = CASE WHEN CONVERT(VARCHAR, t.StartTime, 108) BETWEEN '07:00:00' AND '19:00:00' THEN 'MORNING'
			WHEN CONVERT(VARCHAR, t.StartTime, 108) BETWEEN '19:00:00' AND '24:00:00' THEN 'NIGHT'
			WHEN CONVERT(VARCHAR, t.StartTime, 108) BETWEEN '00:00:00' AND '07:00:00' THEN 'NIGHT'END
, [DateTime] = CASE 
WHEN CONVERT(VARCHAR, t.StartTime, 108) BETWEEN '23:00:00' AND '24:00:00' THEN '23:00 TO 23:59'
WHEN CONVERT(VARCHAR, t.StartTime, 108) BETWEEN '22:00:00' AND '23:00:00' THEN '22:00 TO 22:59'
WHEN CONVERT(VARCHAR, t.StartTime, 108) BETWEEN '21:00:00' AND '22:00:00' THEN '21:00 TO 21:59'
WHEN CONVERT(VARCHAR, t.StartTime, 108) BETWEEN '20:00:00' AND '21:00:00' THEN '20:00 TO 20:59'
WHEN CONVERT(VARCHAR, t.StartTime, 108) BETWEEN '19:00:00' AND '20:00:00' THEN '19:00 TO 19:59'
WHEN CONVERT(VARCHAR, t.StartTime, 108) BETWEEN '18:00:00' AND '19:00:00' THEN '18:00 TO 18:59'
WHEN CONVERT(VARCHAR, t.StartTime, 108) BETWEEN '17:00:00' AND '18:00:00' THEN '17:00 TO 17:59'
WHEN CONVERT(VARCHAR, t.StartTime, 108) BETWEEN '16:00:00' AND '17:00:00' THEN '16:00 TO 16:59'
WHEN CONVERT(VARCHAR, t.StartTime, 108) BETWEEN '15:00:00' AND '16:00:00' THEN '15:00 TO 15:59'
WHEN CONVERT(VARCHAR, t.StartTime, 108) BETWEEN '14:00:00' AND '15:00:00' THEN '14:00 TO 14:59'
WHEN CONVERT(VARCHAR, t.StartTime, 108) BETWEEN '13:00:00' AND '14:00:00' THEN '13:00 TO 13:59'
WHEN CONVERT(VARCHAR, t.StartTime, 108) BETWEEN '12:00:00' AND '13:00:00' THEN '12:00 TO 12:59'
WHEN CONVERT(VARCHAR, t.StartTime, 108) BETWEEN '11:00:00' AND '12:00:00' THEN '11:00 TO 11:59'
WHEN CONVERT(VARCHAR, t.StartTime, 108) BETWEEN '10:00:00' AND '11:00:00' THEN '10:00 TO 10:59'
WHEN CONVERT(VARCHAR, t.StartTime, 108) BETWEEN '09:00:00' AND '10:00:00' THEN '09:00 TO 09:59'
WHEN CONVERT(VARCHAR, t.StartTime, 108) BETWEEN '08:00:00' AND '09:00:00' THEN '08:00 TO 08:59'
WHEN CONVERT(VARCHAR, t.StartTime, 108) BETWEEN '07:00:00' AND '08:00:00' THEN '07:00 TO 07:59'
WHEN CONVERT(VARCHAR, t.StartTime, 108) BETWEEN '06:00:00' AND '07:00:00' THEN '06:00 TO 06:59'
WHEN CONVERT(VARCHAR, t.StartTime, 108) BETWEEN '05:00:00' AND '06:00:00' THEN '05:00 TO 05:59'
WHEN CONVERT(VARCHAR, t.StartTime, 108) BETWEEN '04:00:00' AND '05:00:00' THEN '04:00 TO 04:59'
WHEN CONVERT(VARCHAR, t.StartTime, 108) BETWEEN '03:00:00' AND '04:00:00' THEN '03:00 TO 03:59'
WHEN CONVERT(VARCHAR, t.StartTime, 108) BETWEEN '02:00:00' AND '03:00:00' THEN '02:00 TO 02:59'
WHEN CONVERT(VARCHAR, t.StartTime, 108) BETWEEN '01:00:00' AND '02:00:00' THEN '01:00 TO 01:59'
WHEN CONVERT(VARCHAR, t.StartTime, 108) BETWEEN '00:00:00' AND '01:00:00' THEN '00:00 TO 00:59' END
FROM V_TASKDETAIL t (NOLOCK)
JOIN V_RECEIPTDETAIL d (NOLOCK) ON t.SourceKey = d.ReceiptKey AND t.FromID = d.ToID
JOIN V_RECEIPT r (NOLOCK) ON d.ReceiptKey = r.ReceiptKey
JOIN V_SKU s (NOLOCK) ON d.Sku = s.Sku AND d.Storerkey = s.StorerKey
JOIN V_LOC l (NOLOCK) ON t.ToLoc = l.Loc
WHERE t.Storerkey = 'UNILEVER'
AND t.TaskType IN ('ASTPA1', 'PA1')
AND t.StartTime >= DATEADD(MONTH, DATEDIFF(MONTH, 0, GETDATE())-1, 0)
--AND t.Status IN ('0', '9')
GROUP BY t.Storerkey
, l.Facility
, t.TaskDetailKey
, t.TaskType
, t.Sku
, s.Descr
, t.Lot
, t.UOM
, t.UOMQty
, t.Qty
, t.SystemQty
, t.PendingMoveIn
, t.QtyReplen
, t.AreaKey
, t.FromLoc
, t.ToLoc
, t.LogicalFromLoc
, t.LogicalToLoc
, t.FromID
, t.ToID
, t.CaseID
, t.DropID
, t.DeviceID
, t.PickMethod
, t.Status
, t.StatusMsg
, t.Priority
, t.SourcePriority
, t.Holdkey
, t.UserKey
, t.UserPosition
, t.UserKeyOverRide
, t.StartTime
, t.EndTime
, t.SourceType
, t.SourceKey
, t.LoadKey
, t.OrderKey
, t.OrderLineNumber
, t.ListKey
, t.WaveKey
, t.ReasonKey
, t.Message01
, t.Message02
, t.Message03
, t.AddDate
, t.AddWho
, t.EditDate
, t.EditWho
, t.FinalID
, t.FinalLOC
, t.Groupkey
, r.ExternReceiptKey
, r.WarehouseReference
, r.Status
, r.ASNStatus
, r.CarrierKey
, r.CarrierName
, l.LocationType
, l.PALogicalLoc
, d.Lottable01
, d.Lottable02
, d.Lottable03
, d.Lottable04
, d.Lottable05
--ORDER BY CAST(t.StartTime AS DATE), CONVERT(VARCHAR, t.StartTime, 108)
--, TaskDetailKey ASC

GO
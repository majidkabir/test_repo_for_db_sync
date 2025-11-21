SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: V_SKU_Balance_By_Lottables                         */
/* Creation Date: 23-Aug-2012                                           */
/* Copyright: IDS                                                       */
/* Written by: TKLIM                                                    */
/*                                                                      */
/* Purpose:  For Pfizer US reporting purposes                           */
/*                                                                      */
/* Called By: E-WMS                                                     */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/************************************************************************/
CREATE   VIEW [dbo].[V_SKU_Balance_By_Lottables] AS
SELECT SOH.Facility,
       SKU.StorerKey,
       SKU.SKU,
       master.dbo.fn_ANSI2UNICODE(SKU.DESCR, 'CHT') AS DESCR,
       (SOH.Qty - SOH.QtyAllocated - SOH.QtyPicked) AS QtyAvailable,
       ISNULL(C.Short, SKU.SUSR3)            AS Principal,
       SKU.Style,
       SOH.Lottable02, SOH.Lottable04,
       DATEDIFF(MONTH, GETDATE(), SOH.Lottable04) AS RemainExpMonth,
       p.PackUOM3,
       ISNULL(SOH.HOSTWHCODE,'') AS HostWhCode
FROM SKU WITH (NOLOCK)
JOIN PACK p WITH (NOLOCK) ON SKU.PACKKey = P.PackKey
JOIN (SELECT L.Facility,
             L.HOSTWHCODE,
             LLI.StorerKey,
             LLI.SKU,
             LA.Lottable02,
             LA.Lottable04,
             SUM(LLI.Qty) AS Qty,
             SUM(LLI.QtyAllocated) AS QtyAllocated,
             SUM(LLI.QtyPicked) AS QtyPicked
      FROM LOTxLOCxID LLI WITH (NOLOCK)
      JOIN LOTATTRIBUTE LA WITH (NOLOCK) ON LLI.LOT = LA.LOT
      JOIN LOC l WITH (NOLOCK) ON l.Loc = LLI.Loc AND L.LocationFlag NOT IN ('DAMAGE', 'HOLD') AND L.Status <> 'HOLD'
      JOIN LOT (NOLOCK) ON LOT.LOT = lli.LOT AND LOT.Status <> 'HOLD'
      JOIN ID (NOLOCK) ON ID.ID = lli.ID AND ID.[Status] <> 'HOLD'
      GROUP BY l.Facility, LLI.StorerKey, LLI.SKU, L.HOSTWHCODE, LA.Lottable02, LA.Lottable04
      ) AS SOH ON SOH.Sku = SKU.Sku AND SOH.StorerKey = SKU.StorerKey
LEFT OUTER JOIN CODELKUP c WITH (NOLOCK) ON C.LISTNAME = 'PRINCIPAL' AND c.Code = SKU.SUSR3




GO
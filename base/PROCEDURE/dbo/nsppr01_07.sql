SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: nspPR01_07                                         */
/* Creation Date: 10-Feb-2015                                           */
/* Copyright: LF Logistics                                              */
/* Written by:wtshong                                                   */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* GIT Version: 1.0                                                     */
/*                                                                      */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/* 10-Feb-2015       1.0      Initial Version						         */
/************************************************************************/   
CREATE PROC    [dbo].[nspPR01_07]    
 @c_storerkey NVARCHAR(15) ,    
 @c_sku NVARCHAR(20) ,    
 @c_lot NVARCHAR(10) ,    
 @c_lottable01 NVARCHAR(18) ,    
 @c_lottable02 NVARCHAR(18) ,    
 @c_lottable03 NVARCHAR(18) ,    
 @c_lottable04 datetime ,    
 @c_lottable05 datetime ,    
 @c_uom NVARCHAR(10) ,    
 @c_facility NVARCHAR(10)  ,  -- added By Ricky for IDSV5    
 @n_uombase int ,    
 @n_qtylefttofulfill int    
 AS    
 BEGIN    
     
 IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_lot)) IS NOT NULL    
 BEGIN    
 DECLARE  PREALLOCATE_CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR     
 SELECT LOT.STORERKEY,LOT.SKU,LOT.LOT ,    
 QTYAVAILABLE = (LOT.QTY - LOT.QTYALLOCATED - LOT.QTYPICKED - LOT.QTYPREALLOCATED)    
 FROM LOT (nolock) , LOTATTRIBUTE (Nolock), LOTXLOCXID (NOLOCK), LOC (NOLOCK)     
 WHERE LOT.Lot = Lotattribute.Lot     
 AND LOTXLOCXID.Lot = LOT.LOT    
 AND LOTXLOCXID.LOT = LOTATTRIBUTE.LOT    
 AND LOTXLOCXID.LOC = LOC.LOC    
 AND LOC.Facility = @c_facility    
 AND LOT.LOT = @c_lot    
 ORDER BY Lotattribute.Lottable04, Lotattribute.Lottable02       
 END    
 ELSE    
 BEGIN    
 DECLARE  PREALLOCATE_CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR   
 SELECT LOT.STORERKEY /*SOS307439 - Logic fixed*/  
      ,LOT.SKU  
      ,LOT.LOT  
      ,QTYAVAILABLE = LOT.QTY - LOT.QTYALLOCATED - LOT.QTYPICKED - LOT.QTYPREALLOCATED - LOT.QtyOnHold  
FROM  LOT WITH (NOLOCK)  
JOIN  LotAttribute WITH (NOLOCK) ON LOT.Lot = Lotattribute.Lot  
WHERE LOT.STORERKEY = @c_storerkey  
AND   LOT.SKU = @c_sku  
AND   LOT.STATUS = "OK"   
AND   (LOT.QTY - LOT.QTYALLOCATED - LOT.QTYPICKED - LOT.QTYPREALLOCATED - LOT.QtyOnHold) > 0  
AND EXISTS(SELECT 1   
           FROM LOTxLOCxID WITH (NOLOCK)   
           JOIN LOC WITH (NOLOCK) ON LOC.Loc = LOTxLOCxID.Loc   
           JOIN ID WITH (NOLOCK) ON ID.Id = LOTxLOCxID.Id   
           WHERE LOTxLOCxID.Lot = LOT.LOT   
           AND   LOTxLOCxID.STORERKEY = @c_storerkey   
           AND   LOTxLOCxID.SKU = @c_sku  
           AND   LOC.STATUS = "OK"  
           AND   ID.Status <> "HOLD"   
           AND   LOC.LocationFlag NOT IN ("HOLD", "DAMAGE")  
           AND   LOC.Facility = @c_facility)   
ORDER BY  
       LotAttribute.Lottable04  
      ,LotAttribute.Lottable02    
 END    
 END    


GO
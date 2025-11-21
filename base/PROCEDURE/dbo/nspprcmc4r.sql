SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Stored Procedure: nspPRCMC4R                                         */  
/* Creation Date: 29-Aug-2007                                           */  
/* Copyright: IDS                                                       */  
/* Written by:                                                          */  
/*                                                                      */  
/* Purpose: ULP Allocation which use Acceptance Age Per customer        */  
/*       Per SKU in validating stocks. It will allocate from            */  
/*     DOUBLEDEEP or SELECTIVE location.                                */  
/*                                                                      */  
/* Called By:                                                           */  
/*                                                                      */  
/* PVCS Version: 1.3                                                    */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author        Purposes                                  */  
/* 29-Aug-2007  James         SOS85149  - modified FROM nspPRCMC03      */  
/*                            Check Consignee+SKU Acceptance Age        */ 
/* 28-Oct-2008   Vanessa      SOS#117139 Add checking Loc.Putawayzone<>'GOLD' */
/************************************************************************/  
  
CREATE PROC [dbo].[nspPRCMC4R]  
 @c_Storerkey  NVARCHAR(15) ,  
 @c_SKU        NVARCHAR(20) ,  
 @c_lot        NVARCHAR(10) ,  
 @c_Lottable01 NVARCHAR(18) ,  
 @c_Lottable02 NVARCHAR(18) ,  
 @c_Lottable03 NVARCHAR(18) ,  
 @c_Lottable04 datetime ,  
 @c_Lottable05 datetime ,  
 @c_UOM        NVARCHAR(10) ,  
 @c_Facility   NVARCHAR(10)  ,  -- added By Ricky for IDSV5  
 @n_UOMbase    int ,  
 @n_QtyleftToFulfill int,  
 @c_OtherParms       NVARCHAR(200) = NULL   
  AS  
BEGIN -- main  
   SET NOCOUNT ON
 /* Get SKU Shelf Life */  
   
 DECLARE @n_AcceptAge int   
   DECLARE @c_Consigneekey     NVARCHAR(18)   
  
   DECLARE @c_OrderKey        NVARCHAR(10),  
           @c_OrderLineNumber NVARCHAR(5)  
  
 SET @n_AcceptAge = 0  
     
   IF dbo.fnc_RTrim(@c_OtherParms) IS NOT NULL AND dbo.fnc_RTrim(@c_OtherParms) <> ''  
   BEGIN  
      SELECT @c_OrderKey = LEFT(dbo.fnc_LTrim(@c_OtherParms), 10)  
      SELECT @c_OrderLineNumber = SUBSTRING(dbo.fnc_LTrim(@c_OtherParms), 11, 5)  
   END  
  
    IF dbo.fnc_RTrim(@c_OrderKey) IS NOT NULL AND dbo.fnc_RTrim(@c_OrderKey) <> ''  
    BEGIN  
       SELECT @c_Consigneekey = ORDERS.ConsigneeKey  
       FROM  ORDERS WITH (NOLOCK)   
       WHERE ORDERS.OrderKey = @c_OrderKey  
    
   IF LEN(@c_Consigneekey) > 10   
   BEGIN  
   SET @c_Consigneekey = RIGHT(dbo.fnc_RTrim(dbo.fnc_LTrim(@c_Consigneekey)), 10)  
   END  
  
       SELECT @n_AcceptAge = CASE WHEN ISNUMERIC(CODELKUP.Short) = 1 THEN CAST(ISNULL(CODELKUP.Short, '0') as Int)   
                                ELSE 0   
                             END   
       FROM  CODELKUP WITH (NOLOCK)   
   WHERE CODELKUP.ListName = @c_Consigneekey  
   AND   CODELKUP.Code = @c_SKU  
   END        
    
   IF @n_AcceptAge = 0   
   BEGIN        
    SELECT @n_AcceptAge = BUSR6   
    FROM  SKU WITH (NOLOCK)  
    WHERE Storerkey = @c_Storerkey   
    AND   SKU = @c_SKU  
      
    IF dbo.fnc_LTrim(dbo.fnc_RTrim(@n_AcceptAge)) IS NULL OR  dbo.fnc_LTrim(dbo.fnc_RTrim(@n_AcceptAge)) = ''  
    BEGIN  
     SELECT @n_AcceptAge = 0  
      END  
   END  
     
   
 IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_LOT)) IS NOT NULL AND dbo.fnc_LTrim(dbo.fnc_RTrim(@c_LOT)) <> ''  
 BEGIN  
  DECLARE PREALLOCATE_CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR  
   select LOT.Storerkey, LOT.sku, LOT.lot,   
    Qtyavailable = SUM(LOTxLOCxID.Qty - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyPicked) - MIN(ISNULL(p.QtyPreallocated, 0))  
   FROM LOTxLOCxID WITH (NOLOCK)   
   JOIN LOT WITH (NOLOCK) on LOTxLOCxID.lot = LOT.lot  
   JOIN LotAttribute WITH (NOLOCK) on LOTxLOCxID.lot = LotAttribute.lot  
   JOIN LOC WITH (NOLOCK) on LOTxLOCxID.loc = LOC.loc  
   JOIN ID WITH (NOLOCK) on LOTXLOCXID.ID  = ID.ID  -- SOS131215 
   LEFT OUTER JOIN (SELECT p.lot, ORDERS.Facility, QtyPreallocated = SUM(p.Qty)   
          FROM   PreallocatePickdetail p WITH (NOLOCK), ORDERS WITH(NOLOCK)   
          WHERE  p.Orderkey = ORDERS.Orderkey   
          AND    p.Storerkey = dbo.fnc_RTrim(@c_Storerkey)  
          AND    p.SKU = dbo.fnc_RTrim(@c_SKU)  
          AND    p.Qty > 0  
          GROUP BY p.Lot, ORDERS.Facility) P ON LOTxLOCxID.Lot = p.Lot AND p.Facility = LOC.Facility   
   WHERE LOTxLOCxID.LOT = @c_lot  
    AND LOTxLOCxID.Qty > 0  
    AND LOT.STATUS = 'OK' AND LOC.STATUS = 'OK' AND ID.STATUS = 'OK' And LOC.LocationFlag <> 'HOLD' --SOS131215 START  
    AND LOC.LocationFlag <> 'DAMAGE'  
    --AND LOC.Locationflag = 'NONE'   SOS131215 END   
    AND (LOC.LocationType = 'SELECTIVE' OR LOC.LocationType = 'DOUBLEDEEP')  
    AND LOC.Facility = @c_Facility  -- Added By Ricky for IDSV5  
    AND LOC.Putawayzone <> 'GOLDC'   -- (SOS#117139)
    AND DATEDIFF(DAY, GETDATE(), Lottable04) >= @n_AcceptAge    
   GROUP BY LOT.Storerkey, LOT.SKU, LOT.LOT, Lottable04, Lottable02   
   HAVING SUM(LOTxLOCxID.Qty - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyPicked) - MIN(ISNULL(P.QtyPreallocated, 0)) > 0  
   ORDER BY Lottable04, Lottable02  
 end  
 ELSE -- if dbo.fnc_LTrim(dbo.fnc_RTrim(@c_lot)) is not null  
 BEGIN  
  DECLARE PREALLOCATE_CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR   
  select LOT.Storerkey, LOT.sku, LOT.lot,   
    Qtyavailable = SUM(LOTxLOCxID.Qty - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyPicked) - MIN(ISNULL(p.QtyPreallocated, 0))  
   FROM LOTxLOCxID WITH (NOLOCK)   
   JOIN LOT WITH (NOLOCK) on LOTxLOCxID.lot = LOT.lot  
   JOIN LotAttribute WITH (NOLOCK) on LOTxLOCxID.lot = LotAttribute.lot  
   JOIN LOC WITH (NOLOCK) on LOTxLOCxID.loc = LOC.loc  
   JOIN ID WITH (NOLOCK) on LOTXLOCXID.ID  = ID.ID  -- SOS131215 
   LEFT OUTER JOIN (SELECT p.lot, ORDERS.Facility, QtyPreallocated = SUM(p.Qty)   
          FROM   PreallocatePickdetail p WITH (NOLOCK), ORDERS WITH (NOLOCK)   
          WHERE  p.Orderkey = ORDERS.Orderkey   
          AND    p.Storerkey = dbo.fnc_RTrim(@c_Storerkey)  
          AND    p.SKU = dbo.fnc_RTrim(@c_SKU)  
          AND    p.Qty > 0  
          GROUP BY p.Lot, ORDERS.Facility) P ON LOTxLOCxID.Lot = p.Lot AND p.Facility = LOC.Facility   
   WHERE LOTxLOCxID.Storerkey = @c_Storerkey  
    AND LOTxLOCxID.sku = @c_SKU  
    AND LOTxLOCxID.Qty > 0  
    AND LOT.STATUS = 'OK' AND LOC.STATUS = 'OK' AND ID.STATUS = 'OK' And LOC.LocationFlag <> 'HOLD' --SOS131215 START  
    AND LOC.LocationFlag <> 'DAMAGE'  
    --AND LOC.Locationflag = 'NONE'   SOS131215 END  
    AND (LOC.LocationType = 'SELECTIVE' OR LOC.LocationType = 'DOUBLEDEEP')  
    AND LOC.Facility = @c_Facility  -- Added By Ricky for IDSV5 
    AND LOC.Putawayzone <> 'GOLDC'   -- (SOS#117139) 
    AND DATEDIFF(DAY, GETDATE(), Lottable04) >= @n_AcceptAge  
   GROUP BY LOT.Storerkey, LOT.sku, LOT.lot, Lottable04, Lottable02  
   HAVING SUM(LOTxLOCxID.Qty - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyPicked) - MIN(ISNULL(P.QtyPreallocated, 0)) > 0  
   ORDER BY Lottable04, Lottable02  
 END  
  END -- main  


GO
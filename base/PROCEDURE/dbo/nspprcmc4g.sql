SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/    
/* Stored Procedure: nspPRCMC4G                                         */    
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
/* 28-Oct-2008   Vanessa      SOS#117139 Add checking                   */  
/*                            Loc.Putawayzone<>'GOLD'                   */  
/************************************************************************/    
    
CREATE PROC [dbo].[nspPRCMC4G]    
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
  
   Declare @b_debug int  
  
   SELECT @b_debug= 0  
  
 /* Get SKU Shelf Life */    
     
   DECLARE @n_AcceptAge int     
   DECLARE @c_Consigneekey     NVARCHAR(18)     
  
   DECLARE @c_OrderKey        NVARCHAR(10),    
           @c_OrderLineNumber NVARCHAR(5),    
            -- SHONG01    
            @c_OrderType     NVARCHAR(10),   
            @c_FilterZone    NVARCHAR(200),   
            @c_DeclareCursor NVARCHAR(MAX)  
  
   SET @n_AcceptAge = 0    
  
   IF ISNULL(RTrim(@c_OtherParms),'') <> ''    
   BEGIN    
      SELECT @c_OrderKey = LEFT(LTrim(@c_OtherParms), 10)    
      SELECT @c_OrderLineNumber = SUBSTRING(LTrim(@c_OtherParms), 11, 5)    
   END    
  
   IF ISNULL(RTrim(@c_OrderKey),'') <> ''    
   BEGIN    
      SELECT @c_Consigneekey = ORDERS.ConsigneeKey,   
             @c_OrderType = ORDERS.Type   
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
  
       -- SHONG01  
       SET @c_FilterZone = ''  
  
       IF EXISTS(SELECT 1 FROM CODELKUP WITH (NOLOCK) WHERE ListName = 'U2K2ORDTYP' AND Code = @c_OrderType)  
       BEGIN  
          SET @c_Lottable02 = @c_OrderType  
          SET @c_FilterZone = " AND LOC.PUTAWAYZONE = N'" + RTRIM(@c_OrderType) + "' AND LOTATTRIBUTE.LOTTABLE02 = N'" + @c_OrderType + "' " 
       END  
       ELSE   
       BEGIN  
          IF ISNULL(RTRIM(@c_lottable02),'') = ''  
          BEGIN   
             SET @c_FilterZone = " AND LOTATTRIBUTE.LOTTABLE02 NOT IN (SELECT CODE FROM CODELKUP WITH (NOLOCK) WHERE ListName = 'U2K2ORDTYP') "  
          END   
       END  
       -- SHONG01  
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
       
   IF ISNULL(RTrim(@c_LOT),'') <> ''    
   BEGIN    
     DECLARE PREALLOCATE_CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR    
      SELECT LOT.Storerkey, LOT.sku, LOT.lot,     
             Qtyavailable = SUM(LOTxLOCxID.Qty - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyPicked) - MIN(ISNULL(p.QtyPreallocated, 0))    
      FROM LOTxLOCxID WITH (NOLOCK)     
      JOIN LOT WITH (NOLOCK) on LOTxLOCxID.lot = LOT.lot    
      JOIN LotAttribute WITH (NOLOCK) on LOTxLOCxID.lot = LotAttribute.lot    
      JOIN LOC WITH (NOLOCK) on LOTxLOCxID.loc = LOC.loc    
      JOIN ID WITH (NOLOCK) on LOTXLOCXID.ID  = ID.ID  -- SOS131215    
      LEFT OUTER JOIN (SELECT p.lot, ORDERS.Facility, QtyPreallocated = SUM(p.Qty)     
             FROM   PreallocatePickdetail p WITH (NOLOCK), ORDERS WITH(NOLOCK)     
             WHERE  p.Orderkey = ORDERS.Orderkey     
             AND    p.Storerkey = RTrim(@c_Storerkey)    
             AND    p.SKU = RTrim(@c_SKU)    
             AND    p.Qty > 0    
             GROUP BY p.Lot, ORDERS.Facility) P ON LOTxLOCxID.Lot = p.Lot AND p.Facility = LOC.Facility     
      WHERE LOTxLOCxID.LOT = @c_lot    
       AND LOTxLOCxID.Qty > 0    
       AND LOT.STATUS = 'OK' AND LOC.STATUS = 'OK' AND ID.STATUS = 'OK' And LOC.LocationFlag <> 'HOLD' --SOS131215 START    
       AND LOC.LocationFlag <> 'DAMAGE'    
       --AND LOC.Locationflag = 'NONE'   SOS131215 END   
       AND (LOC.LocationType = 'SELECTIVE' OR LOC.LocationType = 'DOUBLEDEEP')    
       AND LOC.Facility = @c_Facility  -- Added By Ricky for IDSV5    
       AND DATEDIFF(DAY, GETDATE(), Lottable04) >= @n_AcceptAge      
      GROUP BY LOT.Storerkey, LOT.SKU, LOT.LOT, Lottable04, Lottable02     
      HAVING SUM(LOTxLOCxID.Qty - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyPicked) - MIN(ISNULL(P.QtyPreallocated, 0)) > 0    
      ORDER BY Lottable04, Lottable02    
   END    
   ELSE -- if dbo.fnc_LTrim(dbo.fnc_RTrim(@c_lot)) is not null    
   BEGIN    
      IF @b_debug = 1    
      BEGIN   
        SELECT '@c_lottable03 = GOLDC'   
      END  
  
      SET @c_DeclareCursor =   
        " DECLARE PREALLOCATE_CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR   " +   
        " SELECT LOT.Storerkey, LOT.SKU, LOT.LOT,   " +   
        "        Qtyavailable = SUM(LOTxLOCxID.Qty - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyPicked) - MIN(ISNULL(p.QtyPreallocated, 0))  " +   
        "  FROM LOTxLOCxID WITH (NOLOCK)   " +   
        "  JOIN LOT WITH (NOLOCK) on LOTxLOCxID.LOT = LOT.LOT  " +   
        "  JOIN LotAttribute WITH (NOLOCK) on LOTxLOCxID.LOT = LotAttribute.LOT  " +   
        "  JOIN LOC WITH (NOLOCK) on LOTxLOCxID.loc = LOC.loc  " +   
        "  JOIN SKU WITH (NOLOCK) ON (LOTxLOCxID.SKU = SKU.SKU)" +   
        "  JOIN ID WITH (NOLOCK) on LOTXLOCXID.ID  = ID.ID " +   
        "  LEFT OUTER JOIN (SELECT p.LOT, ORDERS.Facility, QtyPreallocated = SUM(p.Qty)   " +   
        "         FROM   PreallocatePickdetail p WITH (NOLOCK), ORDERS WITH (NOLOCK)   " +   
        "         WHERE  p.Orderkey = ORDERS.Orderkey   " +   
        "         AND    p.Storerkey = N'" + RTRIM(@c_Storerkey) + "' " +   
        "         AND    p.SKU = N'" + RTRIM(@c_SKU) + "' " +   
        "         AND    p.Qty > 0  " +   
        "         GROUP BY p.LOT, ORDERS.Facility) P ON LOTxLOCxID.LOT = p.LOT AND p.Facility = LOC.Facility   " +   
        "  WHERE LOTxLOCxID.Storerkey = N'" + RTRIM(@c_Storerkey) + "' " +   
        "   AND LOTxLOCxID.sku = N'" + RTRIM(@c_SKU) + "'   " +   
        "   AND LOTxLOCxID.Qty > 0  " +   
        "   AND LOT.STATUS = 'OK' AND LOC.STATUS = 'OK' AND ID.STATUS = 'OK' And LOC.LocationFlag <> 'HOLD' " +   
        "   AND LOC.LocationFlag <> 'DAMAGE'  " +   
        "   AND (LOC.LocationType = 'SELECTIVE' OR LOC.LocationType = 'DOUBLEDEEP')  " +   
        "   AND LOC.Facility = N'" + RTRIM(@c_Facility) + "' " +   
        CASE WHEN ISNULL(RTRIM(@c_lottable03),'') <> 'GOLDC' THEN " AND LOC.Putawayzone <> 'GOLDC' " ELSE "" END +   
        @c_FilterZone +   
        "   AND DATEDIFF(DAY, GETDATE(), Lottable04) >= " + CAST(@n_AcceptAge as NVARCHAR(6)) +    
        "  GROUP BY SKU.BUSR7, LOC.Putawayzone, LOT.Storerkey, LOT.SKU, LOT.LOT, Lottable04, Lottable02  " +   
        "  HAVING SUM(LOTxLOCxID.Qty - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyPicked) - MIN(ISNULL(P.QtyPreallocated, 0)) > 0  " +   
        "  ORDER BY CASE SKU.BUSR7 WHEN 'GOLDC' THEN 0 WHEN NULL THEN 1 WHEN ' ' THEN 2 ELSE 3 END ASC, " +   
        "           CASE LOC.Putawayzone WHEN 'GOLDC' THEN 0 WHEN NULL THEN 1 WHEN ' ' THEN 2 ELSE 3 END ASC, " +   
        "           Lottable04, Lottable02 "  
  
       EXEC(@c_DeclareCursor)  
  
    END    
END -- main 

GO
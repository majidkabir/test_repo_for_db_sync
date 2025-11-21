SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Stored Procedure: nspPRCDC4G                                         */  
/* Creation Date: 19-11-2008                                            */  
/* Copyright: IDS                                                       */  
/* Written by: Vanessa                                                  */  
/*                                                                      */  
/* Purpose: New Allocation Strategy for GOLD SOS117139                  */  
/*                                                                      */  
/* Called By: Exceed Allocate Orders                                    */  
/*                                                                      */  
/* PVCS Version: 1.3                                                    */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author    Ver Purposes                                  */  
/* 04-Mar-2010  Vanessa   1.1 SOS163817 Add Outgoing Shelf Life         */
/*                            (SKU.SUSR2) (Vanessa01)                   */ 
/* 13-Jul-2010  SHONG01   1.2 SOS220901 Allocation Strategy requirement */
/*                            for Unilever U2K2 Cut-Over                */
/************************************************************************/  
CREATE PROC [dbo].[nspPRCDC4G]  
   @c_storerkey NVARCHAR(15) ,  
   @c_sku NVARCHAR(20) ,  
   @c_lot NVARCHAR(10) ,  
   @c_lottable01 NVARCHAR(18) ,  
   @c_lottable02 NVARCHAR(18) ,  
   @c_lottable03 NVARCHAR(18) ,  
   @d_lottable04 datetime,  
   @d_lottable05 datetime,  
   @c_uom NVARCHAR(10),  
   @c_facility NVARCHAR(10)  ,  
   @n_uombase int ,  
   @n_qtylefttofulfill int,  
   @c_OtherParms NVARCHAR(200)  
 AS  
 BEGIN -- MAIN  
    SET NOCOUNT ON  
  
    Declare @b_debug int,  
            @c_ord_lottable03 NVARCHAR(18)  
   
    SELECT @b_debug= 0  
    SELECT @c_ord_lottable03 = @c_lottable03  
     
    IF ISNULL(RTrim(@c_lot),'') <> ''
    BEGIN         
       DECLARE PREALLOCATE_CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR     
       SELECT LOT.STORERKEY,LOT.SKU,LOT.LOT ,    
              QTYAVAILABLE = (LOT.QTY - LOT.QTYALLOCATED - LOT.QTYPICKED - LOT.QTYPREALLOCATED)    
       FROM LOT (NOLOCK)  
    WHERE LOT.LOT = @c_lot    
   
       GOTO ExitProc  
    END  
   
   
    DECLARE @c_LimitString NVARCHAR(255) -- To limit the where clause based on the user input    
    DECLARE @c_Limitstring1 NVARCHAR(255)    
   
   /* Get SKU Shelf Life */  
    -- wally 23.oct.2002  
  -- consider sku's curing period (sku.busr2)  
   DECLARE @n_shelflife int,  
           @n_curingperiod int,  
           @n_outgoingshelflife int,  -- (Vanessa01)  
           @n_totalshelflife int      -- (Vanessa01)  
   
   SELECT @n_shelflife = Sku.Shelflife,   
          @n_curingperiod = isnull(cast(sku.busr2 as int), 0),  
          @n_outgoingshelflife = isnull(cast(SKU.SUSR2 as int), 0) -- (Vanessa01)  
   FROM  Sku (nolock)  
   WHERE SKU.StorerKey = @c_StorerKey  
    AND   SKU.sku = @c_sku  
   
   IF @n_shelflife IS NULL SELECT @n_shelflife = 0  
   
    -- Get OrderKey and line Number  
    DECLARE @c_OrderKey   NVARCHAR(10),  
            @c_OrderLineNumber NVARCHAR(5)  
   
    IF RTrim(@c_OtherParms) IS NOT NULL AND RTrim(@c_OtherParms) <> ''  
    BEGIN  
       SELECT @c_OrderKey = LEFT(LTrim(@c_OtherParms), 10)  
       SELECT @c_OrderLineNumber = SUBSTRING(LTrim(@c_OtherParms), 11, 5)  
   
       -- print '@c_OrderKey=' + @c_OrderKey + ' Line:' + @c_OrderLineNumber  
    END  
   
    SELECT @c_LimitString = ''    
   
  -- wally 23.oct.2002  
  -- consider sku's curing period, if setup in sku.busr2  
  if @n_curingperiod > 0    
  begin  
   SELECT @c_Limitstring = ISNULL(RTrim(@c_LimitString),'') + " AND DATEADD(day, " +  
      RTrim(CAST(@n_curingperiod as NVARCHAR(10))) + ", Lottable04) < getdate()"  
  end  
   
    -- Get BillToKey  
    DECLARE @c_BillToKey NVARCHAR(15),  
            @c_CustSubCode NVARCHAR(20),  
            @n_ConsigneeMinShelfLife int,  
            @n_ShelfLifePerc int,  
            @n_RemainingShelfLife int,
            -- SHONG01  
            @c_OrderType  NVARCHAR(10), 
            @c_FilterZone NVARCHAR(200)  
   
    IF RTrim(@c_OrderKey) IS NOT NULL AND RTrim(@c_OrderKey) <> ''  
    BEGIN  
       SELECT @c_CustSubCode = ISNULL(STORER.Secondary, ''),  
              @n_ConsigneeMinShelfLife = ISNULL(SUSR3,0),  
              @n_ShelfLifePerc = CAST( ISNULL(MinShelfLife,0) as int)  
       FROM   ORDERS (NOLOCK)  
       JOIN STORER (NOLOCK) ON (ORDERS.BillToKey = STORER.StorerKey AND Storer.Type In ('2','4'))  
       WHERE ORDERS.OrderKey = @c_OrderKey  

       -- SHONG01
       SELECT @c_OrderType = ORDERS.Type   
       FROM   ORDERS (NOLOCK)
       WHERE ORDERS.OrderKey = @c_OrderKey

       SET @c_FilterZone = ''

       IF EXISTS(SELECT 1 FROM CODELKUP WITH (NOLOCK) WHERE ListName = 'U2K2ORDTYP' AND Code = @c_OrderType)
       BEGIN
          SET @c_lottable02 = @c_OrderType
          SET @c_FilterZone = " AND LOC.PUTAWAYZONE = N'" + @c_OrderType + "'"
       END
       ELSE 
       BEGIN
          IF ISNULL(RTRIM(@c_Lottable02),'') = ''
          BEGIN 
             SET @c_FilterZone = " AND LOTATTRIBUTE.LOTTABLE02 NOT IN (SELECT CODE FROM CODELKUP WITH (NOLOCK) WHERE ListName = 'U2K2ORDTYP') "
          END 
       END
       -- SHONG01
   
       IF RTrim(@c_CustSubCode) IS NOT NULL AND RTrim(@c_CustSubCode) <> ''  
          SELECT @c_Lottable03 = @c_CustSubCode  
   
       IF @n_ConsigneeMinShelfLife > 0   
       BEGIN  
          SELECT @c_Limitstring = ISNULL(RTrim(@c_LimitString),'') + " AND DATEDIFF(day, Lottable04, GETDATE()) <= " + CAST(@n_ConsigneeMinShelfLife as NVARCHAR(10))  
       END  
       ELSE  
       BEGIN  
          IF @n_shelflife > 0   
          BEGIN  
            SELECT @n_totalshelflife = @n_shelflife - @n_outgoingshelflife  -- (Vanessa01)  
  
            -- wally 24.oct.2002  
            -- expiry should be shelflife + prod date (lottable04)  
            SELECT @c_Limitstring = ISNULL(RTrim(@c_LimitString),'') +   
                   " AND DATEDIFF(day, GETDATE(), dateadd(day, " + RTrim(cast(@n_totalshelflife as NVARCHAR(10))) +  -- (Vanessa01)  
                   ", lottable04)) > 0 "  
   
             IF @n_ShelfLifePerc > 0   
             BEGIN  
                SELECT @n_RemainingShelfLife = (@n_shelflife * @n_ShelfLifePerc) / 100  
                SELECT @c_Limitstring = ISNULL(RTrim(@c_LimitString),'') + " AND DATEDIFF(day, GETDATE(), " +  
                       " dateadd(day, " + RTrim(cast(@n_shelflife as NVARCHAR(10))) + ", lottable04)) >= " +   
                       CAST(@n_RemainingShelfLife as NVARCHAR(10))  
             END  
          END  
       END  
    END  
   
    -- print @c_Limitstring  
      
    IF @c_lottable01 <> ' '    
       SELECT @c_LimitString =  ISNULL(RTrim(@c_LimitString),'') + " AND Lottable01= N'" + LTrim(RTrim(@c_lottable01)) + "'"    
      
    IF @c_lottable02 <> ' '    
       SELECT @c_LimitString =  ISNULL(RTrim(@c_LimitString),'') + " AND lottable02= N'" + LTrim(RTrim(@c_lottable02)) + "'"   
   
    IF @c_lottable03 <> ' '    
       SELECT @c_LimitString =  ISNULL(RTrim(@c_LimitString),'') + " AND lottable03= N'" + LTrim(RTrim(@c_lottable03)) + "'"    
   
    IF @d_lottable04 IS NOT NULL AND @d_lottable04 <> '1900-01-01'  
       SELECT @c_LimitString =  ISNULL(RTrim(@c_LimitString),'') + " AND lottable04 = N'" + LTrim(RTrim(CONVERT(char(20), @d_lottable04))) + "'"    
      
    IF @d_lottable05 IS NOT NULL  AND @d_lottable05 <> '1900-01-01'  
       SELECT @c_LimitString =  ISNULL(RTrim(@c_LimitString),'') + " AND lottable05= N'" + LTrim(RTrim(CONVERT(char(20), @d_lottable05))) + "'"    

    -- SHONG01
    IF ISNULL(RTRIM(@c_FilterZone), '') <> ''
    BEGIN
       SET @c_LimitString = ISNULL(RTrim(@c_LimitString),'') + @c_FilterZone
    END 
   
  SELECT @c_StorerKey = RTrim(@c_StorerKey)    
  SELECT @c_Sku = RTrim(@c_SKU)    
  
  IF ISNULL(RTRIM(@c_ord_lottable03),'') = 'GOLD'  
  BEGIN  
     IF @b_debug = 1    
     BEGIN   
        SELECT '@c_ord_lottable03 = GOLD'   
     END  
      
     EXEC ("DECLARE PREALLOCATE_CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR " +    
             "SELECT MIN(LOTxLOCxID.STORERKEY) , MIN(LOTxLOCxID.SKU), LOT.LOT," +    
             "QTYAVAILABLE = (SUM(LOTxLOCxID.QTY) - SUM(LOTxLOCxID.QTYALLOCATED) - SUM(LOTxLOCxID.QTYPICKED) - MIN (LOT.QtyPreAllocated) ) " +    
             " FROM LOT (NOLOCK) , LOTATTRIBUTE (NOLOCK), LOTxLOCxID (NOLOCK), LOC (NOLOCK), ID (NOLOCK), " +    
             " SKU (NOLOCK), PACK (NOLOCK)  " +   
             " WHERE LOTxLOCxID.STORERKEY = N'" + @c_storerkey + "'" + " AND LOTxLOCxID.SKU = N'" + @c_sku + "' " +    
             " AND LOT.STATUS = 'OK' AND LOC.STATUS = 'OK' AND ID.STATUS = 'OK'  And LOC.LocationFlag = 'NONE' " +    
             " AND lot.lot = lotattribute.lot AND LOTxLOCxID.LOT = LOT.LOT AND LOTxLOCxID.ID = ID.ID AND LOTxLOCxID.LOT = LOTATTRIBUTE.LOT AND LOTxLOCxID.LOC = LOC.LOC " +  
             " AND LOC.FACILITY = N'" + @c_facility + "'"  +  
             " AND (LOC.LocationType = 'PICK' OR LOC.LocationType = 'CASE') " +  
             " AND LOTxLOCxID.StorerKey = SKU.StorerKey " +  
             " AND LOTxLOCxID.SKU = SKU.SKU " +  
             " AND SKU.PackKey = PACK.PackKey "   
             + @c_LimitString + " " +     
             " GROUP BY SKU.BUSR7, LOC.Putawayzone, LOT.LOT , LOTATTRIBUTE.Lottable04, LOTATTRIBUTE.Lottable02, LOTATTRIBUTE.Lottable05 " +   
             " HAVING (SUM(LOTxLOCxID.QTY) - SUM(LOTxLOCxID.QtyAllocated) - SUM(LOTxLOCxID.QTYPicked)  - MIN (LOT.QtyPreAllocated) ) > 0 " +  
             " ORDER BY CASE SKU.BUSR7 WHEN 'GOLD' THEN 0 WHEN NULL THEN 1 WHEN ' ' THEN 2 ELSE 3 END ASC, CASE LOC.Putawayzone WHEN 'GOLD' " + 
             " THEN 0 WHEN NULL THEN 1 WHEN ' ' THEN 2 ELSE 3 END ASC, LOTATTRIBUTE.LOTTABLE04, LOTATTRIBUTE.LOTTABLE02, LOTATTRIBUTE.Lottable05 ")    
  
        IF @b_debug = 1    
        BEGIN   
            SELECT '@c_Limitstring' = @c_Limitstring  
        END  
  END  
  ELSE  
  BEGIN  
  
     IF @b_debug = 1    
     BEGIN   
        SELECT '@c_ord_lottable03 <> GOLD'   
     END  
  
     EXEC ("DECLARE PREALLOCATE_CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR " +    
             " SELECT MIN(LOTxLOCxID.STORERKEY) , MIN(LOTxLOCxID.SKU), LOT.LOT," +    
             " QTYAVAILABLE = (SUM(LOTxLOCxID.QTY) - SUM(LOTxLOCxID.QTYALLOCATED) - SUM(LOTxLOCxID.QTYPICKED) - MIN (LOT.QtyPreAllocated) ) " +    
             " FROM LOT (NOLOCK) , LOTATTRIBUTE (NOLOCK), LOTxLOCxID (NOLOCK), LOC (NOLOCK), ID (NOLOCK), " +    
             " SKU (NOLOCK), PACK (NOLOCK)  " +   
             " WHERE LOTxLOCxID.STORERKEY = N'" + @c_storerkey + "'" + " AND LOTxLOCxID.SKU = N'" + @c_sku + "' " +    
             " AND LOT.STATUS = 'OK' AND LOC.STATUS = 'OK' AND ID.STATUS = 'OK'  And LOC.LocationFlag = 'NONE' " +    
             " AND lot.lot = lotattribute.lot AND LOTxLOCxID.LOT = LOT.LOT AND LOTxLOCxID.ID = ID.ID AND LOTxLOCxID.LOT = LOTATTRIBUTE.LOT AND LOTxLOCxID.LOC = LOC.LOC " +  
             " AND LOC.FACILITY = N'" + @c_facility + "'"  +  
             " AND LOC.Putawayzone <> 'GOLD' " +   
             " AND (LOC.LocationType = 'PICK' OR LOC.LocationType = 'CASE') " +  
             " AND LOTxLOCxID.StorerKey = SKU.StorerKey " +  
             " AND LOTxLOCxID.SKU = SKU.SKU " +  
             " AND SKU.PackKey = PACK.PackKey "   
             + @c_LimitString + " " +     
             " GROUP BY SKU.BUSR7, LOC.Putawayzone, LOT.LOT , LOTATTRIBUTE.Lottable04, LOTATTRIBUTE.Lottable02, LOTATTRIBUTE.Lottable05 " +   
             " HAVING (SUM(LOTxLOCxID.QTY) - SUM(LOTxLOCxID.QtyAllocated) - SUM(LOTxLOCxID.QTYPicked)  - MIN (LOT.QtyPreAllocated) ) > 0 " +  
             " ORDER BY CASE SKU.BUSR7 WHEN 'GOLD' THEN 0 WHEN NULL THEN 1 WHEN ' ' THEN 2 ELSE 3 END ASC, CASE LOC.Putawayzone WHEN 'GOLD' " +
             " THEN 0 WHEN NULL THEN 1 WHEN ' ' THEN 2 ELSE 3 END ASC, LOTATTRIBUTE.LOTTABLE04, LOTATTRIBUTE.LOTTABLE02, LOTATTRIBUTE.Lottable05 ")    
  
        IF @b_debug = 1    
        BEGIN   
            SELECT '@c_Limitstring' = @c_Limitstring  
        END  
  END   
    
  ExitProc:  
   
END -- main  

GO
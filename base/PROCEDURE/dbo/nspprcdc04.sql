SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: nspPRCDC04                                         */
/* Creation Date: 10-Feb-2002                                           */
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
/* 10-Feb-2002       1.0      Initial Version								   */
/************************************************************************/
CREATE PROC [dbo].[nspPRCDC04]
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
   
    IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_lot)) IS NOT NULL
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
 				@n_curingperiod int
 
  	SELECT @n_shelflife = Sku.Shelflife, @n_curingperiod = isnull(cast(sku.busr2 as int), 0)
  	FROM  Sku (nolock)
  	WHERE SKU.StorerKey = @c_StorerKey
    AND   SKU.sku = @c_sku
 
  	IF dbo.fnc_LTrim(dbo.fnc_RTrim(@n_shelflife)) IS NULL SELECT @n_shelflife = 0
 
    -- Get OrderKey and line Number
    DECLARE @c_OrderKey   NVARCHAR(10),
            @c_OrderLineNumber NVARCHAR(5)
 
    IF dbo.fnc_RTrim(@c_OtherParms) IS NOT NULL AND dbo.fnc_RTrim(@c_OtherParms) <> ''
    BEGIN
       SELECT @c_OrderKey = LEFT(dbo.fnc_LTrim(@c_OtherParms), 10)
       SELECT @c_OrderLineNumber = SUBSTRING(dbo.fnc_LTrim(@c_OtherParms), 11, 5)
 
       -- print '@c_OrderKey=' + @c_OrderKey + ' Line:' + @c_OrderLineNumber
    END
 
    SELECT @c_LimitString = ''  
 
 	-- wally 23.oct.2002
 	-- consider sku's curing period, if setup in sku.busr2
 	if @n_curingperiod > 0  
 	begin
 		SELECT @c_Limitstring = dbo.fnc_RTrim(@c_LimitString) + " AND DATEADD(day, " +
 		   dbo.fnc_RTrim(CAST(@n_curingperiod as NVARCHAR(10))) + ", Lottable04) < getdate()"
 	end
 
    -- Get BillToKey
    DECLARE @c_BillToKey NVARCHAR(15),
            @c_CustSubCode NVARCHAR(20),
            @n_ConsigneeMinShelfLife int,
            @n_ShelfLifePerc int,
            @n_RemainingShelfLife int
 
    IF dbo.fnc_RTrim(@c_OrderKey) IS NOT NULL AND dbo.fnc_RTrim(@c_OrderKey) <> ''
    BEGIN
       SELECT @c_CustSubCode = ISNULL(STORER.Secondary, ''),
              @n_ConsigneeMinShelfLife = ISNULL(SUSR3,0),
              @n_ShelfLifePerc = CAST( ISNULL(MinShelfLife,0) as int)
       FROM   ORDERS (NOLOCK)
       JOIN STORER (NOLOCK) ON (ORDERS.BillToKey = STORER.StorerKey AND Storer.Type In ('2','4'))
       WHERE ORDERS.OrderKey = @c_OrderKey
 
       IF dbo.fnc_RTrim(@c_CustSubCode) IS NOT NULL AND dbo.fnc_RTrim(@c_CustSubCode) <> ''
          SELECT @c_Lottable03 = @c_CustSubCode
 
       IF @n_ConsigneeMinShelfLife > 0 
       BEGIN
          SELECT @c_Limitstring = dbo.fnc_RTrim(@c_LimitString) + " AND DATEDIFF(day, Lottable04, GETDATE()) <= " + CAST(@n_ConsigneeMinShelfLife as NVARCHAR(10))
       END
       ELSE
       BEGIN
          IF @n_shelflife > 0 
          BEGIN
 				-- wally 24.oct.2002
 				-- expiry should be shelflife + prod date (lottable04)
             SELECT @c_Limitstring = dbo.fnc_RTrim(@c_LimitString) + 
 					" AND DATEDIFF(day, GETDATE(), dateadd(day, " + dbo.fnc_RTrim(cast(@n_shelflife as NVARCHAR(10))) +
 					", lottable04)) > 0"
 
             IF @n_ShelfLifePerc > 0 
             BEGIN
                SELECT @n_RemainingShelfLife = (@n_shelflife * @n_ShelfLifePerc) / 100
                SELECT @c_Limitstring = dbo.fnc_RTrim(@c_LimitString) + " AND DATEDIFF(day, GETDATE(), " +
 						"dateadd(day, " + dbo.fnc_RTrim(cast(@n_shelflife as NVARCHAR(10))) + ", lottable04)) >= " + 
 						CAST(@n_RemainingShelfLife as NVARCHAR(10))
             END
          END
       END
    END
 
    -- print @c_Limitstring
    
    IF @c_lottable01 <> ' '  
       SELECT @c_LimitString =  dbo.fnc_RTrim(@c_LimitString) + " AND Lottable01= N'" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_lottable01)) + "'"  
    
    IF @c_lottable02 <> ' '  
       SELECT @c_LimitString =  dbo.fnc_RTrim(@c_LimitString) + " AND lottable02= N'" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_lottable02)) + "'" 
 
 	IF @c_lottable03 <> ' '  
    	SELECT @c_LimitString =  dbo.fnc_RTrim(@c_LimitString) + " AND lottable03= N'" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_lottable03)) + "'"  
 
    IF @d_lottable04 IS NOT NULL AND @d_lottable04 <> '1900-01-01'
       SELECT @c_LimitString =  dbo.fnc_RTrim(@c_LimitString) + " AND lottable04 = N'" + dbo.fnc_LTrim(dbo.fnc_RTrim(CONVERT(char(20), @d_lottable04))) + "'"  
    
    IF @d_lottable05 IS NOT NULL  AND @d_lottable05 <> '1900-01-01'
       SELECT @c_LimitString =  dbo.fnc_RTrim(@c_LimitString) + " AND lottable05= N'" + dbo.fnc_LTrim(dbo.fnc_RTrim(CONVERT(char(20), @d_lottable05))) + "'"  
 
 	SELECT @c_StorerKey = dbo.fnc_RTrim(@c_StorerKey)  
 	SELECT @c_Sku = dbo.fnc_RTrim(@c_SKU)  

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
          " GROUP BY LOT.LOT , LOTATTRIBUTE.Lottable04, LOTATTRIBUTE.Lottable02, LOTATTRIBUTE.Lottable05 " + 
  			 "  HAVING (SUM(LOTxLOCxID.QTY) - SUM(LOTxLOCxID.QtyAllocated) - SUM(LOTxLOCxID.QTYPicked)  - MIN (LOT.QtyPreAllocated) ) > 0 " +
--          "         (SUM(LOTxLOCxID.QTY) - SUM(LOTxLOCxID.QtyAllocated) - SUM(LOTxLOCxID.QTYPicked)  - MIN (LOT.QtyPreAllocated) ) < PACK.Pallet " +
          " ORDER BY LOTATTRIBUTE.LOTTABLE04, LOTATTRIBUTE.LOTTABLE02, LOTATTRIBUTE.Lottable05 ")  
 
  ExitProc:
 
  end -- main

GO
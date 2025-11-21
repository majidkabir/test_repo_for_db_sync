SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Trigger: nspPRIDS24 													            */
/* Creation Date: 21-Jun-2004                                           */
/* Copyright: IDS                                                       */
/* Written by: June                                                     */
/*                                                                      */
/* Purpose:  For IDSMY OW - SOS24337 (Copy from nspIDS20 script,include */
/*           storerconfig "MinShelfLife60Mth")									*/
/*                                                                      */
/* Input Parameters:  @c_storerkey,          - StorerKey                */
/*							 @c_sku,       		   - Sku                      */
/*							 @c_lot,                - Lot                      */
/*                    @c_lottable01,         - Lottable01               */
/*                    @c_lottable02,         - Lottable02               */
/*                    @c_lottable03,         - Lottable03               */
/*                    @c_lottable04,         - Lottable04               */
/*                    @c_lottable05,         - Lottable05               */
/*							 @c_uom,       		   - 1:Pallet, 2:Case, 6:Each */
/*                    @c_Facility,           - Facility                 */
/*                    @n_uombase,            - UOM Base                 */
/*                    @n_qtylefttofulfill,   - Qty Left to Fulfilled    */
/*                                                                      */
/* Output Parameters:                                                   */
/*                                                                      */
/* Return Status:                                                       */
/*                                                                      */
/* Usage:                                                               */
/*                                                                      */
/* Local Variables:                                                     */
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
/* Date         Author     Purposes                                     */
/* 08-Nov-2004	 June	      Bug fixes - IDSSG has ' in lottable02   	   */
/*	16-Dec-2005  Shong      Changed cursor type	                        */
/* 08-Apr-2005 MaryVong    Bug fixed for extra 'For' at cursor          */
/*                                                                      */
/************************************************************************/


CREATE PROC    [dbo].[nspPRIDS24]
   @c_storerkey            NVARCHAR(15) ,
   @c_sku                  NVARCHAR(20) ,
   @c_lot                  NVARCHAR(10) ,
   @c_lottable01           NVARCHAR(18) ,
   @c_lottable02           NVARCHAR(18) ,
   @c_lottable03           NVARCHAR(18) ,
   @d_lottable04           datetime ,
   @d_lottable05           datetime ,
   @c_uom                  NVARCHAR(10) ,
   @c_facility NVARCHAR(10)  ,  -- added By Ricky for IDSV5
   @n_uombase              int ,
   @n_qtylefttofulfill int
AS
BEGIN

        DECLARE @c_Condition NVARCHAR(510) 
        -- Start : SOS24337
			DECLARE @b_success int,@n_err int,@c_errmsg NVARCHAR(250),@b_debug int,  
				@c_manual NVARCHAR(1),
				@n_shelflife int,
				@c_sql NVARCHAR(max),
				@c_Lottable04Label NVARCHAR(20) 
        -- End : SOS24337

        SELECT @b_debug = 0

        IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_lot)) IS NOT NULL AND LEFT(dbo.fnc_LTrim(dbo.fnc_RTrim(@c_lot)), 1) <> "*" 
        BEGIN
				DECLARE  PREALLOCATE_CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR
            -- Remarked by MaryVong on 08-Apr-2004
 			   -- FOR SELECT LOT.STORERKEY, LOT.SKU, LOT.LOT,  
				SELECT LOT.STORERKEY, LOT.SKU, LOT.LOT,  
				                          QTYAVAILABLE = (LOT.QTY - LOT.QTYALLOCATED - LOT.QTYPICKED - LOT.QTYPREALLOCATED)
				FROM    LOT (nolock), LOTATTRIBUTE (nolock), LOTXLOCXID (NOLOCK), LOC (NOLOCK) 
				WHERE LOT.LOT = @c_lot
				AND LOT.LOT = LOTATTRIBUTE.LOT  
				AND LOTXLOCXID.Lot = LOT.LOT
				AND LOTXLOCXID.LOT = LOTATTRIBUTE.LOT
				AND LOTXLOCXID.LOC = LOC.LOC
				AND LOC.Facility = @c_facility
				ORDER BY LOTATTRIBUTE.LOTTABLE04, LOTATTRIBUTE.LOTTABLE05
        END
        ELSE
        BEGIN
				-- Start : SOS24337     
				SELECT @c_Lottable04Label = ISNULL(LOTTABLE04LABEL, "") 
				FROM Sku (nolock), Storer (nolock)
				WHERE Sku.Sku = @c_sku
				AND Sku.Storerkey = @c_storerkey   
				AND Sku.Storerkey = Storer.Storerkey   
				-- End : SOS24337       

           IF dbo.fnc_RTrim(dbo.fnc_LTrim(@c_Lottable01)) <> "" AND @c_Lottable01 IS NOT NULL
           BEGIN
              SELECT @c_Condition = ' AND LOTTABLE01 = N''' + dbo.fnc_RTrim(dbo.fnc_LTrim(@c_Lottable01)) + ''''
           END
           IF dbo.fnc_RTrim(dbo.fnc_LTrim(@c_Lottable02)) <> "" AND @c_Lottable02 IS NOT NULL
           BEGIN
              SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + ' AND LOTTABLE02 = N''' + dbo.fnc_RTrim(dbo.fnc_LTrim(@c_Lottable02)) + ''''
           END
           IF dbo.fnc_RTrim(dbo.fnc_LTrim(@c_Lottable03)) <> "" AND @c_Lottable03 IS NOT NULL
           BEGIN
              SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + ' AND LOTTABLE03 = N''' + dbo.fnc_RTrim(dbo.fnc_LTrim(@c_Lottable03)) + ''''
           END
                -- Start : SOS24337 
--         IF CONVERT(char(10), @d_Lottable04, 103) <> "01/01/1900"
--         BEGIN
--            SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + " AND LOTTABLE04 = '" + dbo.fnc_RTrim(CONVERT( NVARCHAR(20), @d_Lottable04, 106)) + "'"
--         END
                -- End : SOS24337 
           IF CONVERT(char(10), @d_Lottable05, 103) <> "01/01/1900"
           BEGIN
              SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + ' AND LOTTABLE05 = N''' + dbo.fnc_RTrim(CONVERT( NVARCHAR(20), @d_Lottable05, 106)) + ''''
           END
                
	        if @b_debug = 1
					select @c_lot "@c_lot", @c_Lottable02 "@c_Lottable02"

                -- Start : SOS24337 - IDSMY OW - add by June 21.Jun.04
                -- Min Shelf Life Checking
                IF dbo.fnc_RTrim(@c_Lottable04Label) IS NOT NULL AND dbo.fnc_RTrim(@c_Lottable04Label) <> "" 
                BEGIN
                        IF LEFT(@c_lot,1) = "*"
                        BEGIN
--                              DECLARE @c_MinShelfLife60Mth NVARCHAR(1)
                                   SELECT @n_shelflife = CONVERT(int, SUBSTRING(@c_lot, 2, 9))
--                              Select @b_success = 0
--                         
--                              Execute nspGetRight null,                       -- Facility
--                                               @c_storerkey,                 -- Storer
--                                               null,                          -- Sku
--                                               "MinShelfLife60Mth", 
--                                               @b_success                     OUTPUT, 
--                                               @c_MinShelfLife60Mth  OUTPUT, 
--                                               @n_err          OUTPUT, 
--                                               @c_errmsg       OUTPUT 
--                              If @b_success <> 1
--                              Begin
--                                      Select @c_errmsg = "nspPreAllocateOrderProcessing : " + dbo.fnc_RTrim(@c_errmsg)
--                              End                             
                        
--                              IF @c_MinShelfLife60Mth = "1" 
--                              BEGIN
--                                      IF @n_shelflife < 61    
--                                              SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + "AND Lottable04 >= '"  + convert(char(12), DateAdd(MONTH, @n_shelflife, getdate()), 106) + "'"
--                                      ELSE
--                                              SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + " AND Lottable04 >= '"  + convert(char(12), DateAdd(DAY, @n_shelflife, getdate()), 106) + "'"
--                              END
--                              ELSE
--                              BEGIN
--                                      IF @n_shelflife < 13    
--                                              SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + " AND Lottable04 >= '"  + convert(char(12), DateAdd(MONTH, @n_shelflife, getdate()), 106) + "'"
--                                      ELSE
--                                              SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + " AND Lottable04 >= '"  + convert(char(12), DateAdd(DAY, @n_shelflife, getdate()), 106) + "'"
--                              END                                
                                        SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + ' AND Lottable04 >= N'''  + convert(char(12), DateAdd(DAY, @n_shelflife, getdate()), 106) + ''''
                        END
                        ELSE
                        BEGIN
                           SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + ' AND Lottable04 >= N''' + convert(char(12), getdate(), 106) + ''''
                        END 
                END 
                -- End : SOS24337 
        
					SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + ' ORDER BY LOTATTRIBUTE.LOTTABLE04, LOTATTRIBUTE.LOTTABLE05 '
                
					DECLARE @sql NVARCHAR(MAX)
					SELECT @sql = "DECLARE PREALLOCATE_CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR "
					+ "SELECT LOT.STORERKEY, LOT.SKU, LOT.LOT, "
					+ "QTYAVAILABLE = SUM(LOTXLOCXID.QTY - LOTXLOCXID.QTYALLOCATED - LOTXLOCXID.QTYPICKED) - MIN(ISNULL(P.QTYPREALLOCATED, 0)) "
					+ "FROM LOT (NOLOCK) "
					+ "INNER JOIN LOTXLOCXID (NOLOCK) ON LOT.LOT = LOTXLOCXID.LOT "
					+ "INNER JOIN LOC (NOLOCK) ON LOTXLOCXID.LOC = LOC.LOC "
					+ "INNER JOIN LOTATTRIBUTE (NOLOCK) ON LOTXLOCXID.Lot = LOTATTRIBUTE.Lot " 
					+ "INNER JOIN ID  (NOLOCK) ON LOTXLOCXID.ID = ID.ID " 
					+ "LEFT OUTER JOIN (SELECT p.Lot, ORDERS.Facility, QtyPreallocated = SUM(p.Qty) "
					+ "                                             FROM   PreallocatePickDetail p (NOLOCK), ORDERS (NOLOCK) "
					+ "                                             WHERE  p.Orderkey = ORDERS.Orderkey "
					+ "                                             AND      p.Storerkey = N'" + @c_storerkey + "' " 
					+ "                                             AND    p.SKU = N'" + @c_sku + "' " 
					+ "                                             GROUP BY p.Lot, ORDERS.Facility) P ON LOTXLOCXID.Lot = p.Lot AND p.Facility = LOC.Facility "
					+ "WHERE LOT.STORERKEY = N'" + @c_storerkey  + "' "
					+ "AND LOT.SKU = N'" + @c_sku + "' "
					+ "AND LOC.Facility = N'" + @c_facility + "' "
					+ "AND LOT.STATUS = 'OK' AND LOC.STATUS = 'OK' AND ID.STATUS = 'OK' AND (LOC.LOCATIONFLAG <> 'HOLD'  OR LOC.LOCATIONFLAG <> 'DAMAGE' ) "
					+ "GROUP BY LOT.STORERKEY, LOT.SKU, LOT.LOT, LOTATTRIBUTE.LOTTABLE01, LOTATTRIBUTE.LOTTABLE02, LOTATTRIBUTE.LOTTABLE03, LOTATTRIBUTE.LOTTABLE04, LOTATTRIBUTE.LOTTABLE05 "
					+ "HAVING SUM(LOTXLOCXID.QTY - LOTXLOCXID.QTYALLOCATED - LOTXLOCXID.QTYPICKED) - MIN(ISNULL(P.QTYPREALLOCATED, 0)) > 0 "
					+ @c_Condition

                EXEC ( @sql )
        
                IF @b_debug = 1 
                BEGIN
                        SELECT @sql
                        SELECT "Condition", @c_Condition
                END
        END
END

GO
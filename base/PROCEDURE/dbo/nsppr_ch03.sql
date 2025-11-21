SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store Procedure:  nspPR_CH03                                         */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:  Pre-Allocation Strategy of IDSCN - NIKE                    */
/*                                                                      */
/* Input Parameters:  @c_storerkey char                                 */
/*                    @c_sku char                                       */
/*                    @c_lot char                                       */
/*                    @c_lottable01                                     */
/*                    @c_lottable02                                     */
/*                    @c_lottable03                                     */
/*                    @d_lottable04                                     */
/*                    @d_lottable05                                     */
/*                    @c_uom                                            */
/*                    @c_facility                                       */
/*                    @n_uombase                                        */
/*                    @n_qtylefttofulfill                               */
/*                                                                      */
/* Output Parameters:  None                                             */
/*                                                                      */
/* Return Status:  None                                                 */
/*                                                                      */
/* Usage:                                                               */
/*                                                                      */
/* Local Variables:                                                     */
/*                                                                      */
/* Called By: Allocation Module                                         */
/*                                                                      */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Purposes                                      */
/* 01-Apr-2005  YokeBeen  Changed to have an Outer Join to check during */
/*                        pre-allocation for ORDERS.Facility.           */
/*                        - (SOS#33930) - (YokeBeen01)                  */
/* 28-Jun-2007  June		  SOS76195 - Fix allocate Piece from Bulk	loc   */
/* 02-Feb-2009  Leong     SOS128087 - SQL 2005 compatible fix           */
/* 25-Jul-2014  TLTING     Pass extra parm @c_OtherParms                */
/************************************************************************/

CREATE PROCEDURE [dbo].[nspPR_CH03]  
-- for NIKE CN
@c_storerkey NVARCHAR(15) ,  
@c_sku NVARCHAR(20) ,  
@c_lot NVARCHAR(10) ,  
@c_lottable01 NVARCHAR(18) ,  
@c_lottable02 NVARCHAR(18) ,  
@c_lottable03 NVARCHAR(18) ,  
@d_lottable04 datetime ,  
@d_lottable05 datetime ,  
@c_uom NVARCHAR(10) ,
@c_facility NVARCHAR(10)  ,
@n_uombase int ,  
@n_qtylefttofulfill int ,  -- new column  
@c_OtherParms NVARCHAR(200) = ''  --Orderinfo4PreAllocation  
AS
BEGIN  
   
   DECLARE @b_success int,@n_err int,@c_errmsg NVARCHAR(250),@b_debug int  
   DECLARE @c_manual NVARCHAR(1)   
   DECLARE @c_LimitString NVARCHAR(255) -- To limit the where clause based on the user input  
	DECLARE @c_Limitstring1 NVARCHAR(255)  , @c_lottable04label NVARCHAR(20)
   SELECT @b_success= 0, @n_err= 0, @c_errmsg="", @b_debug= 0
   SELECT @c_manual = 'N'  

	DECLARE @n_shelflife int 
   DECLARE @n_continue int

   DECLARE @c_UOMBase NVARCHAR(10)

   SELECT @c_UOMBase = @n_uombase

   IF @d_lottable04 = '1900-01-01'
	BEGIN
		SELECT @d_lottable04 = null
	END

   IF @d_lottable05 = '1900-01-01'
	BEGIN
		SELECT @d_lottable05 = null
	END

   IF @b_debug = 1  
   BEGIN  
      SELECT "nspPR_CH01 : Before Lot Lookup ....."  
      SELECT '@c_lot'=@c_lot,'@c_lottable01'=@c_lottable01, '@c_lottable02'=@c_lottable02, '@c_lottable03'=@c_lottable03   
		SELECT '@d_lottable04' = @d_lottable04, '@d_lottable05' = @d_lottable05, '@c_manual' = @c_manual  , '@c_sku' = @c_sku
		SELECT '@c_storerkey' = @c_storerkey, '@c_facility' = @c_facility
   END  
     
   -- when any of the lottables is supplied, get the specific lot  
--   IF (@c_lottable01<>'' OR @c_lottable02<>'' OR @c_lottable03<>'' OR   
--       @d_lottable04 IS NOT NULL OR @d_lottable05 IS NOT NULL) OR LEFT(@c_lot,1) = '*'

   IF ((ISNULL(LTRIM(RTRIM(@c_lottable01)),'')) <> '' OR 
       (ISNULL(LTRIM(RTRIM(@c_lottable02)),'')) <> '' OR 
       (ISNULL(LTRIM(RTRIM(@c_lottable03)),'')) <> '' OR   
       (ISNULL(LTRIM(RTRIM(@d_lottable04)),'')) <> '' OR 
       (ISNULL(LTRIM(RTRIM(@d_lottable05)),'')) <> '' ) OR 
       LEFT(ISNULL(LTRIM(RTRIM(@c_lot)),''),1) = '*' -- SOS128087

   BEGIN  
     SELECT @c_manual = 'Y'  
   END  
  
   IF @b_debug = 1  
   BEGIN  
      SELECT "nspPR_CH01 : After Lot Lookup ....."  
      SELECT '@c_lot'=@c_lot,'@c_lottable01'=@c_lottable01, '@c_lottable02'=@c_lottable02, '@c_lottable03'=@c_lottable03
		SELECT '@d_lottable04' = @d_lottable04, '@d_lottable05' = @d_lottable05, '@c_manual' = @c_manual  
		SELECT '@c_storerkey' = @c_storerkey
   END  
     
   -- Start : SOS76195  
   IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_lot)) IS NOT NULL AND dbo.fnc_LTrim(dbo.fnc_RTrim(@c_lot)) <> '' AND LEFT(@c_lot, 1) <> '*'  
   -- IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_lot)) IS NOT NULL AND LEFT(@c_lot, 1) <> '*'
   -- END : SOS76195  
   BEGIN       
   	   
		/* Lot specific candidate set */  
      DECLARE PREALLOCATE_CURSOR_CANDIDATES SCROLL CURSOR FOR   
      SELECT LOT.STORERKEY,LOT.SKU,LOT.LOT ,  
             QTYAVAILABLE =  (LOT.QTY - LOT.QTYALLOCATED - LOT.QTYPICKED - LOT.QTYPREALLOCATED)
      FROM LOT (NOLOCK), LOTATTRIBUTE (NOLOCK), LOTXLOCXID (NOLOCK), LOC (NOLOCK), SKUxLOC (NOLOCK) 
      WHERE LOT.LOT = LOTATTRIBUTE.LOT  
		AND LOTXLOCXID.Lot = LOT.LOT
		AND LOTXLOCXID.LOT = LOTATTRIBUTE.LOT
		AND LOTXLOCXID.LOC = LOC.LOC
		AND LOC.Facility = @c_facility
 		AND LOT.LOT = @c_lot
                AND SKUxLOC.StorerKey = LOTxLOCxID.StorerKey 
                AND SKUxLOC.SKU = LOTxLOCxID.SKU 
	        AND SKUxLOC.LOC = LOTxLOCxID.LOC  
--	        AND SKUxLOC.LocationType NOT IN ('PICK', 'CASE')    
           ORDER BY LOTATTRIBUTE.Lottable04, LOTATTRIBUTE.LOTTABLE05  

      IF @b_debug = 1
		BEGIN
			SELECT ' Lot not null'
			SELECT 	LOT.STORERKEY,LOT.SKU,LOT.LOT ,  
            		QTYAVAILABLE = (LOT.QTY - LOT.QTYALLOCATED - LOT.QTYPICKED - LOT.QTYPREALLOCATED)  
      	FROM LOT, LOTATTRIBUTE  
      	WHERE LOT.LOT = LOTATTRIBUTE.LOT  
 			AND LOT.LOT = @c_lot  
      	ORDER BY LOTATTRIBUTE.Lottable04, LOTATTRIBUTE.LOTTABLE02    
		END
   END  
   ELSE  
   BEGIN            
      /* Everything Else when no lottable supplied */  
   	IF @c_manual = 'N'   
	   BEGIN  
         IF @b_debug = 1 SELECT 'Manual = N and Lot is NULL'

			SELECT @n_shelflife = convert(int, SKU.SUSR2)
			FROM SKU (NOLOCK)
			WHERE SKU = @c_sku
			AND STORERKEY = @c_storerkey
         
         SELECT @c_lottable04label = SKU.Lottable04label
         FROM SKU (NOLOCK)
         WHERE SKU = @c_sku
			AND STORERKEY = @c_storerkey
         
         SELECT @c_Limitstring1 = ''

			IF @c_lottable04label = 'MANDATE'
         BEGIN
            IF @n_shelflife > 0
            BEGIN
               SELECT @c_Limitstring1 = dbo.fnc_RTrim(@c_LimitString1) + " AND lottable04  > N'"  +  convert(char(15), DateAdd(day, - @n_shelflife, getdate()), 106) + "'"
            --      SELECT dbo.fnc_RTrim(@c_LimitString1) + " AND convert(char(10), lottable04, 106)  < N'" + convert(char(20), DateAdd(day, @n_shelflife, getdate()), 106) + "'"
            END
            
            ELSE
            BEGIN
               SELECT @c_Limitstring1 = dbo.fnc_RTrim(@c_LimitString1) + " AND Lottable05 <= N'" + convert(char(15), getdate(), 106) + "'"
            END
         END   

         IF @b_debug = 1
         BEGIN
            SELECT 'Manual = N'
            SELECT 'limitstring' , @c_limitstring1
         END
         
--SELECT 'abc' = @c_limitstring1

        EXEC ('DECLARE PREALLOCATE_CURSOR_CANDIDATES SCROLL CURSOR FOR  ' + 
            'SELECT MIN(LOTXLOCXID.STORERKEY) , MIN(LOTXLOCXID.SKU), LOT.LOT,   ' +  
            'QTYAVAILABLE = (SUM(LOTXLOCXID.QTY) - SUM(LOTXLOCXID.QTYALLOCATED) - SUM(LOTXLOCXID.QTYPICKED) - MIN(LOT.QtyPreallocated) )' +
            'FROM LOT (NOLOCK) , LOTATTRIBUTE (NOLOCK), LOTXLOCXID (NOLOCK), LOC (NOLOCK), ID (NOLOCK), SKU (NOLOCK), SKUxLOC (NOLOCK) ' +  
            'WHERE LOTXLOCXID.STORERKEY = N''' + @c_storerkey + ''' ' +
            ' AND LOTXLOCXID.SKU = N''' + @c_sku +  ''' '   +
            ' AND LOT.STATUS = "OK" AND LOC.STATUS = "OK" AND ID.STATUS = "OK" And LOC.LocationFlag = "NONE" ' +  
            ' AND LOTXLOCXID.ID = ID.ID AND lot.lot = lotattribute.lot ' + 
            ' AND LOTXLOCXID.LOT = LOT.LOT AND LOTXLOCXID.LOT = LOTATTRIBUTE.LOT ' +  
            ' AND LOTXLOCXID.LOC = LOC.LOC ' + 
            ' AND SKU.SKU = LOTXLOCxID.SKU ' +
            ' AND SKU.STORERKEY = LOTXLOCXID.STORERKEY ' +
            ' AND LOTATTRIBUTE.SKU = SKU.SKU  AND LOTATTRIBUTE.STORERKEY = SKU.STORERKEY ' +
            ' AND LOC.FACILITY = N''' + @c_facility + ''' ' + @c_LimitString1 + ' ' + 
            ' AND SKUxLOC.StorerKey = LOTxLOCxID.StorerKey '  +
            ' AND SKUxLOC.SKU = LOTxLOCxID.SKU  ' + 
            ' AND SKUxLOC.LOC = LOTxLOCxID.LOC  ' +
--	    ' AND SKUxLOC.LocationType NOT IN ("PICK", "CASE") ' + 
            ' GROUP BY LOT.LOT -- , LOTATTRIBUTE.Lottable04, LOTATTRIBUTE.LOTTABLE05, LOTATTRIBUTE.Lottable02 ' +  
            ' HAVING (SUM(LOTXLOCXID.QTY) - SUM(LOTXLOCXID.QtyAllocated) - SUM(LOTXLOCXID.QTYPicked)- MIN(LOT.QtyPreAllocated) ) > 0 ' +
            ' ORDER BY  lotATTRIBUTE.LOTTABLE04, LOTATTRIBUTE.LOTTABLE05 ')  


         IF @b_debug = 1
         BEGIN
            SELECT 'AND LOC.FACILITY = N''' + @c_facility + '''' + @c_LimitString1 + '"'
         END

      END  
      ELSE  
      BEGIN  
         IF @b_debug = 1 SELECT 'Manual = Y and Lot is NULL'

   		SELECT @c_LimitString = ''  
   
			-- IF @c_lottable01 <> ' '
         IF ISNULL(RTRIM(@c_lottable01),'') <> '' -- SOS128087  
		   SELECT @c_LimitString =  dbo.fnc_RTrim(@c_LimitString) + " AND Lottable01= N'" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_lottable01)) + "'"  
  
			-- IF @c_lottable02 <> ' '
         IF ISNULL(RTRIM(@c_lottable02),'') <> '' -- SOS128087  
         SELECT @c_LimitString =  dbo.fnc_RTrim(@c_LimitString) + " AND lottable02= N'" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_lottable02)) + "'"  
  
			-- IF @c_lottable03 <> ' '
         IF ISNULL(RTRIM(@c_lottable03),'') <> '' -- SOS128087  
			SELECT @c_LimitString =  dbo.fnc_RTrim(@c_LimitString) + " AND lottable03= N'" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_lottable03)) + "'"    
 			
         -- IF @d_lottable04 IS NOT NULL AND @d_lottable04 <> '1900-01-01'
         IF ISNULL(RTRIM(@d_lottable04),'') <> '' AND ISNULL(RTRIM(@d_lottable04),'') <> '1900-01-01' -- SOS128087
         SELECT @c_LimitString =  dbo.fnc_RTrim(@c_LimitString) + " AND lottable04 = N'" + dbo.fnc_LTrim(dbo.fnc_RTrim(CONVERT(char(20), @d_lottable04))) + "'"  
  
 			-- IF @d_lottable05 IS NOT NULL  AND @d_lottable05 <> '1900-01-01'
         IF ISNULL(RTRIM(@d_lottable05),'') <> '' AND ISNULL(RTRIM(@d_lottable05),'') <> '1900-01-01' -- SOS128087
    		SELECT @c_LimitString =  dbo.fnc_RTrim(@c_LimitString) + " AND lottable05= N'" + dbo.fnc_LTrim(dbo.fnc_RTrim(CONVERT(char(20), @d_lottable05))) + "'"  

 			IF LEFT(@c_lot,1) = '*'
			BEGIN
			   SELECT @n_shelflife = convert(int, substring(@c_lot, 2, 9))
           
				IF @n_shelflife < 13
				-- it's month
				BEGIN
					SELECT @c_Limitstring = dbo.fnc_RTrim(@c_LimitString) + " AND lottable04  > N'"  + convert(char(15), dateadd(month, @n_shelflife, getdate()), 106) + "'"
				END
				ELSE
				BEGIN
					SELECT @c_Limitstring = dbo.fnc_RTrim(@c_LimitString) + " AND lottable04  > N'" + convert(char(15), DateAdd(day, @n_shelflife, getdate()), 106) + "'"
				END
			END
         IF @b_debug = 1
         BEGIN
         	SELECT '@c_limitstring', @c_limitstring
         END
			-- set @b_debug = 1

      	IF @b_debug = 1
      	BEGIN
            Print (' DECLARE PREALLOCATE_CURSOR_CANDIDATES SCROLL CURSOR FOR ' +  
                	' SELECT MIN(LOTXLOCXID.STORERKEY) , MIN(LOTXLOCXID.SKU), LOT.LOT, ' +  
                  ' QTYAVAILABLE = (SUM(LOTXLOCXID.QTY) - SUM(LOTXLOCXID.QTYALLOCATED) - SUM(LOTXLOCXID.QTYPICKED) - MIN(LOT.QtyPreallocated) ) ' + 
                  ' FROM LOT (NOLOCK) ' + 
						' JOIN LOTATTRIBUTE (NOLOCK) ON (lot.lot = lotattribute.lot) ' + 
						' JOIN LOTXLOCXID (NOLOCK) ON (LOTXLOCXID.LOT = LOT.LOT AND LOTXLOCXID.LOT = LOTATTRIBUTE.LOT) ' + 
						' JOIN LOC (NOLOCK) ON (LOTXLOCXID.LOC = LOC.LOC) ' + 
						' JOIN ID (NOLOCK) ON (LOTXLOCXID.ID = ID.ID) ' + 
						' JOIN SKUxLOC (NOLOCK) ON (SKUxLOC.SKU = LOTxLOCxID.SKU AND SKUxLOC.LOC = LOTxLOCxID.LOC AND SKUxLOC.StorerKey = LOTxLOCxID.StorerKey) ' + 
						' LEFT OUTER JOIN (SELECT P.lot, ORDERS.Facility, QtyPreallocated = SUM(P.Qty) ' + 
		      					 ' FROM   PreallocatePickdetail P (NOLOCK), ORDERS (NOLOCK) ' + 
		      					 ' WHERE  P.Orderkey = ORDERS.Orderkey ' + 
		      					 ' AND    P.Storerkey = N''' + @c_storerkey + ''' ' +  
		      					 ' AND    P.SKU = N''' + @c_sku +  ''' ' + 
	                         ' AND    ORDERS.FACILITY = N''' + @c_facility + ''' ' + 
									 ' AND    P.qty > 0 ' + 
		      					 ' GROUP BY p.Lot, ORDERS.Facility) P ON LOTXLOCXID.Lot = P.Lot AND P.Facility = LOC.Facility ' + 	
                  ' WHERE LOTXLOCXID.STORERKEY = N''' + @c_storerkey + ''' ' + 
                  ' AND LOTXLOCXID.SKU = N''' + @c_sku +  ''' ' + 
                  ' AND LOT.STATUS = "OK" AND LOC.STATUS = "OK" AND ID.STATUS = "OK" And LOC.LocationFlag = "NONE" ' + 
	               ' AND LOC.FACILITY = N''' + @c_facility + ''' ' + @c_LimitString + ' ' +  
	               ' AND (SKUxLOC.LocationType NOT IN ("PICK", "CASE") OR SKUxLOC.LocationType IN ("PICK", "CASE")) ' + 
                  ' GROUP BY LOT.LOT, SKUxLOC.LocationType, LOTATTRIBUTE.LOTTABLE04, LOTATTRIBUTE.LOTTABLE02, LOTATTRIBUTE.LOTTABLE05 ' + 
		            ' HAVING (SUM(LOTXLOCXID.QTY) - SUM(LOTXLOCXID.QtyAllocated) - SUM(LOTXLOCXID.QTYPicked)- MIN(LOT.QtyPreAllocated) ) > 0 ' + 
	               ' ORDER BY  SKUxLOC.LocationType, LOTATTRIBUTE.LOTTABLE04, LOTATTRIBUTE.LOTTABLE02, LOTATTRIBUTE.LOTTABLE05 ')  
         END

			-- (YokeBeen01) - Start
 			SELECT @c_StorerKey = dbo.fnc_RTrim(@c_StorerKey)  
 			SELECT @c_Sku = dbo.fnc_RTrim(@c_SKU)  
            EXEC (' DECLARE PREALLOCATE_CURSOR_CANDIDATES SCROLL CURSOR FOR ' +  
                	' SELECT MIN(LOTXLOCXID.STORERKEY) , MIN(LOTXLOCXID.SKU), LOT.LOT, ' +  
                  ' QTYAVAILABLE = (SUM(LOTXLOCXID.QTY) - SUM(LOTXLOCXID.QTYALLOCATED) - SUM(LOTXLOCXID.QTYPICKED) - MIN(LOT.QtyPreallocated) ) ' + 
                  ' FROM LOT (NOLOCK) ' + 
						' JOIN LOTATTRIBUTE (NOLOCK) ON (lot.lot = lotattribute.lot) ' + 
						' JOIN LOTXLOCXID (NOLOCK) ON (LOTXLOCXID.LOT = LOT.LOT AND LOTXLOCXID.LOT = LOTATTRIBUTE.LOT) ' + 
						' JOIN LOC (NOLOCK) ON (LOTXLOCXID.LOC = LOC.LOC) ' + 
						' JOIN ID (NOLOCK) ON (LOTXLOCXID.ID = ID.ID) ' + 
						' JOIN SKUxLOC (NOLOCK) ON (SKUxLOC.SKU = LOTxLOCxID.SKU AND SKUxLOC.LOC = LOTxLOCxID.LOC AND SKUxLOC.StorerKey = LOTxLOCxID.StorerKey) ' + 
						' LEFT OUTER JOIN (SELECT P.lot, ORDERS.Facility, QtyPreallocated = SUM(P.Qty) ' + 
		      					 ' FROM   PreallocatePickdetail P (NOLOCK), ORDERS (NOLOCK) ' + 
		      					 ' WHERE  P.Orderkey = ORDERS.Orderkey ' + 
		      					 ' AND    P.Storerkey = N''' + @c_storerkey + ''' ' +  
		      					 ' AND    P.SKU = N''' + @c_sku +  ''' ' + 
	                         ' AND    ORDERS.FACILITY = N''' + @c_facility + ''' ' + 
									 ' AND    P.qty > 0 ' + 
		      					 ' GROUP BY p.Lot, ORDERS.Facility) P ON LOTXLOCXID.Lot = P.Lot AND P.Facility = LOC.Facility ' + 	
             ' WHERE LOTXLOCXID.STORERKEY = N''' + @c_storerkey + ''' ' + 
                  ' AND LOTXLOCXID.SKU = N''' + @c_sku +  ''' ' + 
                  ' AND LOT.STATUS = "OK" AND LOC.STATUS = "OK" AND ID.STATUS = "OK" And LOC.LocationFlag = "NONE" ' + 
	               ' AND LOC.FACILITY = N''' + @c_facility + ''' ' + @c_LimitString + ' ' +  
	               ' AND (SKUxLOC.LocationType NOT IN ("PICK", "CASE") OR SKUxLOC.LocationType IN ("PICK", "CASE")) ' + 
                  ' GROUP BY LOT.LOT, SKUxLOC.LocationType, LOTATTRIBUTE.LOTTABLE04, LOTATTRIBUTE.LOTTABLE02, LOTATTRIBUTE.LOTTABLE05 ' + 
		            ' HAVING (SUM(LOTXLOCXID.QTY) - SUM(LOTXLOCXID.QtyAllocated) - SUM(LOTXLOCXID.QTYPicked)- MIN(LOT.QtyPreAllocated) ) > 0 ' + 
	               ' ORDER BY  SKUxLOC.LocationType, LOTATTRIBUTE.LOTTABLE04, LOTATTRIBUTE.LOTTABLE02, LOTATTRIBUTE.LOTTABLE05 ')  
			-- (YokeBeen01) - END

 		END  
  	END  
END

GO
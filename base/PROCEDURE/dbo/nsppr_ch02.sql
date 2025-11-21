SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Stored Procedure: nspPR_CH02                                         */  
/* Creation Date:                                                       */  
/* Copyright: IDS                                                       */  
/* Written by:                                                          */  
/*                                                                      */  
/* Purpose:                                                             */  
/*                                                                      */  
/* Called By:                                                           */  
/*                                                                      */  
/* PVCS Version: 1.7                                                    */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author        Purposes                                  */  
/* 25-Jul-2014  TLTING        Pass extra parm @c_OtherParms             */  
/* 25-Jul-2018  TLTING01 1.1  Dynamic SQL Cache recompile				        */
/* 03-Dec-2018  Pakyuen  1.2  INC0492755 - Check ISNUMERIC SKU.SUSR2	  */  
/* 22-Sep-2020	NJOW01   1.3  WMS-15289 Skip check lottable01 by config */
/* 02-Sep-2021  NJOW02   1.4  WMS-17582 Skip check lottable01 by order  */
/*                            type setting in codelkup                  */
/* 06-Oct-2021  NJOW     1.5  DEVOPS combine script                     */
/************************************************************************/  
  
CREATE PROCEDURE [dbo].[nspPR_CH02]  
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
@n_qtylefttofulfill INT,  -- new column    
@c_OtherParms NVARCHAR(200) = ''  --Orderinfo4PreAllocation    
AS  
BEGIN  
 SET NOCOUNT ON         
  
   DECLARE @b_success int,@n_err int,@c_errmsg NVARCHAR(250),@b_debug int  
   DECLARE @c_manual NVARCHAR(1)  
   DECLARE @c_LimitString NVARCHAR(255) -- To limit the where clause based on the user input  
   DECLARE @c_Limitstring1 NVARCHAR(255)  , @c_lottable04label NVARCHAR(20)  
   DECLARE @c_SQL              NVARCHAR(4000)    
           ,@c_SQLParm         NVARCHAR(4000)     
           ,@c_OrderType       NVARCHAR(10) --NJOW02
                                        
   SELECT @c_SQL = '', @c_SQLParm = ''  
   SELECT @b_success= 0, @n_err= 0, @c_errmsg="",@b_debug= 0  
   SELECT @c_manual = 'N'  
  
   declare @n_shelflife int  
   declare @n_continue int  
  
   DECLARE @c_UOMBase NVARCHAR(10)  
  
   SELECT @c_UOMBase = @n_uombase  
  
   If @d_lottable04 = '1900-01-01'  
   Begin  
      Select @d_lottable04 = null  
   End  
  
   If @d_lottable05 = '1900-01-01'  
   Begin  
      Select @d_lottable05 = null  
   End  
  
   IF @b_debug = 1  
   BEGIN  
      SELECT "nspPR_CH02 : Before Lot Lookup ....."  
      SELECT '@c_lot'=@c_lot,'@c_lottable01'=@c_lottable01, '@c_lottable02'=@c_lottable02, '@c_lottable03'=@c_lottable03  
      SELECT '@d_lottable04' = @d_lottable04, '@d_lottable05' = @d_lottable05, '@c_manual' = @c_manual  , '@c_sku' = @c_sku  
      SELECT '@c_storerkey' = @c_storerkey, '@c_facility' = @c_facility  
   END  
  
   -- when any of the lottables is supplied, get the specific lot  
   IF (@c_lottable01<>'' OR @c_lottable02<>'' OR @c_lottable03<>'' OR  
   @d_lottable04 IS NOT NULL OR @d_lottable05 IS NOT NULL) OR LEFT(@c_lot,1) = '*'  
   BEGIN  
      select @c_manual = 'Y'  
   END  
  
   IF @b_debug = 1  
   BEGIN  
      SELECT "nspPR_CH02 : After Lot Lookup ....."  
      SELECT '@c_lot'=@c_lot,'@c_lottable01'=@c_lottable01, '@c_lottable02'=@c_lottable02, '@c_lottable03'=@c_lottable03  
      SELECT '@d_lottable04' = @d_lottable04, '@d_lottable05' = @d_lottable05, '@c_manual' = @c_manual  
      SELECT '@c_storerkey' = @c_storerkey  
   END  
  
   IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_lot)) IS NOT NULL AND LEFT(@c_lot, 1) <> '*'  
   BEGIN  
  
      /* Lot specific candidate set */  
      DECLARE PREALLOCATE_CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR  
      SELECT LOT.STORERKEY,LOT.SKU,LOT.LOT ,  
      QTYAVAILABLE =  (LOT.QTY - LOT.QTYALLOCATED - LOT.QTYPICKED - LOT.QTYPREALLOCATED)  
      FROM LOT (NOLOCK) , LOTATTRIBUTE (NOLOCK) , LOTXLOCXID (NOLOCK), LOC (NOLOCK), SKUxLOC (NOLOCK)  
      WHERE LOT.LOT = LOTATTRIBUTE.LOT  
      AND LOTXLOCXID.Lot = LOT.LOT  
      AND LOTXLOCXID.LOT = LOTATTRIBUTE.LOT  
      AND LOTXLOCXID.LOC = LOC.LOC  
      AND LOC.Facility = @c_facility  
      AND LOT.LOT = @c_lot  
      AND SKUxLOC.StorerKey = LOTxLOCxID.StorerKey  
      AND SKUxLOC.SKU = LOTxLOCxID.SKU  
      AND SKUxLOC.LOC = LOTxLOCxID.LOC  
      --  AND SKUxLOC.LocationType IN ('PICK', 'CASE')  
      -- Changed by June 19.Mar.2004 SOS21238  
      -- Richard request to sort by lot02 first for non-Lot specified  
      ORDER BY LOTATTRIBUTE.Lottable02, LOTATTRIBUTE.Lottable04, LOTATTRIBUTE.LOTTABLE05, (LOT.QTY - LOT.QTYALLOCATED - LOT.QTYPICKED - LOT.QTYPREALLOCATED) DESC  
  
      IF @b_debug = 1  
      BEGIN  
         SELECT ' Lot not null'  
         SELECT  LOT.STORERKEY,LOT.SKU,LOT.LOT ,  
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
         IF @b_debug = 1  
         BEGIN  
            SELECT 'MANUAL = N'  
         END  
  
         SELECT @n_shelflife = CASE WHEN ISNUMERIC(ISNULL(SKU.Susr2,'0')) = 1 THEN CONVERT(INT, ISNULL(SKU.Susr2,'0')) ELSE 0 END  --INC0492755
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
               SELECT @c_Limitstring1 = dbo.fnc_RTrim(@c_LimitString1) + " AND lottable04  > DateAdd(day, - @n_shelflife, getdate())  "  
               --      SELECT dbo.fnc_RTrim(@c_LimitString1) + " AND convert(char(10), lottable04, 106)  < '" + convert(char(20), DateAdd(day, @n_shelflife, getdate()), 106) + "'"  
            END  
  
            --         ELSE  
            --        BEGIN  
            --          SELECT @c_Limitstring1 = dbo.fnc_RTrim(@c_LimitString1) + " AND Lottable05 <= '" + convert(char(15), getdate(), 106) + "'"  
            --         END  
         END  
  
         IF @b_debug = 1  
         BEGIN  
            SELECT 'Manual = N'  
            select 'limitstring' , @c_limitstring1  
         END  
  
         ---select 'abc' = @c_limitstring1  
  
         SELECT @c_SQL = N'DECLARE PREALLOCATE_CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR  ' +  
               'SELECT MIN(LOTXLOCXID.STORERKEY) , MIN(LOTXLOCXID.SKU), LOT.LOT,   ' +  
               'QTYAVAILABLE = (SUM(LOTXLOCXID.QTY) - SUM(LOTXLOCXID.QTYALLOCATED) - SUM(LOTXLOCXID.QTYPICKED) - MIN(LOT.QtyPreallocated) )' +  
               'FROM LOT (NOLOCK) , LOTATTRIBUTE (NOLOCK), LOTXLOCXID (NOLOCK), LOC (NOLOCK), ID (NOLOCK), SKU (NOLOCK), SKUxLOC (NOLOCK) ' +  
               'WHERE LOTXLOCXID.STORERKEY = @c_storerkey  ' +  
               ' AND LOTXLOCXID.SKU = @c_sku  '   +  
               ' AND LOT.STATUS = "OK" AND LOC.STATUS = "OK" AND ID.STATUS = "OK" And LOC.LocationFlag = "NONE" ' +  
               ' AND LOTXLOCXID.ID = ID.ID AND lot.lot = lotattribute.lot ' +  
               ' AND LOTXLOCXID.LOT = LOT.LOT AND LOTXLOCXID.LOT = LOTATTRIBUTE.LOT ' +  
               ' AND LOTXLOCXID.LOC = LOC.LOC ' +  
               ' AND SKU.SKU = LOTXLOCxID.SKU ' +  
               ' AND SKU.STORERKEY = LOTXLOCXID.STORERKEY ' +  
               ' AND LOTATTRIBUTE.SKU = SKU.SKU  AND LOTATTRIBUTE.STORERKEY = SKU.STORERKEY ' +  
               ' AND LOC.FACILITY = @c_facility  ' + @c_LimitString1 + ' ' +  
               ' AND SKUxLOC.StorerKey = LOTxLOCxID.StorerKey '  +  
               ' AND SKUxLOC.SKU = LOTxLOCxID.SKU  ' +  
               ' AND SKUxLOC.LOC = LOTxLOCxID.LOC  ' +  
               --     ' AND SKUxLOC.LocationType IN ("PICK", "CASE") ' +  
               -- Change by June 24.Dec.03 Bug Fixes  
               ' GROUP BY LOT.LOT, LOTATTRIBUTE.Lottable04, LOTATTRIBUTE.LOTTABLE05 , LOTATTRIBUTE.Lottable02 ' +  
               -- ' GROUP BY LOT.LOT --, LOTATTRIBUTE.Lottable04, LOTATTRIBUTE.LOTTABLE05 , LOTATTRIBUTE.Lottable02 ' +  
               ' HAVING (SUM(LOTXLOCXID.QTY) - SUM(LOTXLOCXID.QtyAllocated) - SUM(LOTXLOCXID.QTYPicked)- MIN(LOT.QtyPreAllocated) ) > 0 ' +  
               -- Changed by June 19.Mar.2004 SOS21238  
               -- Richard request to sort by lot02 first for non-Lot specified  
               ' ORDER BY LOTATTRIBUTE.Lottable02, lotATTRIBUTE.LOTTABLE04, LOTATTRIBUTE.LOTTABLE05, (SUM(LOTXLOCXID.QTY) - SUM(LOTXLOCXID.QTYALLOCATED) - SUM(LOTXLOCXID.QTYPICKED) - MIN(LOT.QtyPreallocated) ) DESC '  
    
               SET @c_SQLParm =  N'@c_facility   NVARCHAR(5),  @c_storerkey  NVARCHAR(15), @c_SKU        NVARCHAR(20), ' +     
                         '@n_shelflife INT  '       
        
            EXEC sp_ExecuteSQL @c_SQL, @c_SQLParm, @c_facility, @c_storerkey, @c_SKU,   
                         @n_ShelfLife     
  
  
  
         IF @b_debug = 1  
         BEGIN  
            SELECT 'Candidate lines'  
            SELECT MIN(LOTXLOCXID.STORERKEY) , MIN(LOTXLOCXID.SKU), LOT.LOT,  
            QTYAVAILABLE = (SUM(LOTXLOCXID.QTY) - SUM(LOTXLOCXID.QTYALLOCATED) - SUM(LOTXLOCXID.QTYPICKED) - MIN(LOT.QtyPreallocated) )  
            FROM LOT (NOLOCK) , LOTATTRIBUTE (NOLOCK), LOTXLOCXID (NOLOCK), LOC (NOLOCK), ID (NOLOCK), SKU (NOLOCK), SKUxLOC (NOLOCK)  
            WHERE LOT.STORERKEY = @c_storerkey  
            AND LOT.SKU = @c_sku  
            AND LOT.STATUS = "OK" AND LOC.STATUS = "OK" AND ID.STATUS = "OK" And LOC.LocationFlag = "NONE"  
            AND LOTXLOCXID.ID = ID.ID AND lot.lot = lotattribute.lot  
            AND LOTXLOCXID.LOT = LOT.LOT AND LOTXLOCXID.LOT = LOTATTRIBUTE.LOT  
            AND LOTXLOCXID.LOC = LOC.LOC  
            AND SKU.SKU = LOTXLOCxID.SKU  
            AND SKU.STORERKEY = LOTXLOCXID.STORERKEY  
            AND LOTATTRIBUTE.SKU = SKU.SKU  AND LOTATTRIBUTE.STORERKEY = SKU.STORERKEY  
            AND LOC.FACILITY = @c_facility  
            AND SKUxLOC.StorerKey = LOTxLOCxID.StorerKey  
            AND SKUxLOC.SKU = LOTxLOCxID.SKU  
            AND SKUxLOC.LOC = LOTxLOCxID.LOC  
            --      AND SKUxLOC.LocationType IN ("PICK", "CASE")  
            GROUP BY LOT.LOT , LOTATTRIBUTE.Lottable04, LOTATTRIBUTE.LOTTABLE05 , LOTATTRIBUTE.Lottable02  
            HAVING (SUM(LOTXLOCXID.QTY) - SUM(LOTXLOCXID.QtyAllocated) - SUM(LOTXLOCXID.QTYPicked)- MIN(LOT.QtyPreAllocated) ) > 0  
            ORDER BY LOTATTRIBUTE.Lottable02, lotATTRIBUTE.LOTTABLE04, LOTATTRIBUTE.LOTTABLE05, (SUM(LOTXLOCXID.QTY) - SUM(LOTXLOCXID.QTYALLOCATED) - SUM(LOTXLOCXID.QTYPICKED) - MIN(LOT.QtyPreallocated) ) DESC  
         END  
      END  
   ELSE  
      BEGIN  
         IF @b_debug =1  
         BEGIN  
            SELECT 'MANUAL = Y'  
         END  
        
         --NJOW02
         SELECT @c_OrderType = Type
         FROM ORDERS(NOLOCK)
         WHERE Orderkey = LEFT(@c_OtherParms,10)
        
         SELECT @c_LimitString = ''  
         
         IF EXISTS (SELECT 1 FROM CODELKUP (NOLOCK) 
                        WHERE Listname = 'PKCODECFG' 
                        AND Code = 'NOFILTERLOT1'
                        AND Storerkey = @c_Storerkey
                        AND Long = 'nspPR_CH2'
                        AND ISNULL(Short,'') <> 'N'
                        AND (Code2 = @c_Facility OR ISNULL(Code2,'')='') --NJOW01
            AND NOT EXISTS (SELECT 1 
                            FROM CODELKUP (NOLOCK) 
                            WHERE Listname = 'HMORDTYPE'
                            AND Storerkey = @c_Storerkey
                            AND Code = @c_OrderType
                            AND Short = 'M')  --NJOW02
                    )                      
         BEGIN               
            SELECT @c_LimitString = ''                
         END           
         ELSE
         BEGIN               
            IF @c_lottable01 <> ' '  
            SELECT @c_LimitString =  dbo.fnc_RTrim(@c_LimitString) + " AND Lottable01= @c_lottable01 "  
         END
  
         IF @c_lottable02 <> ' '  
         SELECT @c_LimitString =  dbo.fnc_RTrim(@c_LimitString) + " AND lottable02= @c_lottable02 "  
  
         IF @c_lottable03 <> ' '  
         SELECT @c_LimitString =  dbo.fnc_RTrim(@c_LimitString) + " AND lottable03= @c_lottable03 "  
  
         IF @d_lottable04 IS NOT NULL AND @d_lottable04 <> '1900-01-01'  
         SELECT @c_LimitString =  dbo.fnc_RTrim(@c_LimitString) + " AND lottable04 = @d_lottable04 "  
  
         IF @d_lottable05 IS NOT NULL  AND @d_lottable05 <> '1900-01-01'  
         SELECT @c_LimitString =  dbo.fnc_RTrim(@c_LimitString) + " AND lottable05= @d_lottable05 "  
  
         IF LEFT(@c_lot,1) = '*'  
         BEGIN  
            select @n_shelflife = convert(int, substring(@c_lot, 2, 9))  
  
            IF @n_shelflife < 13  
            -- it's month  
            BEGIN  
               SELECT @c_Limitstring = dbo.fnc_RTrim(@c_LimitString) + " AND lottable04  > dateadd(month, @n_shelflife, getdate()) "  
            END  
         ELSE  
            BEGIN  
               SELECT @c_Limitstring = dbo.fnc_RTrim(@c_LimitString) + " AND lottable04  > DateAdd(day, @n_shelflife, getdate()) "  
            END  
         END  
         IF @b_debug = 1  
         BEGIN  
            SELECT 'c_limitstring', @c_limitstring  
         END  
         SELECT @c_StorerKey = RTrim(@c_StorerKey)  
         SELECT @c_Sku = RTrim(@c_SKU)  
         SELECT @c_SQL = '', @c_SQLParm = ''  
  
         SELECT @c_SQL = N' DECLARE PREALLOCATE_CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR  ' +  
         ' SELECT MIN(LOTXLOCXID.STORERKEY) , MIN(LOTXLOCXID.SKU), LOT.LOT,  ' +  
         ' QTYAVAILABLE = (SUM(LOTXLOCXID.QTY) - SUM(LOTXLOCXID.QTYALLOCATED) - SUM(LOTXLOCXID.QTYPICKED) - MIN(LOT.QtyPreallocated) ) ' +  
         ' FROM LOT (NOLOCK) , LOTATTRIBUTE (NOLOCK), LOTXLOCXID (NOLOCK), LOC (NOLOCK), ID (NOLOCK), SKUxLOC (NOLOCK) ' +  
         ' WHERE LOT.STORERKEY =  @c_storerkey   ' +  
         ' AND LOT.SKU = @c_sku '   +  
         ' AND LOT.STATUS = "OK" AND LOC.STATUS = "OK" AND ID.STATUS = "OK" And LOC.LocationFlag = "NONE" ' +  
         ' AND LOTXLOCXID.ID = ID.ID AND lot.lot = lotattribute.lot ' +  
         ' AND LOTXLOCXID.LOT = LOT.LOT AND LOTXLOCXID.LOT = LOTATTRIBUTE.LOT ' +  
         ' AND LOTXLOCXID.LOC = LOC.LOC ' +  
         ' AND LOC.FACILITY = @c_facility ' + @c_LimitString + ' ' +  
         ' AND SKUxLOC.StorerKey = LOTxLOCxID.StorerKey '  +  
         ' AND SKUxLOC.SKU = LOTxLOCxID.SKU  ' +  
         ' AND SKUxLOC.LOC = LOTxLOCxID.LOC  ' +  
         -- ' AND (SKUxLOC.LocationType IN ("PICK", "CASE") OR SKUxLOC.Locationtype NOT IN ("PICK","CASE")) ' +  
         -- Change by June 16.Feb.04 SOS18650 - Bug Fixes  
         -- ' GROUP BY LOT.LOT-- , SKUXLOC.Locationtype, SKUxLOC.LOC, LOTATTRIBUTE.Lottable04, LOTATTRIBUTE.LOTTABLE05, LOTATTRIBUTE.Lottable02 ' +  
         ' GROUP BY LOT.LOT, LOTATTRIBUTE.Lottable04, LOTATTRIBUTE.LOTTABLE05, LOTATTRIBUTE.Lottable02 ' +  
         ' HAVING (SUM(LOTXLOCXID.QTY) - SUM(LOTXLOCXID.QtyAllocated) - SUM(LOTXLOCXID.QTYPicked)- MIN(LOT.QtyPreAllocated) ) > 0 ' +  
         -- Change by June 16.Feb.04 SOS19999 - Bug Fixes (QtyAvail obtained is incorrect)  
         -- ' ORDER BY SKUXLOC.Locationtype desc, LOT.LOT , SKUxLOC.LOC, LOTATTRIBUTE.LOTTABLE04, LOTATTRIBUTE.LOTTABLE02, LOTATTRIBUTE.LOTTABLE05 ')  
         --              ' ORDER BY LOT.LOT, LOTATTRIBUTE.LOTTABLE04, LOTATTRIBUTE.LOTTABLE02, LOTATTRIBUTE.LOTTABLE05 ')  
         ' ORDER BY LOTATTRIBUTE.LOTTABLE02, LOTATTRIBUTE.LOTTABLE04, LOTATTRIBUTE.LOTTABLE05, (SUM(LOTXLOCXID.QTY) - SUM(LOTXLOCXID.QTYALLOCATED) - SUM(LOTXLOCXID.QTYPICKED) - MIN(LOT.QtyPreallocated) ) DESC '  
         -- we want pickface to come first, PICK, so we add locationtype desc sort Jeffrey  
  
         SET @c_SQLParm =  N'@c_facility   NVARCHAR(5),  @c_storerkey  NVARCHAR(15), @c_SKU        NVARCHAR(20), ' +     
                        '@c_Lottable01 NVARCHAR(18), @c_Lottable02 NVARCHAR(18), ' +  
                         '@c_Lottable03 NVARCHAR(18), @d_Lottable04 DATETIME,     @d_Lottable05 DATETIME,  ' +  
                        '@n_shelflife INT  '       
        
         EXEC sp_ExecuteSQL @c_SQL, @c_SQLParm, @c_facility, @c_storerkey, @c_SKU,  @c_Lottable01, @c_Lottable02, @c_Lottable03,  
                         @d_Lottable04, @d_Lottable05, @n_ShelfLife    
      END  
   END  
END  

GO
SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/              
/* Stored Procedure: nspPR_HKNK                                         */              
/* Creation Date:                                                       */              
/* Copyright: IDS                                                       */              
/* Written by:                                                          */              
/*                                                                      */              
/* Purpose:                                                             */        
/*                                                                      */              
/* Called By:                                                           */              
/*                                                                      */              
/* PVCS Version: 1.2                                                    */              
/*                                                                      */              
/* Version: 5.4                                                         */              
/*                                                                      */              
/* Data Modifications:                                                  */              
/*                                                                      */              
/* Updates:                                                             */              
/* Date         Author  Ver   Purposes                                  */          
/* 30-Sep-2013  YTWan   1.1   SOS#290780: TW - Converse - Preallocaton  */        
/*                            Strategy Modification.(Wan01)             */          
/* 18-AUG-2015  YTWan   1.2   SOS#350432 - Project Merlion - Allocation */        
/*                            Strategy (Wan02)                          */          
/* 28-JUL-2021  NJOW01  1.3   WMS-17577 allow filter empty lottable12   */    
/* 21-OCT-2021  RMTWL   1.4   JSM-27475 to allow allocation if UOMbase=0*/     
/*                                                                      */    
/************************************************************************/              
CREATE PROC [dbo].[nspPR_HKNK]         
    @c_storerkey NVARCHAR(15) ,          
    @c_sku NVARCHAR(20) ,          
    @c_lot NVARCHAR(10) ,          
    @c_lottable01 NVARCHAR(18) ,          
    @c_lottable02 NVARCHAR(18) ,          
    @c_lottable03 NVARCHAR(18) ,          
    @d_lottable04 datetime ,          
    @d_lottable05 datetime ,          
    @c_lottable06 NVARCHAR(30) ,  --(Wan02)          
    @c_lottable07 NVARCHAR(30) ,  --(Wan02)          
    @c_lottable08 NVARCHAR(30) ,  --(Wan02)        
    @c_lottable09 NVARCHAR(30) ,  --(Wan02)        
    @c_lottable10 NVARCHAR(30) ,  --(Wan02)        
    @c_lottable11 NVARCHAR(30) ,  --(Wan02)        
    @c_lottable12 NVARCHAR(30) ,  --(Wan02)        
    @d_lottable13 DATETIME ,      --(Wan02)        
    @d_lottable14 DATETIME ,      --(Wan02)           
    @d_lottable15 DATETIME ,      --(Wan02)        
    @c_uom NVARCHAR(10) ,        
    @c_facility NVARCHAR(10)  ,        
    @n_uombase int ,          
    @n_qtylefttofulfill int  -- new column        
   ,@c_OtherParms NVARCHAR(200) = NULL            --(Wan01)              
AS          
        
-- Added by Shong         
-- SOS# 10996 New Strategy For NIKE Hong Kong        
-- PreAllocation Strategy        
-- Order by LogicalLocation, Lottable05        
    SET NOCOUNT ON        
        
DECLARE @b_success int,@n_err int,@c_errmsg NVARCHAR(250),@b_debug int,          
        @c_manual NVARCHAR(1),        
        @c_LimitString NVARCHAR(4000), -- To limit the where clause based on the user input   --(Wan02)        
        @c_Limitstring1 NVARCHAR(255),          
        @n_shelflife int            
        
-- Added By SHONG 23.May.2002        
-- If the SKU.LOTTABLE02LABEL is BLANK, don't sort by Lottable02        
DECLARE @c_Lottable02Label NVARCHAR(20),        
        @c_SortOrder       NVARCHAR(255)        
      , @c_Orderkey        NVARCHAR(10)         --(Wan01)        
        
SELECT @b_success=0, @n_err=0, @c_errmsg="",@b_debug=0, @c_manual = 'N'          
        
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
        
--(Wan02) - START        
IF @d_lottable13 = '1900-01-01'        
BEGIN        
   SET @d_lottable13 = NULL        
END        
        
IF @d_lottable14 = '1900-01-01'        
BEGIN        
   SET @d_lottable14 = NULL        
END        
        
IF @d_lottable15 = '1900-01-01'        
BEGIN        
   SET @d_lottable15 = NULL        
End        
--(Wan02) - END        
        
IF @b_debug = 1          
BEGIN          
    SELECT "nspPR_HKTB : Before Lot Lookup ....."          
    SELECT '@c_lot'=@c_lot,'@c_lottable01'=@c_lottable01, '@c_lottable02'=@c_lottable02, '@c_lottable03'=@c_lottable03           
    SELECT '@d_lottable04' = @d_lottable04, '@d_lottable05' = @d_lottable05, '@c_manual' = @c_manual  , '@c_sku' = @c_sku        
    SELECT '@c_storerkey' = @c_storerkey, '@c_facility' = @c_facility        
END          
             
-- when any of the lottables is supplied, get the specific lot          
IF (@c_lottable01<>'' OR @c_lottable02<>'' OR @c_lottable03<>'' OR           
    @d_lottable04 IS NOT NULL OR @d_lottable05 IS NOT NULL)          
--(Wan02) - START        
   OR @c_lottable06<> '' OR @c_lottable07 <> '' OR @c_lottable08<> '' OR @c_lottable09 <> '' OR @c_lottable10 <> ''        
   OR @c_lottable11 <> '' OR @c_lottable12 <> ''        
   OR @d_lottable13 IS NOT NULL OR @d_lottable14 IS NOT NULL OR @d_lottable15 IS NOT NULL        
--(Wan02) - END        
BEGIN          
     select @c_manual = 'N'          
END          
          
IF @b_debug = 1          
BEGIN          
    SELECT "nspPR_HKTB : After Lot Lookup ....."          
    SELECT '@c_lot'=@c_lot,'@c_lottable01'=@c_lottable01, '@c_lottable02'=@c_lottable02, '@c_lottable03'=@c_lottable03        
    SELECT '@d_lottable04' = @d_lottable04, '@d_lottable05' = @d_lottable05, '@c_manual' = @c_manual          
    SELECT '@c_storerkey' = @c_storerkey        
END          
             
IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_lot)) IS NOT NULL AND LEFT(@c_lot, 1) <> '*'        
BEGIN               
      /* Lot specific candidate set */          
      DECLARE PREALLOCATE_CURSOR_CANDIDATES CURSOR FAST_FORWARD FOR           
      SELECT LOT.STORERKEY,LOT.SKU,LOT.LOT ,          
       QTYAVAILABLE = CASE WHEN ( LOT.QTY - LOT.QTYALLOCATED - LOT.QTYPICKED - LOT.QTYPREALLOCATED ) <  @n_UOMBase         
                      THEN ( LOT.QTY - LOT.QTYALLOCATED - LOT.QTYPICKED - LOT.QTYPREALLOCATED  )         
                   WHEN ( LOT.QTY - LOT.QTYALLOCATED - LOT.QTYPICKED - LOT.QTYPREALLOCATED  ) % @n_UOMBase = 0         
                      THEN ( LOT.QTY - LOT.QTYALLOCATED - LOT.QTYPICKED - LOT.QTYPREALLOCATED  )         
                   ELSE        
                      ( LOT.QTY - LOT.QTYALLOCATED - LOT.QTYPICKED - LOT.QTYPREALLOCATED )         
                      -  ( LOT.QTY - LOT.QTYALLOCATED - LOT.QTYPICKED - LOT.QTYPREALLOCATED ) % @n_UOMBase         
                   END         
      FROM LOT (NOLOCK), LOTATTRIBUTE (NOLOCK), LOTXLOCXID (NOLOCK), LOC (NOLOCK)         
      WHERE LOT.LOT = LOTATTRIBUTE.LOT          
      AND LOTXLOCXID.Lot = LOT.LOT        
      AND LOTXLOCXID.LOT = LOTATTRIBUTE.LOT        
      AND LOTXLOCXID.LOC = LOC.LOC        
      AND LOC.Facility = @c_facility        
      AND LOT.LOT = @c_lot        
        
    IF @b_debug = 1        
    BEGIN        
        SELECT ' Lot not null'        
        SELECT LOT.STORERKEY,LOT.SKU,LOT.LOT ,          
               QTYAVAILABLE = (LOT.QTY - LOT.QTYALLOCATED - LOT.QTYPICKED - LOT.QTYPREALLOCATED)         
         FROM LOT (nolock), LOTATTRIBUTE (Nolock)         
         WHERE LOT.LOT = LOTATTRIBUTE.LOT AND LOT.LOT = @c_lot          
         -- ORDER BY LOTATTRIBUTE.LOTTABLE02 DESC, LOTATTRIBUTE.Lottable04 ASC             
    END        
END          
ELSE         
BEGIN                    
/* Everything Else when no lottable supplied */          
IF @c_manual = 'N'           
BEGIN          
   SELECT @c_LimitString = ''          
   SELECT @c_SortOrder = " ORDER BY LOC.LogicalLocation ASC, LOTATTRIBUTE.Lottable05 ASC "        
        
   --(Wan01) -- START        
   IF ISNULL(RTRIM(@c_OtherParms),'') <> ''        
   BEGIN        
      SET @c_Orderkey = LEFT(@c_OtherParms,10)        
        
      IF EXISTS ( SELECT 1         
                  FROM ORDERS   WITH (NOLOCK)        
                  JOIN CODELKUP WITH (NOLOCK) ON (CODELKUP.ListName = 'nspPR_HKNK')        
                                              AND(CODELKUP.Code = 'LIFO4EverGreen')        
                                              AND(CODELKUP.Storerkey = ORDERS.Storerkey)        
                  WHERE ORDERS.Orderkey = @c_Orderkey        
                  AND   ORDERS.Type    <> CODELKUP.UDF01)        
      BEGIN        
         SET @c_SortOrder = ' ORDER BY LOC.LogicalLocation ASC, LOTATTRIBUTE.Lottable05 DESC'        
      END        
 END        
   --(Wan01) - END        
        
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
              
   --(Wan02) - START        
   IF RTRIM(@c_Lottable06) <> '' AND @c_Lottable06 IS NOT NULL        
   BEGIN        
      SET @c_LimitString = @c_LimitString + ' AND Lottable06 = N''' + RTRIM(@c_Lottable06) + ''''         
   END           
        
   IF RTRIM(@c_Lottable07) <> '' AND @c_Lottable07 IS NOT NULL        
   BEGIN        
      SET @c_LimitString = @c_LimitString + ' AND Lottable07 = N''' + RTRIM(@c_Lottable07) + ''''         
   END           
        
   IF RTRIM(@c_Lottable08) <> '' AND @c_Lottable08 IS NOT NULL        
   BEGIN        
      SET @c_LimitString = @c_LimitString + ' AND Lottable08 = N''' + RTRIM(@c_Lottable08) + ''''         
   END           
        
   IF RTRIM(@c_Lottable09) <> '' AND @c_Lottable09 IS NOT NULL        
   BEGIN        
      SET @c_LimitString = @c_LimitString + ' AND Lottable09 = N''' + RTRIM(@c_Lottable09) + ''''         
   END           
        
   IF RTRIM(@c_Lottable10) <> '' AND @c_Lottable10 IS NOT NULL        
   BEGIN        
      SET @c_LimitString = @c_LimitString + ' AND Lottable10 = N''' + RTRIM(@c_Lottable10) + ''''         
   END           
        
   IF RTRIM(@c_Lottable11) <> '' AND @c_Lottable11 IS NOT NULL        
   BEGIN        
      SET @c_LimitString = @c_LimitString + ' AND Lottable11 = N''' + RTRIM(@c_Lottable11) + ''''         
   END           
   ELSE IF EXISTS (SELECT 1 FROM CODELKUP CL (NOLOCK)  --NJOW01        
                           WHERE CL.Storerkey = @c_Storerkey        
                           AND CL.Code = 'FILTEREMPTYLOT11'        
          AND CL.Listname = 'PKCODECFG'        
                           AND CL.Long = 'nspPR_HKNK'        
                           AND ISNULL(CL.Short,'') <> 'N')         
   BEGIN                    
      SET @c_LimitString = @c_LimitString +  + ' AND LOTTABLE11 = '''' '        
   END        
        
   IF RTRIM(@c_Lottable12) <> '' AND @c_Lottable12 IS NOT NULL        
   BEGIN        
      SET @c_LimitString = @c_LimitString + ' AND Lottable12 = N''' + RTRIM(@c_Lottable12) + ''''      
   END        
   ELSE IF EXISTS (SELECT 1 FROM CODELKUP CL (NOLOCK)  --NJOW01        
                           WHERE CL.Storerkey = @c_Storerkey        
                           AND CL.Code = 'FILTEREMPTYLOT12'        
                           AND CL.Listname = 'PKCODECFG'        
                           AND CL.Long = 'nspPR_HKNK'        
                           AND ISNULL(CL.Short,'') <> 'N')         
   BEGIN                    
      SET @c_LimitString = @c_LimitString +  + ' AND LOTTABLE12 = '''' '        
   END        
        
   IF @d_Lottable13 <> '1900-01-01' AND @d_Lottable13 IS NOT NULL         
   BEGIN        
      SET @c_LimitString = @c_LimitString + ' AND Lottable13 = N''' + RTRIM(CONVERT( NVARCHAR(20), @d_Lottable13, 106)) + ''''        
   END        
        
   IF @d_Lottable14 <> '1900-01-01' AND @d_Lottable14 IS NOT NULL         
   BEGIN        
      SET @c_LimitString = @c_LimitString + ' AND Lottable14 = N''' + RTRIM(CONVERT( NVARCHAR(20), @d_Lottable14, 106)) + ''''        
   END        
        
   IF @d_Lottable15 <> '1900-01-01' AND @d_Lottable15 IS NOT NULL        
   BEGIN        
      SET @c_LimitString = @c_LimitString + ' AND Lottable15 = N''' + RTRIM(CONVERT( NVARCHAR(20), @d_Lottable15, 106)) + ''''        
   END        
        
   --(Wan02) - END        
        
   IF LEFT(@c_lot,1) = '*'        
   BEGIN        
      select @n_shelflife = convert(int, substring(@c_lot, 2, 9))        
      IF @n_shelflife < 13  -- it's month        
      BEGIN        
          SELECT @c_Limitstring = dbo.fnc_RTrim(@c_LimitString) + " AND convert(char(8),Lottable04, 112) >= N'"  + convert(char(8), dateadd(month, @n_shelflife, getdate()), 112) + "'"        
      END        
       ELSE BEGIN        
          SELECT @c_Limitstring = dbo.fnc_RTrim(@c_LimitString) + " AND convert(char(8),Lottable04, 112) >= N'" + convert(char(8), DateAdd(day, @n_shelflife, getdate()), 112) + "'"        
      END        
   END        
        
 --(rmtwl 20211022)    
    IF (@c_uombase='0')        
    BEGIN       
        EXEC (" DECLARE PREALLOCATE_CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR " +          
        " SELECT null,null,null,null " )      
        RETURN      
    END      
        
       
   EXEC (" DECLARE PREALLOCATE_CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR " +          
        " SELECT MIN(LOTXLOCXID.STORERKEY) , MIN(LOTXLOCXID.SKU), LOT.LOT," +          
        " QTYAVAILABLE = CASE WHEN ( SUM(LOTXLOCXID.QTY) - SUM(LOTXLOCXID.QTYALLOCATED) - " +        
                        " SUM(LOTXLOCXID.QTYPICKED) - MIN(LOT.QtyPreallocated) ) < " + @c_UOMBase +        
                  " THEN ( SUM(LOTXLOCXID.QTY) - SUM(LOTXLOCXID.QTYALLOCATED) " +        
                       " - SUM(LOTXLOCXID.QTYPICKED) - MIN(LOT.QtyPreallocated) ) " +        
                  " WHEN ( SUM(LOTXLOCXID.QTY) - SUM(LOTXLOCXID.QTYALLOCATED) - " +        
                        " SUM(LOTXLOCXID.QTYPICKED) - MIN(LOT.QtyPreallocated) ) % " + @c_UOMBase + " = 0 " +        
                  " THEN ( SUM(LOTXLOCXID.QTY) - SUM(LOTXLOCXID.QTYALLOCATED) " +        
                        " - SUM(LOTXLOCXID.QTYPICKED) - MIN(LOT.QtyPreallocated) ) " +        
                  " ELSE " +        
                  " ( SUM(LOTXLOCXID.QTY) - SUM(LOTXLOCXID.QTYALLOCATED) - SUM(LOTXLOCXID.QTYPICKED) - MIN(LOT.QtyPreallocated) ) " +        
                  " -  ( SUM(LOTXLOCXID.QTY) - SUM(LOTXLOCXID.QTYALLOCATED) - SUM(LOTXLOCXID.QTYPICKED) - MIN(LOT.QtyPreallocated) ) % " + @c_UOMBase + " " +         
                  " END " +        
        " FROM LOT (NOLOCK) , LOTATTRIBUTE (NOLOCK), LOTXLOCXID (NOLOCK), LOC (NOLOCK), ID (NOLOCK)" +          
        " WHERE LOTXLOCXID.STORERKEY = N'" + @c_storerkey + "'" + " AND LOTXLOCXID.SKU = N'" + @c_sku + "' " +          
        " AND LOT.STATUS = 'OK' AND LOC.STATUS = 'OK' AND ID.STATUS = 'OK'  And LOC.LocationFlag = 'NONE' " +          
        " AND lot.lot = lotattribute.lot AND LOTXLOCXID.LOT = LOT.LOT AND LOTXLOCXID.ID = ID.ID AND LOTXLOCXID.LOT = LOTATTRIBUTE.LOT AND LOTXLOCXID.LOC = LOC.LOC " +        
        " AND LOC.FACILITY = N'" + @c_facility + "'"  + @c_LimitString + " " +           
        " GROUP BY LOT.LOT , LOTATTRIBUTE.Lottable04, LOTATTRIBUTE.Lottable02, LOTATTRIBUTE.Lottable05, LOC.LogicalLocation " +         
        " HAVING (SUM(LOTXLOCXID.QTY) - SUM(LOTXLOCXID.QtyAllocated) - SUM(LOTXLOCXID.QTYPicked)- MIN(LOT.QtyPreAllocated) ) >= " + @c_UOMBase + " " +        
        @c_SortOrder)        
END -- Manual = 'N'        
END 

GO
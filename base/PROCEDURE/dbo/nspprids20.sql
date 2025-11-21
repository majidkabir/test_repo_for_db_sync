SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store Procedure:  nspPRIDS20                                         */
/* Creation Date: -                                                     */
/* Copyright: IDS                                                       */
/* Written by: -                                                        */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Input Parameters:                                                    */
/* Output Parameters:                                                   */
/*                                                                      */
/* Called By:  nspPreallocateOrderProcessing                            */
/*                                                                      */
/* PVCS Version: 1.3                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver.  Purposes                                  */
/* 18-AUG-2015 YTWan    1.1   SOS#350432 - Project Merlion -            */
/*                              Allocation Strategy (Wan01)             */
/* 2024-07-02  Wan02    1.2   UWP-21429-Mattel Overallocation Enhancement*/
/*                            -Match LOC.HostWHCode at Preallocate      */
/* 2024-07-05  Wan03    1.3   UWP-21429-Mattel Overallocation Enhancement*/
/*                            - Minus QtyReplen when find stock         */
/************************************************************************/

CREATE   PROC nspPRIDS20
@c_storerkey    NVARCHAR(15) ,
@c_sku          NVARCHAR(20) ,
@c_lot          NVARCHAR(10) ,
@c_lottable01   NVARCHAR(18) ,
@c_lottable02   NVARCHAR(18) ,
@c_lottable03   NVARCHAR(18) ,
@d_lottable04   datetime ,
@d_lottable05   datetime ,
@c_lottable06   NVARCHAR(30) ,  --(Wan01)  
@c_lottable07   NVARCHAR(30) ,  --(Wan01)  
@c_lottable08   NVARCHAR(30) ,  --(Wan01)
@c_lottable09   NVARCHAR(30) ,  --(Wan01)
@c_lottable10   NVARCHAR(30) ,  --(Wan01)
@c_lottable11   NVARCHAR(30) ,  --(Wan01)
@c_lottable12   NVARCHAR(30) ,  --(Wan01)
@d_lottable13   DATETIME ,      --(Wan01)
@d_lottable14   DATETIME ,      --(Wan01)   
@d_lottable15   DATETIME ,      --(Wan01)
@c_uom          NVARCHAR(10) ,
@c_facility NVARCHAR(10)  ,  -- added By Ricky for IDSV5
@n_uombase        int ,
@n_qtylefttofulfill int
,@c_OtherParms  NVARCHAR(200)=''--(Wan01)
AS
BEGIN
   DECLARE @c_Condition             NVARCHAR(4000) --(Wan01)
         , @c_OrderBy               NVARCHAR(550)  --(Wan01)
         , @c_CLKCondition          NVARCHAR(4000)= ''                              --(Wan02)
         , @c_AllocateStrategykey   NVARCHAR(10)  = ''                              --(Wan02)
         , @c_SQL                   NVARCHAR(MAX) = ''                              --(Wan02)               
         , @c_SQLParms              NVARCHAR(4000)= ''                              --(Wan02) 
         , @c_AllocQtyReplenFlag    NCHAR(1)      = 'N'                             --(Wan03)

   DECLARE @TMP_CODELKUP TABLE (                                                    --(Wan02)-START
           [LISTNAME]      [nvarchar](10)   NOT NULL DEFAULT('') 
         , [Code]          [nvarchar](30)   NOT NULL DEFAULT('') 
         , [Description]   [nvarchar](250)  NULL 
         , [Short]         [nvarchar](10)   NULL 
         , [Long]          [nvarchar](250)  NULL 
         , [Notes]         [nvarchar](4000) NULL 
         , [Notes2]        [nvarchar](4000) NULL 
         , [Storerkey]     [nvarchar](50)   NOT NULL  DEFAULT('') 
         , [UDF01]         [nvarchar](60)   NOT NULL  DEFAULT('')
         , [UDF02]         [nvarchar](60)   NOT NULL  DEFAULT('')
         , [UDF03]         [nvarchar](60)   NOT NULL  DEFAULT('')
         , [UDF04]         [nvarchar](60)   NOT NULL  DEFAULT('')
         , [UDF05]         [nvarchar](60)   NOT NULL  DEFAULT('')
         , [code2]         [nvarchar](30)   NOT NULL  DEFAULT('')
       )

   SELECT @c_AllocateStrategykey = STRATEGY.AllocateStrategykey
   FROM SKU (NOLOCK)
   JOIN STRATEGY (NOLOCK) ON SKU.Strategykey = STRATEGY.Strategykey
   WHERE SKU.Storerkey = @c_Storerkey
   AND SKU.Sku = @c_Sku
   
   INSERT INTO @TMP_CODELKUP (Listname, Code, Description, Short, Long, Notes, Notes2, Storerkey, UDF01, UDF02, UDF03, UDF04, UDF05, Code2)
   SELECT CODELKUP.Listname,
          CODELKUP.Code,
          CODELKUP.Description,
          CODELKUP.Short,
          CODELKUP.Long,
          CODELKUP.Notes,
          CODELKUP.Notes2,
          CODELKUP.Storerkey,
          CODELKUP.UDF01,
          CODELKUP.UDF02,
          CODELKUP.UDF03,
          CODELKUP.UDF04,
          CODELKUP.UDF05,
          CODELKUP.Code2
   FROM CODELKUP (NOLOCK)
   WHERE CODELKUP.Listname = 'nspPRIDS20'
   AND CODELKUP.Storerkey = CASE WHEN CODELKUP.Short = @c_AllocateStrategykey AND CODELKUP.Storerkey = '' THEN CODELKUP.Storerkey ELSE @c_Storerkey END --if setup short and no setup storer ignore storer otherwise by storer.
   AND CODELKUP.Short IN  ( CASE WHEN CODELKUP.Short NOT IN (NULL,'') THEN @c_AllocateStrategykey ELSE CODELKUP.Short END ) --if short setup must match Allocate strategykey
   AND Code2 IN (@c_UOM,'')

   SELECT TOP 1 @c_CLKCondition = ISNULL(Notes,'')
   FROM @TMP_CODELKUP
   WHERE Code = 'CONDITION'   --retrieve addition conditions
   AND Code2 IN (@c_UOM,'')   --if defined uom in code2 only apply for the specific strategy uom
   ORDER BY CASE WHEN Code2 = @c_UOM THEN 0 ELSE 1 END --consider matched uom first

   IF @c_CLKCondition <> '' AND LEFT(LTRIM(@c_CLKCondition),3) <> 'AND'
   BEGIN
      SET @c_CLKCondition = ' AND ' + RTRIM(LTRIM(@c_CLKCondition))
   END

   SELECT TOP 1 @c_AllocQtyReplenFlag = ISNULL(UDF01,'')                            --(Wan03)MINUS QtyReplen If SET 'Y'  
   FROM @TMP_CODELKUP  
   WHERE Code = 'ALLOCATEQTYREPLEN' 
   AND Code2 IN (@c_UOM,'')
   ORDER BY CASE WHEN Code2 = @c_UOM THEN 0 ELSE 1 END  

   IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_lot)) IS NOT NULL
   BEGIN
      DECLARE  PREALLOCATE_CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR
      SELECT LOT.STORERKEY, LOT.SKU, LOT.LOT,
      QTYAVAILABLE = (LOT.QTY - LOT.QTYALLOCATED - LOT.QTYPICKED - LOT.QTYPREALLOCATED)
      FROM  LOT (nolock), LOTATTRIBUTE (nolock), LOTXLOCXID (NOLOCK), LOC (NOLOCK)
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
      IF dbo.fnc_RTrim(dbo.fnc_LTrim(@c_Lottable01)) <> '' AND @c_Lottable01 IS NOT NULL
      BEGIN
         SELECT @c_Condition = ' AND LOTTABLE01 = N''' + dbo.fnc_RTrim(dbo.fnc_LTrim(@c_Lottable01)) + ''' '
      END
      IF dbo.fnc_RTrim(dbo.fnc_LTrim(@c_Lottable02)) <> '' AND @c_Lottable02 IS NOT NULL
      BEGIN
         SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + ' AND LOTTABLE02 = N''' + dbo.fnc_RTrim(dbo.fnc_LTrim(@c_Lottable02)) + ''' '
      END
      IF dbo.fnc_RTrim(dbo.fnc_LTrim(@c_Lottable03)) <> '' AND @c_Lottable03 IS NOT NULL
      BEGIN
         SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + ' AND LOTTABLE03 = N''' + dbo.fnc_RTrim(dbo.fnc_LTrim(@c_Lottable03)) + ''' '
      END
      IF CONVERT(char(10), @d_Lottable04, 103) <> '01/01/1900'
      BEGIN
         SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + ' AND LOTTABLE04 = N''' + dbo.fnc_RTrim(CONVERT( NVARCHAR(20), @d_Lottable04, 106)) + ''' '
      END
      IF CONVERT(char(10), @d_Lottable05, 103) <> '01/01/1900'
      BEGIN
         SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + ' AND LOTTABLE05 = N''' + dbo.fnc_RTrim(CONVERT( NVARCHAR(20), @d_Lottable05, 106)) + ''' '
      END
      --(Wan01) - START
      IF RTRIM(@c_Lottable06) <> '' AND @c_Lottable06 IS NOT NULL
      BEGIN
         SET @c_Condition = @c_Condition + ' AND LOTATTRIBUTE.Lottable06 = N''' + RTRIM(@c_Lottable06) + '''' 
      END   

      IF RTRIM(@c_Lottable07) <> '' AND @c_Lottable07 IS NOT NULL
      BEGIN
         SET @c_Condition = @c_Condition + ' AND LOTATTRIBUTE.Lottable07 = N''' + RTRIM(@c_Lottable07) + '''' 
      END   

      IF RTRIM(@c_Lottable08) <> '' AND @c_Lottable08 IS NOT NULL
      BEGIN
         SET @c_Condition = @c_Condition + ' AND LOTATTRIBUTE.Lottable08 = N''' + RTRIM(@c_Lottable08) + '''' 
      END   

      IF RTRIM(@c_Lottable09) <> '' AND @c_Lottable09 IS NOT NULL
      BEGIN
         SET @c_Condition = @c_Condition + ' AND LOTATTRIBUTE.Lottable09 = N''' + RTRIM(@c_Lottable09) + '''' 
      END   

      IF RTRIM(@c_Lottable10) <> '' AND @c_Lottable10 IS NOT NULL
      BEGIN
         SET @c_Condition = @c_Condition + ' AND LOTATTRIBUTE.Lottable10 = N''' + RTRIM(@c_Lottable10) + '''' 
      END   

      IF RTRIM(@c_Lottable11) <> '' AND @c_Lottable11 IS NOT NULL
      BEGIN
         SET @c_Condition = @c_Condition + ' AND LOTATTRIBUTE.Lottable11 = N''' + RTRIM(@c_Lottable11) + '''' 
      END   

      IF RTRIM(@c_Lottable12) <> '' AND @c_Lottable12 IS NOT NULL
      BEGIN
         SET @c_Condition = @c_Condition + ' AND LOTATTRIBUTE.Lottable12 = N''' + RTRIM(@c_Lottable12) + '''' 
      END  

      IF CONVERT(CHAR(10), @d_Lottable13, 103) <> '01/01/1900'
      BEGIN
         SET @c_Condition = @c_Condition + ' AND LOTATTRIBUTE.Lottable13 = N''' + RTRIM(CONVERT( NVARCHAR(20), @d_Lottable13, 106)) + ''''
      END

      IF CONVERT(CHAR(10), @d_Lottable14, 103) <> '01/01/1900'
      BEGIN
         SET @c_Condition = @c_Condition + ' AND LOTATTRIBUTE.Lottable14 = N''' + RTRIM(CONVERT( NVARCHAR(20), @d_Lottable14, 106)) + ''''
      END

      IF CONVERT(CHAR(10), @d_Lottable15, 103) <> '01/01/1900'
      BEGIN
         SET @c_Condition = @c_Condition + ' AND LOTATTRIBUTE.Lottable15 = N''' + RTRIM(CONVERT( NVARCHAR(20), @d_Lottable15, 106)) + ''''
      END
      -- SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + " ORDER BY LOTATTRIBUTE.LOTTABLE04, LOTATTRIBUTE.LOTTABLE05 "
      SET @c_OrderBy = ' ORDER BY LOTATTRIBUTE.LOTTABLE04, LOTATTRIBUTE.LOTTABLE05 '
      --(Wan01) - END

      -- Start : Changed by June 24.Feb.2004 SOS20265
      /*
      EXEC ( 'DECLARE PREALLOCATE_CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR '
      + 'SELECT LOT.STORERKEY, LOT.SKU, LOT.LOT, '
      + 'QTYAVAILABLE = (LOT.QTY - LOT.QTYALLOCATED - LOT.QTYPICKED - LOT.QTYPREALLOCATED - QTYONHOLD) '
      + 'FROM LOT (nolock), LOTATTRIBUTE (nolock), LOTXLOCXID (NOLOCK), LOC (NOLOCK) '
      + 'WHERE LOT.STORERKEY = "' + @c_storerkey  + '" '
      + 'AND LOT.SKU = "' + @c_sku + '" '
      + 'AND LOT.STATUS = "OK" '
      + 'AND (LOT.QTY - LOT.QTYALLOCATED - LOT.QTYPICKED - LOT.QTYPREALLOCATED - QTYONHOLD) > 0 '
      + 'AND LOT.LOT = LOTATTRIBUTE.LOT '
      + 'AND LOTXLOCXID.Lot = LOT.LOT '
      + 'AND LOTXLOCXID.LOT = LOTATTRIBUTE.LOT '
      + 'AND LOTXLOCXID.LOC = LOC.LOC '
      + 'AND LOC.Facility = "' + @c_facility + '" '
      + @c_Condition )
      */
      --(Wan02) - START - Use Parameter instead of concatenate string
      SET @c_SQL = N'DECLARE PREALLOCATE_CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR '
      + 'SELECT LOT.STORERKEY, LOT.SKU, LOT.LOT, '
      + 'QTYAVAILABLE = SUM(LOTXLOCXID.QTY - LOTXLOCXID.QTYALLOCATED - LOTXLOCXID.QTYPICKED) - MIN(ISNULL(P.QTYPREALLOCATED, 0)) '
      + 'FROM LOT (NOLOCK) '
      + 'INNER JOIN LOTXLOCXID (NOLOCK) ON LOT.LOT = LOTXLOCXID.LOT '
      + 'INNER JOIN LOC (NOLOCK) ON LOTXLOCXID.LOC = LOC.LOC '
      + 'INNER JOIN LOTATTRIBUTE (NOLOCK) ON LOTXLOCXID.Lot = LOTATTRIBUTE.Lot '
      + 'LEFT OUTER JOIN (SELECT p.Lot, ORDERS.Facility, QtyPreallocated = SUM(p.Qty) '
      + '                  FROM   PreallocatePickDetail p (NOLOCK), ORDERS (NOLOCK) '
      + '                  WHERE  p.Orderkey = ORDERS.Orderkey '
      + '                  AND    p.Storerkey = @c_Storerkey '
      + '                  AND    p.SKU = @c_Sku '
      + '                  GROUP BY p.Lot, ORDERS.Facility) P ON LOTXLOCXID.Lot = p.Lot AND p.Facility = LOC.Facility '
      + 'WHERE LOT.STORERKEY = @c_storerkey '
      + 'AND LOT.SKU = @c_Sku '
      + 'AND LOC.Facility = @c_facility '
      + @c_Condition + ' '
      + @c_CLKCondition + ' '                                                       --(Wan02)
      + 'AND LOT.STATUS = ''OK'' AND LOC.STATUS = ''OK'' AND LOC.LOCATIONFLAG = ''NONE'' '
      + 'GROUP BY LOT.STORERKEY, LOT.SKU, LOT.LOT, LOTATTRIBUTE.LOTTABLE01, LOTATTRIBUTE.LOTTABLE02, LOTATTRIBUTE.LOTTABLE03, LOTATTRIBUTE.LOTTABLE04, LOTATTRIBUTE.LOTTABLE05 '
      --+ 'HAVING SUM(LOTXLOCXID.QTY - LOTXLOCXID.QTYALLOCATED - LOTXLOCXID.QTYPICKED) - MIN(ISNULL(P.QTYPREALLOCATED, 0)) > 0 '
      + CASE WHEN @c_AllocQtyReplenFlag ='Y' THEN                                   --(Wan03) - START
        'HAVING SUM(LOTXLOCXID.QTY - LOTXLOCXID.QTYALLOCATED - LOTXLOCXID.QTYPICKED 
                  - LOTXLOCXID.QTYREPLEN) - MIN(ISNULL(P.QTYPREALLOCATED, 0)) > 0 '
             ELSE
        'HAVING SUM(LOTXLOCXID.QTY - LOTXLOCXID.QTYALLOCATED - LOTXLOCXID.QTYPICKED) - MIN(ISNULL(P.QTYPREALLOCATED, 0)) > 0 '
             END                                                                    --(Wan03) - END 
      + @c_OrderBy

   SET @c_SQLParms = N'@c_Storerkey NVARCHAR(15)'
                   + ',@c_Sku       NVARCHAR(20)'
                   + ',@c_facility  NVARCHAR(5)'

   EXEC sp_executesql @c_SQL  
                     ,@c_SQLParms
                     ,@c_Storerkey
                     ,@c_Sku
                     ,@c_facility     
     
      -- End : Changed by June 24.Feb.2004 SOS20265
   END
END

GO
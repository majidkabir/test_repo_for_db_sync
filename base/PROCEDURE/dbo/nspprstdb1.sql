SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/      
/* Stored Procedure: nspPRstdB1                                         */      
/* Creation Date:                                                       */      
/* Copyright: IDS                                                       */      
/* Written by:                                                          */      
/*                                                                      */      
/* Purpose:                                                             */
/*                                                                      */      
/* Called By:                                                           */      
/*                                                                      */      
/* PVCS Version: 1.1                                                    */      
/*                                                                      */      
/* Version: 5.4                                                         */      
/*                                                                      */      
/* Data Modifications:                                                  */      
/*                                                                      */      
/* Updates:                                                             */      
/* Date        Author   Ver   Purposes                                  */  
/* 18-AUG-2015 YTWan    1.1   SOS#350432 - Project Merlion - Allocation */
/*                            Strategy (Wan01)                          */  
/* 01-JUN-2018 NJOW01   1.2   WMS-5158 Prestige allocate shelflife by   */
/*                            consignee                                 */  
/* 06-Aug-2018 NJOW02   1.3   Fix FIFO Shelflife                        */
/* 09-Nov-2018 NJOW03   1.4   WMS-6892 change FIFO shelflife filter     */
/* 24-Jul-2019 NJOW04   1.5   WMS-9509 SG Prestige lottable03 filter    */
/* 28-May-2020 NJOW05   1.6   WMS-13544 Change FIFO to use lottable04   */
/* 15-Dec-2021 NJOW06   1.7   WMS-18573 Lottable07 filtring condition   */
/* 15-Dec-2021 NJOW06   1.7   DEVOPS combine script                     */
/* 21-Mar-2024 USH022   1.7   ORDERKey datatype changed                 */
/************************************************************************/  

CREATE   PROC  nspPRstdB1  -- Rename from IDSSG:nspPRstd01
@c_storerkey NVARCHAR(15) ,
@c_sku NVARCHAR(20) ,
@c_lot NVARCHAR(10) ,
@c_lottable01 NVARCHAR(18) ,
@c_lottable02 NVARCHAR(18) ,
@c_lottable03 NVARCHAR(18) ,
@d_lottable04 datetime,
@d_lottable05 datetime,
@c_lottable06 NVARCHAR(30) ,  --(Wan01)  
@c_lottable07 NVARCHAR(30) ,  --(Wan01)  
@c_lottable08 NVARCHAR(30) ,  --(Wan01)
@c_lottable09 NVARCHAR(30) ,  --(Wan01)
@c_lottable10 NVARCHAR(30) ,  --(Wan01)
@c_lottable11 NVARCHAR(30) ,  --(Wan01)
@c_lottable12 NVARCHAR(30) ,  --(Wan01)
@d_lottable13 DATETIME ,      --(Wan01)
@d_lottable14 DATETIME ,      --(Wan01)   
@d_lottable15 DATETIME ,      --(Wan01)
@c_uom NVARCHAR(10) ,
@c_facility NVARCHAR(10)  ,   -- added By Ricky for IDSV5
@n_uombase int ,
@n_qtylefttofulfill int,
@c_OtherParms NVARCHAR(200) = ''  --Orderinfo4PreAllocation   
AS
BEGIN

DECLARE @n_StorerMinShelfLife int
      , @c_Condition          NVARCHAR(4000) --(Wan01)
      , @c_SQLStatement       NVARCHAR(4000) --(Wan01)
      , @n_ConMinShelfLife    INT --NJOW01
      , @c_Orderkey           NVARCHAR(20) --USH022 --INT --NJOW01
      , @c_Strategykey        NVARCHAR(10) --NJOW01
      , @n_SkuOGShelfLife       INT --NJOW03

SELECT @c_Orderkey = LEFT(@c_OtherParms,10) --NJOW01

IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_lot)) IS NOT NULL
BEGIN

/* Get Storer Minimum Shelf Life */

SELECT @n_StorerMinShelfLife = ((Sku.Shelflife * Storer.MinShelflife/100) * -1)
FROM Sku (nolock), Storer (nolock), Lot (nolock)
WHERE Lot.Lot = @c_lot
AND Lot.Sku = Sku.Sku
AND Sku.Storerkey = Storer.Storerkey

DECLARE  PREALLOCATE_CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR 
SELECT LOT.STORERKEY,LOT.SKU,LOT.LOT ,
QTYAVAILABLE = (LOT.QTY - LOT.QTYALLOCATED - LOT.QTYPICKED - LOT.QTYPREALLOCATED)
FROM LOT (Nolock), Lotattribute (Nolock), LOTXLOCXID (NOLOCK), LOC (NOLOCK) 
WHERE LOT.LOT = LOTATTRIBUTE.LOT  
AND LOTXLOCXID.Lot = LOT.LOT
AND LOTXLOCXID.LOT = LOTATTRIBUTE.LOT
AND LOTXLOCXID.LOC = LOC.LOC
AND LOC.Facility = @c_facility
AND LOT.LOT = @c_lot 
-- AND DateAdd(Day, @n_StorerMinShelfLife, Lotattribute.Lottable04) > GetDate() 
ORDER BY Lotattribute.Lottable04, Lotattribute.Lottable05

END
ELSE
BEGIN
/* Get Storer Minimum Shelf Life */
--    SELECT @n_StorerMinShelfLife = ((Sku.Shelflife * Storer.MinShelflife/100) * -1)
--    FROM Sku (nolock), Storer (nolock)
--    WHERE Sku.Sku = @c_sku
--    AND Sku.Storerkey = @c_storerkey   
--    AND Sku.Storerkey = Storer.Storerkey
-- 
--    IF @n_StorerMinShelfLife IS NULL
--       SELECT @n_StorerMinShelfLife = 0

   --(Wan01) - START
   SET @c_Condition = ''

   IF RTRIM(@c_Lottable01) <> '' AND @c_Lottable01 IS NOT NULL
   BEGIN
      SET @c_Condition = @c_Condition + ' AND LOTATTRIBUTE.Lottable01 = N''' + RTRIM(@c_Lottable01) + '''' 
   END   

   IF RTRIM(@c_Lottable02) <> '' AND @c_Lottable02 IS NOT NULL
   BEGIN
      SET @c_Condition = @c_Condition + ' AND LOTATTRIBUTE.Lottable02 = N''' + RTRIM(@c_Lottable02) + '''' 
   END   

   IF RTRIM(@c_Lottable03) <> '' AND @c_Lottable03 IS NOT NULL
   BEGIN
      SET @c_Condition = @c_Condition + ' AND LOTATTRIBUTE.Lottable03 = N''' + RTRIM(@c_Lottable03) + '''' 
   END   
   ELSE IF @c_Storerkey = 'PRESTIGE'  --NJOW04
   BEGIN
      SET @c_Condition = @c_Condition + ' AND LOTATTRIBUTE.Lottable03 = ''OK'' '              
   END

   IF CONVERT(CHAR(10), @d_Lottable04, 103) <> '01/01/1900'
   BEGIN
      SET @c_Condition = @c_Condition + ' AND LOTATTRIBUTE.Lottable04 = N''' + RTRIM(CONVERT( NVARCHAR(20), @d_Lottable04, 106)) + ''''
   END

   --NJOW01 Strart
   SELECT @c_Strategykey = Strategykey,
          @n_SkuOGShelfLife = CASE WHEN ISNUMERIC(susr2) = 1 THEN CAST(Susr2 AS INT) ELSE 0 END --NJOW03 
   FROM  SKU (NOLOCK)
   WHERE SKU = @c_SKU
   AND   STORERKEY = @c_StorerKey
   
   SELECT @n_ConMinShelfLife = S.MinShelflife
   FROM ORDERS O (NOLOCK)
   JOIN STORER S (NOLOCK) ON O.Consigneekey = S.Storerkey
   WHERE O.Orderkey = @c_Orderkey
   
   IF @c_Strategykey = 'PPDSTD' AND (ISNULL(@n_ConMinShelfLife,0) > 0 OR ISNULL(@n_SkuOGShelfLife,0) > 0)   --NJOW03
   BEGIN
      --SET @c_Condition = @c_Condition + " AND LOTATTRIBUTE.Lottable05 >= N'" + CONVERT( NVARCHAR(8), DateAdd(day, @n_ConMinShelfLife * -1, GETDATE()), 112) + "'"  --NJOW02    	       	
        
        --NJOW03
        IF ISNULL(@n_ConMinShelfLife,0) > 0
           --SET @c_Condition = @c_Condition + " AND DateDiff(Day, GETDATE(), LOTATTRIBUTE.Lottable05 + SKU.ShelfLife) >= " + CAST(@n_ConMinShelfLife AS NVARCHAR)   
           SET @c_Condition = @c_Condition + " AND DateDiff(Day, GETDATE(), LOTATTRIBUTE.Lottable04) >= " + CAST(@n_ConMinShelfLife AS NVARCHAR) --NJOW05   
        ELSE   
           --SET @c_Condition = @c_Condition + " AND DateDiff(Day, GETDATE(), LOTATTRIBUTE.Lottable05 + SKU.ShelfLife) >= " + CAST(@n_SkuOGShelfLife AS NVARCHAR)   
           SET @c_Condition = @c_Condition + " AND DateDiff(Day, GETDATE(), LOTATTRIBUTE.Lottable04) >= " + CAST(@n_SkuOGShelfLife AS NVARCHAR)   --NJOW05
   END --NJOW01 End
   ELSE IF CONVERT(CHAR(10), @d_Lottable05, 103) <> '01/01/1900'
   BEGIN
      SET @c_Condition = @c_Condition + ' AND LOTATTRIBUTE.Lottable05 = N''' + RTRIM(CONVERT( NVARCHAR(20), @d_Lottable05, 106)) + ''''
   END
   
   IF RTRIM(@c_Lottable06) <> '' AND @c_Lottable06 IS NOT NULL
   BEGIN
      SET @c_Condition = @c_Condition + ' AND LOTATTRIBUTE.Lottable06 = N''' + RTRIM(@c_Lottable06) + '''' 
   END   
   
   --NJOW06
   IF @c_Strategykey = 'PPDSTD'
   BEGIN
   	  SELECT TOP 1 @c_Lottable07 = CASE WHEN ISNULL(@c_Lottable07,'') = '' AND ISNULL(CL.Code2,'') <> ''  THEN ISNULL(CL.Code2,'') ELSE @c_Lottable07 END
   	  FROM ORDERS O (NOLOCK)
   	  JOIN ORDERDETAIL OD (NOLOCK) ON O.Orderkey = OD.Orderkey
   	  JOIN SKU (NOLOCK) ON OD.Storerkey = SKU.Storerkey AND OD.Sku = SKU.Sku
      JOIN STORER CONS (NOLOCK) ON O.Consigneekey = CONS.Storerkey
      OUTER APPLY (SELECT TOP 1 CL.Code2 FROM CODELKUP CL (NOLOCK) WHERE O.Storerkey = CL.Storerkey AND SKU.Busr6 = CL.Code AND CL.Listname = 'ALLOBYLTBL' 
                   AND ((CONS.Secondary = CL.UDF01 OR CONS.Secondary = CL.UDF02 OR CONS.Secondary = CL.UDF03 OR CONS.Secondary = CL.UDF04 OR CONS.Secondary = CL.UDF05) AND ISNULL(CONS.Secondary, '') <> '')) CL   
      WHERE O.Orderkey = @c_Orderkey
      AND SKU.Sku = @c_Sku
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

   SET @c_SQLStatement = N'DECLARE  PREALLOCATE_CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR' 
                     + ' SELECT LOT.STORERKEY,LOT.SKU,LOT.LOT  ,'
                     + ' QTYAVAILABLE = (LOT.QTY - LOT.QTYALLOCATED - LOT.QTYPICKED - LOT.QTYPREALLOCATED - QTYONHOLD)'
                     + ' FROM LOT (Nolock), Lotattribute (Nolock), LOTXLOCXID (NOLOCK), LOC (NOLOCK), SKU (NOLOCK)' 
                     + ' WHERE LOT.LOT = LOTATTRIBUTE.LOT'  
                     + ' AND LOTXLOCXID.Lot = LOT.LOT'
                     + ' AND LOTXLOCXID.LOT = LOTATTRIBUTE.LOT'
                     + ' AND LOTXLOCXID.LOC = LOC.LOC'
                     + ' AND LOTXLOCXID.Storerkey = SKU.Storerkey'
                     +'  AND LOTXLOCXID.Sku = SKU.Sku'
                     + ' AND LOC.Facility = ''' + @c_facility + ''''
                     + ' AND LOT.STORERKEY = ''' + @c_storerkey + '''' 
                     + ' AND LOT.SKU = ''' + @c_sku + '''' 
                     + ' AND LOT.STATUS = "OK"'
                     + ' AND (LOT.QTY - LOT.QTYALLOCATED - LOT.QTYPICKED - LOT.QTYPREALLOCATED - QTYONHOLD) > 0'
                     + @c_Condition
                     -- AND DateAdd(Day, @n_StorerMinShelfLife, Lotattribute.Lottable04) > GetDate()' 
                     + ' ORDER BY Lotattribute.Lottable04, Lotattribute.Lottable05'
                     
   EXEC (@c_SQLStatement)
   --(Wan01) - END                     
END
END

GO
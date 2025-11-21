SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: nspPR01_B7                                         */
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
/* Date         Author  Ver.  Purposes                                  */
/* 28-Jul-2005  June    1.0   SOS38650 - TBLM1 allocation error         */
/*                                     - multiple rows of same records return*/
/* 15-May-2015  NJOW01  1.1   333643 - SG-Melion - IVAS control check   */
/*                            lottable10                                */   
/* 18-AUG-2015  YTWan   1.2   SOS#350432 - Project Merlion - Allocation */
/*                            Strategy (Wan01)                          */
/* 01-JUN-2018  NJOW02  1.3   WMS-5158 Prestige allocate shelflife by   */
/*                            consignee                                 */  
/* 06/08/2018   NJOW03  1.4   Fix FIFO Shelflife                        */
/* 09/11/2018   NJOW04  1.5   WMS-6892 change FIFO shelflife filter     */
/* 24/07/2019   NJOW05  1.6   WMS-9509 SG Prestige lottable03 filter    */
/* 28/05/2020   NJOW06  1.7   WMS-13544 Change FIFO to use lottable04   */
/* 15/12/2021   NJOW07  1.8   WMS-18573 Lottable07 filtring condition   */
/* 15/12/2021   NJOW07  1.8   DEVOPS combine script                     */
/************************************************************************/

CREATE PROC    [dbo].[nspPR01_B7]  -- Rename From nspPR01_07; used by IDSSG
@c_storerkey NVARCHAR(15) ,
@c_sku NVARCHAR(20) ,
@c_lot NVARCHAR(10) ,
@c_lottable01 NVARCHAR(18) ,
@c_lottable02 NVARCHAR(18) ,
@c_lottable03 NVARCHAR(18) ,
@c_lottable04 datetime ,
@c_lottable05 datetime ,
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
@c_facility NVARCHAR(10)  ,  -- added By Ricky for IDSV5
@n_uombase int ,
@n_qtylefttofulfill int,
@c_OtherParms NVARCHAR(200)=''--(Wan01)           
AS
BEGIN
   --(Wan01) - START
   DECLARE @c_SQLStatement NVARCHAR(4000) 
          ,@c_Condition    NVARCHAR(4000)   
          ,@n_ConMinShelfLife INT  --NJOW02
          ,@c_Orderkey        INT  --NJOW02
          ,@c_Strategykey     NVARCHAR(10) --NJOW02
          ,@n_SkuOGShelflife  INT  --NJOW04
   
   SELECT @c_Orderkey = LEFT(@c_OtherParms,10) --NJOW02
         
   SET @c_SQLStatement = ''
   --(Wan01) - END
         
   IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_lot)) IS NOT NULL
   BEGIN
      DECLARE  PREALLOCATE_CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR   
         SELECT LOT.STORERKEY,LOT.SKU,LOT.LOT ,
         QTYAVAILABLE = (LOT.QTY - LOT.QTYALLOCATED - LOT.QTYPICKED - LOT.QTYPREALLOCATED - LOT.QtyOnHold)
         FROM LOT (NOLOCK), LOTXLOCXID (NOLOCK), LOC (NOLOCK)
         WHERE LOTXLOCXID.Lot = LOT.LOT
         AND LOTXLOCXID.LOC = LOC.LOC
         And LOC.LocationFlag <> 'DAMAGE' And LOC.LocationFlag <> 'HOLD'
         AND LOC.Facility = @c_facility
         AND LOT.LOT = @c_lot
         ORDER BY LOT.LOT
   END
   ELSE
   BEGIN
      IF EXISTS (SELECT 1 
                 FROM SKU (NOLOCK)
                 JOIN STORERCONFIG (NOLOCK) ON (SKU.Storerkey = STORERCONFIG.Storerkey AND STORERCONFIG.Configkey = 'nspPR01_B7_CHECKIVAS' AND STORERCONFIG.SValue = '1')
                 WHERE SKU.Storerkey = @c_Storerkey
                 AND SKU.Sku = @c_Sku
                 AND ISNULL(SKU.IVAS,'') <> ''
                 AND ISNULL(SKU.Lottable10Label,'') <> '')                   
       BEGIN
            DECLARE  PREALLOCATE_CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR
            SELECT LOT.STORERKEY, LOT.SKU, LOT.LOT, 
--           QTYAVAILABLE = MAX(LOT.QTY - LOT.QTYALLOCATED - LOT.QTYPICKED - LOT.QTYPREALLOCATED - LOT.QtyOnHold) -- SOS38650
            QTYAVAILABLE = SUM(LOTXLOCXID.QTY - LOTXLOCXID.QTYALLOCATED - LOTXLOCXID.QTYPICKED) - MIN(ISNULL(P.QTYPREALLOCATED, 0))
--           FROM LOT (NOLOCK), LOTATTRIBUTE (NOLOCK), LOTXLOCXID (NOLOCK), LOC (NOLOCK), ID (NOLOCK)
            FROM LOT WITH (NOLOCK)
            JOIN LOTATTRIBUTE (NOLOCK) ON (LOT.LOT = LOTATTRIBUTE.LOT) 
            JOIN LOTXLOCXID   (NOLOCK) ON (LOT.LOT = LOTXLOCXID.LOT) 
            JOIN LOC (NOLOCK) ON (LOTXLOCXID.LOC = LOC.LOC)
            JOIN ID  (NOLOCK) ON (LOTxLOCxID.ID = ID.ID)
            LEFT OUTER JOIN (SELECT PP.lot, OH.facility, QtyPreallocated = ISNULL(SUM(PP.Qty),0)  
                             FROM PreallocatePickdetail PP WITH (NOLOCK)
                             JOIN  ORDERS OH WITH(NOLOCK) ON (PP.Orderkey = OH.Orderkey)
                             WHERE PP.Storerkey = @c_Storerkey
                             AND   PP.SKU = @c_Sku
                             AND   OH.Facility = @c_Facility
                             GROUP BY PP.Lot, OH.Facility) p 
                             ON LOTXLOCXID.Lot = p.Lot AND p.Facility = LOC.Facility  
            WHERE LOT.STORERKEY = @c_Storerkey
            AND LOT.SKU = @c_Sku
            AND LOT.STATUS = 'OK'
            --AND (LOT.QTY - LOT.QTYALLOCATED - LOT.QTYPICKED - LOT.QTYPREALLOCATED - LOT.QtyOnHold) > 0
            AND LOT.STATUS = 'OK' AND LOC.STATUS = 'OK' AND ID.STATUS = 'OK' 
            And LOC.LocationFlag <> 'DAMAGE' And LOC.LocationFlag <> 'HOLD'   
--            AND LOTxLOCxID.ID = ID.ID 
--            AND LOT.LOT = LOTATTRIBUTE.LOT
--            AND LOTXLOCXID.Lot = LOT.LOT
--            AND LOTXLOCXID.LOT = LOTATTRIBUTE.LOT
--            AND LOTXLOCXID.LOC = LOC.LOC
            AND LOC.Facility = @c_facility
            AND ISNULL(LOTATTRIBUTE.Lottable10,'') = ''
            GROUP BY LOT.STORERKEY, LOT.SKU, LOT.LOT, LOTATTRIBUTE.LOTTABLE04, LOTATTRIBUTE.LOTTABLE05 -- SOS38650
            HAVING SUM(LOTXLOCXID.QTY - LOTXLOCXID.QTYALLOCATED - LOTXLOCXID.QTYPICKED) - MIN(ISNULL(P.QTYPREALLOCATED, 0)) > 0
            ORDER BY LOTATTRIBUTE.LOTTABLE04, LOTATTRIBUTE.LOTTABLE05
       END
       ELSE
       BEGIN
         SELECT @c_Strategykey = Strategykey,
                @n_SkuOGShelfLife = CASE WHEN ISNUMERIC(susr2) = 1 THEN CAST(Susr2 AS INT) ELSE 0 END --NJOW04
         FROM  SKU (NOLOCK)
         WHERE SKU = @c_SKU
         AND   STORERKEY = @c_StorerKey
                	
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
         ELSE IF @c_Storerkey = 'PRESTIGE'  --NJOW05
         BEGIN
            SET @c_Condition = @c_Condition + ' AND LOTATTRIBUTE.Lottable03 = ''OK'' '              
         END

         IF CONVERT(CHAR(10), @c_Lottable04, 103) <> '01/01/1900'
         BEGIN
            SET @c_Condition = @c_Condition + ' AND LOTATTRIBUTE.Lottable04 = N''' + RTRIM(CONVERT( NVARCHAR(20), @c_Lottable04, 106)) + ''''
         END
   
         IF CONVERT(CHAR(10), @c_Lottable05, 103) <> '01/01/1900'
         BEGIN
            SET @c_Condition = @c_Condition + ' AND LOTATTRIBUTE.Lottable05 = N''' + RTRIM(CONVERT( NVARCHAR(20), @c_Lottable05, 106)) + ''''
         END
         
         IF RTRIM(@c_Lottable06) <> '' AND @c_Lottable06 IS NOT NULL
         BEGIN
            SET @c_Condition = @c_Condition + ' AND LOTATTRIBUTE.Lottable06 = N''' + RTRIM(@c_Lottable06) + '''' 
         END   
   
         --NJOW07
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
   
         IF CONVERT(CHAR(10), @d_lottable13, 103) <> '01/01/1900'
         BEGIN
            SET @c_Condition = @c_Condition + ' AND LOTATTRIBUTE.Lottable13 = N''' + RTRIM(CONVERT( NVARCHAR(20), @d_lottable13, 106)) + ''''
         END
   
         IF CONVERT(CHAR(10), @d_lottable14, 103) <> '01/01/1900'
         BEGIN
            SET @c_Condition = @c_Condition + ' AND LOTATTRIBUTE.Lottable14 = N''' + RTRIM(CONVERT( NVARCHAR(20), @d_lottable14, 106)) + ''''
         END

         IF CONVERT(CHAR(10), @d_lottable15, 103) <> '01/01/1900'
         BEGIN
            SET @c_Condition = @c_Condition + ' AND LOTATTRIBUTE.Lottable15 = N''' + RTRIM(CONVERT( NVARCHAR(20), @d_lottable15, 106)) + ''''
         END
   
         --NJOW02 Strart
       	 SELECT @n_ConMinShelfLife = S.MinShelflife
         FROM ORDERS O (NOLOCK)
         JOIN STORER S (NOLOCK) ON O.Consigneekey = S.Storerkey
         WHERE O.Orderkey = @c_Orderkey
         
         IF @c_Strategykey = 'PPDSTD' 
         BEGIN
            --SET @c_Condition = @c_Condition + " AND LOTATTRIBUTE.Lottable05 >= N'" + CONVERT( NVARCHAR(8), DateAdd(day, @n_ConMinShelfLife * -1, GETDATE()), 112) + "'"  --NJOW03            
            
            --NJOW04
            IF ISNULL(@n_ConMinShelfLife,0) > 0
               --SET @c_Condition = @c_Condition + " AND DateDiff(Day, GETDATE(), LOTATTRIBUTE.Lottable05 + SKU.ShelfLife) >= " + CAST(@n_ConMinShelfLife AS NVARCHAR)   
               SET @c_Condition = @c_Condition + " AND DateDiff(Day, GETDATE(), LOTATTRIBUTE.Lottable04) >= " + CAST(@n_ConMinShelfLife AS NVARCHAR)   --NJOW06
            ELSE IF ISNULL(@n_SkuOGShelflife,0) > 0
               --SET @c_Condition = @c_Condition + " AND DateDiff(Day, GETDATE(), LOTATTRIBUTE.Lottable05 + SKU.ShelfLife) >= " + CAST(@n_SkuOGShelfLife AS NVARCHAR)   
               SET @c_Condition = @c_Condition + " AND DateDiff(Day, GETDATE(), LOTATTRIBUTE.Lottable04) >= " + CAST(@n_SkuOGShelfLife AS NVARCHAR)   --NJOW06
         END --NJOW02 End
                        
         SET @c_SQLStatement = N'DECLARE  PREALLOCATE_CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR
                                 SELECT LOT.STORERKEY, LOT.SKU, LOT.LOT, 
                                 --QTYAVAILABLE = MAX(LOT.QTY - LOT.QTYALLOCATED - LOT.QTYPICKED - LOT.QTYPREALLOCATED - LOT.QtyOnHold) -- SOS38650
                                 QTYAVAILABLE = SUM(LOTXLOCXID.QTY - LOTXLOCXID.QTYALLOCATED - LOTXLOCXID.QTYPICKED) - MIN(ISNULL(P.QTYPREALLOCATED, 0))
                                 FROM LOT WITH (NOLOCK)
                                 JOIN LOTATTRIBUTE (NOLOCK) ON (LOT.LOT = LOTATTRIBUTE.LOT) 
                                 JOIN LOTXLOCXID   (NOLOCK) ON (LOT.LOT = LOTXLOCXID.LOT) 
                                 JOIN LOC (NOLOCK) ON (LOTXLOCXID.LOC = LOC.LOC)
                                 JOIN ID  (NOLOCK) ON (LOTxLOCxID.ID = ID.ID)
                                 JOIN SKU (NOLOCK) ON (LOTxLOCxID.Storerkey = SKU.Storerkey AND LOTxLOCxID.Sku = SKU.Sku)
                                 LEFT OUTER JOIN (SELECT PP.lot, OH.facility, QtyPreallocated = ISNULL(SUM(PP.Qty),0)  
                                                  FROM PreallocatePickdetail PP WITH (NOLOCK)
                                                  JOIN  ORDERS OH WITH(NOLOCK) ON (PP.Orderkey = OH.Orderkey)
                                                  WHERE PP.Storerkey = N''' + @c_Storerkey + '''  
                                                  AND   PP.SKU = N''' + @c_Sku + '''  
                                                  AND   OH.Facility = N''' + @c_Facility + ''' 
                                                  GROUP BY PP.Lot, OH.Facility) p 
                                                  ON LOTXLOCXID.Lot = p.Lot AND p.Facility = LOC.Facility 
                                 WHERE LOT.STORERKEY = N''' +@c_Storerkey + '''
                                 AND LOT.SKU = N''' +@c_Sku + '''
                                 AND LOT.STATUS = ''OK''
                                 --AND (LOT.QTY - LOT.QTYALLOCATED - LOT.QTYPICKED - P.QTYPREALLOCATED - LOT.QtyOnHold) > 0
                                 AND LOT.STATUS = ''OK'' AND LOC.STATUS = ''OK'' AND ID.STATUS = ''OK'' 
                                 And LOC.LocationFlag <> ''DAMAGE'' And LOC.LocationFlag <> ''HOLD''   
                                 AND LOC.Facility = ''' + @c_facility + '''' + 
                                 @c_Condition + '
                                 GROUP BY LOT.STORERKEY, LOT.SKU, LOT.LOT, LOTATTRIBUTE.LOTTABLE04, LOTATTRIBUTE.LOTTABLE05 -- SOS38650
                                 HAVING SUM(LOTXLOCXID.QTY - LOTXLOCXID.QTYALLOCATED - LOTXLOCXID.QTYPICKED) - MIN(ISNULL(P.QTYPREALLOCATED, 0)) > 0
                                 ORDER BY LOTATTRIBUTE.LOTTABLE04, LOTATTRIBUTE.LOTTABLE05 '

         EXEC(@c_SQLStatement)
         --(Wan01) - END
      END
   END
END

GO
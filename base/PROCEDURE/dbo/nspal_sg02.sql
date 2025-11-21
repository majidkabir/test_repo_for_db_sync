SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: nspAL_SG02                                         */
/* Creation Date: 28-Jun-2018                                           */
/* Copyright: LFL                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: WMS-5471 - SG Pernod ricard allocation                      */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author   Ver. Purposes                                  */
/* 16/10/2018   NJOW01   1.0  Fix @n_SQL to MAX                         */    
/* 03/01/2019   NJOW02   1.1  WMS-7293 try allocate COPACK in same      */
/*                            pallet                                    */
/* 02/10/2019   NJOW03   1.2  Fix sorting                               */
/* 21/01/2022   NJOW04   1.3  WMS-18786 Change sorting                  */
/* 21/01/2022   NJOW04   1.3  DEVOPS combine script                     */
/************************************************************************/
CREATE PROC    [dbo].[nspAL_SG02]
   @c_lot NVARCHAR(10) ,
   @c_uom NVARCHAR(10) ,
   @c_HostWHCode NVARCHAR(10),
   @c_Facility NVARCHAR(5),
   @n_uombase int ,
   @n_qtylefttofulfill int,  
   @c_OtherParms NVARCHAR(200) = ''
AS
BEGIN
   SET NOCOUNT ON 
  
   DECLARE @c_SQL NVARCHAR(MAX),
           @c_Loc NVARCHAR(10),
           @c_ID  NVARCHAR(18),
           @n_QtyAvailable INT,
           @n_QtyTake INT,
           @n_QtyOrderRemainByUOM INT,
           @c_Skucopack1 NVARCHAR(20),
           @c_skucopack2 NVARCHAR(20),
           @c_Storerkey NVARCHAR(15),
           @c_Lottable01 NVARCHAR(18),
           @c_Lottable02 NVARCHAR(18),
           @c_Lottable03 NVARCHAR(18),
           @c_Lottable06 NVARCHAR(30),
           @c_Lottable07 NVARCHAR(30),
           @c_Lottable08 NVARCHAR(30),
           @c_Lottable09 NVARCHAR(30),
           @c_Lottable10 NVARCHAR(30),
           @c_Lottable11 NVARCHAR(30),
           @c_Lottable12 NVARCHAR(30),
           @c_Lottable02Prefix NVARCHAR(10),
           @c_Orderkey   NVARCHAR(10),       --NJOW04
           @c_OrderLineNumber NVARCHAR(5),   --NJOW04       
           @n_CaseCnt    INT = 0             --NJOW04
           
   CREATE TABLE #TMP_ID (ID NVARCHAR(18) NULL,
                         Lottable05 DATETIME NULL,
                         Seq NVARCHAR(10) NULL)      
   
   SET @c_SQL = ''
   SET @c_Skucopack1 = ''
   SET @c_Skucopack2 = ''
  
   --NJOW04 Start
   SELECT @c_Orderkey = LEFT(@c_OtherParms,10)
   SELECT @c_OrderLineNumber = SUBSTRING(@c_OtherParms, 11,5)
   
   IF EXISTS(SELECT 1 
             FROM ORDERS O (NOLOCK)
             JOIN ORDERDETAIL OD (NOLOCK) ON O.Orderkey = OD.Orderkey
             JOIN SKU (NOLOCK) ON OD.Storerkey = SKU.Storerkey AND OD.Sku = SKU.Sku
             JOIN PACK (NOLOCK) ON SKU.Packkey = PACK.Packkey
             JOIN CODELKUP CL (NOLOCK) ON O.Storerkey = CL.Storerkey AND O.Consigneekey = CL.Code 
             WHERE O.Orderkey = @c_Orderkey
             AND OD.OrderLineNumber = @c_OrderLineNumber
             AND CL.Listname = 'PRFULLCS'
             AND PACK.CaseCnt > 0
             AND OD.OpenQty >= PACK.CaseCnt)  --the consignee only allocate full case
   BEGIN      
      SELECT @n_Casecnt = PACK.CaseCnt
      FROM LOT (NOLOCK)
      JOIN SKU (NOLOCK) ON LOT.Storerkey = SKU.Storerkey AND LOT.Sku = SKU.Sku
      JOIN PACK (NOLOCK) ON SKU.Packkey = PACK.Packkey
      WHERE LOT.Lot = @c_Lot
      
      IF @n_CaseCnt > 0   
        SET @n_uombase = @n_CaseCnt      
   END
   --NJOW04 E
      
   --NJOW02 -S      
   SELECT @C_Skucopack1 = SKU.Sku,
          @c_Storerkey = SKU.Storerkey
   FROM SKU (NOLOCK)
   JOIN LOT (NOLOCK) ON SKU.Storerkey = LOT.Storerkey AND SKU.Sku = LOT.Sku
   WHERE LOT.Lot = @c_Lot
   AND SKU.Productmodel = 'COPACK'
   
   IF ISNULL(@c_Skucopack1,'') <> ''
   BEGIN
   	  SELECT @c_Skucopack2 = MAX(OD.SKU)
   	  FROM ORDERDETAIL OD (NOLOCK)
   	  JOIN SKU (NOLOCK) ON OD.Storerkey = SKU.Storerkey AND OD.Sku = SKU.Sku
   	  WHERE OD.Orderkey = LEFT(@c_Otherparms,10)
   	  AND SKU.Productmodel = 'COPACK'
   	  AND OD.Sku <> @c_skucopack1
   	  AND SKU.Style = @c_skucopack1 
   END
   
   IF ISNULL(@c_Skucopack2,'') <> ''
   BEGIN
   	  SELECT @c_Lottable02Prefix = LEFT(LOTTABLE02, 3)
   	  FROM LOTATTRIBUTE (NOLOCK)
   	  WHERE Lot = @c_Lot
   	  
      SELECT TOP 1 @c_Lottable01 = Lottable01,
             @c_Lottable02 = Lottable02,
             @c_Lottable03 = Lottable03,
             @c_Lottable06 = Lottable06,
             @c_Lottable07 = Lottable07,
             @c_Lottable08 = Lottable08,
             @c_Lottable09 = Lottable09,
             @c_Lottable10 = Lottable10,
             @c_Lottable11 = Lottable11,
             @c_Lottable12 = Lottable12
      FROM ORDERDETAIL(NOLOCK)
      WHERE Orderkey = LEFT(@c_Otherparms,10)
      AND Sku = @c_Skucopack2
   	  ORDER BY CASE WHEN ORDERDETAIL.OpenQty = @n_qtylefttofulfill THEN 1 ELSE 2 END,   	  
               CASE WHEN LEFT(Lottable02, 3) = @c_Lottable02Prefix THEN 1 ELSE 2 END   	          

   	  INSERT INTO #TMP_ID (ID, Lottable05, Seq)
   	  SELECT LOTxLOCxID.ID, MIN(LOTATTRIBUTE.Lottable05), 
   	         CASE WHEN ALLOCID.ID IS NOT NULL THEN '1' ELSE '2' END
      FROM LOTxLOCxID (NOLOCK) 
      JOIN SKUXLOC (NOLOCK) ON LOTXLOCXID.Storerkey = SKUXLOC.Storerkey AND LOTXLOCXID.Sku = SKUXLOC.Sku AND LOTXLOCXID.Loc = SKUXLOC.Loc
      JOIN LOC (NOLOCK) ON (LOTxLOCxID.Loc = LOC.LOC)
      JOIN ID (NOLOCK) ON (LOTxLOCxID.Id = ID.ID) 
      JOIN LOT (NOLOCK) ON (LOTXLOCXID.LOT = LOT.LOT)
      JOIN LOTATTRIBUTE (NOLOCK) ON LOT.Lot = LOTATTRIBUTE.Lot
      OUTER APPLY (SELECT TOP 1 PD.ID FROM PICKDETAIL PD (NOLOCK) 
                   WHERE PD.Id = LOTxLOCxID.ID
                   AND PD.Storerkey = LOTxLOCxID.Storerkey
                   AND PD.Sku = LOTxLOCxID.Sku 
                   AND PD.Orderkey = LEFT(@c_Otherparms,10)) AS ALLOCID
      OUTER APPLY (SELECT SUM(Qty) AS Qty --Get Copack qty 
                   FROM LOTXLOCXID LLI (NOLOCK)
                   WHERE LLI.ID = LOTxLOCxID.ID
                   AND LLI.Storerkey = LOTxLOCxID.Storerkey
                   AND LLI.Sku = @C_Skucopack1) AS COPACK1                                    
      WHERE LOTxLOCxID.Storerkey = @c_Storerkey
      AND LOTxLOCxID.Sku = @c_Skucopack2
      AND LOC.Locationflag <> 'HOLD'
      AND LOC.Locationflag <> 'DAMAGE'
      AND LOC.Status <> 'HOLD'
      AND LOC.Facility = @c_Facility
      AND ID.STATUS <> 'HOLD'
      AND LOT.STATUS <> 'HOLD' 
      AND LOTxLOCxID.ID <> ''
      AND (LOTxLOCxID.QTY - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QTYREPLEN) > 0
      AND LOTATTRIBUTE.Lottable01 = CASE WHEN ISNULL(@c_Lottable01,'') <> '' THEN @c_Lottable01 ELSE LOTATTRIBUTE.Lottable01 END 
      AND LOTATTRIBUTE.Lottable02 = CASE WHEN ISNULL(@c_Lottable02,'') <> '' THEN @c_Lottable02 ELSE LOTATTRIBUTE.Lottable02 END 
      AND LOTATTRIBUTE.Lottable03 = CASE WHEN ISNULL(@c_Lottable03,'') <> '' THEN @c_Lottable03 ELSE LOTATTRIBUTE.Lottable03 END 
      AND LOTATTRIBUTE.Lottable06 = CASE WHEN ISNULL(@c_Lottable06,'') <> '' THEN @c_Lottable06 ELSE LOTATTRIBUTE.Lottable06 END 
      AND LOTATTRIBUTE.Lottable07 = CASE WHEN ISNULL(@c_Lottable07,'') <> '' THEN @c_Lottable07 ELSE LOTATTRIBUTE.Lottable07 END 
      AND LOTATTRIBUTE.Lottable08 = CASE WHEN ISNULL(@c_Lottable08,'') <> '' THEN @c_Lottable08 ELSE LOTATTRIBUTE.Lottable08 END 
      AND LOTATTRIBUTE.Lottable09 = CASE WHEN ISNULL(@c_Lottable09,'') <> '' THEN @c_Lottable09 ELSE LOTATTRIBUTE.Lottable09 END 
      AND LOTATTRIBUTE.Lottable10 = CASE WHEN ISNULL(@c_Lottable10,'') <> '' THEN @c_Lottable10 ELSE LOTATTRIBUTE.Lottable10 END 
      AND LOTATTRIBUTE.Lottable11 = CASE WHEN ISNULL(@c_Lottable11,'') <> '' THEN @c_Lottable11 ELSE LOTATTRIBUTE.Lottable11 END 
      AND LOTATTRIBUTE.Lottable12 = CASE WHEN ISNULL(@c_Lottable12,'') <> '' THEN @c_Lottable12 ELSE LOTATTRIBUTE.Lottable12 END 
      GROUP BY LOTxLOCxID.ID, CASE WHEN ALLOCID.ID IS NOT NULL THEN '1' ELSE '2' END,  ISNULL(COPACK1.Qty,0)
      HAVING SUM(LOTxLOCxID.Qty) = ISNULL(COPACK1.Qty,0)  --only get the pallet with all copack item have tally qty
   END   
   --NJOW02 E
          
   SELECT LOTxLOCxID.LOC,LOTxLOCxID.ID,
          QTYAVAILABLE = (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QTYREPLEN), 'N' AS Allocated,
          CASE WHEN #TMP_ID.ID IS NOT NULL THEN #TMP_ID.Seq ELSE '3' END AS Seq,
          CASE WHEN #TMP_ID.ID IS NOT NULL THEN CONVERT(NVARCHAR, #TMP_ID.Lottable05,112) ELSE 'ZZZZZZZZZZ' END AS Lottable05
   INTO #TMP_INV       
   FROM LOTxLOCxID (NOLOCK) 
   JOIN SKUXLOC (NOLOCK) ON LOTXLOCXID.Storerkey = SKUXLOC.Storerkey AND LOTXLOCXID.Sku = SKUXLOC.Sku AND LOTXLOCXID.Loc = SKUXLOC.Loc
   JOIN LOC (NOLOCK) ON (LOTxLOCxID.Loc = LOC.LOC)
   JOIN ID (NOLOCK) ON (LOTxLOCxID.Id = ID.ID) 
   JOIN LOT (NOLOCK) ON (LOTXLOCXID.LOT = LOT.LOT) 
   LEFT JOIN #TMP_ID ON #TMP_ID.Id = LOTxLOCxID.ID
   WHERE LOTxLOCxID.Lot = @c_lot
   AND LOC.Locationflag <> 'HOLD'
   AND LOC.Locationflag <> 'DAMAGE'
   AND LOC.Status <> 'HOLD'
   AND LOC.Facility = @c_Facility
   AND ID.STATUS <> 'HOLD'
   AND LOT.STATUS <> 'HOLD' 
   AND (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QTYREPLEN) >= @n_uombase 
   AND ( #TMP_ID.ID IS NOT NULL   
         OR ISNULL(@c_Skucopack1,'') = '' ) 
   ORDER BY CASE WHEN #TMP_ID.ID IS NOT NULL THEN CONVERT(NVARCHAR, #TMP_ID.Lottable05,112) ELSE 'ZZZZZZZZZZ' END, CASE WHEN LOC.LogicalLocation IN('','WCS01') THEN 1 ELSE 0 END, LOC.LOC  --NJOW02  --NJOW04
   
   SET @n_QtyOrderRemainByUOM = FLOOR(@n_QtyLeftToFulfill / @n_uombase) * @n_uombase 
                         
   WHILE @n_QtyOrderRemainByUOM > 0 
   BEGIN   	  
      SELECT @c_Loc = '', @c_ID ='', @n_QtyAvailable = 0, @n_QtyTake = 0
   	  
   	  IF @c_UOM = '1'
   	  BEGIN
         SELECT TOP 1 @c_Loc = LOC, @c_ID = ID, @n_QtyAvailable = QtyAvailable
         FROM #TMP_INV
         WHERE Allocated = 'N'     
         ORDER BY Seq, Lottable05, QtyAvailable, Loc
   	  END
   	  ELSE
   	  BEGIN
         /*  --NJOW04 Request to remove
         SELECT TOP 1 @c_Loc = LOC, @c_ID = ID, @n_QtyAvailable = QtyAvailable
         FROM #TMP_INV
         WHERE Allocated = 'N'     
         AND QtyAvailable <= @n_QtyOrderRemainByUOM         
         ORDER BY Seq, QtyAvailable Desc, Loc  --Fix
         --ORDER BY Seq, Lottable05, QtyAvailable Desc, Loc
         */
         
         IF ISNULL(@c_Loc,'') = ''
         BEGIN
            SELECT TOP 1 @c_Loc = LOC, @c_ID = ID, @n_QtyAvailable = QtyAvailable
            FROM #TMP_INV
            WHERE Allocated = 'N'     
            ORDER BY Seq, QtyAvailable, Loc  --NJOW04
            --ORDER BY Seq, QtyAvailable DESC, Loc  --Fix
            --ORDER BY Seq, Lottable05, QtyAvailable Loc  
         END
      END
            
      IF ISNULL(@c_Loc,'') = ''
         BREAK
      
      UPDATE #TMP_INV 
      SET Allocated = 'Y'
      WHERE Loc = @c_Loc
      AND Id = @c_ID
      
      IF @n_QtyAvailable > @n_QtyOrderRemainByUOM
         SELECT @n_QtyTake = @n_QtyOrderRemainByUOM
      ELSE       
         SELECT @n_QtyTake = FLOOR(@n_QtyAvailable / @n_uombase) * @n_uombase       

      IF @n_QtyTake > 0
      BEGIN
         IF ISNULL(@c_SQL,'') = ''
         BEGIN
            SET @c_SQL = N'   
                  DECLARE CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR    
                  SELECT '''  + @c_Loc + ''', ''' + RTRIM(@c_Id) + ''', ' + RTRIM(CAST(@n_QtyTake AS NVARCHAR(10))) + ',''1'''
         END
         ELSE
         BEGIN
            SET @c_SQL = @c_SQL + N'  
                  UNION ALL
                  SELECT '''  + @c_Loc + ''', ''' + RTRIM(@c_Id) + ''', ' + RTRIM(CAST(@n_QtyTake AS NVARCHAR(10))) + ',''1'''
         END            
      END
   
      SET @n_QtyOrderRemainByUOM = @n_QtyOrderRemainByUOM - @n_QtyTake               	
   END
   
   IF ISNULL(@c_SQL,'') <> ''
   BEGIN
      EXEC sp_ExecuteSQL @c_SQL
   END
   ELSE
   BEGIN
      DECLARE CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR 
      SELECT TOP 0 NULL, NULL, NULL, NULL
   END                                              
END

GO
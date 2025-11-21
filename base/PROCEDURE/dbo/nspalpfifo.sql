SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/    
/* Stored Procedure: nspALPFIFO                                         */    
/* Creation Date: 02-MAR-2016                                           */    
/* Copyright: LFL                                                       */    
/* Written by:                                                          */    
/*                                                                      */    
/* Purpose: 357365-SG-Allocate Full pallet by loc/id balance for UOM 1  */
/*          FIFO. Other UOM as normal                                   */
/*          SkipPreallocation = '1'                                     */
/*                                                                      */
/* Called By:                                                           */    
/*                                                                      */    
/* PVCS Version: 1.0                                                    */    
/*                                                                      */    
/* Version: 1.0                                                         */    
/*                                                                      */    
/* Data Modifications:                                                  */    
/*                                                                      */    
/* Updates:                                                             */    
/* Date         Author  Ver.  Purposes                                  */   
/* 22-APR-2016  NJOW01  1.0   Fix UOM <> 1 Sorting by qty available     */ 
/* 27-APR-2016  NJOW02  1.1   Remove locationtype='OTHER' filter        */
/* 13-May-2016  NJOW03  1.2   Fix to check transferdetail.status for    */
/*                            calculate qtyavailable                    */
/* 24-Mar-2017  NJOW04  1.3   WMS-1408 allocate inventory day range by  */
/*                            consignee condition                       */
/* 04-Sep-2018  NJOW05  1.4   WMS-6226 lottable03 filtering for consignee*/
/* 01-Aug-2018  NJOW06  1.5   WMS-9967 allocate full case for specific  */
/*                            consignee only                            */
/* 17-Oct-2019  NJOW07  1.6   WMS-10923 Support sort by qty by config   */
/* 06-May-2020  NJOW08  1.7   WMS-6226 skip UOM 1 allocation by condition*/
/* 01-Dec-2020  NJOW09  1.8   WMS-15743 MHAP Get shelflife from codelkup */
/************************************************************************/    
CREATE PROC [dbo].[nspALPFIFO]        
   @c_Orderkey    NVARCHAR(10),  
   @c_Facility   NVARCHAR(5),     
   @c_StorerKey  NVARCHAR(15),     
   @c_SKU        NVARCHAR(20),    
   @c_Lottable01 NVARCHAR(18),    
   @c_Lottable02 NVARCHAR(18),    
   @c_Lottable03 NVARCHAR(18),    
   @d_Lottable04 DATETIME,    
   @d_Lottable05 DATETIME,    
   @c_Lottable06 NVARCHAR(30),    
   @c_Lottable07 NVARCHAR(30),    
   @c_Lottable08 NVARCHAR(30),    
   @c_Lottable09 NVARCHAR(30),    
   @c_Lottable10 NVARCHAR(30),    
   @c_Lottable11 NVARCHAR(30),    
   @c_Lottable12 NVARCHAR(30),    
   @d_Lottable13 DATETIME,    
   @d_Lottable14 DATETIME,    
   @d_Lottable15 DATETIME,    
   @c_UOM        NVARCHAR(10),    
   @c_HostWHCode NVARCHAR(10),    
   @n_UOMBase    INT,    
   @n_QtyLeftToFulfill INT,
   @c_OtherParms NVARCHAR(200)=''
AS    
BEGIN    
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET ANSI_NULLS OFF    

   DECLARE @b_debug       INT,      
           @c_SQL         NVARCHAR(MAX),    
           @c_SQLParm     NVARCHAR(MAX)    
          
   DECLARE @n_QtyAvailable     INT,  
           @c_LOT              NVARCHAR(10),
           @c_LOC              NVARCHAR(10),
           @c_ID               NVARCHAR(18), 
           @c_OtherValue       NVARCHAR(20),
           @n_QtyToTake        INT,
           @c_LogicalLocation  NVARCHAR(18),
           @n_StorerMinShelfLife INT,
           @c_PrevLOT          NVARCHAR(10),
           @n_cnt              INT,
           @n_LotQtyAvailable  INT,
           @n_LocQty           INT,
           @n_NoOfLot          INT, 
           @c_Conditions       NVARCHAR(2000), --NJOW04
           @n_RestrictDays     INT, --NJOW04
           @c_Key1             NVARCHAR(10), --NJOW04
           @c_Key2             NVARCHAR(5), --NJOW04
           @c_Key3             NVARCHAR(1), --NJOW04
           @c_UDF01            NVARCHAR(30), --NJOW06
           @c_SORTBYQTY        NVARCHAR(30), --NJOW07
           @c_SORTUOM1         NVARCHAR(1000), --NJOW07
           @c_SORTNOTUOM1      NVARCHAR(1000), --NJOW07
           @c_UOM2NOCONSCHK    NVARCHAR(10) --NJOW08

   SET @b_debug = 0
   SET @n_QtyAvailable = 0          
   SET @c_OtherValue = '1' 
   SET @n_QtyToTake = 0
   SET @c_Conditions = '' --NJOW04
   SET @n_RestrictDays = 0 --NJOW04   
   SET @c_UOM2NOCONSCHK = 'N'
   
   --NJOW08
   IF LEFT(@c_Lottable07,4) = '2016' AND EXISTS(SELECT 1 FROM SKU(NOLOCK) WHERE Storerkey = @c_Storerkey AND Sku = @c_Sku AND ItemClass = '001')
   BEGIN    
   	  IF @c_UOM = '1'  
         GOTO EXIT_SP
      ELSE
         SET @c_UOM2NOCONSCHK = 'Y'      
   END
   
   --NJOW04 Start
   IF LEN(@c_OtherParms) > 0 
   BEGIN
      SET @c_OrderKey = LEFT(@c_OtherParms,10) 
      SET @c_key1 = LEFT(@c_OtherParms, 10) --Orderkey, Loadkey(conso), Wavekey(conso)
      SET @c_key2 = SUBSTRING(@c_OtherParms, 11, 5) --OrderLineNumber      	    
      SET @c_key3 = SUBSTRING(@c_OtherParms, 16, 1) --W=Wave     	    
      
      IF ISNULL(@c_key2,'')='' AND ISNULL(@c_key3,'')='' 
      BEGIN
         SET @c_Orderkey = ''
         SELECT TOP 1 @c_Orderkey = O.Orderkey
         FROM ORDERS O (NOLOCK) 
         JOIN ORDERDETAIL OD (NOLOCK) ON O.Orderkey = OD.Orderkey
         WHERE O.Loadkey = @c_key1
         AND OD.Sku = @c_SKU
         ORDER BY O.Orderkey, OD.OrderLineNumber
      END        	     
         
      IF ISNULL(@c_key2,'')='' AND ISNULL(@c_key3,'')='W' 
      BEGIN
         SET @c_Orderkey = ''
         SELECT TOP 1 @c_Orderkey = O.Orderkey
         FROM ORDERS O (NOLOCK) 
         JOIN ORDERDETAIL OD (NOLOCK) ON O.Orderkey = OD.Orderkey
         JOIN WAVEDETAIL WD (NOLOCK) ON O.Orderkey = WD.Orderkey
         WHERE WD.Wavekey = @c_key1
         AND OD.Sku = @c_SKU
         ORDER BY O.Orderkey, OD.OrderLineNumber
      END            
   END
   
   --NJOW06 S
   SELECT @c_UDF01 = UDF01 --HNWI%
   FROM CODELKUP (NOLOCK)
   WHERE Listname = 'PKCODECFG'
   AND Storerkey = @c_Storerkey
   AND Long = 'nspALPFIFO'
   AND Code = 'UOM2BYCONSIGNEE'
   AND Short <> 'N'
   AND (Code2 = @c_Facility OR ISNULL(Code2,'') = '')

   IF @c_UOM = '2'
   BEGIN      
      IF ISNULL(@C_UDF01,'') <> '' AND @c_UOM2NOCONSCHK = 'N'
      BEGIN       
         IF NOT EXISTS (SELECT 1
                        FROM ORDERS (NOLOCK)
                        WHERE Orderkey = @c_Orderkey
                        AND C_Company LIKE @c_UDF01)
         BEGIN         	
            GOTO EXIT_SP      
         END             
      END
      --ELSE
      --BEGIN
      --   GOTO EXIT_SP           
      --END           	     
   END   

   IF @c_UOM IN('1','6')
   BEGIN      
      IF ISNULL(@C_UDF01,'') <> '' 
      BEGIN       
         IF EXISTS (SELECT 1
                        FROM ORDERS (NOLOCK)
                        WHERE Orderkey = @c_Orderkey
                        AND C_Company LIKE @c_UDF01)
         BEGIN         	
            GOTO EXIT_SP      
         END             
      END
   END    
   --NJOW06 E
   
   --NJOW07 S   
   SELECT @c_SortByQty = Code 
   FROM CODELKUP (NOLOCK)
   WHERE Listname = 'PKCODECFG'
   AND Storerkey = @c_Storerkey
   AND Long = 'nspALPFIFO'
   AND Code = 'SORTBYQTY'
   AND Short <> 'N'
   AND (Code2 = @c_Facility OR ISNULL(Code2,'') = '')
   
   IF @c_SortByQty = 'SORTBYQTY'
   BEGIN
      SET @c_SORTUOM1 = ' ORDER BY CASE WHEN ((LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QtyReplen - ISNULL(TRFLLI.FromQty,0)) % @n_QtyLeftToFulfill) = 0 THEN 1 ELSE 2 END, 4 DESC, LA.Lottable05, LA.Lot, LOC.LogicalLocation, LOC.LOC ' 
      SET @c_SORTNOTUOM1 = ' ORDER BY 4, LA.Lottable05, LOC.LogicalLocation, LOC.LOC '
   END
   ELSE
   BEGIN 
      --SET @c_SORTUOM1 = ' ORDER BY LA.Lottable05, CASE WHEN ((LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QtyReplen - ISNULL(TRFLLI.FromQty,0)) % @n_QtyLeftToFulfill) = 0 THEN 1 ELSE 2 END, 4 DESC, LA.Lot, LOC.LogicalLocation, LOC.LOC ' 
      SET @c_SORTUOM1 = ' ORDER BY LA.Lottable05, CASE WHEN ((LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QtyReplen - ISNULL(TRFLLI.FromQty,0)) % @n_QtyLeftToFulfill) = 0 THEN 1 ELSE 2 END, 4, LA.Lot, LOC.LogicalLocation, LOC.LOC '  --NJOW08 
      SET @c_SORTNOTUOM1 = ' ORDER BY LA.Lottable05, 4, LOC.LogicalLocation, LOC.LOC '
   END 
   --NJOW07 E
      
   SELECT TOP 1 @n_RestrictDays = CASE WHEN (CON.Susr1 = 'DCNM1' OR CON.Susr2 = 'DCNM1' OR CON.Susr3 = 'DCNM1' OR CON.Susr4 = 'DCNM1' OR CON.Susr5 = 'DCNM1') --AND
                                            THEN --(SKU.Skugroup IN ('AG','AR','CE','CH','CS','CM','GP')) THEN 
                                                CASE WHEN ISNUMERIC(RDAY.Short) = 1 THEN CAST(RDAY.Short AS INT) ELSE 0 END --NJOW09
                                       WHEN (CON.Susr1 = 'DCNM2' OR CON.Susr2 = 'DCNM2' OR CON.Susr3 = 'DCNM2' OR CON.Susr4 = 'DCNM2' OR CON.Susr5 = 'DCNM2') --AND              
                                            THEN --(SKU.Skugroup = 'CB') THEN 
                                                CASE WHEN ISNUMERIC(RDAY.Short) = 1 THEN CAST(RDAY.Short AS INT) ELSE 0 END --NJOW09
                                       WHEN (CON.Susr1 = 'DCNM3' OR CON.Susr2 = 'DCNM3' OR CON.Susr3 = 'DCNM3' OR CON.Susr4 = 'DCNM3' OR CON.Susr5 = 'DCNM3') AND              
                                            (SKU.ItemClass = '001') THEN 
                                                CASE WHEN ISNUMERIC(RDAY.Short) = 1 THEN CAST(RDAY.Short AS INT) ELSE 0 END --NJOW09                                           
                                  ELSE 0 END                                                                                                                                
   FROM ORDERS O (NOLOCK)
   JOIN ORDERDETAIL OD (NOLOCK) ON O.Orderkey = OD.Orderkey
   JOIN SKU (NOLOCK) ON OD.Storerkey = SKU.Storerkey AND OD.Sku = SKU.Sku
   JOIN STORER CON (NOLOCK) ON O.Consigneekey = CON.Storerkey
   OUTER APPLY (SELECT TOP 1 CL.Short FROM CODELKUP CL (NOLOCK) WHERE CL.Listname = 'MHAPRESDAY' AND CL.Code = O.Consigneekey --AND SKU.SkuGroup = CL.Long
                AND SKU.Skugroup IN(SELECT ColValue FROM dbo.fnc_DelimSplit(',',CL.Long))) RDAY --NJOW09
   WHERE O.Orderkey = @c_Orderkey
   AND OD.Sku = @c_Sku 
   AND (CON.Susr1 LIKE 'DCNM%' OR CON.Susr2 LIKE 'DCNM%' OR CON.Susr3 LIKE 'DCNM%' OR CON.Susr4 LIKE 'DCNM%' OR CON.Susr5 LIKE 'DCNM%')
   
   IF ISNULL(@n_RestrictDays,0) > 0
   BEGIN
      SET @c_Conditions = RTRIM(ISNULL(@c_Conditions,'')) + ' AND DateDiff(Day, LA.Lottable05, GetDate()) <= ' + CAST(@n_RestrictDays AS NVARCHAR(10))   
      --SET @c_Conditions = RTRIM(ISNULL(@c_Conditions,'')) + ' AND DateAdd(Day, ' + CAST(@n_RestrictDays AS NVARCHAR(10)) + ', LA.Lottable05) > GetDate() '   
   END
   --NJOW04 End
   
   --NJOW05
   IF EXISTS (SELECT 1
              FROM ORDERS O (NOLOCK)
              JOIN ORDERDETAIL OD (NOLOCK) ON O.Orderkey = OD.Orderkey
              JOIN SKU (NOLOCK) ON OD.Storerkey = SKU.Storerkey AND OD.Sku = SKU.Sku
              JOIN STORER CON (NOLOCK) ON O.Consigneekey = CON.Storerkey
              WHERE O.Orderkey = @c_Orderkey
              AND OD.Sku = @c_Sku 
              AND CON.Susr5 = 'OVASOSTATUS'
              AND SKU.OVAS = 'MHOSTATUS'
              )
   BEGIN
   	  SET @c_Lottable03 = 'O'
   END           
   
   SELECT @n_StorerMinShelfLife = ((Sku.Shelflife * Storer.MinShelflife/100) * -1)
   FROM Sku (nolock)
   JOIN Storer (nolock) ON Sku.Storerkey = Storer.Storerkey
   WHERE Sku.Sku = @c_sku
   AND Sku.Storerkey = @c_storerkey   
   
   IF @n_StorerMinShelfLife IS NULL
      SELECT @n_StorerMinShelfLife = 0

   SET @c_SQL = N'   
      DECLARE CURSOR_AVAILABLE CURSOR FAST_FORWARD READ_ONLY FOR
      SELECT LOTxLOCxID.LOT,
             LOTxLOCxID.LOC,
             LOTxLOCxID.ID,
             QTYAVAILABLE = (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QtyReplen - ISNULL(TRFLLI.FromQty,0))
      FROM LOTxLOCxID (NOLOCK)
      JOIN LOC (NOLOCK) ON (LOTxLOCxID.Loc = LOC.LOC)
      JOIN ID (NOLOCK) ON (LOTxLOCxID.Id = ID.ID)
      JOIN LOT (NOLOCK) ON (LOTXLOCXID.LOT = LOT.LOT)
      JOIN LOTATTRIBUTE LA (NOLOCK) ON LOT.LOT = LA.LOT
      JOIN SKUXLOC SL (NOLOCK) ON (LOTxLOCxID.Storerkey = SL.Storerkey AND LOTxLOCxID.Sku = SL.Sku AND LOTxLOCxID.Loc = SL.Loc)
      LEFT JOIN (SELECT TD.FromLot, TD.FromLoc, TD.FromID, SUM(TD.FromQty) AS FromQty
                 FROM TRANSFER T (NOLOCK)
                 JOIN TRANSFERDETAIL TD (NOLOCK) ON T.Transferkey = TD.Transferkey
                 WHERE TD.Status <> ''9''
                 AND TD.FromStorerkey = ''' + RTRIM(@c_StorerKey) + ''' ' +
               ' AND TD.FromSku = ''' + RTRIM(@c_Sku) + ''' ' +
               ' GROUP BY TD.FromLot, TD.FromLoc, TD.FromID) AS TRFLLI ON LOTXLOCXID.Lot = TRFLLI.FromLot 
                                                                          AND LOTXLOCXID.Loc = TRFLLI.FromLoc 
                                                                          AND LOTXLOCXID.ID = TRFLLI.FromID             
      WHERE LOC.LocationFlag <> ''HOLD''
      AND LOC.LocationFlag <> ''DAMAGE''
      AND LOC.Status <> ''HOLD''
      AND LOT.Status <> ''HOLD''
      AND ID.Status <> ''HOLD''
      AND LOC.Facility = @c_Facility
      AND (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QtyReplen - ISNULL(TRFLLI.FromQty,0)) > 0
      AND LOTxLOCxID.STORERKEY = @c_StorerKey
      AND LOTxLOCxID.SKU = @c_SKU 
      AND SL.LocationType NOT IN (''PICK'',''CASE'') ' +
      CASE WHEN @c_UOM = '1' THEN '  AND (LOTxLOCxID.QTYALLOCATED + LOTxLOCxID.QtyReplen + ISNULL(TRFLLI.FromQty,0)) = 0 ' ELSE ' ' END + 
      CASE WHEN ISNULL(RTRIM(@c_Lottable01),'') = '' THEN '' ELSE ' AND LA.Lottable01 = @c_Lottable01 ' END +
      CASE WHEN ISNULL(RTRIM(@c_Lottable02),'') = '' THEN '' ELSE ' AND LA.Lottable02 = @c_Lottable02 ' END +
      CASE WHEN ISNULL(RTRIM(@c_Lottable03),'') = '' THEN '' ELSE ' AND LA.Lottable03 = @c_Lottable03 ' END +
      CASE WHEN CONVERT(NVARCHAR(8) ,@d_Lottable04 ,112) <> '19000101' AND @d_Lottable04 IS NOT NULL THEN ' AND LA.Lottable04 = RTRIM(CONVERT( NVARCHAR(20), @d_Lottable04, 106)) ' ELSE ' ' END +
      CASE WHEN @n_StorerMinShelfLife <> 0 THEN ' AND DateAdd(Day, ' + CAST(@n_StorerMinShelfLife AS NVARCHAR(10)) + ', LA.Lottable04) > GetDate() ' ELSE ' ' END + 
      CASE WHEN CONVERT(NVARCHAR(8) ,@d_Lottable05 ,112) <> '19000101' AND @d_Lottable05 IS NOT NULL THEN ' AND LA.Lottable05 = RTRIM(CONVERT( NVARCHAR(20), @d_Lottable05, 106)) ' ELSE ' ' END +
      CASE WHEN ISNULL(RTRIM(@c_Lottable06),'') = '' THEN '' ELSE ' AND LA.Lottable06 = @c_Lottable06 ' END +
      CASE WHEN ISNULL(RTRIM(@c_Lottable07),'') = '' THEN '' ELSE ' AND LA.Lottable07 = @c_Lottable07 ' END +
      CASE WHEN ISNULL(RTRIM(@c_Lottable08),'') = '' THEN '' ELSE ' AND LA.Lottable08 = @c_Lottable08 ' END +
      CASE WHEN ISNULL(RTRIM(@c_Lottable09),'') = '' THEN '' ELSE ' AND LA.Lottable09 = @c_Lottable09 ' END +
      CASE WHEN ISNULL(RTRIM(@c_Lottable10),'') = '' THEN '' ELSE ' AND LA.Lottable10 = @c_Lottable10 ' END +
      CASE WHEN ISNULL(RTRIM(@c_Lottable11),'') = '' THEN '' ELSE ' AND LA.Lottable11 = @c_Lottable11 ' END +
      CASE WHEN ISNULL(RTRIM(@c_Lottable12),'') = '' THEN '' ELSE ' AND LA.Lottable12 = @c_Lottable12 ' END +
      CASE WHEN CONVERT(NVARCHAR(8) ,@d_Lottable13 ,112) <> '19000101' AND @d_Lottable13 IS NOT NULL THEN ' AND LA.Lottable13 = RTRIM(CONVERT( NVARCHAR(20), @d_Lottable13, 106)) ' ELSE ' ' END +
      CASE WHEN CONVERT(NVARCHAR(8) ,@d_Lottable14 ,112) <> '19000101' AND @d_Lottable14 IS NOT NULL THEN ' AND LA.Lottable14 = RTRIM(CONVERT( NVARCHAR(20), @d_Lottable14, 106)) ' ELSE ' ' END +
      CASE WHEN CONVERT(NVARCHAR(8) ,@d_Lottable15 ,112) <> '19000101' AND @d_Lottable15 IS NOT NULL THEN ' AND LA.Lottable15 = RTRIM(CONVERT( NVARCHAR(20), @d_Lottable15, 106)) ' ELSE ' ' END +
      CASE WHEN @c_UOM = '1' THEN ' AND (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QtyReplen - ISNULL(TRFLLI.FromQty,0)) <= @n_QtyLeftToFulfill ' ELSE ' ' END + 
      CASE WHEN @c_UOM <> '1' THEN ' AND (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QtyReplen - ISNULL(TRFLLI.FromQty,0)) >= @n_UOMBase ' ELSE ' ' END  +
      ' ' + RTRIM(ISNULL(@c_Conditions,'')) + ' ' + --NJOW04 
      CASE WHEN @c_UOM = '1' THEN @c_SORTUOM1 ELSE ' ' END +   --NJOW07
      CASE WHEN @c_UOM <> '1' THEN @c_SORTNOTUOM1 ELSE ' ' END   --NJOW07

   SET @c_SQLParm =  N'@c_Facility   NVARCHAR(5),  @c_StorerKey  NVARCHAR(15), @c_SKU NVARCHAR(20), @n_QtyLeftToFulfill INT, @n_UOMBase INT, ' +
                      '@c_Lottable01 NVARCHAR(18), @c_Lottable02 NVARCHAR(18), @c_Lottable03 NVARCHAR(18), @d_Lottable04 DATETIME, @d_Lottable05 DATETIME, ' +
                      '@c_Lottable06 NVARCHAR(30), @c_Lottable07 NVARCHAR(30), @c_Lottable08 NVARCHAR(30), @c_Lottable09 NVARCHAR(30), @c_Lottable10 NVARCHAR(30), ' +
                      '@c_Lottable11 NVARCHAR(30), @c_Lottable12 NVARCHAR(30), @d_Lottable13 DATETIME, @d_Lottable14 DATETIME, @d_Lottable15 DATETIME ' 

   EXEC sp_ExecuteSQL @c_SQL, @c_SQLParm, @c_Facility, @c_StorerKey, @c_SKU, @n_QtyLeftToFulfill, @n_UOMBase, @c_Lottable01, @c_Lottable02, @c_Lottable03,
                      @d_Lottable04, @d_Lottable05, @c_Lottable06, @c_Lottable07, @c_Lottable08, @c_Lottable09, @c_Lottable10, @c_Lottable11, @c_Lottable12,
                      @d_Lottable13, @d_Lottable14, @d_Lottable15

   SET @c_SQL = ''
   SET @c_PrevLOT = ''
   SET @n_LotQtyAvailable = 0

   OPEN CURSOR_AVAILABLE                    
   FETCH NEXT FROM CURSOR_AVAILABLE INTO @c_LOT, @c_LOC, @c_ID, @n_QtyAvailable   
          
   WHILE (@@FETCH_STATUS <> -1) AND (@n_QtyLeftToFulfill > 0)          
   BEGIN    
      IF @c_LOT <> @c_PrevLOT 
      BEGIN
      	 SELECT @n_LotQtyAvailable = SUM(Qty - QtyAllocated - QtyPicked)
      	        - (SELECT ISNULL(SUM(TD.FromQty),0) 
      	           FROM TRANSFER T (NOLOCK)
      	           JOIN TRANSFERDETAIL TD (NOLOCK) ON T.Transferkey = TD.Transferkey
      	           AND TD.Status <> '9' 
      	           AND TD.FromLot = LOT.Lot)      	         
      	 FROM LOT (NOLOCK)
      	 WHERE LOT = @c_LOT
       	 GROUP BY Lot
      END
      
      IF @n_LotQtyAvailable < @n_QtyAvailable 
      BEGIN
      	 IF @c_UOM = '1' 
      	    SET @n_QtyAvailable = 0
      	 ELSE
            SET @n_QtyAvailable = @n_LotQtyAvailable
      END
               	                  
      IF @c_UOM = '1' --Pallet
      BEGIN
     	   
     	   SELECT @n_LocQty = 0, @n_NoOfLot = 0
          	  
         SELECT @n_LocQty = SUM(LLI.QTY - LLI.QTYALLOCATED - LLI.QTYPICKED - LLI.QtyReplen),
                @n_NoOfLot = COUNT(DISTINCT LLI.Lot)
         FROM LOTXLOCXID LLI (NOLOCK)
         WHERE LLI.Loc = @c_LOC
         AND LLI.ID = @c_ID
         AND LLI.Storerkey = @c_Storerkey
         AND LLI.Sku = @c_Sku 
         AND LLI.Qty > 0  --NJOW07
                	        	
         IF @n_QtyLeftToFulfill >= @n_QtyAvailable 
            AND @n_NoOfLot = 1 -- if multi lot per sku/loc/id then proceed to next strategy allocation by carton
         BEGIN                	    
            SET @n_QtyToTake = @n_QtyAvailable  
         END
         ELSE
         BEGIN
         	  SET @n_QtyToTake = 0
            --GOTO EXIT_SP
         END
      END

      IF @c_UOM <> '1' --Case/Piece 
      BEGIN
      	 IF @n_QtyLeftToFulfill >= @n_QtyAvailable
      	 BEGIN
      	 		 SET @n_QtyToTake = Floor(@n_QtyAvailable / @n_UOMBase) * @n_UOMBase
      	 END
      	 ELSE
      	 BEGIN
      	 	  SET @n_QtyToTake = Floor(@n_QtyLeftToFulfill / @n_UOMBase) * @n_UOMBase
      	 END      	 
      END
      
      IF @n_QtyToTake > 0
      BEGIN
      	 IF @n_QtyToTake = @n_QtyAvailable AND @c_UOM = '1'
          	 SET @c_OtherValue = 'FULLPALLET' 
         ELSE
           	 SET @c_OtherValue = '1'       	 
      	
         IF ISNULL(@c_SQL,'') = ''
         BEGIN
            SET @c_SQL = N'   
                  DECLARE CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR   
                  SELECT '''  + @c_LOT + ''', ''' + @c_LOC + ''', ''' + @c_ID + ''', ''' + CAST(@n_QtyToTake AS NVARCHAR(10)) + ''', ''' + @c_OtherValue + '''
                  '
         END
         ELSE
         BEGIN
            SET @c_SQL = @c_SQL + N'  
                  UNION ALL
                  SELECT '''  + @c_LOT + ''', ''' + @c_LOC + ''', ''' + @c_ID + ''', ''' + CAST(@n_QtyToTake AS NVARCHAR(10)) + ''', ''' + @c_OtherValue + '''
                  '
         END
         SET @n_QtyLeftToFulfill = @n_QtyLeftToFulfill - @n_QtyToTake       
         SET @n_LotQtyAvailable = @n_LotQtyAvailable - @n_QtyToTake    
      END
      
      SET @c_PrevLOT = @c_LOT
      
      FETCH NEXT FROM CURSOR_AVAILABLE INTO @c_LOT, @c_LOC, @c_ID, @n_QtyAvailable  
   END -- END WHILE FOR CURSOR_AVAILABLE          

   EXIT_SP:

   IF CURSOR_STATUS('GLOBAL' , 'CURSOR_AVAILABLE') in (0 , 1)          
   BEGIN          
      CLOSE CURSOR_AVAILABLE          
      DEALLOCATE CURSOR_AVAILABLE          
   END    

   IF ISNULL(@c_SQL,'') <> ''
   BEGIN
      EXEC sp_ExecuteSQL @c_SQL
   END
   ELSE
   BEGIN
      DECLARE  CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR 
      SELECT TOP 0 NULL, NULL, NULL, NULL, NULL    
   END
END -- Procedure

GO
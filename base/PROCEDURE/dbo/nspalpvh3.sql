SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/    
/* Stored Procedure: nspALPVH3                                          */    
/* Creation Date: 17-OCT-2019                                           */    
/* Copyright: LFL                                                       */    
/* Written by:                                                          */    
/*                                                                      */    
/* Purpose: WMS-10919 CN PVH QHW Allocation for lottable02 = 'R'        */
/*          SkipPreallocation = '1'                                     */
/*                                                                      */
/* Called By: Wave                                                      */    
/*                                                                      */    
/* PVCS Version: 1.0                                                    */    
/*                                                                      */    
/* Version: 1.0                                                         */    
/*                                                                      */    
/* Data Modifications:                                                  */    
/*                                                                      */    
/* Updates:                                                             */    
/* Date         Author  Ver.  Purposes                                  */    
/* 12-Jan-2021  NJOW01  1.0   WMS-16073 Change allocation logic by      */
/*                            lottable02.                               */
/* 01-Sep-2021  NJOW02  1.1   WMS-17852 add shipperkey for filtering    */
/* 07-Jul-2023  NJOW03  1.2   WMS-23034 Modify loc sorting              */
/* 07-Jul-2023  NJOW03  1.2   DEVOPS Combine Script                     */
/************************************************************************/    
CREATE  PROC [dbo].[nspALPVH3]        
   @c_DocumentNo NVARCHAR(10),  
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
      
   DECLARE @c_SQL                NVARCHAR(MAX),    
           @c_SQLParm            NVARCHAR(MAX),                                   
           @c_key1               NVARCHAR(10),    
           @c_key2               NVARCHAR(5),    
           @c_key3               NCHAR(1),
           @c_Orderkey           NVARCHAR(10),     
           @n_QtyAvailable       INT,  
           @c_LOT                NVARCHAR(10),
           @c_LOC                NVARCHAR(10),
           @c_ID                 NVARCHAR(18), 
           @c_OtherValue         NVARCHAR(20),
           @n_QtyToTake          INT,
           @n_StorerMinShelfLife INT,
           @n_LotQtyAvailable    INT,
           @c_Country            NVARCHAR(30),
           @c_cond               NVARCHAR(4000),
           @c_BillToKey          NVARCHAR(15),
           @c_SortBy             NVARCHAR(2000),
           @c_UDF02              NVARCHAR(30),
           @n_LocQtyAvailable    INT,
           @n_OrderQty           INT,
           @n_TotalOrderQty      INT,
           @c_cond2              NVARCHAR(4000),
           @c_Shipperkey         NVARCHAR(15)  --NJOW02

   SET @n_QtyAvailable = 0          
   SET @c_OtherValue = '1' 
   SET @n_QtyToTake = 0

   CREATE TABLE #TMP_LOT (LOT NVARCHAR(10) NULL,
                          QtyAvailable INT NULL DEFAULT(0))
                          
   CREATE TABLE #TMP_INV (ROWID INT IDENTITY(1,1), Lot NVARCHAR(10), Loc NVARCHAR(10), ID NVARCHAR(18), Qty INT)
   
   EXEC isp_Init_Allocate_Candidates    
                             
   IF LEN(@c_OtherParms) > 0 
   BEGIN
   	  -- this pickcode can call from wave by discrete / load conso / wave conso
      SET @c_OrderKey = LEFT(@c_OtherParms,10)  --if call by discrete
      SET @c_key1 = LEFT(@c_OtherParms, 10) --Orderkey, Loadkey(conso), Wavekey(conso)
      SET @c_key2 = SUBSTRING(@c_OtherParms, 11, 5) --OrderLineNumber      	    
      SET @c_key3 = SUBSTRING(@c_OtherParms, 16, 1) --W=Wave     	          
      
      IF ISNULL(@c_key2,'')<>''  --call by order
      BEGIN      	
      	 SELECT @c_BillToKey = BillToKey,
      	        @c_Shipperkey = Shipperkey  --NJOW02      	        
      	 FROM ORDERS(NOLOCK)
      	 WHERE Orderkey = @c_Orderkey      	
      END
      ELSE
         SET @c_BillToKey = SUBSTRING(@c_OtherParms, 17, 30)          
   END
   
   SELECT @c_Country = ISOCntryCode
   FROM STORER (NOLOCK)
   WHERE Storerkey = 'PVH-' + @c_Billtokey
   AND Consigneefor = @c_Storerkey
         
   --SET @c_SortBy = 'ORDER BY LOTATTRIBUTE.Lottable02 DESC, LOTATTRIBUTE.Lottable01, LOC.LogicalLocation, LOC.LOC'   
   SET @c_SortBy = 'ORDER BY LOTATTRIBUTE.Lottable05, LOTATTRIBUTE.Lottable01, LOC.LogicalLocation, LOC.LOC'   --NJOW03
      
   SET @c_Cond = ''   
   SELECT @c_Cond = ISNULL(Notes,''),
          @c_UDF02 = ISNULL(UDF02,'')
   FROM CODELKUP (NOLOCK)
   WHERE Listname = 'PVHALLREST'    
   AND Short = @c_Country
   AND Storerkey = @c_Storerkey --NJOW01
   
   
   IF ISNULL(@c_Cond,'') <> ''
   BEGIN
     --SELECT @c_Cond = REPLACE(@c_Cond,"'","''")

     IF @c_UDF02 = 'Y'
     BEGIN
     	   IF NOT EXISTS(SELECT 1 FROM SKUINFO(NOLOCK) 
     	                 WHERE Storerkey = @c_Storerkey
     	                 AND Sku = @c_Sku)
     	   BEGIN     	   	   
            SET @c_Cond = ' AND ' + RTRIM(LTRIM(@c_Cond))
     	   END         
     	   ELSE 
     	      SET @c_Cond = ''
     END
     ELSE
     BEGIN
        SET @c_Cond = ' AND ' + RTRIM(LTRIM(@c_Cond))
     END
   END
   
   --NJOW01 S
   SET @n_TotalOrderQty = 0
         
   IF ISNULL(@c_key2,'')='' AND ISNULL(@c_key3,'')=''
   BEGIN 
      DECLARE CUR_ORD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT O.Orderkey, SUM(OD.OpenQty - OD.QtyAllocated - OD.QtyPicked)
         FROM LOADPLANDETAIL LPD (NOLOCK)
         JOIN ORDERS O (NOLOCK) ON LPD.Orderkey = O.Orderkey
         JOIN ORDERDETAIL OD (NOLOCK) ON O.Orderkey = OD.Orderkey
         WHERE LPD.Loadkey = @c_key1
         AND OD.Sku = @c_Sku         
         AND OD.Lottable01 = @c_Lottable01 
         AND OD.Lottable02 = @c_Lottable02 
         AND OD.Lottable03 = @c_Lottable03 
         AND (OD.Lottable04 = @d_Lottable04 OR @d_Lottable04 IS NULL OR CONVERT(VARCHAR(20), @d_Lottable04, 112) = '19000101') 
         AND (OD.Lottable05 = @d_Lottable05 OR @d_Lottable05 IS NULL OR CONVERT(VARCHAR(20), @d_Lottable05, 112) = '19000101')  
         AND OD.Lottable06 = @c_Lottable06 
         AND OD.Lottable07 = @c_Lottable07 
         AND OD.Lottable08 = @c_Lottable08 
         AND OD.Lottable09 = @c_Lottable09 
         AND OD.Lottable10 = @c_Lottable10 
         AND OD.Lottable11 = @c_Lottable11 
         AND OD.Lottable12 = @c_Lottable12 
         AND (OD.Lottable13 = @d_Lottable13 OR @d_Lottable13 IS NULL OR CONVERT(VARCHAR(20), @d_Lottable13, 112) = '19000101') 
         AND (OD.Lottable14 = @d_Lottable14 OR @d_Lottable14 IS NULL OR CONVERT(VARCHAR(20), @d_Lottable14, 112) = '19000101') 
         AND (OD.Lottable15 = @d_Lottable15 OR @d_Lottable15 IS NULL OR CONVERT(VARCHAR(20), @d_Lottable15, 112) = '19000101')                            
         GROUP BY O.Orderkey
   END
   ELSE IF ISNULL(@c_key2,'')='' AND ISNULL(@c_key3,'')='W'
   BEGIN
      DECLARE CUR_ORD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT O.Orderkey, SUM(OD.OpenQty - OD.QtyAllocated - OD.QtyPicked)
         FROM WAVEDETAIL WD (NOLOCK)
         JOIN ORDERS O (NOLOCK) ON WD.Orderkey = O.Orderkey
         JOIN ORDERDETAIL OD (NOLOCK) ON O.Orderkey = OD.Orderkey
         WHERE WD.Wavekey = @c_key1         
         AND OD.Sku = @c_Sku         
         AND OD.Lottable01 = @c_Lottable01 
         AND OD.Lottable02 = @c_Lottable02 
         AND OD.Lottable03 = @c_Lottable03 
         AND (OD.Lottable04 = @d_Lottable04 OR @d_Lottable04 IS NULL OR CONVERT(VARCHAR(20), @d_Lottable04, 112) = '19000101') 
         AND (OD.Lottable05 = @d_Lottable05 OR @d_Lottable05 IS NULL OR CONVERT(VARCHAR(20), @d_Lottable05, 112) = '19000101')  
         AND OD.Lottable06 = @c_Lottable06 
         AND OD.Lottable07 = @c_Lottable07 
         AND OD.Lottable08 = @c_Lottable08 
         AND OD.Lottable09 = @c_Lottable09 
         AND OD.Lottable10 = @c_Lottable10 
         AND OD.Lottable11 = @c_Lottable11 
         AND OD.Lottable12 = @c_Lottable12 
         AND (OD.Lottable13 = @d_Lottable13 OR @d_Lottable13 IS NULL OR CONVERT(VARCHAR(20), @d_Lottable13, 112) = '19000101') 
         AND (OD.Lottable14 = @d_Lottable14 OR @d_Lottable14 IS NULL OR CONVERT(VARCHAR(20), @d_Lottable14, 112) = '19000101') 
         AND (OD.Lottable15 = @d_Lottable15 OR @d_Lottable15 IS NULL OR CONVERT(VARCHAR(20), @d_Lottable15, 112) = '19000101')                            
         GROUP BY O.Orderkey
   END
   ELSE
   BEGIN
     DECLARE CUR_ORD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
        SELECT NULL, 0
        FROM ORDERS (NOLOCK)
        WHERE 1=2
      
     SET @n_TotalOrderQty = @n_QtyLeftToFulfill 
   END     
   
   OPEN CUR_ORD                                       	           
                                                                                  	           
   FETCH NEXT FROM CUR_ORD INTO @c_Orderkey, @n_OrderQty
   
   WHILE (@@FETCH_STATUS <> -1) 
   BEGIN
      SET @c_Cond2 = ''
      SET @c_UDF02 = ''   
      SET @c_BillTokey = ''
      SET @c_Country = ''
      SET @c_Shipperkey = '' --NJOW02

    	SELECT @c_BillToKey = BillToKey,    	
      	     @c_Shipperkey = Shipperkey  --NJOW02      	            	      	        
      FROM ORDERS(NOLOCK)
      WHERE Orderkey = @c_Orderkey      	

      SELECT @c_Country = ISOCntryCode
      FROM STORER (NOLOCK)
      WHERE Storerkey = 'PVH-' + @c_Billtokey
      AND Consigneefor = @c_Storerkey

      SELECT @c_Cond2 = ISNULL(Notes,''),
             @c_UDF02 = ISNULL(UDF02,'')
      FROM CODELKUP (NOLOCK)
      WHERE Listname = 'PVHALLREST'    
      AND Short = @c_Country
      AND Storerkey = @c_Storerkey --NJOW01
            
      IF ISNULL(@c_Cond2,'') <> ''
      BEGIN      
        IF @c_UDF02 = 'Y'
        BEGIN
        	   IF NOT EXISTS(SELECT 1 FROM SKUINFO(NOLOCK) 
        	                 WHERE Storerkey = @c_Storerkey
        	                 AND Sku = @c_Sku)
        	   BEGIN     	   	   
               SET @c_Cond2 = ' AND ' + RTRIM(LTRIM(@c_Cond2))
        	   END         
        	   ELSE 
        	      SET @c_Cond2 = ''
        END
        ELSE
        BEGIN
           SET @c_Cond2 = ' AND ' + RTRIM(LTRIM(@c_Cond2))
        END
      END
      
      IF @c_Cond = @c_Cond2
         SET @n_TotalOrderQty = @n_TotalOrderQty + @n_OrderQty
      	  
      FETCH NEXT FROM CUR_ORD INTO @c_Orderkey, @n_OrderQty
   END 
   CLOSE CUR_ORD
   DEALLOCATE CUR_ORD
   --NJOW01 E
   
   SET @c_Cond = RTRIM(ISNULL(@c_Cond,'')) + ' AND LOTATTRIBUTE.Lottable02 = ''R'' '  --NJOW01
   
   SELECT @n_StorerMinShelfLife = ((Sku.Shelflife * Storer.MinShelflife/100) * -1)
   FROM Sku (nolock)
   JOIN Storer (nolock) ON Sku.Storerkey = Storer.Storerkey
   WHERE Sku.Sku = @c_sku
   AND Sku.Storerkey = @c_storerkey   
   
   IF @n_StorerMinShelfLife IS NULL
      SELECT @n_StorerMinShelfLife = 0
         
   SET @c_SQL = N'   
      INSERT INTO #TMP_INV (Lot, Loc, ID, Qty)
      SELECT LOTxLOCxID.LOT,      
             LOTxLOCxID.LOC,
             LOTxLOCxID.ID,             
             QTYAVAILABLE = LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QtyReplen
      FROM LOTxLOCxID (NOLOCK)
      JOIN LOC (NOLOCK) ON (LOTxLOCxID.Loc = LOC.LOC)
      JOIN ID (NOLOCK) ON (LOTxLOCxID.Id = ID.ID)
      JOIN LOT (NOLOCK) ON (LOTXLOCXID.LOT = LOT.LOT)
      JOIN LOTATTRIBUTE (NOLOCK) ON LOT.LOT = LOTATTRIBUTE.LOT
      JOIN SKUXLOC SL (NOLOCK) ON (LOTxLOCxID.Storerkey = SL.Storerkey AND LOTxLOCxID.Sku = SL.Sku AND LOTxLOCxID.Loc = SL.Loc)
      WHERE LOC.LocationFlag = ''NONE''
      AND LOC.Status = ''OK''
      AND LOT.Status = ''OK''
      AND ID.Status = ''OK''
      AND LOC.Facility = @c_Facility
      AND LOTxLOCxID.STORERKEY = @c_StorerKey
      AND LOTxLOCxID.SKU = @c_SKU 
      AND (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QtyReplen) > 0 ' +
      ISNULL(@c_Cond,'') + ' ' +
      CASE WHEN ISNULL(RTRIM(@c_Lottable01),'') = '' THEN '' ELSE ' AND LOTATTRIBUTE.Lottable01 = @c_Lottable01 ' END +
      CASE WHEN ISNULL(RTRIM(@c_Lottable02),'') = '' THEN '' ELSE ' AND LOTATTRIBUTE.Lottable02 = @c_Lottable02 ' END +
      CASE WHEN ISNULL(RTRIM(@c_Lottable03),'') = '' THEN '' ELSE ' AND LOTATTRIBUTE.Lottable03 = @c_Lottable03 ' END +
      CASE WHEN CONVERT(NVARCHAR(8) ,@d_Lottable04 ,112) <> '19000101' AND @d_Lottable04 IS NOT NULL THEN ' AND LOTATTRIBUTE.Lottable04 = RTRIM(CONVERT( NVARCHAR(20), @d_Lottable04, 106)) ' ELSE ' ' END +
      CASE WHEN @n_StorerMinShelfLife <> 0 THEN ' AND DateAdd(Day, ' + CAST(@n_StorerMinShelfLife AS NVARCHAR(10)) + ', LOTATTRIBUTE.Lottable04) > GetDate() ' ELSE ' ' END + 
      CASE WHEN CONVERT(NVARCHAR(8) ,@d_Lottable05 ,112) <> '19000101' AND @d_Lottable05 IS NOT NULL THEN ' AND LOTATTRIBUTE.Lottable05 = RTRIM(CONVERT( NVARCHAR(20), @d_Lottable05, 106)) ' ELSE ' ' END +
      CASE WHEN ISNULL(RTRIM(@c_Lottable06),'') = '' THEN '' ELSE ' AND LOTATTRIBUTE.Lottable06 = @c_Lottable06 ' END +
      CASE WHEN ISNULL(RTRIM(@c_Lottable07),'') = '' THEN '' ELSE ' AND LOTATTRIBUTE.Lottable07 = @c_Lottable07 ' END +
      CASE WHEN ISNULL(RTRIM(@c_Lottable08),'') = '' THEN '' ELSE ' AND LOTATTRIBUTE.Lottable08 = @c_Lottable08 ' END +
      CASE WHEN ISNULL(RTRIM(@c_Lottable09),'') = '' THEN '' ELSE ' AND LOTATTRIBUTE.Lottable09 = @c_Lottable09 ' END +
      CASE WHEN ISNULL(RTRIM(@c_Lottable10),'') = '' THEN '' ELSE ' AND LOTATTRIBUTE.Lottable10 = @c_Lottable10 ' END +
      CASE WHEN ISNULL(RTRIM(@c_Lottable11),'') = '' THEN '' ELSE ' AND LOTATTRIBUTE.Lottable11 = @c_Lottable11 ' END +
      CASE WHEN ISNULL(RTRIM(@c_Lottable12),'') = '' THEN '' ELSE ' AND LOTATTRIBUTE.Lottable12 = @c_Lottable12 ' END +
      CASE WHEN CONVERT(NVARCHAR(8) ,@d_Lottable13 ,112) <> '19000101' AND @d_Lottable13 IS NOT NULL THEN ' AND LOTATTRIBUTE.Lottable13 = RTRIM(CONVERT( NVARCHAR(20), @d_Lottable13, 106)) ' ELSE ' ' END +
      CASE WHEN CONVERT(NVARCHAR(8) ,@d_Lottable14 ,112) <> '19000101' AND @d_Lottable14 IS NOT NULL THEN ' AND LOTATTRIBUTE.Lottable14 = RTRIM(CONVERT( NVARCHAR(20), @d_Lottable14, 106)) ' ELSE ' ' END +
      CASE WHEN CONVERT(NVARCHAR(8) ,@d_Lottable15 ,112) <> '19000101' AND @d_Lottable15 IS NOT NULL THEN ' AND LOTATTRIBUTE.Lottable15 = RTRIM(CONVERT( NVARCHAR(20), @d_Lottable15, 106)) ' ELSE ' ' END +
      RTRIM(@c_SortBy)
       
   SET @c_SQLParm =  N'@c_Facility   NVARCHAR(5),  @c_StorerKey  NVARCHAR(15), @c_SKU NVARCHAR(20), @n_QtyLeftToFulfill INT, @n_UOMBase INT, ' +
                      '@c_Lottable01 NVARCHAR(18), @c_Lottable02 NVARCHAR(18), @c_Lottable03 NVARCHAR(18), @d_Lottable04 DATETIME, @d_Lottable05 DATETIME, ' +
                      '@c_Lottable06 NVARCHAR(30), @c_Lottable07 NVARCHAR(30), @c_Lottable08 NVARCHAR(30), @c_Lottable09 NVARCHAR(30), @c_Lottable10 NVARCHAR(30), ' +
                      '@c_Lottable11 NVARCHAR(30), @c_Lottable12 NVARCHAR(30), @d_Lottable13 DATETIME, @d_Lottable14 DATETIME, @d_Lottable15 DATETIME, @c_Shipperkey NVARCHAR(15) ' 

   EXEC sp_ExecuteSQL @c_SQL, @c_SQLParm, @c_Facility, @c_StorerKey, @c_SKU, @n_QtyLeftToFulfill, @n_UOMBase, @c_Lottable01, @c_Lottable02, @c_Lottable03,
                      @d_Lottable04, @d_Lottable05, @c_Lottable06, @c_Lottable07, @c_Lottable08, @c_Lottable09, @c_Lottable10, @c_Lottable11, @c_Lottable12,
                      @d_Lottable13, @d_Lottable14, @d_Lottable15, @c_Shipperkey  --NJOW02
            
   WHILE @n_QtyLeftToFulfill > 0
   BEGIN
      SELECT TOP 1 @c_Loc = TI.LOC, @n_LocQtyAvailable = SUM(TI.Qty)
      FROM #TMP_INV TI
      JOIN LOTATTRIBUTE LA (NOLOCK) ON TI.Lot = LA.Lot     --NJOW03 
      GROUP BY TI.LOC	
      ORDER BY MIN(LA.Lottable05), --NJOW03
               CASE WHEN SUM(TI.Qty) < @n_TotalOrderQty THEN 1  --NJOW03
                    WHEN SUM(TI.Qty) = @n_TotalOrderQty THEN 2  --NJOW03
               ELSE 3 END,
               MIN(TI.RowID)
      
      IF @@ROWCOUNT = 0
         BREAK
                
      DECLARE CURSOR_AVAILABLE CURSOR FAST_FORWARD READ_ONLY FOR
         SELECT I.Lot, I.ID, I.Qty         
         FROM #TMP_INV I
         WHERE I.Loc = @c_Loc
         ORDER BY I.Lot

      OPEN CURSOR_AVAILABLE 
      
      FETCH NEXT FROM CURSOR_AVAILABLE INTO @c_LOT, @c_ID, @n_QtyAvailable   
                
      SET @c_SQL = ''    
      WHILE (@@FETCH_STATUS <> -1) AND (@n_QtyLeftToFulfill > 0)    
      BEGIN
   	     IF NOT EXISTS(SELECT 1 FROM #TMP_LOT WHERE Lot = @c_Lot)
   	     BEGIN
   	     	 INSERT INTO #TMP_LOT (Lot, QtyAvailable)
   	     	 SELECT Lot, Qty - QtyAllocated - QtyPicked
         	 FROM LOT (NOLOCK)
         	 WHERE LOT = @c_LOT       	 
   	     END
   	     
         SET @n_LotQtyAvailable = 0
         
         SELECT @n_LotQtyAvailable = QtyAvailable
         FROM #TMP_LOT 
         WHERE Lot = @c_Lot   	  
   	         
         IF @n_LotQtyAvailable < @n_QtyAvailable 
         BEGIN
         	 IF @c_UOM IN('1')  
         	    SET @n_QtyAvailable = 0
         	 ELSE
              SET @n_QtyAvailable = @n_LotQtyAvailable
         END

         IF @n_QtyLeftToFulfill >= @n_QtyAvailable
         BEGIN
         		SET @n_QtyToTake = Floor(@n_QtyAvailable / @n_UOMBase) * @n_UOMBase
         END
         ELSE
         BEGIN
         	  SET @n_QtyToTake = Floor(@n_QtyLeftToFulfill / @n_UOMBase) * @n_UOMBase
         END  
      
         IF @n_QtyToTake > 0
         BEGIN      	
   	     	  UPDATE #TMP_LOT
   	     	  SET QtyAvailable = QtyAvailable - @n_QtyToTake 
   	     	  WHERE Lot = @c_Lot
   	     	     	     	           	
            /*IF ISNULL(@c_SQL,'') = ''
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
            END*/
            
            SET @c_Lot = RTRIM(@c_Lot)             
            SET @c_Loc = RTRIM(@c_Loc)
            SET @c_ID  = RTRIM(@c_ID)
            
            EXEC isp_Insert_Allocate_Candidates
               @c_Lot = @c_Lot
            ,  @c_Loc = @c_Loc
            ,  @c_ID  = @c_ID
            ,  @n_QtyAvailable = @n_QtyToTake
            ,  @c_OtherValue = @c_OtherValue
            
            SET @n_QtyLeftToFulfill = @n_QtyLeftToFulfill - @n_QtyToTake       
            SET @n_TotalOrderQty = @n_TotalOrderQty - @n_QtyToTake
         END
        	 
         FETCH NEXT FROM CURSOR_AVAILABLE INTO @c_LOT, @c_ID, @n_QtyAvailable   
      END       	      	  
      CLOSE CURSOR_AVAILABLE
      DEALLOCATE CURSOR_AVAILABLE       
      
      DELETE FROM #TMP_INV WHERE Loc = @c_Loc              	  
   END                   

   /*
   SET @c_SQL = N'   
      DECLARE CURSOR_AVAILABLE CURSOR FAST_FORWARD READ_ONLY FOR
      SELECT LOTxLOCxID.LOT,
             LOTxLOCxID.LOC,
             LOTxLOCxID.ID,
             QTYAVAILABLE = (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QtyReplen)
      FROM LOTxLOCxID (NOLOCK)
      JOIN LOC (NOLOCK) ON (LOTxLOCxID.Loc = LOC.LOC)
      JOIN ID (NOLOCK) ON (LOTxLOCxID.Id = ID.ID)
      JOIN LOT (NOLOCK) ON (LOTXLOCXID.LOT = LOT.LOT)
      JOIN LOTATTRIBUTE (NOLOCK) ON LOT.LOT = LOTATTRIBUTE.LOT
      JOIN SKUXLOC SL (NOLOCK) ON (LOTxLOCxID.Storerkey = SL.Storerkey AND LOTxLOCxID.Sku = SL.Sku AND LOTxLOCxID.Loc = SL.Loc)
      WHERE LOC.LocationFlag = ''NONE''
      AND LOC.Status = ''OK''
      AND LOT.Status = ''OK''
      AND ID.Status = ''OK''
      AND LOC.Facility = @c_Facility
      AND LOTxLOCxID.STORERKEY = @c_StorerKey
      AND LOTxLOCxID.SKU = @c_SKU 
      AND (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QtyReplen) >= @n_UOMBase ' +
      ISNULL(@c_Cond,'') + ' ' +
      CASE WHEN ISNULL(RTRIM(@c_Lottable01),'') = '' THEN '' ELSE ' AND LOTATTRIBUTE.Lottable01 = @c_Lottable01 ' END +
      CASE WHEN ISNULL(RTRIM(@c_Lottable02),'') = '' THEN '' ELSE ' AND LOTATTRIBUTE.Lottable02 = @c_Lottable02 ' END +
      CASE WHEN ISNULL(RTRIM(@c_Lottable03),'') = '' THEN '' ELSE ' AND LOTATTRIBUTE.Lottable03 = @c_Lottable03 ' END +
      CASE WHEN CONVERT(NVARCHAR(8) ,@d_Lottable04 ,112) <> '19000101' AND @d_Lottable04 IS NOT NULL THEN ' AND LOTATTRIBUTE.Lottable04 = RTRIM(CONVERT( NVARCHAR(20), @d_Lottable04, 106)) ' ELSE ' ' END +
      CASE WHEN @n_StorerMinShelfLife <> 0 THEN ' AND DateAdd(Day, ' + CAST(@n_StorerMinShelfLife AS NVARCHAR(10)) + ', LOTATTRIBUTE.Lottable04) > GetDate() ' ELSE ' ' END + 
      CASE WHEN CONVERT(NVARCHAR(8) ,@d_Lottable05 ,112) <> '19000101' AND @d_Lottable05 IS NOT NULL THEN ' AND LOTATTRIBUTE.Lottable05 = RTRIM(CONVERT( NVARCHAR(20), @d_Lottable05, 106)) ' ELSE ' ' END +
      CASE WHEN ISNULL(RTRIM(@c_Lottable06),'') = '' THEN '' ELSE ' AND LOTATTRIBUTE.Lottable06 = @c_Lottable06 ' END +
      CASE WHEN ISNULL(RTRIM(@c_Lottable07),'') = '' THEN '' ELSE ' AND LOTATTRIBUTE.Lottable07 = @c_Lottable07 ' END +
      CASE WHEN ISNULL(RTRIM(@c_Lottable08),'') = '' THEN '' ELSE ' AND LOTATTRIBUTE.Lottable08 = @c_Lottable08 ' END +
      CASE WHEN ISNULL(RTRIM(@c_Lottable09),'') = '' THEN '' ELSE ' AND LOTATTRIBUTE.Lottable09 = @c_Lottable09 ' END +
      CASE WHEN ISNULL(RTRIM(@c_Lottable10),'') = '' THEN '' ELSE ' AND LOTATTRIBUTE.Lottable10 = @c_Lottable10 ' END +
      CASE WHEN ISNULL(RTRIM(@c_Lottable11),'') = '' THEN '' ELSE ' AND LOTATTRIBUTE.Lottable11 = @c_Lottable11 ' END +
      CASE WHEN ISNULL(RTRIM(@c_Lottable12),'') = '' THEN '' ELSE ' AND LOTATTRIBUTE.Lottable12 = @c_Lottable12 ' END +
      CASE WHEN CONVERT(NVARCHAR(8) ,@d_Lottable13 ,112) <> '19000101' AND @d_Lottable13 IS NOT NULL THEN ' AND LOTATTRIBUTE.Lottable13 = RTRIM(CONVERT( NVARCHAR(20), @d_Lottable13, 106)) ' ELSE ' ' END +
      CASE WHEN CONVERT(NVARCHAR(8) ,@d_Lottable14 ,112) <> '19000101' AND @d_Lottable14 IS NOT NULL THEN ' AND LOTATTRIBUTE.Lottable14 = RTRIM(CONVERT( NVARCHAR(20), @d_Lottable14, 106)) ' ELSE ' ' END +
      CASE WHEN CONVERT(NVARCHAR(8) ,@d_Lottable15 ,112) <> '19000101' AND @d_Lottable15 IS NOT NULL THEN ' AND LOTATTRIBUTE.Lottable15 = RTRIM(CONVERT( NVARCHAR(20), @d_Lottable15, 106)) ' ELSE ' ' END +
      RTRIM(@c_SortBy)  

   SET @c_SQLParm =  N'@c_Facility   NVARCHAR(5),  @c_StorerKey  NVARCHAR(15), @c_SKU NVARCHAR(20), @n_QtyLeftToFulfill INT, @n_UOMBase INT, ' +
                      '@c_Lottable01 NVARCHAR(18), @c_Lottable02 NVARCHAR(18), @c_Lottable03 NVARCHAR(18), @d_Lottable04 DATETIME, @d_Lottable05 DATETIME, ' +
                      '@c_Lottable06 NVARCHAR(30), @c_Lottable07 NVARCHAR(30), @c_Lottable08 NVARCHAR(30), @c_Lottable09 NVARCHAR(30), @c_Lottable10 NVARCHAR(30), ' +
                      '@c_Lottable11 NVARCHAR(30), @c_Lottable12 NVARCHAR(30), @d_Lottable13 DATETIME, @d_Lottable14 DATETIME, @d_Lottable15 DATETIME ' 

   EXEC sp_ExecuteSQL @c_SQL, @c_SQLParm, @c_Facility, @c_StorerKey, @c_SKU, @n_QtyLeftToFulfill, @n_UOMBase, @c_Lottable01, @c_Lottable02, @c_Lottable03,
                      @d_Lottable04, @d_Lottable05, @c_Lottable06, @c_Lottable07, @c_Lottable08, @c_Lottable09, @c_Lottable10, @c_Lottable11, @c_Lottable12,
                      @d_Lottable13, @d_Lottable14, @d_Lottable15

   SET @c_SQL = ''
   
   OPEN CURSOR_AVAILABLE                    
   FETCH NEXT FROM CURSOR_AVAILABLE INTO @c_LOT, @c_LOC, @c_ID, @n_QtyAvailable   
          
   WHILE (@@FETCH_STATUS <> -1) AND (@n_QtyLeftToFulfill > 0)          
   BEGIN       	      	  
   	  IF NOT EXISTS(SELECT 1 FROM #TMP_LOT WHERE Lot = @c_Lot)
   	  BEGIN
   	  	 INSERT INTO #TMP_LOT (Lot, QtyAvailable)
   	  	 SELECT Lot, Qty - QtyAllocated - QtyPicked
      	 FROM LOT (NOLOCK)
      	 WHERE LOT = @c_LOT       	 
   	  END
   	  
      SET @n_LotQtyAvailable = 0

      SELECT @n_LotQtyAvailable = QtyAvailable
      FROM #TMP_LOT 
      WHERE Lot = @c_Lot   	  
   	      
      IF @n_LotQtyAvailable < @n_QtyAvailable 
      BEGIN
      	 IF @c_UOM IN('1')  
      	    SET @n_QtyAvailable = 0
      	 ELSE
            SET @n_QtyAvailable = @n_LotQtyAvailable
      END
  
      IF @n_QtyLeftToFulfill >= @n_QtyAvailable
      BEGIN
      		 SET @n_QtyToTake = Floor(@n_QtyAvailable / @n_UOMBase) * @n_UOMBase
      END
      ELSE
      BEGIN
      	  SET @n_QtyToTake = Floor(@n_QtyLeftToFulfill / @n_UOMBase) * @n_UOMBase
      END  
      
      IF @n_QtyToTake > 0
      BEGIN      	
   	  	 UPDATE #TMP_LOT
   	  	 SET QtyAvailable = QtyAvailable - @n_QtyToTake 
   	  	 WHERE Lot = @c_Lot
      	
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
      END
            
      FETCH NEXT FROM CURSOR_AVAILABLE INTO @c_LOT, @c_LOC, @c_ID, @n_QtyAvailable  
   END -- END WHILE FOR CURSOR_AVAILABLE       
   */   

   EXIT_SP:

   IF CURSOR_STATUS('GLOBAL' , 'CURSOR_AVAILABLE') in (0 , 1)          
   BEGIN          
      CLOSE CURSOR_AVAILABLE          
      DEALLOCATE CURSOR_AVAILABLE          
   END    

   EXEC isp_Cursor_Allocate_Candidates                      
         @n_SkipPreAllocationFlag = 1--Return Lot column   

   /*         
   IF ISNULL(@c_SQL,'') <> ''
   BEGIN
      EXEC sp_ExecuteSQL @c_SQL
   END
   ELSE
   BEGIN
      DECLARE  CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR 
      SELECT TOP 0 NULL, NULL, NULL, NULL, NULL    
   END
   */
END -- Procedure

GO
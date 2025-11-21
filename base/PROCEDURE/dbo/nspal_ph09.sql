SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/    
/* Stored Procedure: nspAL_PH09                                         */    
/* Creation Date: 07-DEC-2021                                           */    
/* Copyright: LFL                                                       */    
/* Written by:                                                          */    
/*                                                                      */    
/* Purpose: WMS-18447 P&G Allocation                                    */
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
/* 13-Dec-2021  NJOW    1.0   DEVOPS combine script                     */
/************************************************************************/    
CREATE PROC [dbo].[nspAL_PH09]        
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

   IF @n_UOMBase = 0
     SET @n_UOMBase = 1
     
   DECLARE @b_debug                   INT      
          ,@c_SQL                     NVARCHAR(MAX)    
          ,@c_SQLParm                 NVARCHAR(MAX)    
          
   DECLARE @n_QtyAvailable            INT 
          ,@c_LOT                     NVARCHAR(10)
          ,@c_LOC                     NVARCHAR(10)
          ,@c_ID                      NVARCHAR(18) 
          ,@c_OtherValue              NVARCHAR(20)
          ,@n_QtyToTake               INT
          ,@c_PrevLOT                 NVARCHAR(10)
          ,@n_LotQtyAvailable         INT
          ,@n_LocQty                  INT
          ,@n_NoOfLot                 INT 
          ,@c_Conditions              NVARCHAR(2000) 
          ,@c_Key1                    NVARCHAR(10)
          ,@c_Key2                    NVARCHAR(5)
          ,@c_Key3                    NVARCHAR(1) 
          ,@c_LottableList            NVARCHAR(1000)
          ,@n_ConsigneeShelfLife      INT  
          ,@c_Consigneekey            NVARCHAR(15)  
          ,@c_ConSusr1                NVARCHAR(10)  
          ,@c_SortMode                NVARCHAR(20)  
          ,@c_OrderBy                 NVARCHAR(2000)  
          ,@n_SkuOutgoingShelfLife    INT 
          ,@n_SkuShelfLife            INT
          ,@c_AllocateByConsNewExpiry NVARCHAR(30)   
          ,@c_FromTableJoin           NVARCHAR(500)  
             
   SET @b_debug = 0
   SET @n_QtyAvailable = 0          
   SET @c_OtherValue = '1' 
   SET @n_QtyToTake = 0
   SET @c_Conditions = '' 
   SET @c_FromTableJoin = ''   

   EXEC isp_Init_Allocate_Candidates

   CREATE TABLE #TMP_LOT (LOT NVARCHAR(10) NULL,
                          QtyAvailable INT NULL DEFAULT(0))
   
   IF LEN(@c_OtherParms) > 0 
   BEGIN
      SET @c_OrderKey = LEFT(@c_OtherParms,10) 
      SET @c_key1 = LEFT(@c_OtherParms, 10) --Orderkey, Loadkey(conso), Wavekey(conso)
      SET @c_key2 = SUBSTRING(@c_OtherParms, 11, 5) --OrderLineNumber      	    
      SET @c_key3 = SUBSTRING(@c_OtherParms, 16, 1) --W=Wave     	    
            
      IF ISNULL(@c_key1,'')<>'' AND ISNULL(@c_key2,'')<>''  
      BEGIN  
         SELECT TOP 1 @c_Consigneekey = ORDERS.Consigneekey,  
                 @c_ConSusr1 = STORER.Susr1,  
                 @c_SortMode = STORER.Susr2  
         FROM ORDERS(NOLOCK)  
         JOIN STORER (NOLOCK)ON ORDERS.Consigneekey = STORER.Storerkey  
         WHERE ORDERS.Orderkey = @c_key1  

         SELECT @n_ConsigneeShelfLife = ISNULL( STORER.MinShelfLife, 0)  
         FROM   ORDERS (NOLOCK)  
         JOIN   STORER (NOLOCK) ON (ORDERS.ConsigneeKey = STORER.StorerKey)  
         WHERE  ORDERS.OrderKey = @c_key1               
      END   
                             
      IF ISNULL(@c_key1,'')<>'' AND ISNULL(@c_key2,'')='' --call by load/wave conso  
      BEGIN  
         SELECT @c_Consigneekey = SUBSTRING(@c_OtherParms, 17, 15)  
        
         IF ISNULL(@c_Consigneekey,'')='' AND ISNULL(@c_key3,'')='' --Load plan
         BEGIN
         	  SELECT TOP 1 @c_Consigneekey = O.Consigneekey,
         	               @c_ConSusr1 = S.Susr1,  
                         @c_SortMode = S.Susr2   
         	  FROM LOADPLANDETAIL LPD (NOLOCK)
         	  JOIN ORDERS O (NOLOCK) ON LPD.Orderkey = O.Orderkey
         	  JOIN STORER S (NOLOCK) ON O.Consigneekey = S.Storerkey
         	  WHERE LPD.Loadkey = @c_key1
         END
         ELSE
         BEGIN
            SELECT TOP 1 @c_Consigneekey = STORER.Storerkey,  
                         @c_ConSusr1 = STORER.Susr1,  
                         @c_SortMode = STORER.Susr2  
            FROM STORER (NOLOCK)  
            WHERE STORER.Storerkey = @c_Consigneekey
         END               

         SELECT @n_ConsigneeShelfLife = ISNULL( STORER.MinShelfLife, 0)  
         FROM STORER (NOLOCK)   
         WHERE Storerkey = @c_Consigneekey               
      END                                               
   END
   
   --get lottable filtering logic  
   SET @c_LottableList = ''  
   SELECT @c_LottableList = @c_LottableList + code + ' '   
   FROM CODELKUP(NOLOCK)   
   WHERE listname = 'AllocLot'  
   AND Storerkey = @c_Storerkey  

   IF ISNULL(@c_SortMode,'') = 'LEFO'  
   BEGIN    
      IF @c_UOM = '1'                       
         SET @c_OrderBy = ' ORDER BY LA.Lottable04 DESC, LA.Lottable05, LOT.Lot, LOC.LogicalLocation, LOC.LOC  '  
      ELSE IF @c_UOM = '2'  
         SET @c_OrderBy = ' ORDER BY CASE WHEN LOC.LocationType = ''CASE'' THEN 1 WHEN LOC.LocationType = ''PICK'' THEN 2 ELSE 3 END, LA.Lottable04 DESC, LA.Lottable05, LOT.Lot, LOC.LogicalLocation, LOC.LOC '  
      ELSE --uom 6  
         SET @c_OrderBy = ' ORDER BY CASE WHEN LOC.LocationType = ''PICK'' THEN 1 WHEN LOC.LocationType = ''CASE'' THEN 2 ELSE 3 END, LA.Lottable04 DESC, LA.Lottable05, LOT.Lot, LOC.LogicalLocation, LOC.LOC '              
   END     
   ELSE --FEFO  
   BEGIN  
      IF @c_UOM = '1'                       
         SET @c_OrderBy = ' ORDER BY LA.LOTTABLE04, LA.Lottable05, LOT.Lot, LOC.LogicalLocation, LOC.LOC '  
      ELSE IF @c_UOM = '2'  
         SET @c_OrderBy = ' ORDER BY CASE WHEN LOC.LocationType = ''CASE'' THEN 1 WHEN LOC.LocationType = ''PICK'' THEN 2 ELSE 3 END, LA.Lottable04, LA.Lottable05, LOT.Lot, LOC.LogicalLocation, LOC.LOC '  
      ELSE --uom 6  
         SET @c_OrderBy = ' ORDER BY CASE WHEN LOC.LocationType = ''PICK'' THEN 1 WHEN LOC.LocationType = ''CASE'' THEN 2 ELSE 3 END, LA.Lottable04, LA.Lottable05, LOT.Lot, LOC.LogicalLocation, LOC.LOC '              
   END                 
   
   SELECT @n_SkuShelfLife = SKU.Shelflife,   
          @n_SkuOutgoingShelfLife = ISNULL( CAST( SKU.SUSR2 as int), 0)  
   FROM  SKU (NOLOCK)  
   WHERE SKU.StorerKey = @c_storerkey  
   AND SKU.SKU = @c_sku  
                
   IF ISNULL(@n_ConsigneeShelfLife, 0) > 0  
   BEGIN  
      SELECT @c_Conditions =  RTRIM(ISNULL(@c_Conditions,'')) + ' AND DATEADD (Day, @n_ConsigneeShelfLife * -1, Lottable04) >= GetDate() '              
   END  
   ELSE IF ISNULL(@n_SkuOutgoingShelfLife, 0) > 0  
   BEGIN  
      SELECT @c_Conditions =  RTRIM(ISNULL(@c_Conditions,'')) + ' AND DATEADD (Day, @n_SkuOutgoingShelfLife * -1, Lottable04) >= GetDate() '    
   END                  
   
   SELECT @c_AllocateByConsNewExpiry = dbo.fnc_GetRight(@c_Facility, @c_Storerkey, '', 'AllocateByConsNewExpiry')   

   IF ISNULL(@c_AllocateByConsNewExpiry,'') = '1' AND ISNULL(@c_Consigneekey,'') <> '' AND ISNULL(@c_ConSusr1 ,'') IN('Y','nspPRTH01')  
   BEGIN  
      SELECT @c_FromTableJoin = ' LEFT JOIN CONSIGNEESKU WITH (NOLOCK) ON (CONSIGNEESKU.Consigneekey = RTRIM(ISNULL(@c_Consigneekey,'''')) ) '  
                                                        +  ' AND (CONSIGNEESKU.ConsigneeSku = LOT.Sku) '  
      SELECT @c_Conditions =  RTRIM(ISNULL(@c_Conditions,'')) + ' AND (LA.Lottable04 >= ISNULL(CONSIGNEESKU.AddDate,CONVERT(DATETIME,''19000101''))) '         
   END  
    
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
                 AND TD.FromStorerkey = @c_Storerkey
                 AND TD.FromSku = @c_Sku 
                 GROUP BY TD.FromLot, TD.FromLoc, TD.FromID) AS TRFLLI ON LOTXLOCXID.Lot = TRFLLI.FromLot 
                                                                          AND LOTXLOCXID.Loc = TRFLLI.FromLoc 
                                                                          AND LOTXLOCXID.ID = TRFLLI.FromID ' +
      RTRIM(@c_FromTableJoin) +                                                                                     
    ' WHERE LOC.LocationFlag <> ''HOLD''
      AND LOC.LocationFlag <> ''DAMAGE''
      AND LOC.Status <> ''HOLD''
      AND LOT.Status <> ''HOLD''
      AND ID.Status <> ''HOLD''
      AND LOC.Facility = @c_Facility
      AND (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QtyReplen - ISNULL(TRFLLI.FromQty,0)) > 0
      AND LOTxLOCxID.STORERKEY = @c_StorerKey
      AND LOTxLOCxID.SKU = @c_SKU 
      AND ISNULL(LOC.HostWHCode,'''') = @c_lottable01 ' +
      CASE WHEN ISNULL(@c_SortMode,'') = 'LEFO' AND @c_UOM = '2' THEN '' WHEN @c_UOM = '1' THEN ' AND LOC.LocationType NOT IN(''CASE'',''PICK'') ' ELSE ' AND LOC.LocationType IN(''CASE'',''PICK'') ' END +
      CASE WHEN @c_UOM = '1' THEN '  AND (LOTxLOCxID.QTYALLOCATED + LOTxLOCxID.QtyReplen + ISNULL(TRFLLI.FromQty,0)) = 0 ' ELSE ' ' END + 
      --CASE WHEN ISNULL(RTRIM(@c_Lottable01),'') = '' THEN '' ELSE ' AND LA.Lottable01 = @c_Lottable01 ' END +
      CASE WHEN ISNULL(RTRIM(@c_Lottable02),'') = '' AND CHARINDEX('LOTTABLE02', @c_LottableList) = 0 THEN '' ELSE ' AND LA.Lottable02 = @c_Lottable02 ' END +
      CASE WHEN ISNULL(RTRIM(@c_Lottable03),'') = '' AND CHARINDEX('LOTTABLE03', @c_LottableList) = 0 THEN '' ELSE ' AND LA.Lottable03 = @c_Lottable03 ' END +
      CASE WHEN CONVERT(NVARCHAR(8) ,@d_Lottable04 ,112) <> '19000101' AND @d_Lottable04 IS NOT NULL THEN ' AND LA.Lottable04 = RTRIM(CONVERT( NVARCHAR(20), @d_Lottable04, 106)) ' 
           WHEN CHARINDEX('LOTTABLE04', @c_LottableList) > 0 THEN ' AND (lottable04 IS NULL OR lottable04 = N''1900-01-01'') ' ELSE ' ' END +
      CASE WHEN CONVERT(NVARCHAR(8) ,@d_Lottable05 ,112) <> '19000101' AND @d_Lottable05 IS NOT NULL THEN ' AND LA.Lottable05 = RTRIM(CONVERT( NVARCHAR(20), @d_Lottable05, 106)) '
           WHEN CHARINDEX('LOTTABLE05', @c_LottableList) > 0 THEN ' AND (lottable05 IS NULL OR lottable05 = N''1900-01-01'') ' ELSE ' ' END +
      CASE WHEN ISNULL(RTRIM(@c_Lottable06),'') = '' AND CHARINDEX('LOTTABLE06', @c_LottableList) = 0 THEN '' ELSE ' AND LA.Lottable06 = @c_Lottable06 ' END +
      CASE WHEN ISNULL(RTRIM(@c_Lottable07),'') = '' AND CHARINDEX('LOTTABLE07', @c_LottableList) = 0 THEN '' ELSE ' AND LA.Lottable07 = @c_Lottable07 ' END +
      CASE WHEN ISNULL(RTRIM(@c_Lottable08),'') = '' AND CHARINDEX('LOTTABLE08', @c_LottableList) = 0 THEN '' ELSE ' AND LA.Lottable08 = @c_Lottable08 ' END +
      CASE WHEN ISNULL(RTRIM(@c_Lottable09),'') = '' AND CHARINDEX('LOTTABLE09', @c_LottableList) = 0 THEN '' ELSE ' AND LA.Lottable09 = @c_Lottable09 ' END +
      CASE WHEN ISNULL(RTRIM(@c_Lottable10),'') = '' AND CHARINDEX('LOTTABLE10', @c_LottableList) = 0 THEN '' ELSE ' AND LA.Lottable10 = @c_Lottable10 ' END +
      CASE WHEN ISNULL(RTRIM(@c_Lottable11),'') = '' AND CHARINDEX('LOTTABLE11', @c_LottableList) = 0 THEN '' ELSE ' AND LA.Lottable11 = @c_Lottable11 ' END +
      CASE WHEN ISNULL(RTRIM(@c_Lottable12),'') = '' AND CHARINDEX('LOTTABLE12', @c_LottableList) = 0 THEN '' ELSE ' AND LA.Lottable12 = @c_Lottable12 ' END +
      CASE WHEN CONVERT(NVARCHAR(8) ,@d_Lottable13 ,112) <> '19000101' AND @d_Lottable13 IS NOT NULL THEN ' AND LA.Lottable13 = RTRIM(CONVERT( NVARCHAR(20), @d_Lottable13, 106)) ' 
           WHEN CHARINDEX('LOTTABLE13', @c_LottableList) > 0 THEN ' AND (lottable13 IS NULL OR lottable13 = N''1900-01-01'') ' ELSE ' ' END +
      CASE WHEN CONVERT(NVARCHAR(8) ,@d_Lottable14 ,112) <> '19000101' AND @d_Lottable14 IS NOT NULL THEN ' AND LA.Lottable14 = RTRIM(CONVERT( NVARCHAR(20), @d_Lottable14, 106)) '
           WHEN CHARINDEX('LOTTABLE14', @c_LottableList) > 0 THEN ' AND (lottable14 IS NULL OR lottable14 = N''1900-01-01'') ' ELSE ' ' END +
      CASE WHEN CONVERT(NVARCHAR(8) ,@d_Lottable15 ,112) <> '19000101' AND @d_Lottable15 IS NOT NULL THEN ' AND LA.Lottable15 = RTRIM(CONVERT( NVARCHAR(20), @d_Lottable15, 106)) ' 
           WHEN CHARINDEX('LOTTABLE15', @c_LottableList) > 0 THEN ' AND (lottable15 IS NULL OR lottable15 = N''1900-01-01'') ' ELSE ' ' END +
      CASE WHEN @c_UOM = '1' THEN ' AND (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QtyReplen - ISNULL(TRFLLI.FromQty,0)) <= @n_QtyLeftToFulfill ' ELSE ' ' END + 
      CASE WHEN @c_UOM <> '1' THEN ' AND (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QtyReplen - ISNULL(TRFLLI.FromQty,0)) >= @n_UOMBase ' ELSE ' ' END  +
      ' ' + RTRIM(ISNULL(@c_Conditions,'')) + ' ' +
      @c_OrderBy

   SET @c_SQLParm =  N'@c_Facility   NVARCHAR(5),  @c_StorerKey  NVARCHAR(15), @c_SKU NVARCHAR(20), @n_QtyLeftToFulfill INT, @n_UOMBase INT, ' +
                      '@c_Lottable01 NVARCHAR(18), @c_Lottable02 NVARCHAR(18), @c_Lottable03 NVARCHAR(18), @d_Lottable04 DATETIME, @d_Lottable05 DATETIME, ' +
                      '@c_Lottable06 NVARCHAR(30), @c_Lottable07 NVARCHAR(30), @c_Lottable08 NVARCHAR(30), @c_Lottable09 NVARCHAR(30), @c_Lottable10 NVARCHAR(30), ' +
                      '@c_Lottable11 NVARCHAR(30), @c_Lottable12 NVARCHAR(30), @d_Lottable13 DATETIME, @d_Lottable14 DATETIME, @d_Lottable15 DATETIME, ' +
                      '@n_SkuOutgoingShelfLife INT, @n_ConsigneeShelfLife INT, @c_Consigneekey NVARCHAR(15)' 

   EXEC sp_ExecuteSQL @c_SQL, @c_SQLParm, @c_Facility, @c_StorerKey, @c_SKU, @n_QtyLeftToFulfill, @n_UOMBase, @c_Lottable01, @c_Lottable02, @c_Lottable03,
                      @d_Lottable04, @d_Lottable05, @c_Lottable06, @c_Lottable07, @c_Lottable08, @c_Lottable09, @c_Lottable10, @c_Lottable11, @c_Lottable12,
                      @d_Lottable13, @d_Lottable14, @d_Lottable15, @n_SkuOutgoingShelfLife, @n_ConsigneeShelfLife, @c_Consigneekey    

   SET @c_SQL = ''
   SET @c_PrevLOT = ''
   SET @n_LotQtyAvailable = 0

   OPEN CURSOR_AVAILABLE                    
   FETCH NEXT FROM CURSOR_AVAILABLE INTO @c_LOT, @c_LOC, @c_ID, @n_QtyAvailable   
          
   WHILE (@@FETCH_STATUS <> -1) AND (@n_QtyLeftToFulfill > 0)          
   BEGIN    
   	  IF NOT EXISTS(SELECT 1 FROM #TMP_LOT WHERE Lot = @c_Lot)
   	  BEGIN
   	  	 INSERT INTO #TMP_LOT (Lot, QtyAvailable)
      	 SELECT Lot,
      	        SUM(Qty - QtyAllocated - QtyPicked)
      	        - (SELECT ISNULL(SUM(TD.FromQty),0) 
      	           FROM TRANSFER T (NOLOCK)
      	           JOIN TRANSFERDETAIL TD (NOLOCK) ON T.Transferkey = TD.Transferkey
      	           AND TD.Status <> '9' 
      	           AND TD.FromLot = LOT.Lot)      	         
      	 FROM LOT (NOLOCK)
      	 WHERE LOT = @c_LOT
       	 GROUP BY Lot
   	  END
      SET @n_LotQtyAvailable = 0

      SELECT @n_LotQtyAvailable = QtyAvailable
      FROM #TMP_LOT 
      WHERE Lot = @c_Lot   	  
      
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
         AND LLI.Qty > 0  
                	        	
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
   	  	 UPDATE #TMP_LOT
   	  	 SET QtyAvailable = QtyAvailable - @n_QtyToTake 
   	  	 WHERE Lot = @c_Lot

      	 IF @n_QtyToTake = @n_QtyAvailable AND @c_UOM = '1'
          	 SET @c_OtherValue = 'FULLPALLET' 
         ELSE
           	 SET @c_OtherValue = '1'       	 

         EXEC isp_Insert_Allocate_Candidates
              @c_Lot = @c_Lot
           ,  @c_Loc = @c_Loc
           ,  @c_ID  = @c_ID
           ,  @n_QtyAvailable = @n_QtyToTake
           ,  @c_OtherValue = @c_OtherValue
               
         SET @n_QtyLeftToFulfill = @n_QtyLeftToFulfill - @n_QtyToTake       
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
   
   EXEC isp_Cursor_Allocate_Candidates   
         @n_SkipPreAllocationFlag = 1    --Return Lot column 
END -- Procedure

GO
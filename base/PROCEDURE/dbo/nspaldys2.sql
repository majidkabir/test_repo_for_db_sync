SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/    
/* Stored Procedure: nspALDYS2                                          */    
/* Creation Date: 11-MAR-2017                                           */    
/* Copyright: LFL                                                       */    
/* Written by:                                                          */    
/*                                                                      */    
/* Purpose: WMS-1886 CN DYSON allocation by locationflag                */
/*          Without check pick face to skip locationflag from bulk      */
/*          Orderinfo4Allocation = '1'                                  */
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
/* 17-Jan-2018  NJOW01  1.0   WMS-3785 alternate strategy by consignee  */
/*                            for locationflag handling                 */
/************************************************************************/    
CREATE PROC [dbo].[nspALDYS2]        
   @c_Orderey    NVARCHAR(10),  
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
          
   DECLARE @n_QtyAvailable         INT,  
           @c_LOT                  NVARCHAR(10),
           @c_LOC                  NVARCHAR(10),
           @c_ID                   NVARCHAR(18), 
           @c_OtherValue           NVARCHAR(20),
           @n_QtyToTake            INT,
           @n_StorerMinShelfLife   INT,
           @c_PrevLOT              NVARCHAR(10),
           @n_cnt                  INT,
           @n_LotQtyAvailable      INT,
           @c_LocationFlag         NVARCHAR(10),
           @c_Orderkey             NVARCHAR(10),
           @c_OrderLineNumber      NVARCHAR(5),
           @c_Consigneekey         NVARCHAR(20), --NJOW01
           @c_Susr1                NVARCHAR(20), --NJOW01
           @c_ConsigneeStrategy    NVARCHAR(10), --NJOW01
           @c_CaseCond             NVARCHAR(2000), --NJOW01
           @c_ConsBySku            NVARCHAR(10) --NJOW01
           --@c_Strategykey          NVARCHAR(10),
           --@c_LocationTypeOverride NVARCHAR(10)

   SET @b_debug = 0
   SET @n_QtyAvailable = 0          
   SET @c_OtherValue = '1' 
   SET @n_QtyToTake = 0
   SET @c_LocationFlag = ''
   SET @c_ConsBySku = 'N' --NJOW01
   --SET @c_Strategykey = ''
   --SET @c_LocationTypeOverride = ''
   
   IF ISNULL(@c_OtherParms,'') <> ''
   BEGIN
      SELECT @c_Orderkey = LEFT(@c_OtherParms,10)
      SELECT @c_OrderLineNumber = SUBSTRING(@c_OtherParms, 11,5)

      SELECT TOP 1 @c_LocationFlag = OD.Userdefine03,
                   @c_Consigneekey = 'DY'+O.Consigneekey,  --NJOW01
                   @c_Susr1 = ISNULL(S.Susr1,'')  --NJOW01
      FROM ORDERS O (NOLOCK)  
      JOIN ORDERDETAIL OD (NOLOCK) ON O.Orderkey = OD.Orderkey
      LEFT JOIN STORER S (NOLOCK) ON 'DY'+O.Consigneekey = S.Storerkey            
      WHERE O.Orderkey = @c_Orderkey
      AND OD.OrderLineNumber = @c_OrderLineNumber            
   END

   --NJOW01
   IF EXISTS(SELECT 1
       FROM CODELKUP (NOLOCK) 
       WHERE Listname = 'DYSONSL' 
       AND Short = 'N'
       AND Long = @c_locationFlag) AND @c_Susr1 = 'Y'
   BEGIN
   	   IF EXISTS(SELECT 1 
   	             FROM CODELKUP(NOLOCK)
   	             WHERE Listname = 'DYSONSL2'
                 AND Storerkey = @c_Storerkey
                 AND UDF01 = @c_Consigneekey
                 AND UDF03 = @c_Sku)
       BEGIN          
          SET @c_ConsBySku = 'Y'
       END
   	              
   	   SET @c_ConsigneeStrategy = 'Y'   	   
   	   
       SET @c_CaseCond = ' CASE LOC.LocationFlag '
       SELECT @c_casecond = @c_casecond +' WHEN ''' + RTRIM(Long) + ''' THEN ' + UDF02 --CAST(ROW_NUMBER() OVER(ORDER BY Short) AS NVARCHAR)  
       FROM CODELKUP(NOLOCK) 
       WHERE Listname = 'DYSONSL2'
       AND Storerkey = @c_Storerkey
       AND UDF01 = @c_Consigneekey
       AND (UDF03 = @c_Sku OR (ISNULL(UDF03,'') = '' AND @c_ConsBySku = 'N'))
       ORDER BY Short, long
       --ORDER BY CASE WHEN UDF03 = @c_Sku THEN 1 WHEN ISNULL(UDF03,'') = '' THEN 2 ELSE 3 END, Short, long
        
       IF @@ROWCOUNT > 0
          SET @c_casecond = @c_casecond + ' ELSE ''9999'' END '
       ELSE      			       	   			         
       BEGIN
   		    SET @c_Casecond  = @c_casecond + ' WHEN ''*'' THEN ''1'' ELSE ''9999'' END '
          SET @c_ConsigneeStrategy = 'N'
   		 END
   END 
   ELSE       
       SET @c_ConsigneeStrategy = 'N'
   
   /*   
   IF @c_UOM = '6'
   BEGIN
   	 IF EXISTS(SELECT 1 FROM ORDERS O (NOLOCK) 
   	           JOIN LOADPLAN LP (NOLOCK) ON O.Loadkey = LP.Loadkey AND LP.DefaultStrategykey = 'Y' 
   	           AND O.Orderkey = @c_Orderkey)
   	 BEGIN
   	 	  SELECT @c_Strategykey = StrategyKey
   	 	  FROM STORER(NOLOCK)
   	 	  WHERE Storerkey = @c_Storerkey
   	 END
   	 
   	 IF ISNULL(@c_Strategykey,'') = ''
   	 BEGIN
   	    SELECT @c_Strategykey = Strategykey
   	    FROM SKU (NOLOCK)
   	    WHERE Storerkey = @c_Storerkey
   	    AND Sku = @c_Sku      	    
   	 END
   	 
   	 SELECT TOP 1 @c_LocationTypeOverride = LocationTypeOverride
   	 FROM STRATEGY S (NOLOCK)
   	 JOIN ALLOCATESTRATEGYDETAIL ASD (NOLOCK) ON S.AllocateStrategyKey = ASD.AllocateStrategyKey
   	 WHERE ASD.UOM = '6' 
   	 AND ASD.LocationTypeOverride <> '' 
   	 AND ASD.LocationTypeOverride IS NOT NULL
   	 AND S.Strategykey = @c_Strategykey
   END    
   */
      
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
             QTYAVAILABLE = (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QtyReplen)
      FROM LOTxLOCxID (NOLOCK)
      JOIN LOC (NOLOCK) ON (LOTxLOCxID.Loc = LOC.LOC)
      JOIN ID (NOLOCK) ON (LOTxLOCxID.Id = ID.ID)
      JOIN LOT (NOLOCK) ON (LOTXLOCXID.LOT = LOT.LOT)
      JOIN LOTATTRIBUTE LA (NOLOCK) ON LOT.LOT = LA.LOT
      JOIN SKUXLOC SL (NOLOCK) ON (LOTxLOCxID.Storerkey = SL.Storerkey AND LOTxLOCxID.Sku = SL.Sku AND LOTxLOCxID.Loc = SL.Loc)
      WHERE LOC.Status <> ''HOLD''
      AND LOT.Status <> ''HOLD''
      AND ID.Status <> ''HOLD''
      AND LOC.Facility = @c_Facility
      AND LOTxLOCxID.STORERKEY = @c_StorerKey
      AND LOTxLOCxID.SKU = @c_SKU ' + 
      --CASE WHEN @c_UOM = '6' AND @c_LocationTypeOverride IN('PICK','CASE') THEN 
      --    ' AND LOC.LocationFlag IN (SELECT Long FROM CODELKUP (NOLOCK) WHERE Listname = ''DYSONSL'' AND ISNULL(Short,'''') <> ''Y'') ' ELSE ' ' END +
      CASE WHEN @c_UOM = '1' THEN ' AND LOTxLOCxID.ID <> '''' ' ELSE ' ' END +
      CASE WHEN ISNULL(RTRIM(@c_LocationFlag),'') <> '' THEN 
              CASE WHEN @c_ConsigneeStrategy = 'Y'  THEN --NJOW01
                  ' AND Loc.LocationFlag IN (SELECT long FROM CODELKUP (NOLOCK) WHERE listname = ''DYSONSL2'' AND Storerkey = @c_Storerkey AND UDF01 = @c_Consigneekey AND (UDF03 = @c_Sku OR (ISNULL(UDF03,'''') = '''' AND @c_ConsBySku = ''N'')) ) '
                 ELSE ' AND Loc.LocationFlag = @c_LocationFlag ' END 
           ELSE ' AND 1=2 ' END +
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
      ' AND (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QtyReplen) >= @n_UOMBase ' +
      CASE WHEN  @c_ConsigneeStrategy = 'Y'  THEN --NJOW01     
             ' ORDER BY ' + @c_Casecond + ', LA.Lottable05, LA.Lot, 4, LOC.LogicalLocation, LOC.LOC'
        ELSE ' ORDER BY LA.Lottable05, LA.Lot, 4, LOC.LogicalLocation, LOC.LOC ' END 

   SET @c_SQLParm =  N'@c_Facility   NVARCHAR(5),  @c_StorerKey  NVARCHAR(15), @c_SKU NVARCHAR(20), @c_LocationFlag NVARCHAR(10), @n_UOMBase INT, ' +
                      '@c_Lottable01 NVARCHAR(18), @c_Lottable02 NVARCHAR(18), @c_Lottable03 NVARCHAR(18), @d_Lottable04 DATETIME, @d_Lottable05 DATETIME, ' +
                      '@c_Lottable06 NVARCHAR(30), @c_Lottable07 NVARCHAR(30), @c_Lottable08 NVARCHAR(30), @c_Lottable09 NVARCHAR(30), @c_Lottable10 NVARCHAR(30), ' +
                      '@c_Lottable11 NVARCHAR(30), @c_Lottable12 NVARCHAR(30), @d_Lottable13 DATETIME, @d_Lottable14 DATETIME, @d_Lottable15 DATETIME, @c_Consigneekey NVARCHAR(20), @c_ConsBySku NVARCHAR(10) ' --NJOW01 

   EXEC sp_ExecuteSQL @c_SQL, @c_SQLParm, @c_Facility, @c_StorerKey, @c_SKU, @c_LocationFlag, @n_UOMBase, @c_Lottable01, @c_Lottable02, @c_Lottable03,
                      @d_Lottable04, @d_Lottable05, @c_Lottable06, @c_Lottable07, @c_Lottable08, @c_Lottable09, @c_Lottable10, @c_Lottable11, @c_Lottable12,
                      @d_Lottable13, @d_Lottable14, @d_Lottable15, @c_Consigneekey, @c_ConsBySku --NJOW01

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
      	 FROM LOT (NOLOCK)
      	 WHERE LOT = @c_LOT
      END

      IF @n_LotQtyAvailable < @n_QtyAvailable 
         SET @n_QtyAvailable = @n_LotQtyAvailable

      IF @n_QtyLeftToFulfill >= @n_QtyAvailable
      BEGIN
      	   IF @n_UOMBase > 0
      		   SET @n_QtyToTake = Floor(@n_QtyAvailable / @n_UOMBase) * @n_UOMBase
      		 ELSE
      		   SET @n_QtyToTake = @n_QtyAvailable
      END
      ELSE
      BEGIN
      	   IF @n_UOMBase > 0
         	    SET @n_QtyToTake = Floor(@n_QtyLeftToFulfill / @n_UOMBase) * @n_UOMBase
         	 ELSE
         	    SET @n_QtyToTake = @n_QtyLeftToFulfill
      END      	 
            
      IF @n_QtyToTake > 0
      BEGIN      	 
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
SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/    
/* Stored Procedure: nspALDYS5C                                         */    
/* Creation Date: 26-MAR-2020                                           */    
/* Copyright: LFL                                                       */    
/* Written by: WLChooi                                                  */    
/*                                                                      */    
/* Purpose: WMS-12491 CN DYSON Allocation                               */
/*          Pallet (VNA & Shuttle) UOM1                                 */
/*          DYNPPICK UOM 6                                              */
/*          Piece UOM 6                                                 */
/*          Piece UOM 7 (Over-Allocation)                               */
/*	         Orderinfo4Allocation = '1'                                  */
/*          SkipPreallocation = '1'                                     */
/*                                                                      */
/* Called By: Wave (B2B)/Build Load Plan (B2C)                          */    
/*                                                                      */    
/* PVCS Version: 1.0                                                    */    
/*                                                                      */    
/* Version: 1.0                                                         */    
/*                                                                      */    
/* Data Modifications:                                                  */    
/*                                                                      */    
/* Updates:                                                             */    
/* Date         Author  Ver.  Purposes                                  */   
/* 2020-07-21   WLChooi 1.1   Add condition (WL01)                      */    
/************************************************************************/    
CREATE PROC [dbo].[nspALDYS5C]        
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
           @c_DocType            NVARCHAR(1),
           @c_ECOM_SINGLE_Flag   NVARCHAR(1),
           @c_UserDefine03       NVARCHAR(20),
           @c_Notes              NVARCHAR(4000),
           @c_Conditions         NVARCHAR(4000) = '',
           @c_OrderConditions    NVARCHAR(4000) = '',
           @n_SortCount          INT = 1,
           @c_SortBy             NVARCHAR(4000) = 'CASE ',
           @c_ColValue           NVARCHAR(4000),
           @c_IsValid            NVARCHAR(10) = 'N',
           @n_PackPallet         INT

   SET @n_QtyAvailable = 0          
   SET @c_OtherValue = '1' 
   SET @n_QtyToTake = 0

   SELECT @n_PackPallet = ISNULL(PACK.Pallet,0)
   FROM SKU (NOLOCK)
   JOIN PACK (NOLOCK) ON PACK.PackKey = SKU.PACKKey
   WHERE SKU.StorerKey = @c_StorerKey
   AND SKU.SKU = @c_SKU
   
   IF @n_UOMBase = 0
     SET @n_UOMBase = 1

   EXEC isp_Init_Allocate_Candidates

   CREATE TABLE #TMP_LOT (LOT NVARCHAR(10) NULL,
                          QtyAvailable INT NULL DEFAULT(0))

   IF LEN(@c_OtherParms) > 0 
   BEGIN
      SET @c_OrderKey = LEFT(@c_OtherParms,10)  --if call by discrete
      SET @c_key1 = LEFT(@c_OtherParms, 10) --Orderkey, Loadkey(conso), Wavekey(conso)
      SET @c_key2 = SUBSTRING(@c_OtherParms, 11, 5) --OrderLineNumber      	    
      SET @c_key3 = SUBSTRING(@c_OtherParms, 16, 1) --W=Wave     	    
      
      IF ISNULL(@c_key2,'')='' AND ISNULL(@c_key3,'')='' --call by load conso
      BEGIN
         SET @c_Orderkey = ''
         SELECT TOP 1 @c_Orderkey = O.Orderkey
         FROM ORDERS O (NOLOCK) 
         JOIN ORDERDETAIL OD (NOLOCK) ON O.Orderkey = OD.Orderkey
         WHERE O.Loadkey = @c_key1
         AND OD.Sku = @c_SKU
         ORDER BY O.Orderkey, OD.OrderLineNumber
      END        	     
         
      IF ISNULL(@c_key2,'')='' AND ISNULL(@c_key3,'')='W' --call by wave conso
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
                 
      SELECT TOP 1 @c_Doctype = O.DocType,
                   @c_ECOM_SINGLE_Flag = o.ECOM_SINGLE_Flag  --NJOW01
      FROM ORDERS O (NOLOCK)
      WHERE O.Orderkey = @c_Orderkey      

   END

   SELECT TOP 1 @c_UserDefine03 = ISNULL(UserDefine03,'') 
   FROM ORDERDETAIL (NOLOCK) 
   WHERE Orderkey = @c_Orderkey AND OrderLineNumber = @c_key2
      
   SELECT @n_StorerMinShelfLife = ((Sku.Shelflife * Storer.MinShelflife/100) * -1)
   FROM Sku (nolock)
   JOIN Storer (nolock) ON Sku.Storerkey = Storer.Storerkey
   WHERE Sku.Sku = @c_sku
   AND Sku.Storerkey = @c_storerkey   
   
   IF @n_StorerMinShelfLife IS NULL
      SELECT @n_StorerMinShelfLife = 0

   IF @c_UOM NOT IN  ('6','7')
      GOTO EXIT_SP

   IF EXISTS(SELECT 1 
             FROM CODELKUP(NOLOCK)
             WHERE Listname = 'DYSONSL2'
             AND Long = @c_UserDefine03
             AND Short = '3')
   BEGIN
      DECLARE CUR_CODELKUP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT CASE WHEN SUBSTRING(LTRIM(RTRIM(Notes)),1,3) = 'AND' 
                  THEN SUBSTRING(Notes,4,LEN(Notes))
                  ELSE Notes END
      FROM CODELKUP (NOLOCK)
      WHERE Listname = 'DYSONSL2' 
      AND Long = @c_UserDefine03
      AND Short = '3'
      ORDER BY Short

      OPEN CUR_CODELKUP

      FETCH NEXT FROM CUR_CODELKUP INTO @c_Notes
      
      WHILE @@FETCH_STATUS <> -1
      BEGIN
         SET @c_IsValid = 'Y'

         IF LTRIM(RTRIM(ISNULL(@c_Notes,''))) <> ''
         BEGIN
            IF ISNULL(@c_Conditions,'') = ''
            BEGIN
               SET @c_Conditions = '(' + @c_Notes + ')'
               SET @c_OrderConditions = @c_Notes
            END
            ELSE
            BEGIN
               SET @c_Conditions = @c_Conditions + ' OR ' +  '(' + @c_Notes + ')'
               SET @c_OrderConditions = @c_OrderConditions + ', ' + @c_Notes
            END
         END
         ELSE
         BEGIN
            SET @c_IsValid = 'N'
         END

         FETCH NEXT FROM CUR_CODELKUP INTO @c_Notes
      END
      CLOSE CUR_CODELKUP
      DEALLOCATE CUR_CODELKUP
   END
   ELSE
   BEGIN
      GOTO EXIT_SP
   END

   SET @c_Conditions = 'AND (' + @c_Conditions + ')'
   --SELECT @c_Conditions
   SELECT @c_OrderConditions = REPLACE(REPLACE(@c_OrderConditions, 'AND', ', '),'OR',', ')
   --SELECT @c_OrderConditions

   DECLARE CUR_DELIMSPLIT CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT LTRIM(RTRIM(COLVALUE)) FROM fnc_DelimSplit(', ',@c_OrderConditions)

   OPEN CUR_DELIMSPLIT
   
   FETCH NEXT FROM CUR_DELIMSPLIT INTO @c_ColValue
   
   WHILE @@FETCH_STATUS <> -1
   BEGIN
      SET @c_SortBy = @c_SortBy + 'WHEN ' + @c_ColValue + ' THEN ' + CAST(@n_SortCount AS NVARCHAR(10)) + ' '
      SET @n_SortCount = @n_SortCount + 1

      FETCH NEXT FROM CUR_DELIMSPLIT INTO @c_ColValue
   END
   CLOSE CUR_DELIMSPLIT
   DEALLOCATE CUR_DELIMSPLIT

   SET @c_SortBy = @c_SortBy + ' ELSE ' + CAST(@n_SortCount AS NVARCHAR(10)) + ' END, '

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
      AND (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QtyReplen) >= @n_UOMBase
      AND LOTxLOCxID.STORERKEY = @c_StorerKey
      AND LOTxLOCxID.SKU = @c_SKU    
      --AND (LOC.LocationFlag = ''NONE'')  
      --AND LOC.LocationType = ''PICK'' 
      --AND LOC.LocationFlag <> ''HOLD''
      AND LOC.LocationGroup IN (''E'',''N'')
      --AND LOC.LocationCategory IN (''PICK'') ' + CHAR(13) + 
      CASE WHEN @c_IsValid = 'Y' THEN @c_Conditions ELSE '' END + CHAR(13) +
      CASE WHEN @c_UOM = 6 THEN 'AND LOC.LocationGroup = @c_Doctype AND LOC.LocationCategory IN (''PICK'') AND SL.LocationType = ''PICK'' ' ELSE '' END +   --WL01
      CASE WHEN @c_UOM = 7 THEN 'AND SL.LocationType <> ''PICK'' ' ELSE '' END +
      CASE WHEN @c_UOM = 7 AND ISNULL(@n_PackPallet,0) > 0 THEN 'AND (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QtyReplen) = @n_PackPallet ' ELSE '' END +
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
      'ORDER BY CASE WHEN LOC.LocationGroup = @c_Doctype THEN 1 ELSE 2 END, ' +   
                --CASE WHEN @c_IsValid = 'Y' THEN @c_SortBy ELSE '' END +
                 ' LA.Lottable05, LOC.LogicalLocation, LOC.LOC, QTYAVAILABLE '
                         
   SET @c_SQLParm =  N'@c_Facility   NVARCHAR(5),  @c_StorerKey  NVARCHAR(15), @c_SKU NVARCHAR(20), @n_QtyLeftToFulfill INT, @n_UOMBase INT, ' +
                      '@c_Lottable01 NVARCHAR(18), @c_Lottable02 NVARCHAR(18), @c_Lottable03 NVARCHAR(18), @d_Lottable04 DATETIME, @d_Lottable05 DATETIME, ' +
                      '@c_Lottable06 NVARCHAR(30), @c_Lottable07 NVARCHAR(30), @c_Lottable08 NVARCHAR(30), @c_Lottable09 NVARCHAR(30), @c_Lottable10 NVARCHAR(30), ' +
                      '@c_Lottable11 NVARCHAR(30), @c_Lottable12 NVARCHAR(30), @d_Lottable13 DATETIME, @d_Lottable14 DATETIME, @d_Lottable15 DATETIME, ' +
                      '@c_Doctype    NVARCHAR(1) , @n_PackPallet INT '

   EXEC sp_ExecuteSQL @c_SQL, @c_SQLParm, @c_Facility, @c_StorerKey, @c_SKU, @n_QtyLeftToFulfill, @n_UOMBase, @c_Lottable01, @c_Lottable02, @c_Lottable03,
                      @d_Lottable04, @d_Lottable05, @c_Lottable06, @c_Lottable07, @c_Lottable08, @c_Lottable09, @c_Lottable10, @c_Lottable11, @c_Lottable12,
                      @d_Lottable13, @d_Lottable14, @d_Lottable15, @c_Doctype, @n_PackPallet

   SET @c_SQL = ''
   SET @n_LotQtyAvailable = 0
   
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
      	 IF @c_UOM = '1' 
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

         SET @c_Lot       = RTRIM(@c_Lot)               
         SET @c_Loc       = RTRIM(@c_Loc)  
         SET @c_ID        = RTRIM(@c_ID)  
  
         EXEC isp_Insert_Allocate_Candidates  
            @c_Lot = @c_Lot  
         ,  @c_Loc = @c_Loc  
         ,  @c_ID  = @c_ID  
         ,  @n_QtyAvailable = @n_QtyToTake  
         ,  @c_OtherValue = @c_OtherValue  

         SET @n_QtyLeftToFulfill = @n_QtyLeftToFulfill - @n_QtyToTake       
      END
            
      FETCH NEXT FROM CURSOR_AVAILABLE INTO @c_LOT, @c_LOC, @c_ID, @n_QtyAvailable  
   END -- END WHILE FOR CURSOR_AVAILABLE          

   EXIT_SP:

   IF CURSOR_STATUS('GLOBAL' , 'CURSOR_AVAILABLE') in (0 , 1)          
   BEGIN          
      CLOSE CURSOR_AVAILABLE          
      DEALLOCATE CURSOR_AVAILABLE          
   END    

   /*IF ISNULL(@c_SQL,'') <> ''
   BEGIN
      EXEC sp_ExecuteSQL @c_SQL
   END
   ELSE
   BEGIN
      DECLARE  CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR 
      SELECT TOP 0 NULL, NULL, NULL, NULL, NULL    
   END*/

   EXEC isp_Cursor_Allocate_Candidates     
         @n_SkipPreAllocationFlag = 1    --Return Lot column  

END -- Procedure

GO
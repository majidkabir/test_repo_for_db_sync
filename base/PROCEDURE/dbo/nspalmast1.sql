SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/    
/* Stored Procedure: nspALMAST1                                         */    
/* Creation Date: 06-MAR-2019                                           */    
/* Copyright: LFL                                                       */    
/* Written by:                                                          */    
/*                                                                      */    
/* Purpose: WMS-8049 CN Mast Allocation                                 */
/*          Full case by load for B2B + B2C(SINGLE) UOM 2               */
/*         Piece from Mezzanine UOM 6                                   */
/*          Piece from PND UOM 7                                        */
/*         Piece from VNA UOM 7                                         */
/*          SkipPreallocation = '1'                                     */
/*                                                                      */
/* Called By: Wave                                                      */    
/*                                                                      */    
/* PVCS Version: 1.0                                                    */    
/*                                                                      */    
/* Version: 1.1                                                         */    
/*                                                                      */    
/* Data Modifications:                                                  */    
/*                                                                      */    
/* Updates:                                                             */    
/* Date         Author  Ver.  Purposes                                  */    
/* 03-JUN-2019  NJOW01  1.0   WMS-9198 enable full case allocation for  */
/*                            B2C Single Order                          */
/* 11-May-2020 Wan01    1.1   Dynamic SQL review, impact SQL cache log  */  
/* 13-JUL-2020 CSCHONG  1.2   WMS-14154 - revised sorting (CS01)        */
/* 09-AUG-2023 NJOW02   1.3   WMS-23349 Remove lottable05 from sorting  */
/* 12-SEP-2023 CSCHONG  1.4   Performnace tunning (CS02)                */
/************************************************************************/    

CREATE   PROC [dbo].[nspALMAST1]        
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
           @c_ECOM_SINGLE_Flag   NVARCHAR(1),  --NJOW01
           @n_ReorderPoint       INT           --CS01
          

   SET @n_QtyAvailable = 0          
   SET @c_OtherValue = '1' 
   SET @n_QtyToTake = 0
   SET @n_ReorderPoint   = 0                    --CS01 
   
   IF @n_UOMBase = 0
     SET @n_UOMBase = 1
     
   EXEC isp_Init_Allocate_Candidates         --(Wan01)       

   CREATE TABLE #TMP_LOT (LOT NVARCHAR(10) NOT NULL Primary Key,   --(CS02)
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
      
      IF @c_UOM = '2' AND @c_DocType = 'E' AND @c_ECOM_SINGLE_Flag <> 'S' --No case allocation for B2C Multi  --NJOW01
         GOTO EXIT_SP         
   END

   --CS01 START
      SELECT @n_ReorderPoint = S.ReorderPoint
      FROM SKU S WITH (NOLOCK) 
      WHERE S.sku = @c_sku

     IF @n_ReorderPoint = 1
     BEGIN
        GOTO EXIT_SP
     END      
   --CS01 END
      
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
      AND (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QtyReplen) >= @n_UOMBase
      AND LOTxLOCxID.STORERKEY = @c_StorerKey
      AND LOTxLOCxID.SKU = @c_SKU       
      AND (LOC.LocationFlag = ''NONE'' OR LOC.LocationCategory = ''PND'') ' +  --allow allocate from PND with HOLD
      CASE WHEN @c_UOM = '2' THEN ' AND Loc.LocationCategory = ''VNA'' '
           WHEN @c_UOM = '6' THEN ' AND Loc.LocationCategory = ''Mezzanine'' '  
           WHEN @c_UOM = '7' THEN ' AND Loc.LocationCategory IN(''PND'',''VNA'') ' 
           ELSE ' AND LOC.LocationCategory IN(''Mezzanine'',''PND'',''VNA'') ' END +  
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
      ' ORDER BY CASE WHEN LOC.LocationCategory = ''Mezzanine'' THEN 1 WHEN LOC.LocationCategory = ''PND'' THEN 2 WHEN LOC.LocationCategory = ''VNA'' THEN 3 ELSE 4 END, ' +   
                      CASE WHEN @c_UOM = '7' THEN ' CASE WHEN LOTxLOCxID.QtyReplen > 0 THEN 1 ELSE 2 END, ' ELSE '' END  +   --if VNA or PND allocate loc with qtyreplen first
                      ' LA.Lottable04, QTYAVAILABLE, LOC.LogicalLocation, LOC.LOC '  --CS01 --NJOW02

   SET @c_SQLParm =  N'@c_Facility   NVARCHAR(5),  @c_StorerKey  NVARCHAR(15), @c_SKU NVARCHAR(20), @n_QtyLeftToFulfill INT, @n_UOMBase INT, ' +
                      '@c_Lottable01 NVARCHAR(18), @c_Lottable02 NVARCHAR(18), @c_Lottable03 NVARCHAR(18), @d_Lottable04 DATETIME, @d_Lottable05 DATETIME, ' +
                      '@c_Lottable06 NVARCHAR(30), @c_Lottable07 NVARCHAR(30), @c_Lottable08 NVARCHAR(30), @c_Lottable09 NVARCHAR(30), @c_Lottable10 NVARCHAR(30), ' +
                      '@c_Lottable11 NVARCHAR(30), @c_Lottable12 NVARCHAR(30), @d_Lottable13 DATETIME, @d_Lottable14 DATETIME, @d_Lottable15 DATETIME ' 

   EXEC sp_ExecuteSQL @c_SQL, @c_SQLParm, @c_Facility, @c_StorerKey, @c_SKU, @n_QtyLeftToFulfill, @n_UOMBase, @c_Lottable01, @c_Lottable02, @c_Lottable03,
                      @d_Lottable04, @d_Lottable05, @c_Lottable06, @c_Lottable07, @c_Lottable08, @c_Lottable09, @c_Lottable10, @c_Lottable11, @c_Lottable12,
                      @d_Lottable13, @d_Lottable14, @d_Lottable15

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
         
         --(Wan01) - START
         --IF ISNULL(@c_SQL,'') = ''
         --BEGIN
         --   SET @c_SQL = N'   
         --         DECLARE CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR   
         --         SELECT '''  + @c_LOT + ''', ''' + @c_LOC + ''', ''' + @c_ID + ''', ''' + CAST(@n_QtyToTake AS NVARCHAR(10)) + ''', ''' + @c_OtherValue + '''
         --         '
         --END
         --ELSE
         --BEGIN
         --   SET @c_SQL = @c_SQL + N'  
         --         UNION ALL
         --         SELECT '''  + @c_LOT + ''', ''' + @c_LOC + ''', ''' + @c_ID + ''', ''' + CAST(@n_QtyToTake AS NVARCHAR(10)) + ''', ''' + @c_OtherValue + '''
         --         '
         --END
         SET @c_Lot       = RTRIM(@c_Lot)             
         SET @c_Loc       = RTRIM(@c_Loc)
         SET @c_ID        = RTRIM(@c_ID)

         EXEC isp_Insert_Allocate_Candidates
            @c_Lot = @c_Lot
         ,  @c_Loc = @c_Loc
         ,  @c_ID  = @c_ID
         ,  @n_QtyAvailable = @n_QtyToTake
         ,  @c_OtherValue = @c_OtherValue
         --(Wan01) - END             
         
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

   --(Wan01) - START
   EXEC isp_Cursor_Allocate_Candidates   
         @n_SkipPreAllocationFlag = 1    --Return Lot column
   --IF ISNULL(@c_SQL,'') <> ''
   --BEGIN
   --   EXEC sp_ExecuteSQL @c_SQL
   --END
   --ELSE
   --BEGIN
   --   DECLARE  CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR 
   --   SELECT TOP 0 NULL, NULL, NULL, NULL, NULL    
   --END
   --(Wan01) - END
END -- Procedure

GO
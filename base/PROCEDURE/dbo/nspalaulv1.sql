SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: nspALAULV1                                         */
/* Creation Date: 02-MAY-2023                                           */
/* Copyright: MAERSK                                                    */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: WMS-22465 AU Levis allocation                               */
/*          UCC allocation from bulk for UOM 2 and 6                    */
/*          UOM 2 for discrete and conso                                */
/*          UCC Full pallet only for LVS-PAL                            */
/*                                                                      */
/* Called By: Wave                                                      */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author  Ver.  Purposes                                  */
/* 02-May-2023  NJOW    1.0   DEVOPS Combine Script                     */
/************************************************************************/
CREATE   PROC [dbo].[nspALAULV1]
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
           @c_ExtraCondition     NVARCHAR(4000),
           @c_SortingCondition   NVARCHAR(4000),
           @c_FullPalletUCC      NVARCHAR(10) = ''

   SET @n_QtyAvailable = 0
   SET @c_OtherValue = '1'
   SET @n_QtyToTake = 0

   IF @n_UOMBase = 0 OR @c_UOM = '2'
     SET @n_UOMBase = 1

   EXEC isp_Init_Allocate_Candidates

   CREATE TABLE #TMP_LOT (LOT NVARCHAR(10) NULL,
                          QtyAvailable INT NULL DEFAULT(0))
   
   CREATE TABLE #TMP_LLIAVAI (RowID  INT IDENTITY(1,1) PRIMARY KEY,
                              Lot NVARCHAR(10),
                              Loc NVARCHAR(10),
                              ID  NVARCHAR(18),  
                              QtyAvailable INT,
                              UCCNo NVARCHAR(20) NULL,
                              UCCStatus NVARCHAR(10) NULL)
                                                            
   IF LEN(@c_OtherParms) > 0
   BEGIN
      SET @c_OrderKey = LEFT(@c_OtherParms,10)  --if call by discrete
      SET @c_key1 = LEFT(@c_OtherParms, 10) --Orderkey, Loadkey(conso), Wavekey(conso)
      SET @c_key2 = SUBSTRING(@c_OtherParms, 11, 5) --OrderLineNumber
      SET @c_key3 = SUBSTRING(@c_OtherParms, 16, 1) --W=Wave

      IF ISNULL(@c_key1,'')<>'' AND ISNULL(@c_key2,'')<>'' --call by discrete
      BEGIN
      	 IF @c_UOM <> '2'  --if discrete allocation is not uom 2 skip. For uom 2 only.
      	    GOTO EXIT_SP
 
      	 IF EXISTS(SELECT 1 
      	           FROM ORDERS O (NOLOCK) 
      	           JOIN WAVEDETAIL WD (NOLOCK) ON O.Orderkey = WD.Orderkey 
      	           JOIN WAVE W (NOLOCK) ON WD.Wavekey = W.Wavekey
      	           WHERE O.Orderkey = @c_Key1 AND W.WaveType = 'LVS-PAL') --LVS-PAL only allocte full pallet by order
      	    SET @c_FullPalletUCC = 'Y'      	    
      END

      IF ISNULL(@c_key2,'')='' AND ISNULL(@c_key3,'')='W' --call by wave conso
      BEGIN
      	 IF EXISTS(SELECT 1 FROM WAVE (NOLOCK) WHERE Wavekey = @c_Key1 AND WaveType = 'LVS-PAL') --Not to proceed conso allocation if PAL
      	    GOTO EXIT_SP
 
      	 IF @c_UOM = '2'
      	    IF NOT EXISTS(SELECT 1 FROM WAVE (NOLOCK) WHERE Wavekey = @c_Key1 AND WaveType = 'LVS-PTL') --Not to proceed conso carton allocation if not PTL
      	       GOTO EXIT_SP
      END
   END
   
   IF @c_UOM = '6'  --for bulk replenshment
   BEGIN
      SET @c_ExtraCondition = ' AND UCC.Qty > 0 AND SL.LocationType NOT IN (''PICK'',''CASE'') ' + CHAR(13) +
                              ' AND LOC.LocationType = ''BULK'' '
   END
   ELSE
   BEGIN
      SET @c_ExtraCondition = ' AND UCC.Qty > 0 AND SL.LocationType NOT IN (''PICK'',''CASE'') ' + CHAR(13) +
                              ' AND LOC.LocationType = ''CASE'' '
   END                           
                           
   IF @c_FullPalletUCC = 'Y'              
   BEGIN             
      SET @c_ExtraCondition = RTRIM(@c_ExtraCondition) +  ' AND LOC.LocationCategory IN (SELECT CL.Code FROM CODELKUP CL (NOLOCK) WHERE CL.ListName = ''LVSPALAC'' AND CL.Storerkey = @c_Storerkey) '
      SET @c_SortingCondition = ' ORDER BY LOC.LogicalLocation, LOC.Loc, LOTxLOCxID.ID '
   END
   ELSE
   BEGIN
      SET @c_SortingCondition = ' ORDER BY LA.Lottable05, LOC.LogicalLocation, LOC.Loc '
   END
   

   SELECT @n_StorerMinShelfLife = ((Sku.Shelflife * Storer.MinShelflife/100) * -1)
   FROM Sku (nolock)
   JOIN Storer (nolock) ON Sku.Storerkey = Storer.Storerkey
   WHERE Sku.Sku = @c_sku
   AND Sku.Storerkey = @c_storerkey

   IF @n_StorerMinShelfLife IS NULL
      SELECT @n_StorerMinShelfLife = 0

   SET @c_SQL = N'
      INSERT INTO #TMP_LLIAVAI (Lot, Loc, ID, QtyAvailable, UCCNo, UCCStatus)
      SELECT LOTxLOCxID.LOT,
             LOTxLOCxID.LOC,
             LOTxLOCxID.ID,
             UCC.Qty,
             UCC.UCCNo,
             UCC.Status
      FROM LOTxLOCxID (NOLOCK)
      JOIN LOC (NOLOCK) ON (LOTxLOCxID.Loc = LOC.LOC)
      JOIN ID (NOLOCK) ON (LOTxLOCxID.Id = ID.ID)
      JOIN LOT (NOLOCK) ON (LOTXLOCXID.LOT = LOT.LOT)
      JOIN LOTATTRIBUTE LA (NOLOCK) ON LOT.LOT = LA.LOT
      JOIN SKUXLOC SL (NOLOCK) ON (LOTxLOCxID.Storerkey = SL.Storerkey AND LOTxLOCxID.Sku = SL.Sku AND LOTxLOCxID.Loc = SL.Loc)
      JOIN UCC (NOLOCK) ON (UCC.StorerKey = LOTxLOCxID.StorerKey AND UCC.SKU = LOTxLOCxID.SKU AND
                                  UCC.LOT = LOTxLOCxID.LOT AND UCC.LOC = LOC.LOC AND UCC.ID = ID.ID AND UCC.Status <= ''3'')
      WHERE LOC.Status <> ''HOLD''
      AND LOT.Status <> ''HOLD''
      AND ID.Status <> ''HOLD''
      AND LOC.Facility = @c_Facility
      AND (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QtyReplen) >= @n_UOMBase
      AND LOTxLOCxID.STORERKEY = @c_StorerKey
      AND LOTxLOCxID.SKU = @c_SKU
      AND (LOC.LocationFlag = ''NONE'') ' +
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
      @c_ExtraCondition + CHAR(13) +  @c_SortingCondition

   SET @c_SQLParm =  N'@c_Facility   NVARCHAR(5),  @c_StorerKey  NVARCHAR(15), @c_SKU NVARCHAR(20), @n_QtyLeftToFulfill INT, @n_UOMBase INT, ' +
                      '@c_Lottable01 NVARCHAR(18), @c_Lottable02 NVARCHAR(18), @c_Lottable03 NVARCHAR(18), @d_Lottable04 DATETIME, @d_Lottable05 DATETIME, ' +
                      '@c_Lottable06 NVARCHAR(30), @c_Lottable07 NVARCHAR(30), @c_Lottable08 NVARCHAR(30), @c_Lottable09 NVARCHAR(30), @c_Lottable10 NVARCHAR(30), ' +
                      '@c_Lottable11 NVARCHAR(30), @c_Lottable12 NVARCHAR(30), @d_Lottable13 DATETIME, @d_Lottable14 DATETIME, @d_Lottable15 DATETIME '

   EXEC sp_ExecuteSQL @c_SQL, @c_SQLParm, @c_Facility, @c_StorerKey, @c_SKU, @n_QtyLeftToFulfill, @n_UOMBase, @c_Lottable01, @c_Lottable02, @c_Lottable03,
                      @d_Lottable04, @d_Lottable05, @c_Lottable06, @c_Lottable07, @c_Lottable08, @c_Lottable09, @c_Lottable10, @c_Lottable11, @c_Lottable12,
                      @d_Lottable13, @d_Lottable14, @d_Lottable15

   SET @c_SQL = ''
   SET @n_LotQtyAvailable = 0

   IF @c_FullPalletUCC = 'Y'
   BEGIN
   	  WHILE @n_QtyLeftToFulfill > 0
   	  BEGIN   	       
         SELECT TOP 1 @c_Loc = Loc, @c_Id = Id
         FROM #TMP_LLIAVAI
         GROUP BY Loc, ID
         HAVING SUM(CASE WHEN UccStatus = '3' THEN 1 ELSE 0 END) = 0 
                AND SUM(QtyAvailable) <= @n_QtyLeftToFulfill
         ORDER BY CASE WHEN SUM(QtyAvailable) % @n_QtyLeftToFulfill = 0 THEN 1 ELSE 2 END, MIN(RowID)                
                
         IF @@ROWCOUNT = 0
            BREAK

         DECLARE CURSOR_PALLET CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT Lot, QtyAvailable, UCCNo
            FROM #TMP_LLIAVAI
            WHERE UCCStatus < 3
            AND Loc = @c_Loc
            AND Id = @c_ID
            ORDER BY RowId   
         
         OPEN CURSOR_PALLET
         FETCH NEXT FROM CURSOR_PALLET INTO @c_LOT, @n_QtyAvailable, @c_OtherValue
         
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
              IF @c_UOM IN ('1', '2')
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
         
            IF @n_QtyLeftToFulfill < @n_QtyAvailable
            BEGIN
               SET @n_QtyToTake = 0
            END
         
            IF @n_QtyToTake > 0
            BEGIN
              UPDATE #TMP_LOT
              SET QtyAvailable = QtyAvailable - @n_QtyToTake
              WHERE Lot = @c_Lot
         
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
         
            FETCH NEXT FROM CURSOR_PALLET INTO @c_LOT, @n_QtyAvailable, @c_OtherValue
         END -- END WHILE FOR CURSOR_PALLET
         CLOSE CURSOR_PALLET
         DEALLOCATE CURSOR_PALLET                                                 
         
         DELETE FROM #TMP_LLIAVAI WHERE Loc = @c_Loc AND ID = @c_ID         
   	  END
   END
   ELSE
   BEGIN
      DECLARE CURSOR_AVAILABLE CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT Lot, Loc, ID, QtyAvailable, UCCNo
         FROM #TMP_LLIAVAI
         WHERE UCCStatus < 3
         ORDER BY RowId   
      
      OPEN CURSOR_AVAILABLE
      FETCH NEXT FROM CURSOR_AVAILABLE INTO @c_LOT, @c_LOC, @c_ID, @n_QtyAvailable, @c_OtherValue
      
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
           IF @c_UOM IN ('1', '2')
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
          
         IF @n_QtyLeftToFulfill < @n_QtyAvailable AND @c_UOM = '2'
         BEGIN
            SET @n_QtyToTake = 0
         END
               
         IF @n_QtyToTake > 0
         BEGIN
           UPDATE #TMP_LOT
           SET QtyAvailable = QtyAvailable - @n_QtyToTake
           WHERE Lot = @c_Lot
      
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
      
         FETCH NEXT FROM CURSOR_AVAILABLE INTO @c_LOT, @c_LOC, @c_ID, @n_QtyAvailable, @c_OtherValue
      END -- END WHILE FOR CURSOR_AVAILABLE
      CLOSE CURSOR_AVAILABLE
      DEALLOCATE CURSOR_AVAILABLE
   END

   EXIT_SP:

   IF CURSOR_STATUS('LOCAL' , 'CURSOR_AVAILABLE') in (0 , 1)
   BEGIN
      CLOSE CURSOR_AVAILABLE
      DEALLOCATE CURSOR_AVAILABLE
   END

   IF CURSOR_STATUS('LOCAL' , 'CURSOR_PALLET') in (0 , 1)
   BEGIN
      CLOSE CURSOR_PALLET
      DEALLOCATE CURSOR_PALLET
   END

   EXEC isp_Cursor_Allocate_Candidates
        @n_SkipPreAllocationFlag = 1
END -- Procedure nspALAULV1

GO
SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/    
/* Stored Procedure: ispPOUNI01                                         */    
/* Creation Date: 30-Jul-2014                                           */    
/* Copyright: LFL                                                       */    
/* Written by: Chee Jun Yan                                             */    
/*                                                                      */    
/* Purpose: SOS#315963 - Alter PickDetail based on calculation of       */    
/*          rounding formula & round-robin/reverse logic                */    
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
/* Date         Author    Ver.  Purposes                                */    
/************************************************************************/    
CREATE PROC [dbo].[ispPOUNI01]    
    @c_WaveKey                      NVARCHAR(10)    
  , @c_UOM                          NVARCHAR(10)    
  , @c_LocationTypeOverride         NVARCHAR(10)    
  , @c_LocationTypeOverRideStripe   NVARCHAR(10)    
  , @b_Success                      INT           OUTPUT    
  , @n_Err                          INT           OUTPUT    
  , @c_ErrMsg                       NVARCHAR(250) OUTPUT    
  , @b_Debug                        INT = 0    
AS    
BEGIN    
   SET NOCOUNT ON 
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF    
    
   DECLARE    
      @n_Continue    INT,    
      @n_StartTCnt   INT    
    
   DECLARE    
      @c_PickDetailKey    NVARCHAR(18),    
      @c_NewPickDetailKey NVARCHAR(18),    
      @c_StorerKey        NVARCHAR(15),    
      @c_SKU              NVARCHAR(20),    
      @c_Facility         NVARCHAR(5),    
      @c_Lottable01       NVARCHAR(18),    
      @c_Lottable02       NVARCHAR(18),    
      @c_Lottable03       NVARCHAR(18),    
      @c_Loc              NVARCHAR(10),    
      @c_Lot              NVARCHAR(10),    
      @c_ID               NVARCHAR(18),    
      @n_QtyAvailable     INT,    
      @c_PickMethod       NVARCHAR(1),    
      @c_SQL              NVARCHAR(MAX),        
      @c_SQLParm          NVARCHAR(MAX)     
    
   DECLARE    
      @c_OrderKey           NVARCHAR(10),    
      @c_OrderLineNumber    NVARCHAR(5),    
      @n_OrderQty           INT,    
      @n_TotalOrderQty      INT,    
      @n_TotalAvailableQty  INT,    
      @n_TotalAllocateQty   INT,    
      @d_AllocateQty        DECIMAL(18,1),    
      @n_AllocateQty        INT,    
      @c_PackKey            NVARCHAR(10),    
      @c_aUOM               NVARCHAR(30),    
      @n_PackSize           INT,    
      @n_RemainingQty       INT,    
      @n_RoundRobin         INT,    
      @n_Row                INT,    
      @n_Diff               INT,    
      @n_Count              INT,    
      @n_Qty                INT    
    
   SELECT @n_StartTCnt = @@TRANCOUNT , @n_Continue=1, @b_Success=1, @n_Err=0, @c_ErrMsg=''    
    
   IF OBJECT_ID('tempdb..#ORDERLINES','u') IS NOT NULL    
      DROP TABLE #ORDERLINES;    
    
   -- Store all OrderDetail in Wave    
   CREATE TABLE #ORDERLINES (    
      SeqNo           INT IDENTITY(1,1),    
      OrderKey        NVARCHAR(10),    
      OrderLineNumber NVARCHAR(5),    
      OpenQty         INT,    
      AllocatedQty    INT,    
      NewAllocatedQty INT,    
      Facility        NVARCHAR(5),    
      StorerKey       NVARCHAR(15),    
      SKU             NVARCHAR(20),    
      StorePriority   NVARCHAR(10),    
      PackKey    NVARCHAR(10),    
      UOM             NVARCHAR(30),    
      PackSize        INT,    
      Lottable01      NVARCHAR(18),    
      Lottable02      NVARCHAR(18),    
      Lottable03      NVARCHAR(18)    
   )    
    
   /*********************************/    
   /***  GET ORDERLINES OF WAVE   ***/    
   /*********************************/    
   INSERT INTO #ORDERLINES    
   SELECT    
      OD.OrderKey,    
      OD.OrderLineNumber,    
      OD.OpenQty,    
      OD.QtyAllocated,    
      0,    
      ISNULL(RTRIM(O.Facility),''),    
      ISNULL(RTRIM(OD.Storerkey),''),    
      ISNULL(RTRIM(OD.Sku),''),    
      ISNULL(RTRIM(SD.Priority),''),    
      ISNULL(RTRIM(SKU.PackKey),''),    
      '1',    
      1,    
      ISNULL(RTRIM(OD.Lottable01),''),    
      ISNULL(RTRIM(OD.Lottable02),''),    
      ISNULL(RTRIM(OD.Lottable03),'')    
   FROM ORDERDETAIL OD WITH (NOLOCK)    
   JOIN SKU WITH (NOLOCK) ON SKU.StorerKey = OD.StorerKey AND SKU.Sku = OD.Sku    
   JOIN ORDERS O WITH (NOLOCK) ON O.OrderKey = OD.OrderKey    
   JOIN WAVEDETAIL WD WITH (NOLOCK) ON OD.OrderKey = WD.OrderKey    
   JOIN STORERSODEFAULT SD WITH (NOLOCK) ON SD.StorerKey = OD.StorerKey    
   WHERE WD.WaveKey = @c_WaveKey    
     AND O.Type NOT IN ('M', 'I')    
     AND O.SOStatus <> 'CANC'    
     AND O.Status < '9'    
     AND (OD.OpenQty - ( OD.QtyAllocated + OD.QtyPreAllocated + OD.QtyPicked )) > 0    
    
   IF @b_Debug = 1    
   BEGIN    
      SELECT * FROM #ORDERLINES WITH (NOLOCK)    
   END    
    
   DECLARE CURSOR_ORDERLINES CURSOR FAST_FORWARD READ_ONLY FOR    
   SELECT #ORDERLINES.StorerKey,    
          #ORDERLINES.SKU,    
          SUM(#ORDERLINES.OpenQty),    
          SUM(#ORDERLINES.AllocatedQty),    
          #ORDERLINES.Facility,    
          #ORDERLINES.Lottable01,    
          #ORDERLINES.Lottable02,    
          #ORDERLINES.Lottable03    
   FROM #ORDERLINES WITH (NOLOCK)    
   GROUP BY #ORDERLINES.StorerKey,    
          #ORDERLINES.SKU,    
          #ORDERLINES.Facility,    
          #ORDERLINES.Lottable01,    
          #ORDERLINES.Lottable02,    
          #ORDERLINES.Lottable03    
    
   OPEN CURSOR_ORDERLINES    
   FETCH NEXT FROM CURSOR_ORDERLINES INTO @c_StorerKey, @c_SKU, @n_TotalOrderQty, @n_TotalAvailableQty, @c_Facility,    
                                          @c_Lottable01, @c_Lottable02, @c_Lottable03    
    
   WHILE (@@FETCH_STATUS <> -1)    
   BEGIN    
      IF @b_Debug = 1    
      BEGIN    
         PRINT '--------------------------------------------' + CHAR(13) +    
               '  @c_StorerKey: ' + @c_StorerKey + CHAR(13) +    
               ', @c_SKU: ' +@c_SKU + CHAR(13) +    
               ', @n_TotalOrderQty: ' + CAST(@n_TotalOrderQty AS NVARCHAR) + CHAR(13) +    
               ', @n_TotalAvailableQty: ' + CAST(@n_TotalAvailableQty AS NVARCHAR) + CHAR(13) +    
               ', @c_Facility: ' + @c_Facility + CHAR(13) +    
               ', @c_Lottable01: ' + @c_Lottable01 + CHAR(13) +    
               ', @c_Lottable02: ' + @c_Lottable02 + CHAR(13) +    
               ', @c_Lottable03: ' + @c_Lottable03 +' (' + CONVERT(NVARCHAR(24), GETDATE(), 121) + ')' + CHAR(13) +    
               '--------------------------------------------'     
      END    
    
--   SELECT    
--      @n_TotalOrderQty = SUM(OD.OpenQty),    
--      @n_TotalAvailableQty = SUM(OD.QtyAllocated)    
--   FROM OrderDetail OD WITH (NOLOCK)    
--   JOIN WaveDetail WD WITH (NOLOCK) ON (OD.OrderKey = WD.OrderKey)    
--   WHERE WD.WaveKey = @c_WaveKey    
    
      -- IF TotalAllocatedQty < TotalOrderQty, then continue    
      IF @n_TotalAvailableQty < @n_TotalOrderQty    
      BEGIN    
         -- Calculate PackSize & AllocateQty and store into temp table    
         DECLARE CURSOR_ORDER_ROUNDING CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
         SELECT OrderKey, OrderLineNumber, PackKey, UOM, OpenQty    
         FROM #ORDERLINES WITH (NOLOCK)    
         WHERE StorerKey = @c_StorerKey    
           AND SKU = @c_SKU    
           AND Facility = @c_Facility    
           AND Lottable01 = @c_Lottable01    
           AND Lottable02 = @c_Lottable02    
           AND Lottable03 = @c_Lottable03    
    
         OPEN CURSOR_ORDER_ROUNDING    
         FETCH NEXT FROM CURSOR_ORDER_ROUNDING INTO @c_OrderKey, @c_OrderLineNumber, @c_PackKey, @c_aUOM, @n_OrderQty    
    
         WHILE (@@FETCH_STATUS <> -1)    
         BEGIN    
            -- Calculate PackSize    
            SET @n_PackSize = 0    
            WHILE @n_PackSize = 0    
            BEGIN    
               SELECT @n_PackSize = CASE @c_aUOM    
                                    WHEN '1' THEN Pallet    
                                    WHEN '2' THEN CaseCnt    
                                    WHEN '3' THEN InnerPack    
                                    WHEN '4' THEN CONVERT(INT,OtherUnit1)    
                                    WHEN '5' THEN CONVERT(INT,OtherUnit2)    
                                    WHEN '6' THEN 1    
                                    WHEN '7' THEN 1    
                                    ELSE 1    
                                 END    
               FROM PACK WITH (NOLOCK)    
               WHERE PackKey = @c_PackKey    
    
               IF @n_PackSize > @n_OrderQty    
                  SET @n_PackSize = 0    
    
               IF @c_aUOM >= '7'    
                  SET @n_PackSize = 1    
               ELSE IF @n_PackSize = 0    
                  SELECT @c_aUOM = CONVERT(NVARCHAR(1), CONVERT(INT,@c_aUOM)+1)    
            END -- WHILE @n_PackSize = 0    
    
            SET @d_AllocateQty = @n_OrderQty * 1.0 / @n_TotalOrderQty * @n_TotalAvailableQty    
    
            IF @d_AllocateQty % 1 >= 0.8    
               SET @n_AllocateQty = @d_AllocateQty + 1    
            ELSE    
               SET @n_AllocateQty = @d_AllocateQty    
    
            -- Round down to nearest packsize    
            SET @n_AllocateQty = (@n_AllocateQty / @n_PackSize) * @n_PackSize    
    
            UPDATE #ORDERLINES WITH (ROWLOCK)    
            SET NewAllocatedQty = @n_AllocateQty, PackSize = @n_PackSize    
            WHERE OrderKey = @c_OrderKey    
              AND OrderLineNumber = @c_OrderLineNumber    
    
            FETCH NEXT FROM CURSOR_ORDER_ROUNDING INTO @c_OrderKey, @c_OrderLineNumber, @c_PackKey, @c_aUOM, @n_OrderQty    
         END    
         CLOSE CURSOR_ORDER_ROUNDING    
         DEALLOCATE CURSOR_ORDER_ROUNDING    
    
         IF @b_Debug = 1    
            SELECT * FROM #ORDERLINES WITH (NOLOCK)    
            WHERE StorerKey = @c_StorerKey    
              AND SKU = @c_SKU    
              AND Facility = @c_Facility    
              AND Lottable01 = @c_Lottable01    
              AND Lottable02 = @c_Lottable02    
              AND Lottable03 = @c_Lottable03    
    
         SELECT @n_TotalAllocateQty = SUM(NewAllocatedQty)     
         FROM #ORDERLINES WITH (NOLOCK)    
         WHERE StorerKey = @c_StorerKey    
           AND SKU = @c_SKU    
           AND Facility = @c_Facility    
           AND Lottable01 = @c_Lottable01    
           AND Lottable02 = @c_Lottable02    
           AND Lottable03 = @c_Lottable03    
    
         IF @n_TotalAvailableQty <> @n_TotalAllocateQty    
         BEGIN    
            IF @n_TotalAvailableQty > @n_TotalAllocateQty    
            BEGIN    
               SET @n_RemainingQty = @n_TotalAvailableQty - @n_TotalAllocateQty    
               SET @n_RoundRobin = 1    
            END    
            ELSE    
            BEGIN    
               SET @n_RemainingQty = @n_TotalAllocateQty - @n_TotalAvailableQty    
               SET @n_RoundRobin = 0      
            END    
    
            SELECT @n_Row = 0, @n_Count = COUNT(1)     
            FROM #ORDERLINES WITH (NOLOCK)    
            WHERE StorerKey = @c_StorerKey    
              AND SKU = @c_SKU    
              AND Facility = @c_Facility    
           AND Lottable01 = @c_Lottable01    
              AND Lottable02 = @c_Lottable02    
              AND Lottable03 = @c_Lottable03    
    
            IF @b_Debug = 1    
               SELECT     
                 CASE WHEN @n_RoundRobin = 1 THEN 'ROUND ROBIN' ELSE 'REVERSE ROUND ROBIN' END    
               , @n_RemainingQty     AS '@n_RemainingQty'    
               , @n_TotalAllocateQty AS '@n_TotalAllocateQty'    
               , @n_Count            AS '@n_Count'    
    
            -- Do Round Robin / Reverse Round Robin    
            WHILE @n_RemainingQty > 0 AND @n_Count > @n_Row     
            BEGIN    
               SELECT TOP 1        
                  @n_Row             = Row        
                 ,@c_OrderKey        = OrderKey    
                 ,@c_OrderLineNumber = OrderLineNumber    
                 ,@n_OrderQty        = OpenQty    
                 ,@n_AllocateQty     = NewAllocatedQty    
                 ,@n_PackSize        = PackSize    
               FROM (    
                  SELECT    
                     ROW_NUMBER() OVER (ORDER BY (CASE WHEN @n_RoundRobin = 1 THEN StorePriority ELSE '' END) ASC,    
                                                 (CASE WHEN @n_RoundRobin = 0 THEN StorePriority ELSE '' END) DESC) AS Row,    
                     OrderKey, OrderLineNumber, Facility, StorerKey, SKU, StorePriority, PackSize, OpenQty, NewAllocatedQty    
                  FROM #ORDERLINES WITH (NOLOCK)    
                  WHERE StorerKey = @c_StorerKey    
                    AND SKU = @c_SKU    
                    AND Facility = @c_Facility    
                    AND Lottable01 = @c_Lottable01    
                    AND Lottable02 = @c_Lottable02    
                    AND Lottable03 = @c_Lottable03  ) AS A    
               WHERE Row > @n_Row        
               ORDER BY Row    
    
               IF @n_RoundRobin = 1    
                  SET @n_Diff = @n_OrderQty - @n_AllocateQty    
               ELSE     
                  SET @n_Diff = (@n_AllocateQty / @n_PackSize) * @n_PackSize     
    
               IF @b_Debug = 1    
                  SELECT     
                     @n_Row             AS '@n_Row',    
                     @c_OrderKey        AS '@c_OrderKey',    
                     @c_OrderLineNumber AS '@c_OrderLineNumber',    
                     @n_PackSize         AS '@n_PackSize',    
                     @n_OrderQty        AS '@n_OrderQty',    
                     @n_AllocateQty     AS '@n_AllocateQty',    
                     @n_RemainingQty    AS '@n_RemainingQty',    
                     @n_Diff            AS '@n_Diff'    
    
               IF @n_RemainingQty >= @n_Diff    
               BEGIN    
                  UPDATE #ORDERLINES WITH (ROWLOCK)    
                  SET NewAllocatedQty = NewAllocatedQty + CASE WHEN @n_RoundRobin = 1 THEN @n_Diff ELSE - @n_Diff END    
                  WHERE OrderKey = @c_OrderKey     
                    AND OrderLineNumber = @c_OrderLineNumber     
    
                  SET @n_RemainingQty = @n_RemainingQty - @n_Diff    
               END -- IF @n_RemainingQty >= @n_Diff    
            END -- WHILE @n_RemainingQty > 0    
         END -- IF @n_TotalAvailableQty <> @n_TotalAllocateQty    
    
         -- Alter existing PickDetail    
         DECLARE CURSOR_PICKDETAIL CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
         SELECT OrderKey, OrderLineNumber, NewAllocatedQty, AllocatedQty    
         FROM #ORDERLINES WITH (NOLOCK)    
         WHERE StorerKey = @c_StorerKey    
           AND SKU = @c_SKU    
           AND Facility = @c_Facility    
           AND Lottable01 = @c_Lottable01    
           AND Lottable02 = @c_Lottable02    
           AND Lottable03 = @c_Lottable03    
           AND NewAllocatedQty <> AllocatedQty    
         ORDER BY NewAllocatedQty - AllocatedQty    
    
         OPEN CURSOR_PICKDETAIL    
         FETCH NEXT FROM CURSOR_PICKDETAIL INTO @c_OrderKey, @c_OrderLineNumber, @n_OrderQty, @n_AllocateQty    
    
         WHILE (@@FETCH_STATUS <> -1)    
         BEGIN    
            -- If new allocated Qty is smaller than allocated Qty, delete pickdetail. Else, insert pickdetail    
            IF @n_OrderQty < @n_AllocateQty    
            BEGIN    
               SET @n_Diff = @n_AllocateQty - @n_OrderQty    
    
               WHILE (@n_Diff > 0)    
               BEGIN    
                  SELECT TOP 1    
                     @c_PickDetailKey = PickDetailKey,    
                     @n_Qty = Qty    
                  FROM PickDetail WITH (NOLOCK)      
                  WHERE Orderkey = @c_OrderKey      
                    AND OrderLineNumber = @c_OrderLineNumber      
                  ORDER BY Qty    
    
                  IF @n_Diff < @n_Qty      
                  BEGIN      
                     UPDATE PickDetail WITH (ROWLOCK)    
                     SET Qty = Qty - @n_Diff      
                     WHERE PickDetailKey = @c_PickDetailKey      
    
                     IF @@ERROR <> 0      
                     BEGIN      
                        SET @n_Continue = 3      
                        SET @n_Err = 14000      
                        SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0)) +       
                                        ': Update PickDetail Failed. (ispPOUNI01)'      
                        GOTO Quit      
                     END      
    
                     SET @n_Diff = 0      
                  END      
                  ELSE      
                  BEGIN      
                     DELETE FROM PickDetail      
                     WHERE PickDetailKey = @c_PickDetailKey      
    
                     IF @@ERROR <> 0      
                     BEGIN      
                        SET @n_Continue = 3      
                        SET @n_Err = 14001     
                        SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0)) +       
                                        ': Delete PickDetail Failed. (ispPOUNI01)'      
                        GOTO Quit      
                     END      
    
                     SET @n_Diff = @n_Diff - @n_Qty    
                  END     
               END -- WHILE (@n_Diff > 0)    
            END -- IF @n_OrderQty < @n_AllocateQty    
            ELSE    
            BEGIN    
               SET @n_Diff = @n_OrderQty - @n_AllocateQty    
    
               SET @c_SQL = N'        
                     DECLARE CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR    
                     SELECT LOTxLOCxID.LOT,        
                            LOTxLOCxID.LOC,         
                            LOTxLOCxID.ID,        
                            QTYAVAILABLE = (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QtyReplen)       
                     FROM LOTxLOCxID (NOLOCK)         
                     JOIN LOC (NOLOCK) ON (LOTxLOCxID.Loc = LOC.LOC)        
                     JOIN ID (NOLOCK) ON (LOTxLOCxID.Id = ID.ID AND ID.STATUS <> ''HOLD'')         
                     JOIN LOT (NOLOCK) ON (LOTXLOCXID.LOT = LOT.LOT AND LOT.STATUS <> ''HOLD'')           
                     JOIN LOTATTRIBUTE LA (NOLOCK) ON LOT.LOT = LA.LOT    
                     JOIN STORERSODEFAULT SD (NOLOCK) ON SD.StorerKey = LOTxLOCxID.STORERKEY         
                     WHERE LOC.LocationFlag <> ''HOLD''    
                     AND LOC.LocationFlag <> ''DAMAGE''    
                     AND LOC.Status <> ''HOLD''    
                     AND LOC.Facility = @c_Facility    
                     AND LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QtyReplen > 0    
                     AND LOTxLOCxID.STORERKEY = @c_StorerKey     
                     AND LOTxLOCxID.SKU = @c_SKU ' + CHAR(13) +              
                     CASE WHEN ISNULL(RTRIM(@c_Lottable01),'') = '' THEN '' ELSE ' AND LA.Lottable01 = @c_Lottable01 ' + CHAR(13) END +    
                     CASE WHEN ISNULL(RTRIM(@c_Lottable02),'') = '' THEN '' ELSE ' AND LA.Lottable02 = @c_Lottable02 ' + CHAR(13) END +    
            CASE WHEN ISNULL(RTRIM(@c_Lottable03),'') = '' THEN '' ELSE ' AND LA.Lottable03 = @c_Lottable03 ' + CHAR(13) END +    
                     'ORDER BY SD.Priority'    
    
               SET @c_SQLParm =  N'@c_Facility   NVARCHAR(5),  @c_StorerKey  NVARCHAR(15), @c_SKU        NVARCHAR(20), ' +    
                                  '@c_Lottable01 NVARCHAR(18), @c_Lottable02 NVARCHAR(18), @c_Lottable03 NVARCHAR(18) '    
    
               EXEC sp_ExecuteSQL @c_SQL, @c_SQLParm, @c_Facility, @c_StorerKey, @c_SKU, @c_Lottable01, @c_Lottable02, @c_Lottable03    
    
               OPEN CURSOR_CANDIDATES    
               FETCH NEXT FROM CURSOR_CANDIDATES INTO @c_Lot, @c_Loc, @c_ID, @n_QtyAvailable    
    
               WHILE (@@FETCH_STATUS <> -1)    
               BEGIN    
                  SELECT @c_PickMethod =    
                             CASE @c_aUOM    
                                 WHEN '1' THEN UOM4PickMethod -- Full Pallets    
                                 WHEN '2' THEN UOM1PickMethod -- Full Case    
                                 WHEN '3' THEN UOM2PickMethod -- Inner    
                                 WHEN '4' THEN UOM5PickMethod -- Other 1    
                                 WHEN '5' THEN UOM6PickMethod -- Other 2 (uses the same PickMethod as other1)    
                                 WHEN '6' THEN UOM3PickMethod -- Piece    
                                 WHEN '7' THEN UOM3PickMethod -- Piece    
                                 ELSE '0'    
                        END    
                  FROM LOC WITH (NOLOCK)    
                  JOIN PUTAWAYZONE WITH (NOLOCK) ON LOC.Putawayzone = PUtawayzone.Putawayzone    
                  WHERE LOC.LOC = @c_Loc    
    
                  IF ISNULL(RTRIM(@c_PickMethod),'') = ''    
                  BEGIN    
                     SET @c_PickMethod = '3'    
                  END    
    
                  IF @n_Diff < @n_QtyAvailable    
                  BEGIN    
                     SET @n_Qty = @n_Diff    
                     SET @n_Diff = 0      
                  END      
                  ELSE      
                  BEGIN    
                     SET @n_Qty = @n_QtyAvailable    
                     SET @n_Diff = @n_Diff - @n_QtyAvailable    
                  END    
    
                  -- INSERT PickDetail    
                  EXECUTE nspg_getkey    
                    'PickDetailKey'    
                    , 10        
                    , @c_PickDetailKey OUTPUT    
                    , @b_Success       OUTPUT    
                    , @n_Err           OUTPUT    
                    , @c_ErrMsg        OUTPUT    
    
                  IF @b_Success <> 1    
                  BEGIN    
                     SET @n_Continue = 3    
                     SET @n_Err = 14002    
                     SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0)) +    
                                     ': Get PickDetailKey Failed. (ispPOUNI01)'    
                     GOTO Quit    
                  END    
                  ELSE    
                  BEGIN    
                     INSERT PICKDETAIL (    
                         PickDetailKey, PickHeaderKey, OrderKey, OrderLineNumber,    
                         Lot, StorerKey, Sku, Qty, Loc, Id,    
                         UOMQty, UOM, CaseID,    
                         PackKey, CartonGroup, doCartonize,    
                         DoReplenish, replenishzone, PickMethod, WaveKey, Notes    
                     ) VALUES (    
                         @c_PickDetailKey, '', @c_OrderKey, @c_OrderLineNumber,    
                         @c_Lot, @c_StorerKey, @c_SKU, @n_Qty, @c_Loc, @c_Id,    
                         @n_Qty, @c_aUOM, '',       
                         @c_PackKey, '', 'N',     
                         'N', '', @c_PickMethod, @c_WaveKey, 'ispPOUNI01'    
                     )    
    
                     IF @@ERROR <> 0    
                     BEGIN      
                        SET @n_Continue = 3    
                        SET @n_Err = 14003    
                        SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0)) +    
                                        ': Insert PickDetail Failed. (ispPOUNI01)'    
                        GOTO Quit    
                     END      
                  END -- IF @b_Success = 1    
      
                  FETCH NEXT FROM CURSOR_CANDIDATES INTO @c_Lot, @c_Loc, @c_ID, @n_QtyAvailable    
               END    
               CLOSE CURSOR_CANDIDATES    
               DEALLOCATE CURSOR_CANDIDATES    
    
            END -- IF @n_OrderQty > @n_AllocateQty    
    
            FETCH NEXT FROM CURSOR_PICKDETAIL INTO @c_OrderKey, @c_OrderLineNumber, @n_OrderQty, @n_AllocateQty    
         END    
         CLOSE CURSOR_PICKDETAIL    
         DEALLOCATE CURSOR_PICKDETAIL    
    
      END -- IF TotalAllocatedQty < TotalOrderQty    
    
      IF @b_Debug = 1    
         PRINT '-------------------------------------------------' + CHAR(13)    
    
      FETCH NEXT FROM CURSOR_ORDERLINES INTO @c_StorerKey, @c_SKU, @n_TotalOrderQty, @n_TotalAvailableQty, @c_Facility,    
                                 @c_Lottable01, @c_Lottable02, @c_Lottable03    
   END -- END WHILE FOR CURSOR_ORDERLINES    
   CLOSE CURSOR_ORDERLINES    
   DEALLOCATE CURSOR_ORDERLINES    
    
QUIT:    
   IF (SELECT CURSOR_STATUS('LOCAL','CURSOR_ORDER_ROUNDING')) >=0    
   BEGIN    
      CLOSE CURSOR_ORDER_ROUNDING    
      DEALLOCATE CURSOR_ORDER_ROUNDING    
   END    
    
   IF (SELECT CURSOR_STATUS('LOCAL','CURSOR_PICKDETAIL')) >=0    
   BEGIN    
      CLOSE CURSOR_PICKDETAIL    
      DEALLOCATE CURSOR_PICKDETAIL    
   END    
    
   IF (SELECT CURSOR_STATUS('LOCAL','CURSOR_ORDERLINES')) >=0    
   BEGIN    
      CLOSE CURSOR_ORDERLINES    
      DEALLOCATE CURSOR_ORDERLINES    
   END    
    
   IF (SELECT CURSOR_STATUS('LOCAL','CURSOR_CANDIDATES')) >=0    
   BEGIN    
      CLOSE CURSOR_CANDIDATES    
      DEALLOCATE CURSOR_CANDIDATES    
   END    
    
   IF @n_Continue=3  -- Error Occured - Process And Return    
   BEGIN    
      SELECT @b_Success = 0    
      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt    
      BEGIN    
         ROLLBACK TRAN    
      END    
      ELSE    
      BEGIN    
         WHILE @@TRANCOUNT > @n_StartTCnt    
         BEGIN      
            COMMIT TRAN    
         END    
      END    
      EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'ispPOUNI01'    
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012    
      RETURN    
   END    
   ELSE    
   BEGIN    
      SELECT @b_Success = 1    
      WHILE @@TRANCOUNT > @n_StartTCnt    
      BEGIN    
         COMMIT TRAN    
      END    
      RETURN    
   END    
    
END -- Procedure 


GO
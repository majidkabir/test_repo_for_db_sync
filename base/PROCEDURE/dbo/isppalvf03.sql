SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/    
/* Stored Procedure: ispPALVF03                                         */    
/* Creation Date: 20-Jun-2014                                           */    
/* Copyright: LFL                                                       */    
/* Written by: Chee Jun Yan                                             */    
/*                                                                      */    
/* Purpose: Step 0b - Pick Full Pallet from Bulk first (to release bulk */ 
/*                    pallet location), then from Pallet :              */
/*                    1. Pick Full Case by Orderline [UOM:2]            */ 
/*                    2. Pick Consolidate Orders' Full Case [UOM:6]     */ 
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
/* Date         Author        Purposes                                  */ 
/* 20-Jun-2014  Chee          SOS#                                      */
/* 21-Oct-2014  Chee          SOS#323318 Fix XDock Multiple UCC Pack    */
/*                            Size in one pallet issue (Chee01)         */
/* 07-Nov-2014  Shong         Cater XD Orders - UOM Should equal to 2   */
/************************************************************************/    
CREATE PROC [dbo].[ispPALVF03]        
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
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF

   DECLARE
      @n_Continue    INT,
      @n_StartTCnt   INT,
      @c_SQL         NVARCHAR(MAX),
      @c_SQLParm     NVARCHAR(MAX)

   DECLARE 
      @c_Loc               NVARCHAR(10),
      @c_Lot               NVARCHAR(10),
      @c_ID                NVARCHAR(18),
      @c_OrderKey          NVARCHAR(10),
      @c_OrderLineNumber   NVARCHAR(5),
      @c_Facility          NVARCHAR(5),     
      @c_StorerKey         NVARCHAR(15),     
      @c_LocationType      NVARCHAR(10),    
      @c_LocationCategory  NVARCHAR(10),
      @c_SKU               NVARCHAR(20),    
      @c_Lottable01        NVARCHAR(18),    
      @c_Lottable02        NVARCHAR(18),    
      @c_Lottable03        NVARCHAR(18),
      @c_PickDetailKey     NVARCHAR(10),
      @c_PackKey           NVARCHAR(10), 
      @n_QtyLeftToFulfill  INT,
      @n_QtyAvailable      INT,
      @n_CtnCount          INT,
      @n_QtyCount          INT,
      @n_QtyNeeded         INT,
      @n_RemainingUCCQty   INT, 
      @n_RemainingCtn      INT, 
      @n_PickQty           INT,
      @n_OrderQty          INT,
      @n_UCCQty            INT,
      @n_Count             INT,
      @n_Sum               INT,
      @n_Number            INT, 
      @n_Pos               INT,
      @c_Subset            NVARCHAR(MAX), 
      @c_TempStr           NVARCHAR(MAX),
      @n_QtyOrd            INT, 
      @c_OrderGroup        NVARCHAR(10),
      @n_QtyToAllocate     INT
      

   DECLARE
      @c_FullCaseUOM         NVARCHAR(1),
      @c_ConsoCaseUOM        NVARCHAR(1),
      @c_FullCasePickMethod  NVARCHAR(1),
      @c_ConsoCasePickMethod NVARCHAR(1)

   -- FROM VNA BULK Area 
   SET @c_LocationType = 'OTHER'      
   SET @c_LocationCategory = 'VNA'

   -- UOM
   SET @c_FullCaseUOM  = '2'
   SET @c_ConsoCaseUOM = '6'

   -- PickMethod
   SET @c_FullCasePickMethod  = 'F'
   SET @c_ConsoCasePickMethod = 'C'

   SELECT @n_StartTCnt = @@TRANCOUNT , @n_Continue=1, @b_Success=1, @n_Err=0, @c_ErrMsg=''

   /*****************************/
   /***   CREATE TEMP TABLE   ***/
   /*****************************/

   IF OBJECT_ID('tempdb..#ORDERLINES','u') IS NOT NULL
      DROP TABLE #ORDERLINES;

   -- Store all OrderDetail in Wave
   CREATE TABLE #ORDERLINES (  
      SeqNo             INT IDENTITY(1, 1),  
      OrderKey          NVARCHAR(10), 
      OrderLineNumber   NVARCHAR(5), 
      OrderQty          INT, 
      SKU               NVARCHAR(20),
      PackKey           NVARCHAR(10), 
      StorerKey         NVARCHAR(15), 
      Facility          NVARCHAR(5),  
      Lottable01        NVARCHAR(18), 
      Lottable02        NVARCHAR(18), 
      Lottable03        NVARCHAR(18),
      Result            NVARCHAR(MAX),
      OrderGroup        NVARCHAR(10)  
   )

   IF OBJECT_ID('tempdb..#CombinationPool','u') IS NOT NULL
      DROP TABLE #CombinationPool;

   -- Store all possible combination numbers
   CREATE TABLE #CombinationPool (
      [Sum]    INT, 
      Subset   NVARCHAR(MAX)
   )

   IF OBJECT_ID('tempdb..#SplitList','u') IS NOT NULL
      DROP TABLE #SplitList;

   -- Store SPLIT of #CombinationPool.Subset
   CREATE TABLE #SplitList (
      Qty      INT,
      [Count]  INT
   )

   /*********************************/
   /***  GET ORDERLINES OF WAVE   ***/
   /*********************************/
   INSERT INTO #ORDERLINES
   SELECT
      OD.OrderKey,
      OD.OrderLineNumber,
      (OD.OpenQty - (OD.QtyAllocated + OD.QtyPreAllocated + OD.QtyPicked)),
      ISNULL(RTRIM(OD.Sku),''),
      ISNULL(RTRIM(SKU.PackKey),''),
      ISNULL(RTRIM(OD.Storerkey),''),
      ISNULL(RTRIM(O.Facility),''),
      ISNULL(RTRIM(OD.Lottable01),''),
      ISNULL(RTRIM(OD.Lottable02),''),
      ISNULL(RTRIM(OD.Lottable03),''),
      '',
      ISNULL(RTRIM(O.OrderGroup), '')
   FROM ORDERDETAIL OD WITH (NOLOCK)
   JOIN SKU WITH (NOLOCK) ON SKU.StorerKey = OD.StorerKey AND SKU.Sku = OD.Sku
   JOIN ORDERS O WITH (NOLOCK) ON O.OrderKey = OD.OrderKey
   JOIN WAVEDETAIL WD WITH (NOLOCK) ON OD.OrderKey = WD.OrderKey
   WHERE WD.WaveKey = @c_WaveKey
     AND O.Type NOT IN ( 'M', 'I' )
     AND O.SOStatus <> 'CANC'
     AND O.Status < '9'
     AND (OD.OpenQty - ( OD.QtyAllocated + OD.QtyPreAllocated + OD.QtyPicked )) > 0

   IF @b_Debug = 1
   BEGIN
      SELECT * FROM #ORDERLINES WITH (NOLOCK)
   END

   /*******************************/
   /***  LOOP BY DISTINCT SKU   ***/
   /*******************************/

   DECLARE CURSOR_ORDERLINES CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
   SELECT DISTINCT SKU, StorerKey, Facility, Lottable01, Lottable02, Lottable03, OrderGroup
   FROM #ORDERLINES WITH (NOLOCK)

   OPEN CURSOR_ORDERLINES
   FETCH NEXT FROM CURSOR_ORDERLINES INTO @c_SKU, @c_StorerKey, @c_Facility, @c_Lottable01, @c_Lottable02, @c_Lottable03, @c_OrderGroup
          
   WHILE (@@FETCH_STATUS <> -1)
   BEGIN 
      IF @c_OrderGroup = 'XD' 
      BEGIN
        SELECT @n_QtyLeftToFulfill = OrderQty
         FROM #ORDERLINES WITH (NOLOCK)
         WHERE SKU = @c_SKU
           AND StorerKey = @c_StorerKey
           AND Facility = @c_Facility 
           AND Lottable01 = CASE WHEN ISNULL(@c_Lottable01, '') = '' THEN Lottable01 ELSE @c_Lottable01 END
           AND Lottable02 = CASE WHEN ISNULL(@c_Lottable02, '') = '' THEN Lottable02 ELSE @c_Lottable02 END
           AND Lottable03 = CASE WHEN ISNULL(@c_Lottable03, '') = '' THEN Lottable03 ELSE @c_Lottable03 END 
           AND OrderKey   = @c_OrderKey 
           AND OrderLineNumber = @c_OrderLineNumber 
      END
      ELSE
      BEGIN
         SELECT @n_QtyLeftToFulfill = SUM(OrderQty)
         FROM #ORDERLINES WITH (NOLOCK)
         WHERE SKU = @c_SKU
           AND StorerKey = @c_StorerKey
           AND Facility = @c_Facility 
           AND Lottable01 = CASE WHEN ISNULL(@c_Lottable01, '') = '' THEN Lottable01 ELSE @c_Lottable01 END
           AND Lottable02 = CASE WHEN ISNULL(@c_Lottable02, '') = '' THEN Lottable02 ELSE @c_Lottable02 END
           AND Lottable03 = CASE WHEN ISNULL(@c_Lottable03, '') = '' THEN Lottable03 ELSE @c_Lottable03 END         
      END

      IF @b_Debug = 1
      BEGIN
         PRINT '--------------------------------------------' + CHAR(13) +
               '  @c_SKU: ' +@c_SKU + CHAR(13) + 
               ', @c_StorerKey: ' + @c_StorerKey + CHAR(13) + 
               ', @c_Facility: ' + @c_Facility + CHAR(13) +
               ', @c_Lottable01: ' + @c_Lottable01 + CHAR(13) + 
               ', @c_Lottable02: ' + @c_Lottable02 + CHAR(13) + 
               ', @c_Lottable03: ' + @c_Lottable03 + CHAR(13) +
               ', @n_QtyLeftToFulfill: ' + CAST(@n_QtyLeftToFulfill AS NVARCHAR) + ' (' + CONVERT(NVARCHAR(24), GETDATE(), 121) + ')' + CHAR(13) +
               '--------------------------------------------' + CHAR(13) 
      END

      /**********************************/
      /***  LOOP AVAILABLE INVENTORY  ***/
      /**********************************/
      SET @c_SQL = N'
      DECLARE CURSOR_AVAILABLE CURSOR FAST_FORWARD READ_ONLY FOR
      SELECT LOTxLOCxID.LOT,
             LOTxLOCxID.LOC,
             LOTxLOCxID.ID,
             QTYAVAILABLE = (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QtyReplen)
      FROM LOTxLOCxID (NOLOCK)
      JOIN LOC (NOLOCK) ON (LOTxLOCxID.Loc = LOC.LOC)
      JOIN ID (NOLOCK) ON (LOTxLOCxID.Id = ID.ID AND ID.STATUS <> ''HOLD'')
      JOIN LOT (NOLOCK) ON (LOTXLOCXID.LOT = LOT.LOT AND LOT.STATUS <> ''HOLD'')
      JOIN LOTATTRIBUTE LA (NOLOCK) ON LOT.LOT = LA.LOT
      WHERE LOC.LocationFlag <> ''HOLD''
      AND LOC.LocationFlag <> ''DAMAGE''
      AND LOC.Status <> ''HOLD''
      AND LOC.Facility = @c_Facility
      AND (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QtyReplen) > 0
      AND (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QtyReplen) <= @n_QtyLeftToFulfill
      AND LOTxLOCxID.STORERKEY = @c_StorerKey
      AND LOTxLOCxID.SKU = @c_SKU
      AND LOC.LocationHandling IN (''1'', ''9'') ' + CHAR(13) +
      CASE WHEN ISNULL(RTRIM(@c_LocationType),'') = '' THEN ''
           ELSE ' AND LOC.LocationType = ''' + @c_LocationType + '''' + CHAR(13) END +
      CASE WHEN ISNULL(RTRIM(@c_LocationCategory),'') = '' THEN ''
           ELSE ' AND LOC.LocationCategory = ''' + @c_LocationCategory + '''' + CHAR(13) END +
      CASE WHEN ISNULL(RTRIM(@c_Lottable01),'') = '' THEN '' ELSE ' AND LA.Lottable01 = @c_Lottable01 ' + CHAR(13) END +
      CASE WHEN ISNULL(RTRIM(@c_Lottable02),'') = '' THEN '' ELSE ' AND LA.Lottable02 = @c_Lottable02 ' + CHAR(13) END +
      CASE WHEN ISNULL(RTRIM(@c_Lottable03),'') = '' THEN '' ELSE ' AND LA.Lottable03 = @c_Lottable03 ' + CHAR(13) END +
      CASE WHEN @c_OrderGroup = 'XD' THEN 
         'ORDER BY CASE WHEN (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QtyReplen) = @n_QtyLeftToFulfill   
               THEN 1 ELSE 2 END, LOC.LocationHandling DESC, LOC.LogicalLocation, LOC.LOC' 
      ELSE 
         'ORDER BY LOC.LocationHandling DESC, LOC.LogicalLocation, LOC.LOC'
      END

      SET @c_SQLParm =  N'@c_Facility   NVARCHAR(5),  @c_StorerKey  NVARCHAR(15), @c_SKU NVARCHAR(20), ' +
                         '@c_Lottable01 NVARCHAR(18), @c_Lottable02 NVARCHAR(18), @c_Lottable03 NVARCHAR(18), @n_QtyLeftToFulfill INT '
 
      EXEC sp_ExecuteSQL @c_SQL, @c_SQLParm, @c_Facility, @c_StorerKey, @c_SKU, @c_Lottable01, @c_Lottable02, @c_Lottable03, @n_QtyLeftToFulfill


      --PRINT @c_SQL
      
      OPEN CURSOR_AVAILABLE
      FETCH NEXT FROM CURSOR_AVAILABLE INTO @c_LOT, @c_LOC, @c_ID, @n_QtyAvailable

      WHILE (@@FETCH_STATUS <> -1)
      BEGIN
         IF @n_QtyLeftToFulfill < @n_QtyAvailable
            BREAK
         
         IF @c_OrderGroup = 'XD'
         BEGIN
            /***************************/
            /***  Insert PickDetail  ***/
            /***************************/
            
            IF @n_QtyAvailable < @n_QtyLeftToFulfill
               SET @n_QtyToAllocate = @n_QtyAvailable
            ELSE 
               SET @n_QtyToAllocate = @n_QtyLeftToFulfill
               
            SELECT @b_Success = 0
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
               SET @n_Err = 15000
               SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0)) +
                               ': Get PickDetailKey Failed. (ispPALVF03)'
               GOTO Quit
            END
            ELSE
            BEGIN
               IF @b_Debug = 1
               BEGIN
                  PRINT 'i. PickDetailKey: ' + @c_PickDetailKey + CHAR(13) +
                        'OrderKey: ' + @c_OrderKey + CHAR(13) +
                        'OrderLineNumber: ' + @c_OrderLineNumber + CHAR(13) +
                        'QtyToAllocate: ' + CAST(@n_QtyToAllocate AS NVARCHAR) + CHAR(13) +
                        'SKU: ' + @c_SKU + CHAR(13) +
                        'PackKey: ' + @c_PackKey + CHAR(13) +
                        'Lot: ' + @c_Lot + CHAR(13) +
                        'Loc: ' + @c_Loc + CHAR(13) +
                        'ID: ' + @c_ID + CHAR(13) +
                        'UOM: ' + @c_FullCaseUOM + CHAR(13) +
                        'PickMethod: ' + @c_FullCasePickMethod + CHAR(13)
               END

               INSERT PICKDETAIL (
                   PickDetailKey, CaseID, PickHeaderKey, OrderKey, OrderLineNumber,
                   Lot, StorerKey, Sku, UOM, UOMQty, Qty,
                   Loc, Id, PackKey, CartonGroup, DoReplenish,
                   replenishzone, doCartonize, Trafficcop, PickMethod, WaveKey
               ) VALUES (
                   @c_PickDetailKey, '', '', @c_OrderKey, @c_OrderLineNumber,
                   @c_Lot, @c_StorerKey, @c_SKU, @c_FullCaseUOM, @n_QtyToAllocate, @n_QtyToAllocate,
                   @c_Loc, @c_ID, @c_PackKey, '', 'N',
                   '', NULL, 'U', @c_FullCasePickMethod, @c_WaveKey
               )

               IF @@ERROR <> 0
               BEGIN
                  SET @n_Continue = 3
                  SET @n_Err = 15001
                  SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0)) +
                                  ': Insert PickDetail Failed. (ispPALVF03)'
                  GOTO Quit
               END

               SET @n_QtyLeftToFulfill = @n_QtyLeftToFulfill - @n_QtyToAllocate
               SET @n_QtyAvailable = @n_QtyAvailable - @n_QtyToAllocate                 
            END
            
            GOTO FETCH_NEXT_AVAILABLE
         END
         
         -- Loop available packsize and its carton count (Chee01)
         DECLARE CURSOR_AVAILABLEUCC CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
         SELECT Qty, @n_QtyAvailable/QTY
         FROM dbo.UCC WITH (NOLOCK) 
         WHERE StorerKey = @c_StorerKey
           AND SKU = @c_SKU
           AND Lot = @c_LOT
           AND Loc = @c_LOC
           AND ID = @c_ID
           AND Status < '4'
         GROUP BY Qty
         HAVING @n_QtyAvailable/QTY > 0
         ORDER BY QTY DESC

         OPEN CURSOR_AVAILABLEUCC
         FETCH NEXT FROM CURSOR_AVAILABLEUCC INTO @n_UCCQty, @n_CtnCount

         WHILE (@@FETCH_STATUS <> -1)          
         BEGIN
            IF @b_Debug = 1
               PRINT 'AVAILABLE:' + CHAR(13) +
                     '  @c_LOT: ' + @c_Lottable01 + CHAR(13) + 
                     ', @c_LOC: ' + @c_Lottable02 + CHAR(13) + 
                     ', @c_ID: ' + @c_Lottable03 + CHAR(13) +
                     ', @n_QtyAvailable: ' + CAST(@n_QtyAvailable AS NVARCHAR) + CHAR(13) +
                     ', @n_UCCQty: ' + CAST(@n_UCCQty AS NVARCHAR) + CHAR(13) +
                     ', @n_CtnCount: ' + CAST(@n_CtnCount AS NVARCHAR) + CHAR(13)

            SET @n_CtnCount = @n_QtyAvailable / @n_UCCQty

            IF @n_CtnCount = 0
               BREAK

            /*****************************************************/
            /***  Step 1: Get Full Case by Orderline [UOM:2]   ***/
            /*****************************************************/
            WHILE @n_CtnCount > 0
            BEGIN
               SELECT @c_OrderKey = '', @c_OrderLineNumber = '', @n_OrderQty = 0, @c_PackKey = ''
               SELECT TOP 1 
                  @c_OrderKey = OrderKey,
                  @c_OrderLineNumber = OrderLineNumber,
                  @n_OrderQty = OrderQty,
                  @c_PackKey = PackKey
               FROM #ORDERLINES WITH (NOLOCK) 
               WHERE SKU = @c_SKU
                 AND StorerKey = @c_StorerKey
                 AND Facility = @c_Facility 
                 AND Lottable01 = CASE WHEN ISNULL(@c_Lottable01, '') = '' THEN Lottable01 ELSE @c_Lottable01 END
                 AND Lottable02 = CASE WHEN ISNULL(@c_Lottable02, '') = '' THEN Lottable02 ELSE @c_Lottable02 END
                 AND Lottable03 = CASE WHEN ISNULL(@c_Lottable03, '') = '' THEN Lottable03 ELSE @c_Lottable03 END
                 AND OrderQty >= @n_UCCQty
               ORDER BY OrderKey, OrderLineNumber

               IF ISNULL(@c_OrderKey, '') = ''
                  BREAK

               /****************************/
               /***  Update #ORDERLINES  ***/
               /****************************/
               -- Exact match, delete orderlines 
               IF @n_OrderQty = @n_UCCQty  
               BEGIN  
                  DELETE #ORDERLINES
                  WHERE OrderKey = @c_OrderKey
                    AND OrderLineNumber = @c_OrderLineNumber
               END   
               -- Else, update orderlines
               ELSE 
               BEGIN  
                  UPDATE #ORDERLINES WITH (ROWLOCK)
                  SET OrderQty = OrderQty - @n_UCCQty
                  WHERE OrderKey = @c_OrderKey
                    AND OrderLineNumber = @c_OrderLineNumber
               END

               /***************************/
               /***  Insert PickDetail  ***/
               /***************************/
               SELECT @b_Success = 0
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
                  SET @n_Err = 15000
                  SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0)) +
                                  ': Get PickDetailKey Failed. (ispPALVF03)'
                  GOTO Quit
               END
               ELSE
               BEGIN
                  IF @b_Debug = 1
                  BEGIN
                     PRINT 'i. PickDetailKey: ' + @c_PickDetailKey + CHAR(13) +
                           'OrderKey: ' + @c_OrderKey + CHAR(13) +
                           'OrderLineNumber: ' + @c_OrderLineNumber + CHAR(13) +
                           'PickQty: ' + CAST(@n_UCCQty AS NVARCHAR) + CHAR(13) +
                           'SKU: ' + @c_SKU + CHAR(13) +
                           'PackKey: ' + @c_PackKey + CHAR(13) +
                           'Lot: ' + @c_Lot + CHAR(13) +
                           'Loc: ' + @c_Loc + CHAR(13) +
                           'ID: ' + @c_ID + CHAR(13) +
                           'UOM: ' + @c_FullCaseUOM + CHAR(13) +
                           'PickMethod: ' + @c_FullCasePickMethod + CHAR(13)
                  END

                  INSERT PICKDETAIL (
                      PickDetailKey, CaseID, PickHeaderKey, OrderKey, OrderLineNumber,
                      Lot, StorerKey, Sku, UOM, UOMQty, Qty,
                      Loc, Id, PackKey, CartonGroup, DoReplenish,
                      replenishzone, doCartonize, Trafficcop, PickMethod, WaveKey
                  ) VALUES (
                      @c_PickDetailKey, '', '', @c_OrderKey, @c_OrderLineNumber,
                      @c_Lot, @c_StorerKey, @c_SKU, @c_FullCaseUOM, @n_UCCQty, @n_UCCQty,
                      @c_Loc, @c_ID, @c_PackKey, '', 'N',
                      '', NULL, 'U', @c_FullCasePickMethod, @c_WaveKey
                  )

                  IF @@ERROR <> 0
                  BEGIN
                     SET @n_Continue = 3
                     SET @n_Err = 15001
                     SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0)) +
                                     ': Insert PickDetail Failed. (ispPALVF03)'
                     GOTO Quit
                  END
               END

               SET @n_CtnCount = @n_CtnCount - 1
               SET @n_QtyLeftToFulfill = @n_QtyLeftToFulfill - @n_UCCQty
               SET @n_QtyAvailable = @n_QtyAvailable - @n_UCCQty
            END -- WHILE @n_CtnCount > 0

            /*************************************************************/
            /***  Step 2: Pick Consolidate Orders' Full Case [UOM:6]   ***/
            /*************************************************************/

            -- (i) Get all available combination of remaining #ORDERLINES into #CombinationPool
            DELETE #CombinationPool 
            DECLARE CURSOR_COMBINATION CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
            SELECT OrderQty, COUNT(1)
            FROM #ORDERLINES WITH (ROWLOCK)
            WHERE SKU = @c_SKU
              AND StorerKey = @c_StorerKey
              AND Facility = @c_Facility 
              AND Lottable01 = CASE WHEN ISNULL(@c_Lottable01, '') = '' THEN Lottable01 ELSE @c_Lottable01 END
              AND Lottable02 = CASE WHEN ISNULL(@c_Lottable02, '') = '' THEN Lottable02 ELSE @c_Lottable02 END
              AND Lottable03 = CASE WHEN ISNULL(@c_Lottable03, '') = '' THEN Lottable03 ELSE @c_Lottable03 END
            GROUP BY OrderQty

            OPEN CURSOR_COMBINATION               
            FETCH NEXT FROM CURSOR_COMBINATION INTO @n_OrderQty, @n_QtyCount
                   
            WHILE (@@FETCH_STATUS <> -1)          
            BEGIN
               SET @n_Count = 1

               WHILE (@n_Count <= @n_QtyCount)
               BEGIN
                  INSERT INTO #CombinationPool 
                  VALUES (@n_OrderQty * @n_Count, 
                          CAST(@n_OrderQty AS NVARCHAR) + ' * ' + CAST(@n_Count AS NVARCHAR))

                  DECLARE CURSOR_COMBINATION_INNER CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
                  SELECT [Sum], Subset 
                  FROM #CombinationPool WITH (NOLOCK)
                  WHERE CHARINDEX(CAST(@n_OrderQty AS NVARCHAR) + ' * ', Subset) = 0

                  OPEN CURSOR_COMBINATION_INNER               
                  FETCH NEXT FROM CURSOR_COMBINATION_INNER INTO @n_Sum, @c_Subset
                  WHILE (@@FETCH_STATUS <> -1)          
                  BEGIN

                     INSERT INTO #CombinationPool 
                     VALUES (@n_Sum + @n_OrderQty * @n_Count, 
                             @c_Subset + ' + ' + CAST(@n_OrderQty AS NVARCHAR) + ' * ' + CAST(@n_Count AS NVARCHAR))

                     FETCH NEXT FROM CURSOR_COMBINATION_INNER INTO @n_Sum, @c_Subset
                  END -- END WHILE FOR CURSOR_COMBINATION_INNER      
                  CLOSE CURSOR_COMBINATION_INNER          
                  DEALLOCATE CURSOR_COMBINATION_INNER 

                  SET @n_Count = @n_Count + 1
               END
               FETCH NEXT FROM CURSOR_COMBINATION INTO @n_OrderQty, @n_QtyCount
            END -- END WHILE FOR CURSOR_COMBINATION      
            CLOSE CURSOR_COMBINATION
            DEALLOCATE CURSOR_COMBINATION

            -- (ii) Loop #CombinationPool with mod UCCQty = 0 and insert into PickDetail 
            WHILE (1=1)
            BEGIN
               IF @n_CtnCount = 0
                  BREAK

               SET @c_Subset = ''
               SELECT TOP 1 
                  @c_Subset = Subset, 
                  @n_CtnCount = @n_CtnCount - [Sum] / @n_UCCQty 
               FROM #CombinationPool WITH (NOLOCK)
               WHERE [Sum] % @n_UCCQty = 0
                 AND [Sum] / @n_UCCQty <= @n_CtnCount
               ORDER BY [Sum] DESC, LEN(Subset) - LEN(REPLACE(Subset, '+', '')) DESC

               IF ISNULL(@c_Subset, '') = ''
                  BREAK

               -- Clear #SplitList
               DELETE FROM #SplitList
               SET @c_TempStr = @c_Subset

               -- Convert Result string into #SplitList table
               WHILE CHARINDEX('+', @c_TempStr) > 0
               BEGIN
                  SET @n_Pos  = CHARINDEX('+', @c_TempStr)  
                  SET @c_Subset = SUBSTRING(@c_TempStr, 1, @n_Pos-2)
                  SET @c_TempStr = SUBSTRING(@c_TempStr, @n_Pos+2, LEN(@c_TempStr)-@n_Pos)

                  SET @n_Pos  = CHARINDEX('*', @c_Subset)
                  SET @n_Number = CAST(SUBSTRING(@c_Subset, 1, @n_Pos-2) AS INT)
                  SET @n_QtyCount = CAST(SUBSTRING(@c_Subset, @n_Pos+2, LEN(@c_Subset) - @n_Pos+2) AS INT)
                  INSERT INTO #SplitList VALUES (@n_Number, @n_QtyCount) 
               END -- WHILE CHARINDEX('+', @c_TempStr) > 0

               SET @n_Pos  = CHARINDEX('*', @c_TempStr)
               SET @n_Number = CAST(SUBSTRING(@c_TempStr, 1, @n_Pos-2) AS INT)
               SET @n_QtyCount = CAST(SUBSTRING(@c_TempStr, @n_Pos+2, LEN(@c_TempStr) - @n_Pos+2) AS INT)
               INSERT INTO #SplitList VALUES (@n_Number, @n_QtyCount) 

               DECLARE CURSOR_SPLITLIST CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
               SELECT Qty, [Count] 
               FROM #SplitList WITH (NOLOCK)

               OPEN CURSOR_SPLITLIST
               FETCH NEXT FROM CURSOR_SPLITLIST INTO @n_OrderQty, @n_QtyNeeded

               WHILE (@@FETCH_STATUS <> -1)
               BEGIN
                  -- Get Current OrderQty Count & Remaining Count 
                  SELECT @n_QtyCount = COUNT(1)
                  FROM #ORDERLINES WITH (ROWLOCK)
                  WHERE SKU = @c_SKU
                    AND StorerKey = @c_StorerKey
                    AND Facility = @c_Facility 
                    AND Lottable01 = CASE WHEN ISNULL(@c_Lottable01, '') = '' THEN Lottable01 ELSE @c_Lottable01 END
                    AND Lottable02 = CASE WHEN ISNULL(@c_Lottable02, '') = '' THEN Lottable02 ELSE @c_Lottable02 END
                    AND Lottable03 = CASE WHEN ISNULL(@c_Lottable03, '') = '' THEN Lottable03 ELSE @c_Lottable03 END
                    AND OrderQty = @n_OrderQty
                  SELECT @n_Count = @n_QtyCount - @n_QtyNeeded

                  SET @c_SQL = N'DECLARE CURSOR_SPLITLIST_ORDERLINES CURSOR FAST_FORWARD READ_ONLY FOR ' + 
                                'SELECT TOP ' + CAST(@n_QtyNeeded AS NVARCHAR) + ' OrderKey, OrderLineNumber, PackKey ' + 
                                'FROM #ORDERLINES WITH (NOLOCK) ' + 
                                'WHERE SKU = @cSKU ' +
                                  'AND StorerKey = @cStorerKey ' +
                                  'AND Facility = @cFacility ' +
                                  'AND OrderQty = @nOrderQty ' + 
                                   CASE WHEN ISNULL(RTRIM(@c_Lottable01),'') = '' THEN '' ELSE ' AND Lottable01 = @cLottable01 ' + CHAR(13) END +
                                   CASE WHEN ISNULL(RTRIM(@c_Lottable02),'') = '' THEN '' ELSE ' AND Lottable02 = @cLottable02 ' + CHAR(13) END +
                                   CASE WHEN ISNULL(RTRIM(@c_Lottable03),'') = '' THEN '' ELSE ' AND Lottable03 = @cLottable03 ' + CHAR(13) END +
                                'ORDER BY OrderKey, OrderLineNumber'

                  SET @c_SQLParm =  N'@cFacility NVARCHAR(5), @cStorerKey NVARCHAR(15), @cSKU NVARCHAR(20), @nOrderQty INT, ' +
                                     '@cLottable01 NVARCHAR(18), @cLottable02 NVARCHAR(18), @cLottable03 NVARCHAR(18)'

                  EXEC sp_ExecuteSQL @c_SQL, @c_SQLParm, @c_Facility, @c_StorerKey, @c_SKU, @n_OrderQty, @c_Lottable01, @c_Lottable02, @c_Lottable03

                  OPEN CURSOR_SPLITLIST_ORDERLINES
                  FETCH NEXT FROM CURSOR_SPLITLIST_ORDERLINES INTO @c_OrderKey, @c_OrderLineNumber, @c_PackKey

                  WHILE (@@FETCH_STATUS <> -1)
                  BEGIN  

                     /****************************/
                     /***  Delete #ORDERLINES  ***/
                     /****************************/
                     DELETE #ORDERLINES
                     WHERE OrderKey = @c_OrderKey
                       AND OrderLineNumber = @c_OrderLineNumber

                     /***************************/
                     /***  Insert PickDetail  ***/
                     /***************************/
                     SELECT @b_Success = 0  
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
                        SET @n_Err = 15002
                        SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0)) + 
                                        ': Get PickDetailKey Failed. (ispPALVF03)'
                        GOTO Quit
                     END
                     ELSE
                     BEGIN
                        IF @b_Debug = 1
                        BEGIN
                           PRINT 'ii. PickDetailKey: ' + @c_PickDetailKey + CHAR(13) +
                                 'OrderKey: ' + @c_OrderKey + CHAR(13) +
                                 'OrderLineNumber: ' + @c_OrderLineNumber + CHAR(13) +
                                 'PickQty: ' + CAST(@n_OrderQty AS NVARCHAR) + CHAR(13) +
                                 'SKU: ' + @c_SKU + CHAR(13) +
                                 'PackKey: ' + @c_PackKey + CHAR(13) +
                                 'Lot: ' + @c_Lot + CHAR(13) +
                                 'Loc: ' + @c_Loc + CHAR(13) +
                                 'ID: ' + @c_ID + CHAR(13) +
                                 'UOM: ' + @c_ConsoCaseUOM + CHAR(13) +
                                 'PickMethod: ' + @c_ConsoCasePickMethod + CHAR(13)
                        END

                        INSERT PICKDETAIL (  
                            PickDetailKey, CaseID, PickHeaderKey, OrderKey, OrderLineNumber,  
                            Lot, StorerKey, Sku, UOM, UOMQty, Qty, 
                            Loc, Id, PackKey, CartonGroup, DoReplenish,  
                            replenishzone, doCartonize, Trafficcop, PickMethod, WaveKey 
                        ) VALUES (  
                            @c_PickDetailKey, '', '', @c_OrderKey, @c_OrderLineNumber,  
                            @c_Lot, @c_StorerKey, @c_SKU, @c_ConsoCaseUOM, @n_UCCQty, @n_OrderQty, 
                            @c_Loc, @c_ID, @c_PackKey, '', 'N',  
                            '', NULL, 'U', @c_ConsoCasePickMethod, @c_WaveKey  
                        ) 

                        IF @@ERROR <> 0
                        BEGIN
                           SET @n_Continue = 3
                           SET @n_Err = 15003
                           SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0)) + 
                                           ': Insert PickDetail Failed. (ispPALVF03)'
                           GOTO Quit
                        END
                     END

                     FETCH NEXT FROM CURSOR_SPLITLIST_ORDERLINES INTO @c_OrderKey, @c_OrderLineNumber, @c_PackKey
                  END -- END WHILE FOR CURSOR_SPLITLIST_ORDERLINES      
                  CLOSE CURSOR_SPLITLIST_ORDERLINES
                  DEALLOCATE CURSOR_SPLITLIST_ORDERLINES    

                  /*********************************/
                  /***  Delete #CombinationPool  ***/
                  /*********************************/
                  IF @n_Count > 0
                  BEGIN
                     WHILE (@n_QtyCount > @n_Count)
                     BEGIN
                        DELETE FROM #CombinationPool WITH (ROWLOCK)
                        WHERE CHARINDEX(CAST(@n_OrderQty AS NVARCHAR) + ' * ' + CAST(@n_QtyCount AS NVARCHAR), Subset) > 0 

                        IF @b_Debug = 1
                        BEGIN
                           PRINT '/** REMOVED ' + CAST(@n_OrderQty AS NVARCHAR) + ' * ' + CAST(@n_QtyCount AS NVARCHAR) + ' FROM COMBINATION POOL  **/' 
                        END
                        SET @n_QtyCount = @n_QtyCount - 1
                     END
                  END -- IF @n_Count > 0
                  ELSE
                  BEGIN
                     DELETE FROM #CombinationPool WITH (ROWLOCK)
                     WHERE CHARINDEX(CAST(@n_OrderQty AS NVARCHAR) + ' * ', Subset) > 0

                     IF @b_Debug = 1
                     BEGIN
                        PRINT '/** REMOVED ' + CAST(@n_OrderQty AS NVARCHAR) + ' FROM COMBINATION POOL  **/' 
                     END
                  END -- IF @n_Count <= 0 

                  FETCH NEXT FROM CURSOR_SPLITLIST INTO @n_OrderQty, @n_QtyNeeded
               END -- END WHILE FOR CURSOR_SPLITLIST      
               CLOSE CURSOR_SPLITLIST          
               DEALLOCATE CURSOR_SPLITLIST 
            END -- WHILE (1=1)

            -- (iii) Loop remaining UCCs to fulfill remaining orderQty in #CombinationPool 
            WHILE @n_CtnCount > 0
            BEGIN
               SELECT @c_Subset = '', @n_RemainingUCCQty = 0
               SELECT TOP 1 
                  @c_Subset = Subset, 
                  @n_CtnCount = @n_CtnCount - [Sum] / @n_UCCQty,
                  @n_RemainingCtn =  [Sum] / @n_UCCQty,
                  @n_RemainingUCCQty = @n_UCCQty
               FROM #CombinationPool WITH (NOLOCK)
               WHERE [Sum] / @n_UCCQty <= @n_CtnCount
               ORDER BY [Sum] % @n_UCCQty, [Sum] DESC, LEN(Subset) - LEN(REPLACE(Subset, '+', '')) DESC

               IF ISNULL(@c_Subset, '') = ''
                  BREAK

               -- Clear #SplitList
               DELETE FROM #SplitList
               SET @c_TempStr = @c_Subset

               -- Convert Result string into #SplitList table
               WHILE CHARINDEX('+', @c_TempStr) > 0
               BEGIN
                  SET @n_Pos  = CHARINDEX('+', @c_TempStr)  
                  SET @c_Subset = SUBSTRING(@c_TempStr, 1, @n_Pos-2)
                  SET @c_TempStr = SUBSTRING(@c_TempStr, @n_Pos+2, LEN(@c_TempStr)-@n_Pos)

                  SET @n_Pos  = CHARINDEX('*', @c_Subset)
                  SET @n_Number = CAST(SUBSTRING(@c_Subset, 1, @n_Pos-2) AS INT)
                  SET @n_QtyCount = CAST(SUBSTRING(@c_Subset, @n_Pos+2, LEN(@c_Subset) - @n_Pos+2) AS INT)
                  INSERT INTO #SplitList VALUES (@n_Number, @n_QtyCount) 
               END -- WHILE CHARINDEX('+', @c_Result) > 0

               SET @n_Pos  = CHARINDEX('*', @c_TempStr)
               SET @n_Number = CAST(SUBSTRING(@c_TempStr, 1, @n_Pos-2) AS INT)
               SET @n_QtyCount = CAST(SUBSTRING(@c_TempStr, @n_Pos+2, LEN(@c_TempStr) - @n_Pos+2) AS INT)
               INSERT INTO #SplitList VALUES (@n_Number, @n_QtyCount) 

               DECLARE CURSOR_SPLITLIST CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
               SELECT Qty, [Count] 
               FROM #SplitList WITH (NOLOCK)

               OPEN CURSOR_SPLITLIST
               FETCH NEXT FROM CURSOR_SPLITLIST INTO @n_OrderQty, @n_QtyNeeded

               WHILE (@@FETCH_STATUS <> -1)
               BEGIN
                  SELECT @n_QtyCount = COUNT(1)
                  FROM #ORDERLINES WITH (ROWLOCK)
                  WHERE SKU = @c_SKU
                    AND StorerKey = @c_StorerKey
                    AND Facility = @c_Facility 
                    AND Lottable01 = CASE WHEN ISNULL(@c_Lottable01, '') = '' THEN Lottable01 ELSE @c_Lottable01 END
                    AND Lottable02 = CASE WHEN ISNULL(@c_Lottable02, '') = '' THEN Lottable02 ELSE @c_Lottable02 END
                    AND Lottable03 = CASE WHEN ISNULL(@c_Lottable03, '') = '' THEN Lottable03 ELSE @c_Lottable03 END
                    AND OrderQty = @n_OrderQty
                  SELECT @n_Count = @n_QtyCount - @n_QtyNeeded

                  SET @c_SQL = N'DECLARE CURSOR_SPLITLIST_ORDERLINES CURSOR FAST_FORWARD READ_ONLY FOR ' + 
                                'SELECT TOP ' + CAST(@n_QtyNeeded AS NVARCHAR) + ' OrderKey, OrderLineNumber, PackKey ' + 
                                'FROM #ORDERLINES WITH (NOLOCK) ' + 
                                'WHERE SKU = @cSKU ' +
                                  'AND StorerKey = @cStorerKey ' +
                                  'AND Facility = @cFacility ' +
                                  'AND OrderQty = @nOrderQty ' + 
                                   CASE WHEN ISNULL(RTRIM(@c_Lottable01),'') = '' THEN '' ELSE ' AND Lottable01 = @cLottable01 ' + CHAR(13) END +
                                   CASE WHEN ISNULL(RTRIM(@c_Lottable02),'') = '' THEN '' ELSE ' AND Lottable02 = @cLottable02 ' + CHAR(13) END +
                                   CASE WHEN ISNULL(RTRIM(@c_Lottable03),'') = '' THEN '' ELSE ' AND Lottable03 = @cLottable03 ' + CHAR(13) END +
                                'ORDER BY OrderKey, OrderLineNumber'

                  SET @c_SQLParm =  N'@cFacility NVARCHAR(5), @cStorerKey NVARCHAR(15), @cSKU NVARCHAR(20), @nOrderQty INT, ' +      
                                     '@cLottable01 NVARCHAR(18), @cLottable02 NVARCHAR(18), @cLottable03 NVARCHAR(18)'
                     
                  EXEC sp_ExecuteSQL @c_SQL, @c_SQLParm, @c_Facility, @c_StorerKey, @c_SKU, @n_OrderQty, @c_Lottable01, @c_Lottable02, @c_Lottable03

                  OPEN CURSOR_SPLITLIST_ORDERLINES                    
                  FETCH NEXT FROM CURSOR_SPLITLIST_ORDERLINES INTO @c_OrderKey, @c_OrderLineNumber, @c_PackKey
                         
                  WHILE (@@FETCH_STATUS <> -1)
                  BEGIN
                     SET @n_QtyOrd = @n_OrderQty

                     WHILE @n_QtyOrd > 0
                     BEGIN
                        IF @n_RemainingUCCQty = 0 AND  @n_RemainingCtn > 0
                        BEGIN
                           SET @n_RemainingUCCQty = @n_UCCQty
                           SET @n_RemainingCtn = @n_RemainingCtn - 1
                        END

                        IF @n_RemainingCtn = 0
                           BREAK

                        IF @n_RemainingUCCQty >= @n_QtyOrd
                        BEGIN
                           /****************************/
                           /***  Delete #ORDERLINES  ***/
                           /****************************/
                           DELETE #ORDERLINES
                           WHERE OrderKey = @c_OrderKey
                             AND OrderLineNumber = @c_OrderLineNumber

                           SET @n_RemainingUCCQty = @n_RemainingUCCQty - @n_QtyOrd
                           SET @n_PickQty = @n_QtyOrd
                           SET @n_QtyOrd = 0
                        END
                        ELSE
                        BEGIN
                           /****************************/
                           /***  Update #ORDERLINES  ***/
                           /****************************/
                           UPDATE #ORDERLINES
                           SET OrderQty = OrderQty - @n_RemainingUCCQty
                           WHERE OrderKey = @c_OrderKey
                             AND OrderLineNumber = @c_OrderLineNumber

                           SET @n_PickQty = @n_RemainingUCCQty
                           SET @n_RemainingUCCQty = 0
                           SET @n_QtyOrd = @n_QtyOrd - @n_PickQty
                        END

                        /***************************/
                        /***  Insert PickDetail  ***/
                        /***************************/
                        SELECT @b_Success = 0  
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
                           SET @n_Err = 15002
                           SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0)) + 
                                           ': Get PickDetailKey Failed. (ispPALVF03)'
                           GOTO Quit
                        END
                        ELSE
                        BEGIN
                           IF @b_Debug = 1
                           BEGIN
                              PRINT 'iii. PickDetailKey: ' + @c_PickDetailKey + CHAR(13) +
                                    'OrderKey: ' + @c_OrderKey + CHAR(13) +
                                    'OrderLineNumber: ' + @c_OrderLineNumber + CHAR(13) +
                                    'PickQty: ' + CAST(@n_PickQty AS NVARCHAR) + CHAR(13) +
                                    'SKU: ' + @c_SKU + CHAR(13) +
                                    'PackKey: ' + @c_PackKey + CHAR(13) +
                                    'Lot: ' + @c_Lot + CHAR(13) +
                                    'Loc: ' + @c_Loc + CHAR(13) +
                                    'ID: ' + @c_ID + CHAR(13) +
                                    'UOM: ' + @c_ConsoCaseUOM + CHAR(13) +
                                    'PickMethod: ' + @c_ConsoCasePickMethod + CHAR(13)
                           END

                           INSERT PICKDETAIL (  
                               PickDetailKey, CaseID, PickHeaderKey, OrderKey, OrderLineNumber,  
                               Lot, StorerKey, Sku, UOM, UOMQty, Qty, 
                               Loc, Id, PackKey, CartonGroup, DoReplenish,  
                               replenishzone, doCartonize, Trafficcop, PickMethod, WaveKey 
                           ) VALUES (  
                               @c_PickDetailKey, '', '', @c_OrderKey, @c_OrderLineNumber,  
                               @c_Lot, @c_StorerKey, @c_SKU, @c_ConsoCaseUOM, @n_UCCQty, @n_PickQty, 
                               @c_Loc, @c_ID, @c_PackKey, '', 'N',  
                               '', NULL, 'U', @c_ConsoCasePickMethod, @c_WaveKey  
                           ) 

                           IF @@ERROR <> 0
                           BEGIN
                              SET @n_Continue = 3
                              SET @n_Err = 15003
                              SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0)) + 
                                              ': Insert PickDetail Failed. (ispPALVF03)'
                              GOTO Quit
                           END
                        END
                     END -- WHILE @n_QtyOrd > 0

                     FETCH NEXT FROM CURSOR_SPLITLIST_ORDERLINES INTO @c_OrderKey, @c_OrderLineNumber, @c_PackKey
                  END -- END WHILE FOR CURSOR_SPLITLIST_ORDERLINES      
                  CLOSE CURSOR_SPLITLIST_ORDERLINES
                  DEALLOCATE CURSOR_SPLITLIST_ORDERLINES    

                  FETCH NEXT FROM CURSOR_SPLITLIST INTO @n_OrderQty, @n_QtyNeeded
               END -- END WHILE FOR CURSOR_SPLITLIST      
               CLOSE CURSOR_SPLITLIST          
               DEALLOCATE CURSOR_SPLITLIST          

               /**********************************/
               /***  Rebuild #CombinationPool  ***/
               /**********************************/
               DELETE #CombinationPool
               DECLARE CURSOR_COMBINATION CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
               SELECT OrderQty, COUNT(1)
               FROM #ORDERLINES WITH (ROWLOCK)
               WHERE SKU = @c_SKU
                 AND StorerKey = @c_StorerKey
                 AND Facility = @c_Facility 
                 AND Lottable01 = CASE WHEN ISNULL(@c_Lottable01, '') = '' THEN Lottable01 ELSE @c_Lottable01 END
                 AND Lottable02 = CASE WHEN ISNULL(@c_Lottable02, '') = '' THEN Lottable02 ELSE @c_Lottable02 END
                 AND Lottable03 = CASE WHEN ISNULL(@c_Lottable03, '') = '' THEN Lottable03 ELSE @c_Lottable03 END
               GROUP BY OrderQty

               OPEN CURSOR_COMBINATION               
               FETCH NEXT FROM CURSOR_COMBINATION INTO @n_OrderQty, @n_QtyCount
                      
               WHILE (@@FETCH_STATUS <> -1)          
               BEGIN
                  SET @n_Count = 1

                  WHILE (@n_Count <= @n_QtyCount)
                  BEGIN
                     INSERT INTO #CombinationPool 
                     VALUES (@n_OrderQty * @n_Count, 
                             CAST(@n_OrderQty AS NVARCHAR) + ' * ' + CAST(@n_Count AS NVARCHAR))

                     DECLARE CURSOR_COMBINATION_INNER CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
                     SELECT [Sum], Subset 
                     FROM #CombinationPool WITH (NOLOCK)
                     WHERE CHARINDEX(CAST(@n_OrderQty AS NVARCHAR) + ' * ', Subset) = 0

                     OPEN CURSOR_COMBINATION_INNER               
                     FETCH NEXT FROM CURSOR_COMBINATION_INNER INTO @n_Sum, @c_Subset
                     WHILE (@@FETCH_STATUS <> -1)          
                     BEGIN

                        INSERT INTO #CombinationPool 
                        VALUES (@n_Sum + @n_OrderQty * @n_Count, 
                                @c_Subset + ' + ' + CAST(@n_OrderQty AS NVARCHAR) + ' * ' + CAST(@n_Count AS NVARCHAR))

                        FETCH NEXT FROM CURSOR_COMBINATION_INNER INTO @n_Sum, @c_Subset
                     END -- END WHILE FOR CURSOR_COMBINATION_INNER      
                     CLOSE CURSOR_COMBINATION_INNER          
                     DEALLOCATE CURSOR_COMBINATION_INNER 

                     SET @n_Count = @n_Count + 1
                  END

                  FETCH NEXT FROM CURSOR_COMBINATION INTO @n_OrderQty, @n_QtyCount
               END -- END WHILE FOR CURSOR_COMBINATION      
               CLOSE CURSOR_COMBINATION
               DEALLOCATE CURSOR_COMBINATION 
            END -- WHILE @n_CtnCount > 0

            FETCH NEXT FROM CURSOR_AVAILABLEUCC INTO @n_UCCQty, @n_CtnCount
         END -- END WHILE FOR CURSOR_AVAILABLEUCC 
         CLOSE CURSOR_AVAILABLEUCC          
         DEALLOCATE CURSOR_AVAILABLEUCC   

         FETCH_NEXT_AVAILABLE:
         
         FETCH NEXT FROM CURSOR_AVAILABLE INTO @c_LOT, @c_LOC, @c_ID, @n_QtyAvailable  
      END -- END WHILE FOR CURSOR_AVAILABLE 
      CLOSE CURSOR_AVAILABLE          
      DEALLOCATE CURSOR_AVAILABLE           

      IF @b_Debug = 1
      BEGIN
         PRINT '--------------------------------------------' + CHAR(13)
      END

      FETCH NEXT FROM CURSOR_ORDERLINES INTO @c_SKU, @c_StorerKey, @c_Facility, @c_Lottable01, @c_Lottable02, @c_Lottable03, @c_OrderGroup       
   END -- END WHILE FOR CURSOR_ORDERLINES             
   CLOSE CURSOR_ORDERLINES          
   DEALLOCATE CURSOR_ORDERLINES
      
   IF @b_Debug = 1
   BEGIN
      SELECT PD.PickDetailKey, PD.OrderKey, PD.OrderLineNumber, PD.Qty, PD.SKU, PD.PackKey, PD.Lot, PD.Loc, PD.ID, PD.UOM
      FROM PickDetail PD WITH (NOLOCK)
      JOIN OrderDetail OD WITH (NOLOCK) ON (OD.OrderKey = PD.OrderKey AND OD.OrderLineNumber = PD.OrderLineNumber)
      JOIN WAVEDETAIL WD WITH (NOLOCK) ON (OD.OrderKey = WD.OrderKey)
      WHERE WD.WaveKey = @c_WaveKey
   END

QUIT:

   IF CURSOR_STATUS('LOCAL' , 'CURSOR_AVAILABLE') >=0          
   BEGIN          
      CLOSE CURSOR_AVAILABLE          
      DEALLOCATE CURSOR_AVAILABLE          
   END    

   IF (SELECT CURSOR_STATUS('LOCAL','CURSOR_ORDERLINES')) >=0 
   BEGIN
      CLOSE CURSOR_ORDERLINES           
      DEALLOCATE CURSOR_ORDERLINES      
   END  

   IF (SELECT CURSOR_STATUS('LOCAL','CURSOR_COMBINATION')) >=0 
   BEGIN
      CLOSE CURSOR_COMBINATION           
      DEALLOCATE CURSOR_COMBINATION      
   END  

   IF (SELECT CURSOR_STATUS('LOCAL','CURSOR_COMBINATION_INNER')) >=0 
   BEGIN
      CLOSE CURSOR_COMBINATION_INNER           
      DEALLOCATE CURSOR_COMBINATION_INNER      
   END  

   IF (SELECT CURSOR_STATUS('LOCAL','CURSOR_SPLITLIST')) >=0 
   BEGIN
      CLOSE CURSOR_SPLITLIST           
      DEALLOCATE CURSOR_SPLITLIST      
   END  

   IF (SELECT CURSOR_STATUS('LOCAL','CURSOR_SPLITLIST_ORDERLINES')) >=0 
   BEGIN
      CLOSE CURSOR_SPLITLIST_ORDERLINES           
      DEALLOCATE CURSOR_SPLITLIST_ORDERLINES      
   END  

   IF OBJECT_ID('tempdb..#ORDERLINES','u') IS NOT NULL
      DROP TABLE #ORDERLINES;

   IF OBJECT_ID('tempdb..#CombinationPool','u') IS NOT NULL
      DROP TABLE #CombinationPool;

   IF OBJECT_ID('tempdb..#SplitList','u') IS NOT NULL
      DROP TABLE #SplitList;

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
      EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'ispPALVF03'  
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
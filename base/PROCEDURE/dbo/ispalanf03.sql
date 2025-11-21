SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: ispALANF03                                         */
/* Creation Date: 07-Feb-2014                                           */
/* Copyright: LFL                                                       */
/* Written by: Chee Jun Yan                                             */
/*                                                                      */
/* Purpose: Allocate Best Matched Fullcase from BULK (Others) UOM:6     */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.4                                                    */
/*                                                                      */
/* Version: 1.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver.  Purposes                                  */
/* 2014-05-26  Chee     1.1   Bug Fix when calculating combinations     */
/*                            for low UCC qty (Chee01)                  */
/* 2015-02-12  CSCHONG  1.2   New Lottable06 to 15  (CS11)              */
/* 14-Feb-2020 Wan01    1.3   Dynamic SQL review, impact SQL cache log  */ 
/* 08-Feb-2021 WLChooi  1.4   WMS-16327 - Use Codelkup to control       */
/*                            sorting (WL01)                            */
/************************************************************************/
CREATE PROC [dbo].[ispALANF03]
   @c_LoadKey    NVARCHAR(10), 
   @c_Facility   NVARCHAR(5),     
   @c_StorerKey  NVARCHAR(15),     
   @c_SKU        NVARCHAR(20),    
   @c_Lottable01 NVARCHAR(18),    
   @c_Lottable02 NVARCHAR(18),    
   @c_Lottable03 NVARCHAR(18),    
   @d_Lottable04 NVARCHAR(20),    
   @d_Lottable05 NVARCHAR(20), 
   @c_Lottable06 NVARCHAR(30) = '',       --(CS01) 
   @c_Lottable07 NVARCHAR(30) = '',       --(CS01)
   @c_Lottable08 NVARCHAR(30) = '',       --(CS01)
   @c_Lottable09 NVARCHAR(30) = '',       --(CS01) 
   @c_Lottable10 NVARCHAR(30) = '',       --(CS01)
   @c_Lottable11 NVARCHAR(30) = '',       --(CS01)
   @c_Lottable12 NVARCHAR(30) = '',       --(CS01)
   @d_Lottable13 NVARCHAR(20) = NULL,     --(CS01)
   @d_Lottable14 NVARCHAR(20) = NULL,     --(CS01)
   @d_Lottable15 NVARCHAR(20) = NULL,     --(CS01)    
   @c_UOM        NVARCHAR(10),    
   @c_HostWHCode NVARCHAR(10),    
   @n_UOMBase    INT,    
   @n_QtyLeftToFulfill INT     
AS    
BEGIN    
   SET NOCOUNT ON 
   --SET QUOTED_IDENTIFIER OFF 
   --SET ANSI_NULLS OFF    

   DECLARE @b_debug       INT,      
           @c_SQL         NVARCHAR(MAX),    
           @c_SQLParm     NVARCHAR(MAX)    
          
   DECLARE 
      @n_QtyAvailable      INT,
      @n_UCCQty            INT,
      @n_CntCount          INT,
      @n_LowerBound        INT,
      @n_CntNeeded         INT,
      @n_Count             INT,
      @n_Sum               INT,
      @n_Number            INT, 
      @n_Pos               INT,
      @n_Result            INT,
      @c_LOC               NVARCHAR(10),
      @c_LOT               NVARCHAR(10),
      @c_ID                NVARCHAR(18),
      @c_LocationType      NVARCHAR(10),    
      @c_LocationCategory  NVARCHAR(10),
      @c_Subset            NVARCHAR(MAX), 
      @c_Result            NVARCHAR(MAX),
      @c_TempStr           NVARCHAR(MAX),
      @c_LoadType          NVARCHAR(20),
      @c_SortingSQL        NVARCHAR(4000)  --WL01

   SET @b_debug = 0
   SET @c_LocationType = 'OTHER'
   SET @c_LocationCategory = 'SELECTIVE'
   SET @c_SortingSQL = 'ORDER BY LOC.LogicalLocation, LOC.LOC '   --WL01

   --WL01 START
   IF EXISTS (SELECT 1 FROM CODELKUP CL (NOLOCK)  
              WHERE CL.Storerkey = @c_Storerkey  
              AND CL.Code = 'SORTBY'  
              AND CL.Listname = 'PKCODECFG'  
              AND CL.Long = 'ispALANF03'
              AND ISNULL(CL.Short,'') <> 'N')
   BEGIN
      SELECT @c_SortingSQL = LTRIM(RTRIM(ISNULL(CL.Notes,'')))
      FROM CODELKUP CL (NOLOCK)
      WHERE CL.Storerkey = @c_Storerkey
      AND CL.Code = 'SORTBY'
      AND CL.Listname = 'PKCODECFG'
      AND CL.Long = 'ispALANF03'
      AND ISNULL(CL.Short,'') <> 'N'
   END
   --WL01 END
   
   EXEC isp_Init_Allocate_Candidates         --(Wan01)   

   -- GET LoadType FROM LoadPlan
   SELECT TOP 1 
      @c_LoadType = O.Type
   FROM LOADPLANDETAIL LPD WITH (NOLOCK)
   JOIN ORDERS O WITH (NOLOCK) ON (LPD.OrderKey = O.OrderKey)
   WHERE LPD.LoadKey = @c_LoadKey

   IF ISNULL(@c_LoadType,'') NOT IN ('N', 'DCToDC')
   BEGIN
      /*****************************/
      /***   CREATE TEMP TABLE   ***/
      /*****************************/
      IF OBJECT_ID('tempdb..#UCCxLOTxLOCxID','u') IS NOT NULL
         DROP TABLE #UCCxLOTxLOCxID;

      -- Store Stock in Inventory (UCC & LOTxLOCxID info)
      CREATE TABLE #UCCxLOTxLOCxID (  
         UCCQty            INT, 
         CntCount          INT, 
         Loc               NVARCHAR(10), 
         LogicalLocation   NVARCHAR(18), 
         [Lot]             NVARCHAR(10), 
         [ID]              NVARCHAR(18)
      )

      IF OBJECT_ID('tempdb..#NumPool','u') IS NOT NULL
         DROP TABLE #NumPool;

      -- For Pre-Alloc UCC processing
      CREATE TABLE #NumPool (  
         UCCQty        INT,
         CntCount      INT DEFAULT 0, 
         CntAllocated  INT DEFAULT 0
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
         UCCQty            INT, 
         CntCount          INT
      )

      IF @b_Debug = 1
      BEGIN
         PRINT '--------------------------------------------' + CHAR(13) +
               '  @c_SKU: ' +@c_SKU + CHAR(13) + 
               ', @c_StorerKey: ' + @c_StorerKey + CHAR(13) + 
               ', @c_Facility: ' + @c_Facility + CHAR(13) +
               ', @c_Lottable01: ' + @c_Lottable01 + CHAR(13) + 
               ', @c_Lottable02: ' + @c_Lottable02 + CHAR(13) + 
               ', @c_Lottable03: ' + @c_Lottable03 +' (' + CONVERT(NVARCHAR(24), GETDATE(), 121) + ')' + CHAR(13) +
               ', @c_Lottable06: ' + @c_Lottable06 + CHAR(13) + 
               ', @c_Lottable07: ' + @c_Lottable07 + CHAR(13) +  
               ', @c_Lottable08: ' + @c_Lottable08 + CHAR(13) + 
               ', @c_Lottable09: ' + @c_Lottable09 + CHAR(13) +  
               ', @c_Lottable10: ' + @c_Lottable10 + CHAR(13) + 
               ', @c_Lottable11: ' + @c_Lottable11 + CHAR(13) +
               ', @c_Lottable12: ' + @c_Lottable11 + CHAR(13) +
               '--------------------------------------------' 
      END

      /*************************************/
      /***  INSERT INTO UCCxLOTxLOCxID   ***/
      /*************************************/
      SET @c_SQL = N'
      INSERT INTO #UCCxLOTxLOCxID (UCCQty, CntCount, Loc, LogicalLocation, Lot, ID)
      SELECT DISTINCT UCC.Qty, COUNT(1), Loc.Loc, Loc.LogicalLocation, LOTxLOCxID.LOT, LOTxLOCxID.ID 
      FROM LOTxLOCxID WITH (NOLOCK)      
         JOIN LOC WITH (NOLOCK) ON (LOTxLOCxID.Loc = LOC.LOC)      
         JOIN ID WITH (NOLOCK) ON (LOTxLOCxID.Id = ID.ID AND ID.STATUS <> ''HOLD'')       
         JOIN LOT WITH (NOLOCK) ON (LOTXLOCXID.LOT = LOT.LOT AND LOT.STATUS <> ''HOLD'')         
         JOIN LOTATTRIBUTE LA WITH (NOLOCK) ON LOT.LOT = LA.LOT            
         JOIN UCC WITH (NOLOCK) ON (UCC.SKU = LOTxLOCxID.SKU AND UCC.LOT = LOT.LOT AND UCC.LOC = LOC.LOC AND UCC.ID = ID.ID
                                          AND UCC.Status < ''3'')
      WHERE LOC.LocationFlag <> ''HOLD''       
         AND LOC.LocationFlag <> ''DAMAGE''       
         AND LOC.Status <> ''HOLD''
         AND LOC.Facility = @c_Facility   
         AND LOTxLOCxID.STORERKEY = @c_StorerKey
         AND LOTxLOCxID.SKU = @c_SKU ' + CHAR(13) +
         CASE WHEN ISNULL(RTRIM(@c_LocationType),'') = '' THEN '' 
              ELSE ' AND LOC.LocationType = @c_LocationType' + CHAR(13) END +      
         CASE WHEN ISNULL(RTRIM(@c_LocationCategory),'') = '' THEN ''       
              ELSE ' AND LOC.LocationCategory = @c_LocationCategory' + CHAR(13) END +      
         CASE WHEN ISNULL(RTRIM(@c_Lottable01),'') = '' THEN '' ELSE ' AND LA.Lottable01 = @c_Lottable01 ' + CHAR(13) END +      
         CASE WHEN ISNULL(RTRIM(@c_Lottable02),'') = '' THEN '' ELSE ' AND LA.Lottable02 = @c_Lottable02 ' + CHAR(13) END +      
         CASE WHEN ISNULL(RTRIM(@c_Lottable03),'') = '' THEN '' ELSE ' AND LA.Lottable03 = @c_Lottable03 ' + CHAR(13) END +
         /*CS01 Start*/
         CASE WHEN ISNULL(RTRIM(@c_Lottable06),'') = '' THEN '' ELSE ' AND LA.Lottable06 = @c_Lottable06 ' + CHAR(13) END +      
         CASE WHEN ISNULL(RTRIM(@c_Lottable07),'') = '' THEN '' ELSE ' AND LA.Lottable07 = @c_Lottable07 ' + CHAR(13) END +      
         CASE WHEN ISNULL(RTRIM(@c_Lottable08),'') = '' THEN '' ELSE ' AND LA.Lottable08 = @c_Lottable08 ' + CHAR(13) END +  
         CASE WHEN ISNULL(RTRIM(@c_Lottable09),'') = '' THEN '' ELSE ' AND LA.Lottable09 = @c_Lottable09' + CHAR(13) END +      
         CASE WHEN ISNULL(RTRIM(@c_Lottable10),'') = '' THEN '' ELSE ' AND LA.Lottable10 = @c_Lottable10 ' + CHAR(13) END +      
         CASE WHEN ISNULL(RTRIM(@c_Lottable11),'') = '' THEN '' ELSE ' AND LA.Lottable11 = @c_Lottable11 ' + CHAR(13) END +  
         CASE WHEN ISNULL(RTRIM(@c_Lottable12),'') = '' THEN '' ELSE ' AND LA.Lottable12 = @c_Lottable12 ' + CHAR(13) END +   
         'AND (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QtyReplen) >= UCC.Qty
      GROUP BY UCC.Qty, Loc.LocationHandling, Loc.LogicalLocation, LOC.LOC, LOTxLOCxID.LOT, LOTxLOCxID.ID
      HAVING COUNT(1) > 0 ' +                    --WL01
      --ORDER BY Loc.LogicalLocation, LOC.LOC'   --WL01
      @c_SortingSQL                              --WL01

      SET @c_SQLParm =  N'@c_Facility   NVARCHAR(5),  @c_StorerKey  NVARCHAR(15), @c_SKU NVARCHAR(20), ' + 
                         '@c_LocationType NVARCHAR(10), @c_LocationCategory NVARCHAR(10),' +           
                         '@c_Lottable01 NVARCHAR(18), @c_Lottable02 NVARCHAR(18), @c_Lottable03 NVARCHAR(18), ' +
                         '@c_Lottable06 NVARCHAR(30), @c_Lottable07 NVARCHAR(30), @c_Lottable08 NVARCHAR(30), ' + 
                         '@c_Lottable09 NVARCHAR(30), @c_Lottable10 NVARCHAR(30), @c_Lottable11 NVARCHAR(30), ' + 
                         '@c_Lottable12 NVARCHAR(30)'   

         
      EXEC sp_ExecuteSQL @c_SQL, @c_SQLParm, @c_Facility, @c_StorerKey, @c_SKU, @c_LocationType, @c_LocationCategory, 
                         @c_Lottable01, @c_Lottable02, @c_Lottable03, 
                         @c_Lottable06, @c_Lottable07, @c_Lottable08,@c_Lottable09, @c_Lottable10, @c_Lottable11, @c_Lottable12
      
      /*CS01 End*/
       SET @c_SQL = ''

      INSERT INTO #NumPool (UCCQty, CntCount)
      SELECT UCCQty, SUM(CntCount)
      FROM #UCCxLOTxLOCxID WITH (NOLOCK)
      GROUP BY UCCQty

      -- Get Lower Bound to reduce loop size
      SELECT @n_LowerBound = MIN(UCCQty)
      FROM #NumPool

      IF @b_Debug = 1
      BEGIN
         PRINT 'LowerBound: ' + CAST(@n_LowerBound AS NVARCHAR)
      END

      IF @n_QtyLeftToFulfill >= @n_LowerBound
      BEGIN
         IF @b_Debug = 1
         BEGIN
            PRINT 'STEP 1: START - ' + CONVERT(NVARCHAR(24), GETDATE(), 121)
         END

         /****************************************************************************************************/
         /***  STEP 1: Try MOD QtyLeftToFulfill with all number in NumPool = 0, GOTO STEP 2 IF no result   ***/
         /****************************************************************************************************/
         SET @n_UCCQty = 0
         SELECT TOP 1 @n_UCCQty = UCCQty
         FROM #NumPool WITH (NOLOCK)
         WHERE @n_QtyLeftToFulfill % UCCQty = 0
           AND @n_QtyLeftToFulfill/UCCQty <= CntCount
           AND CntCount > 0

         IF ISNULL(@n_UCCQty, 0) <> 0
         BEGIN
            SET @n_CntNeeded = @n_QtyLeftToFulfill/@n_UCCQty
            SET @c_Result = CAST(@n_UCCQty AS NVARCHAR) + ' * ' + CAST(@n_CntNeeded AS NVARCHAR)
            SET @n_Result = @n_CntNeeded * @n_UCCQty
         END -- IF ISNULL(@n_UCCQty,'') <> ''

         IF @b_Debug = 1
         BEGIN
            PRINT 'STEP 1: END - ' + CONVERT(NVARCHAR(24), GETDATE(), 121)
         END

         /***************************************************************************************************/
         /***  STEP 2: Get all possible combination of numbers, GET Combination with least Remainder,     ***/
         /***  exit if no result                                                                          ***/
         /***************************************************************************************************/
         IF ISNULL(@c_Result, '') = ''
         BEGIN
            IF @b_Debug = 1
            BEGIN
               PRINT 'STEP 2: START - ' + CONVERT(NVARCHAR(24), GETDATE(), 121)
            END

            /**************************************************************/
            /***   Get all possible combination of NumPool (once only)  ***/
            /**************************************************************/
            DECLARE CURSOR_COMBINATION CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
            SELECT UCCQty, CntCount
            FROM #NumPool WITH (ROWLOCK)
            WHERE CntCount > 0

            OPEN CURSOR_COMBINATION               
            FETCH NEXT FROM CURSOR_COMBINATION INTO @n_UCCQty, @n_CntCount
                   
            WHILE (@@FETCH_STATUS <> -1)          
            BEGIN
               SET @n_Count = 1

               WHILE (@n_Count <= @n_CntCount)
               BEGIN
                  INSERT INTO #CombinationPool 
                  VALUES (@n_UCCQty * @n_Count, 
                          CAST(@n_UCCQty AS NVARCHAR) + ' * ' + CAST(@n_Count AS NVARCHAR))

                  DECLARE CURSOR_COMBINATION_INNER CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
                  SELECT [Sum], Subset 
                  FROM #CombinationPool WITH (NOLOCK)
                  --WHERE CHARINDEX(CAST(@n_UCCQty AS NVARCHAR), Subset) = 0 
                  WHERE CHARINDEX(CAST(@n_UCCQty AS NVARCHAR) + ' * ', Subset) = 0 -- (Chee01)

                  OPEN CURSOR_COMBINATION_INNER               
                  FETCH NEXT FROM CURSOR_COMBINATION_INNER INTO @n_Sum, @c_Subset
                  WHILE (@@FETCH_STATUS <> -1)          
                  BEGIN

                     INSERT INTO #CombinationPool 
                     VALUES (@n_Sum + @n_UCCQty * @n_Count, 
                             @c_Subset + ' + ' + CAST(@n_UCCQty AS NVARCHAR) + ' * ' + CAST(@n_Count AS NVARCHAR))

                     FETCH NEXT FROM CURSOR_COMBINATION_INNER INTO @n_Sum, @c_Subset
                  END -- END WHILE FOR CURSOR_COMBINATION_INNER      
                  CLOSE CURSOR_COMBINATION_INNER          
                  DEALLOCATE CURSOR_COMBINATION_INNER 

                  SET @n_Count = @n_Count + 1
               END

               FETCH NEXT FROM CURSOR_COMBINATION INTO @n_UCCQty, @n_CntCount
            END -- END WHILE FOR CURSOR_COMBINATION      
            CLOSE CURSOR_COMBINATION
            DEALLOCATE CURSOR_COMBINATION  

            IF @b_Debug = 1
            BEGIN
               SELECT @c_SKU, * 
               FROM #CombinationPool 
               ORDER BY [Sum] DESC,
                        LEN(Subset) - LEN(REPLACE(Subset, '+', ''))
            END   

            -- GET Combination with least Remainder, least number combination
            SELECT TOP 1 @c_Result = Subset, @n_Result = [Sum]
            FROM #CombinationPool WITH (NOLOCK)
            WHERE [Sum] <= @n_QtyLeftToFulfill
            ORDER BY [Sum] DESC,
                     LEN(Subset) - LEN(REPLACE(Subset, '+', ''))

            IF @b_Debug = 1
            BEGIN
               PRINT 'STEP 2: END - ' + CONVERT(NVARCHAR(24), GETDATE(), 121)
            END   
         END -- IF ISNULL(@c_Result, '') = ''

         IF @b_Debug = 1
         BEGIN
            IF ISNULL(@c_Result, '') = ''
               PRINT 'NO RESULT' + CHAR(13)
            ELSE
               PRINT 'RESULT FOR ' + CAST(@n_QtyLeftToFulfill AS NVARCHAR) + ': ' + @c_Result + 
                     ' (Remainder: ' + CAST((@n_QtyLeftToFulfill - @n_Result) AS NVARCHAR) + ')' + CHAR(13) 
         END

         /*************************/
         /***  Process Result   ***/
         /************************/
         IF ISNULL(@c_Result, '') <> ''
         BEGIN
            -- Clear #SplitList
            DELETE FROM #SplitList
            SET @c_TempStr = @c_Result

            -- Convert Result string into #SplitList table
            WHILE CHARINDEX('+', @c_TempStr) > 0
            BEGIN
               SET @n_Pos  = CHARINDEX('+', @c_TempStr)  
               SET @c_Subset = SUBSTRING(@c_TempStr, 1, @n_Pos-2)
               SET @c_TempStr = SUBSTRING(@c_TempStr, @n_Pos+2, LEN(@c_TempStr)-@n_Pos)

               SET @n_Pos  = CHARINDEX('*', @c_Subset)
               SET @n_Number = CAST(SUBSTRING(@c_Subset, 1, @n_Pos-2) AS INT)
               SET @n_CntCount = CAST(SUBSTRING(@c_Subset, @n_Pos+2, LEN(@c_Subset) - @n_Pos+2) AS INT)
               INSERT INTO #SplitList VALUES (@n_Number, @n_CntCount) 
            END -- WHILE CHARINDEX('+', @c_Result) > 0

            SET @n_Pos  = CHARINDEX('*', @c_TempStr)
            SET @n_Number = CAST(SUBSTRING(@c_TempStr, 1, @n_Pos-2) AS INT)
            SET @n_CntCount = CAST(SUBSTRING(@c_TempStr, @n_Pos+2, LEN(@c_TempStr) - @n_Pos+2) AS INT)
            INSERT INTO #SplitList VALUES (@n_Number, @n_CntCount) 

            DECLARE CURSOR_SPLITLIST CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
            SELECT UCCQty, CntCount
            FROM #SplitList WITH (NOLOCK)

            OPEN CURSOR_SPLITLIST               
            FETCH NEXT FROM CURSOR_SPLITLIST INTO @n_UCCQty, @n_Count
                   
            WHILE (@@FETCH_STATUS <> -1)          
            BEGIN 
               WHILE @n_Count > 0
               BEGIN
                  SELECT TOP 1 @c_Loc = Loc, @c_Lot = Lot, @c_ID = ID, @n_CntCount = CntCount
                  FROM #UCCxLOTxLOCxID WITH (NOLOCK)
                  WHERE UCCQty = @n_UCCQty
                  AND CntCount > 0
                  ORDER BY LogicalLocation, Loc, CntCount DESC

                  -- UPDATE @n_Count
                  IF (@n_CntCount - @n_Count) >= 0
                  BEGIN
                     SET @n_CntCount = @n_Count
                     SET @n_Count = 0
                  END
                  ELSE
                  BEGIN
                     SET @n_Count = @n_Count - @n_CntCount
                  END

                  -- UPDATE #UCCxLOTxLOCxID
                  UPDATE #UCCxLOTxLOCxID WITH (ROWLOCK)
                  SET CntCount = CntCount - @n_CntCount
                  WHERE UCCQty = @n_UCCQty
                  AND Loc = @c_LOC
                  AND Lot = @c_LOT
                  AND ID  = @c_ID

                  SET @n_QtyAvailable = @n_UCCQty * @n_CntCount

                  --(Wan01) - START
                  --IF ISNULL(@c_SQL,'') = ''
                  --BEGIN
                  --   SET @c_SQL = N'   
                  --         DECLARE CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR   
                  --         SELECT '''  + @c_LOT + ''', ''' + @c_LOC + ''', ''' + @c_ID + ''', ''' + CAST(@n_QtyAvailable AS NVARCHAR(10)) + ''', ''1''
                  --         '
                  --END
                  --ELSE
                  --BEGIN
                  --   SET @c_SQL = @c_SQL + N'  
                  --         UNION
                  --         SELECT '''  + @c_LOT + ''', ''' + @c_LOC + ''', ''' + @c_ID + ''', ''' + CAST(@n_QtyAvailable AS NVARCHAR(10)) + ''', ''1''
                  --         '
                  --END
                  SET @c_Lot       = RTRIM(@c_Lot)             
                  SET @c_Loc       = RTRIM(@c_Loc)
                  SET @c_ID        = RTRIM(@c_ID)

                  EXEC isp_Insert_Allocate_Candidates
                     @c_Lot = @c_Lot
                  ,  @c_Loc = @c_Loc
                  ,  @c_ID  = @c_ID
                  ,  @n_QtyAvailable = @n_QtyAvailable
                  ,  @c_OtherValue = '1'

                  --(Wan01) - END
               END -- WHILE @n_Count > 0

               FETCH NEXT FROM CURSOR_SPLITLIST INTO @n_UCCQty, @n_Count
            END -- END WHILE FOR CURSOR_SPLITLIST      
            CLOSE CURSOR_SPLITLIST         
            DEALLOCATE CURSOR_SPLITLIST
         END -- IF ISNULL(@c_Result, '') <> ''
      END -- IF @n_QtyLeftToFulfill >= @n_LowerBound
   END  -- IF ISNULL(@c_LoadType,'') NOT IN ('N', 'DCToDC')

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
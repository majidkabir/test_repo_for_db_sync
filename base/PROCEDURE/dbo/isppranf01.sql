SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/    
/* Stored Procedure: ispPRANF01                                         */    
/* Creation Date: 07-Feb-2014                                           */    
/* Copyright: LFL                                                       */    
/* Written by: Chee Jun Yan                                             */    
/*                                                                      */    
/* Purpose: Alter OpenQty to factor of virtual rounding threshold value */
/*          (DCToDC Only)                                               */ 
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
/* 2014-05-26   Chee      1.1   Bug Fix when calculating combinations   */
/*                              for low UCC qty (Chee01)                */
/* 2015-01-13   NJOW01    1.2   329253-modify rounding method           */ 
/************************************************************************/    
CREATE PROC [dbo].[ispPRANF01]        
    @c_LoadKey                      NVARCHAR(10)
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
      @c_LoadType          NVARCHAR(20),
      @c_ANFSOType         NVARCHAR(60),
      @c_OrderKey          NVARCHAR(10),
      @c_OrderLineNumber   NVARCHAR(5),
      @c_Facility          NVARCHAR(5),
      @c_StorerKey         NVARCHAR(15),     
      @c_SKU               NVARCHAR(20), 
      @c_Lottable01        NVARCHAR(18),    
      @c_Lottable02        NVARCHAR(18),    
      @c_Lottable03        NVARCHAR(18),  
      @c_Destination       NVARCHAR(18),
      @c_Brand             NVARCHAR(18),
      @c_LocationType      NVARCHAR(10),    
      @c_LocationCategory  NVARCHAR(10),
      @n_EnteredQty        INT,
      @n_ThresholdQty      INT

   DECLARE
      @n_UCCQty          INT,
      @n_CntCount        INT,
      @n_CntNeeded       INT,
      @n_Count           INT,
      @n_Sum             INT,
      @n_Number          INT, 
      @n_Pos             INT,
      @c_Subset          NVARCHAR(4000), 
      @n_Result          INT,
      @c_TempStr         NVARCHAR(4000),
      @n_QtyAvailableDPP INT

   /************* --NJOW01 Remove Start
   IF OBJECT_ID('tempdb..#NumPool','u') IS NOT NULL
      DROP TABLE #NumPool;

   CREATE TABLE #NumPool (  
      UCCQty        INT,
      CntCount      INT DEFAULT 0
   )

   IF OBJECT_ID('tempdb..#CombinationPool','u') IS NOT NULL
      DROP TABLE #CombinationPool;

   -- Store all possible combination numbers
   CREATE TABLE #CombinationPool (
      [Sum]    INT, 
      Subset   NVARCHAR(4000)
   )
   *************/ --NJOW01 Remove End

   SELECT @n_StartTCnt = @@TRANCOUNT , @n_Continue=1, @b_Success=1, @n_Err=0, @c_ErrMsg=''

   -- GET LoadType FROM LoadPlan
   SELECT TOP 1 
      @c_LoadType = O.Type
   FROM LOADPLANDETAIL LPD WITH (NOLOCK) 
   JOIN ORDERS O WITH (NOLOCK) ON (LPD.OrderKey = O.OrderKey)
   WHERE LPD.LoadKey = @c_LoadKey

   -- SKIP THIS STEP IF Ordertype is not DCToDC
   IF ISNULL(@c_LoadType,'') <> 'DCToDC' 
      GOTO Quit

   -- Do not allow to process if already allocated 
   IF EXISTS(SELECT 1
             FROM PickDetail PD WITH (NOLOCK)
             JOIN OrderDetail OD WITH (NOLOCK) ON (OD.OrderKey = PD.OrderKey AND OD.OrderLineNumber = PD.OrderLineNumber)
             JOIN LOADPLANDETAIL LPD WITH (NOLOCK) ON (OD.OrderKey = LPD.OrderKey)
             WHERE LPD.LoadKey = @c_LoadKey)
   BEGIN  
      SET @n_Continue = 3
      SET @n_Err = 13000
      SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0)) + 
                      ': Load#' + RTRIM(@c_LoadKey) + ' already allocated. (ispPRANF01)'
      GOTO Quit
   END 

   -- Reset OrderDetail.OpenQty
   UPDATE OD
   SET OD.OpenQty = OD.EnteredQty
   FROM ORDERDETAIL OD WITH (NOLOCK)  
   JOIN ORDERS O WITH (NOLOCK) ON O.OrderKey = OD.OrderKey
   JOIN LoadPlanDetail LPD WITH (NOLOCK) ON OD.OrderKey = LPD.OrderKey
   WHERE LPD.LoadKey = @c_LoadKey   
     AND O.Type NOT IN ( 'M', 'I' )   
     AND O.SOStatus <> 'CANC'   
     AND O.Status < '9'   
     AND (OD.OpenQty - ( OD.QtyAllocated + OD.QtyPreAllocated + OD.QtyPicked )) > 0

   IF @@ERROR <> 0
   BEGIN
      SET @n_Continue = 3
      SET @n_Err = 13001
      SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0)) + 
                      ': Update OrderDetail Failed. (ispPOANF01)'
      GOTO Quit
   END

   DECLARE CURSOR_ORDERLINES CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
   SELECT  
      O.Facility,
      OD.StorerKey,
      OD.SKU,
      ISNULL(RTRIM(OD.UserDefine02),''),
      ISNULL(RTRIM(OD.UserDefine01),''),
      OD.Lottable01,
      OD.Lottable02,
      OD.Lottable03,
      SUM(OD.EnteredQty),
      OD.Orderkey, --NJOW01
      OD.OrderLineNumber --NJOW01      
   FROM ORDERDETAIL OD WITH (NOLOCK)  
   JOIN ORDERS O WITH (NOLOCK) ON O.OrderKey = OD.OrderKey
   JOIN LoadPlanDetail LPD WITH (NOLOCK) ON OD.OrderKey = LPD.OrderKey
   JOIN SKU WITH (NOLOCK) ON OD.Storerkey = SKU.Storerkey AND OD.Sku = SKU.Sku --NJOW01
   WHERE LPD.LoadKey = @c_LoadKey   
     AND O.Type NOT IN ( 'M', 'I' )   
     AND O.SOStatus <> 'CANC'   
     AND O.Status < '9'   
     AND (OD.OpenQty - ( OD.QtyAllocated + OD.QtyPreAllocated + OD.QtyPicked )) > 0
     AND SKU.PrepackIndicator <> 'Y' --NJOW01
   GROUP BY O.Facility, OD.StorerKey, OD.SKU, ISNULL(RTRIM(OD.UserDefine02),''), 
            ISNULL(RTRIM(OD.UserDefine01),''), OD.Lottable01, OD.Lottable02, OD.Lottable03,
            OD.Orderkey, OD.OrderLineNumber --NJOW01

   OPEN CURSOR_ORDERLINES
   FETCH NEXT FROM CURSOR_ORDERLINES INTO @c_Facility, @c_StorerKey, @c_SKU, @c_Destination, @c_Brand, 
                                          @c_Lottable01, @c_Lottable02, @c_Lottable03, @n_EnteredQty,
                                          @c_Orderkey, @c_OrderLineNumber --NJOW01

   WHILE (@@FETCH_STATUS <> -1)          
   BEGIN 
      SELECT @n_ThresholdQty = 0, @c_ANFSOType = 'N'

      -- Get Virtual Rounding Threshold Value
      SELECT @n_ThresholdQty = CODELKUP.UDF01
      FROM CODELKUP WITH (NOLOCK) 
      WHERE Listname = 'VirtualRdg'
        AND Code = @c_Destination + @c_Brand

      -- GET ANFSOType 
      SELECT @c_ANFSOType = CODELKUP.UDF05
      FROM CODELKUP WITH (NOLOCK)
      WHERE Listname = 'ANFSOtype'
        AND StorerKey + Code = @c_Destination

      IF @b_Debug = 1
         PRINT 'Virtual Rounding (' + @c_Destination + ', ' + @c_Brand + ') [' + CAST(@n_EnteredQty AS NVARCHAR) + ']: ' + CHAR(13) + 
               'ANFSOType: ' + @c_ANFSOType + ', ThresholdQty: ' + CAST(@n_ThresholdQty AS NVARCHAR) + CHAR(13)

      --NJOW01
      IF @n_ThresholdQty > 0 AND ISNULL(@c_ANFSOType,'') = 'Y' 
      BEGIN
      	 IF @n_EnteredQty < @n_ThresholdQty 
      	 BEGIN
            UPDATE ORDERDETAIL WITH (ROWLOCK)
            SET OpenQty = @n_ThresholdQty 
            WHERE OrderKey = @c_OrderKey
              AND OrderLineNumber = @c_OrderLineNumber

            IF @@ERROR <> 0
            BEGIN
               SET @n_Continue = 3
               SET @n_Err = 13002
               SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0)) + 
                               ': Update OrderDetail Failed. (ispPOANF01)'
               GOTO Quit
            END      	 	
      	 END      	 
      END

      /************* --NJOW01 Remove Start
      IF @n_ThresholdQty > 0 AND ISNULL(@c_ANFSOType,'') = 'Y' 
      BEGIN
      	 
         -- Check UCC if there's exact match
         DELETE FROM #CombinationPool
         DELETE FROM #NumPool
         -- Get Available Qty in Bulk
         SET @c_LocationType = 'OTHER'
         SET @c_LocationCategory = 'SELECTIVE'
         SET @c_SQL = N'
         INSERT INTO #NumPool (UCCQty, CntCount)
         SELECT DISTINCT UCC.Qty, COUNT(1)
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
            AND LOTxLOCxID.SKU = @c_SKU'+ CHAR(13) +
            CASE WHEN ISNULL(RTRIM(@c_LocationType),'') = '' THEN '' 
                 ELSE ' AND LOC.LocationType = ''' + @c_LocationType + '''' + CHAR(13) END +      
            CASE WHEN ISNULL(RTRIM(@c_LocationCategory),'') = '' THEN ''       
                 ELSE ' AND LOC.LocationCategory = ''' + @c_LocationCategory + '''' + CHAR(13) END +      
            CASE WHEN ISNULL(RTRIM(@c_Lottable01),'') = '' THEN '' ELSE ' AND LA.Lottable01 = @c_Lottable01 ' + CHAR(13) END +      
            CASE WHEN ISNULL(RTRIM(@c_Lottable02),'') = '' THEN '' ELSE ' AND LA.Lottable02 = @c_Lottable02 ' + CHAR(13) END +      
            CASE WHEN ISNULL(RTRIM(@c_Lottable03),'') = '' THEN '' ELSE ' AND LA.Lottable03 = @c_Lottable03 ' + CHAR(13) END +  
            'AND (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QtyReplen) >= UCC.Qty
         GROUP BY UCC.Qty, LOTxLOCxID.QTYALLOCATED
         HAVING COUNT(1) > 0'

         SET @c_SQLParm =  N'@c_Facility   NVARCHAR(5),  @c_StorerKey  NVARCHAR(15), @c_SKU NVARCHAR(20), ' +      
                            '@c_Lottable01 NVARCHAR(18), @c_Lottable02 NVARCHAR(18), @c_Lottable03 NVARCHAR(18) ' 
            
         EXEC sp_ExecuteSQL @c_SQL, @c_SQLParm, @c_Facility, @c_StorerKey, @c_SKU, @c_Lottable01, @c_Lottable02, @c_Lottable03 

         SET @n_QtyAvailableDPP = 0
         -- Get Available Qty in DPP
         SET @c_LocationType = 'DYNPPICK'    
         SET @c_LocationCategory = 'MEZZANINE'  
         SET @c_SQL = N'SELECT @n_QtyAvailableDPP = (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QtyReplen)     
                        FROM LOTxLOCxID (NOLOCK)     
                        JOIN LOC (NOLOCK) ON (LOTxLOCxID.Loc = LOC.LOC)    
                        JOIN ID (NOLOCK) ON (LOTxLOCxID.Id = ID.ID AND ID.STATUS <> ''HOLD'')     
                        JOIN LOT (NOLOCK) ON (LOTXLOCXID.LOT = LOT.LOT AND LOT.STATUS <> ''HOLD'')       
                        JOIN LOTATTRIBUTE LA (NOLOCK) ON LOT.LOT = LA.LOT          
                        WHERE LOC.LocationFlag <> ''HOLD''     
                        AND LOC.LocationFlag <> ''DAMAGE''     
                        AND LOC.Status <> ''HOLD''
                        AND LOC.Facility = @c_Facility
                        AND LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QtyReplen > 0    
                        AND LOTxLOCxID.STORERKEY = @c_StorerKey 
                        AND LOTxLOCxID.SKU = @c_SKU ' + CHAR(13) +      
                        CASE WHEN ISNULL(RTRIM(@c_LocationType),'') = '' THEN '' 
                             ELSE ' AND LOC.LocationType = ''' + @c_LocationType + '''' + CHAR(13) END +      
                        CASE WHEN ISNULL(RTRIM(@c_LocationCategory),'') = '' THEN ''       
                             ELSE ' AND LOC.LocationCategory = ''' + @c_LocationCategory + '''' + CHAR(13) END +      
                        CASE WHEN ISNULL(RTRIM(@c_Lottable01),'') = '' THEN '' ELSE ' AND LA.Lottable01 = @c_Lottable01 ' + CHAR(13) END +      
                        CASE WHEN ISNULL(RTRIM(@c_Lottable02),'') = '' THEN '' ELSE ' AND LA.Lottable02 = @c_Lottable02 ' + CHAR(13) END +      
                        CASE WHEN ISNULL(RTRIM(@c_Lottable03),'') = '' THEN '' ELSE ' AND LA.Lottable03 = @c_Lottable03 ' + CHAR(13) END 
 
         SET @c_SQLParm =  N'@c_Facility   NVARCHAR(5),  @c_StorerKey  NVARCHAR(15), @c_SKU        NVARCHAR(20), ' +    
                            '@c_Lottable01 NVARCHAR(18), @c_Lottable02 NVARCHAR(18), @c_Lottable03 NVARCHAR(18), @n_QtyAvailableDPP INT OUTPUT '     

         EXEC sp_ExecuteSQL @c_SQL, @c_SQLParm, @c_Facility, @c_StorerKey, @c_SKU, @c_Lottable01, @c_Lottable02, @c_Lottable03, @n_QtyAvailableDPP OUTPUT

         IF @b_Debug = 1
         BEGIN
            SET @c_TempStr = ''
            SELECT @c_TempStr = @c_TempStr + CAST(UCCQty AS NVARCHAR) + ', Count: ' + CAST(CntCount AS NVARCHAR) + CHAR(13) FROM #NumPool WITH (NOLOCK)
            PRINT 'Selected UCC for StorerKey: ' + RTRIM(@c_StorerKey) + ', SKU: ' + RTRIM(@c_SKU) +
                  ', Lottable01: ' + RTRIM(@c_Lottable01) + ', Lottable02: ' + RTRIM(@c_Lottable02) + ', Lottable03: ' + RTRIM(@c_Lottable03) + 
                  ', QtyAvailableDPP: ' + CAST(@n_QtyAvailableDPP AS NVARCHAR) + CHAR(13) + 
                  SUBSTRING(@c_TempStr, 0, LEN(@c_TempStr)) + CHAR(13)
         END

         SELECT @n_Result = 0, @n_UCCQty = 0
         
         --*********************************************************************************************
         --***  STEP 1: Try MOD OrderQty with all number in NumPool = 0, GOTO STEP 2 IF no result    ***
         --*********************************************************************************************
         
         SELECT TOP 1 @n_UCCQty = UCCQty
         FROM #NumPool WITH (NOLOCK)
         WHERE @n_EnteredQty % UCCQty = 0
           AND @n_EnteredQty/UCCQty <= CntCount
           AND CntCount > 0

         IF ISNULL(@n_UCCQty, 0) <> 0
         BEGIN
            SET @n_CntNeeded = @n_EnteredQty/@n_UCCQty
            SET @n_Result = @n_CntNeeded * @n_UCCQty
         END -- IF ISNULL(@n_UCCQty,'') <> ''

         --***************************************************************************************************
         --***  STEP 2: Get all possible combination of numbers                                            ***
         --***************************************************************************************************
         IF @n_Result = 0
         BEGIN
            SELECT @n_Count = COUNT(1) 
            FROM #CombinationPool WITH (NOLOCK)

            --*********************************************************************
            --***   START: Get all possible combination of NumPool (once only)  ***
            --*********************************************************************
            IF @n_Count = 0
            BEGIN
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
            END -- IF @n_Count = 0
            --*******************************************************************
            --***   END: Get all possible combination of NumPool (once only)  ***
            --*******************************************************************
            IF @b_Debug = 1
            BEGIN
               SET @c_TempStr = ''
               SELECT @c_TempStr = @c_TempStr + Subset + ', ' + CAST([Sum] AS NVARCHAR) + CHAR(13) FROM #CombinationPool WITH (NOLOCK) WHERE [Sum] <= @n_EnteredQty
               PRINT 'Combination Pool for ' + CAST(@n_EnteredQty AS NVARCHAR) + ' : ' + CHAR(13) + 
                     SUBSTRING(@c_TempStr, 0, LEN(@c_TempStr)) + CHAR(13) 
            END

            -- GET Combination with exact match
            SELECT TOP 1 @n_Result = [Sum]
            FROM #CombinationPool WITH (NOLOCK)
            WHERE [Sum] = @n_EnteredQty
            ORDER BY LEN(Subset) - LEN(REPLACE(Subset, '+', ''))

         END -- IF @n_Result = 0 [STEP 2]

         -- Exact Match
         IF @n_Result = @n_EnteredQty
         BEGIN
            SET @n_ThresholdQty = @n_EnteredQty
         END
         ELSE 
         BEGIN
            -- Get Minimum UCCQty
            SELECT @n_UCCQty = 0
            SELECT @n_UCCQty = ISNULL(MIN(UCCQty), 0)
            FROM #NumPool WITH (NOLOCK)
            WHERE CntCount > 0

            IF @n_EnteredQty > @n_UCCQty AND @n_UCCQty > 0
            BEGIN 
               -- Difference between EnterQty and UCC * n 
               SET @n_UCCQty = @n_EnteredQty - (@n_EnteredQty/@n_UCCQty) * @n_UCCQty
               SET @n_ThresholdQty = @n_EnteredQty + 
                                     CASE WHEN @n_ThresholdQty < @n_UCCQty THEN @n_ThresholdQty * (ABS(@n_ThresholdQty - @n_UCCQty + 1)/@n_ThresholdQty + 2)
                                          ELSE @n_ThresholdQty 
                                     END - @n_UCCQty
            END
            ELSE
            BEGIN
               SET @n_ThresholdQty = @n_ThresholdQty * ((@n_EnteredQty - 1) / @n_ThresholdQty + 1)  
            END

            -- Get from Bulk, add to QtyAvailableDPP
            IF (@n_ThresholdQty - @n_Result) > @n_QtyAvailableDPP
            BEGIN
               -- Get Minimum UCCQty
               SELECT @n_UCCQty = 0
               SELECT @n_UCCQty = ISNULL(MIN(UCCQty), 0)
               FROM #NumPool WITH (NOLOCK)
               WHERE CntCount > 0
                 AND CntCount >= CASE WHEN (@n_ThresholdQty - @n_Result - @n_QtyAvailableDPP) <= 0 THEN 0
                                      ELSE (@n_ThresholdQty - @n_Result - @n_QtyAvailableDPP - 1) / UCCQty + 1
                                 END

               -- If No UCC Found in BULK, revert entered qty
               IF @n_UCCQty = 0
               BEGIN
                  SET @n_ThresholdQty = @n_EnteredQty
               END
            END -- IF (@n_ThresholdQty - @n_Result) > @n_QtyAvailableDPP
         END -- IF @n_Result <> @n_EnteredQty

         IF (@n_ThresholdQty - @n_EnteredQty) > 0
         BEGIN
            SELECT @c_OrderKey = '', @c_OrderLineNumber = ''
            SELECT TOP 1 
               @c_OrderKey = OD.OrderKey,
               @c_OrderLineNumber = OD.OrderLineNumber
            FROM ORDERDETAIL OD WITH (NOLOCK)  
            JOIN ORDERS O WITH (NOLOCK) ON O.OrderKey = OD.OrderKey
            JOIN LoadPlanDetail LPD WITH (NOLOCK) ON OD.OrderKey = LPD.OrderKey
            WHERE LPD.LoadKey = @c_LoadKey   
              AND O.Type NOT IN ( 'M', 'I' )   
              AND O.SOStatus <> 'CANC'   
              AND O.Status < '9'   
              AND (OD.OpenQty - ( OD.QtyAllocated + OD.QtyPreAllocated + OD.QtyPicked )) > 0
              AND O.Facility = @c_Facility
              AND OD.StorerKey = @c_StorerKey
              AND OD.SKU = @c_SKU
              AND ISNULL(RTRIM(OD.UserDefine02),'') = @c_Destination
              AND ISNULL(RTRIM(OD.UserDefine01),'') = @c_Brand
              AND OD.Lottable01 = @c_Lottable01
              AND OD.Lottable02 = @c_Lottable02
              AND OD.Lottable03 = @c_Lottable03
            ORDER BY EnteredQty

            UPDATE ORDERDETAIL WITH (ROWLOCK)
            SET OpenQty = EnteredQty + (@n_ThresholdQty - @n_EnteredQty)
            WHERE OrderKey = @c_OrderKey
              AND OrderLineNumber = @c_OrderLineNumber

            IF @@ERROR <> 0
            BEGIN
               SET @n_Continue = 3
               SET @n_Err = 13002
               SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0)) + 
                               ': Update OrderDetail Failed. (ispPOANF01)'
               GOTO Quit
            END

            IF @b_Debug = 1
               PRINT 'Altered EnteredQty ' + CAST(@n_EnteredQty AS NVARCHAR) + ' >> ' + CAST(@n_ThresholdQty AS NVARCHAR) + CHAR(13) 

         END -- IF @n_ThresholdQty - @n_EnteredQty > 0
      END -- IF @n_ThresholdQty > 0 AND ISNULL(@c_ANFSOType,'') = 'Y' 
      *************/ --NJOW01 Remove End
     
      FETCH NEXT FROM CURSOR_ORDERLINES INTO @c_Facility, @c_StorerKey, @c_SKU, @c_Destination, @c_Brand, 
                                             @c_Lottable01, @c_Lottable02, @c_Lottable03, @n_EnteredQty,
                                             @c_Orderkey, @c_OrderLineNumber --NJOW01
   END -- END WHILE FOR CURSOR_ORDERLINES
   CLOSE CURSOR_ORDERLINES
   DEALLOCATE CURSOR_ORDERLINES

QUIT:
   IF (SELECT CURSOR_STATUS('LOCAL','CURSOR_ORDERLINES')) >=0 
   BEGIN
      CLOSE CURSOR_ORDERLINES           
      DEALLOCATE CURSOR_ORDERLINES      
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
      EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'ispPRANF01'  
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
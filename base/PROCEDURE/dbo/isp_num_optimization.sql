SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Stored Procedure: isp_Num_Optimization                               */  
/* Creation Date: 02-DEC-2021                                           */  
/* Copyright: LFL                                                       */  
/* Written by: NJOW                                                     */  
/*                                                                      */  
/* Purpose: WMS-18517 - General Optimization function                   */  
/*                                                                      */                                                    
/* Called By:                                                           */  
/*                                                                      */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 7.0                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author  Ver. Purposes                                   */  
/* 15-Dec-2021  NJOW    1.0  DEVOPS combine script                      */
/************************************************************************/  

CREATE PROC [dbo].[isp_Num_Optimization]  
     @n_NumRequest           DECIMAL(14,6) = 0.00  --request qty / cube / weight / other
    ,@c_OptimizeMode         NVARCHAR(10) = '0' -- 0=Best combination result allow more(1st priority)/less than NumRequest with partial unit (default). 
                                                -- 1=Best combination result allow more but not less than NumRequest with partial unit. 
                                                -- 2=Best combination result not allow more than NumRequest and no partial unit. Usually search for best full carton/ucc combination. 
                                                -- 3=Best combination result must exact match with NumRequest.
                                                
                                                -- Best combination mean minimum combination of different Num and minimum units to fulfill the requested num. 
                                                -- Partial unit mean one of the combination result's unit is partially taken by the requested num. 
                                                -- e.g. requested 10 qty(num) and combination result return 1 unit with 2 qty and 3 units with 3 qty, total is 11 qty, so last unit is partial unit due to extra 1 qty.
    --,@b_success              INT           = 1  OUTPUT  
    --,@n_err                  INT           = 0  OUTPUT  
    --,@c_errmsg               NVARCHAR(250) = '' OUTPUT  
AS  
BEGIN
	  /* --Sample calling method
	  CREATE TABLE #NUM_OPTIMIZATION_INPUT (RowID INT IDENTITY(1,1), KeyField NVARCHAR(60), Num DECIMAL(14,6), UnitCount INT)
	  CREATE TABLE #NUM_OPTIMIZATION_OUTPUT (RowID INT IDENTITY(1,1), KeyField NVARCHAR(60), Num DECIMAL(14,6), UnitCount INT)
	  
	  INSERT INTO #NUM_OPTIMIZATION_INPUT (KeyField, Num, UnitCount) --Without keyfield
	    SELECT '',1, 4
	     UNION ALL
	    SELECT '',2, 3
	     UNION ALL
	    SELECT '',3, 2
	    
	  OR

	  INSERT INTO #NUM_OPTIMIZATION_INPUT (KeyField, Num, UnitCount) --with keyfield
	    SELECT 'A',1, 4
	     UNION ALL
	    SELECT 'C',2, 3
	     UNION ALL
	    SELECT 'F',3, 2
	     UNION ALL
	    SELECT 'G',3, 2
	  
	  INSERT INTO #NUM_OPTIMIZATION_OUTPUT
	  EXEC isp_Num_Optimization 
	         @n_NumRequest = 5
	        ,@c_OptimizeMode = '0'
	  
	  SELECT * FROM #NUM_OPTIMIZATION_OUTPUT     
	  */
    SET NOCOUNT ON   
    SET ANSI_NULLS OFF
    SET QUOTED_IDENTIFIER OFF   
    SET CONCAT_NULL_YIELDS_NULL OFF  

    DECLARE @n_continue             INT,
            @b_debug                INT = 0, 
            @c_Found                NVARCHAR(10) = 'N',
            @n_UnitNeeded           INT = 0,
            @n_Num                  DECIMAL(14,6) = 0.00,
            @c_Result               NVARCHAR(MAX) = '',
            @n_UnitCount            INT = 0,
            @n_Count                INT = 0,
            @c_SubSet               NVARCHAR(MAX) = '',
            @n_SubSetSum            DECIMAL(14,6) = 0.00,
            @n_Pos                  INT = 0,
            @c_TempStr              NVARCHAR(MAX) = '',      
            @n_Number               DECIMAL(14,6) = 0.00,
            @n_SubSetUnitCount      INT = 0,
            @c_IncludeKeyField      NVARCHAR(10) = 'N',
            @n_RowID                INT = 0,
            @n_RowID2               INT = 0         
            
    SELECT @n_continue=1--, @n_err=0, @c_ErrMsg='', @b_Success=1
    
    IF ISNULL(@c_OptimizeMode,'') = ''
       SET @c_OptimizeMode = '0'

    --Initialization
    IF @n_continue IN(1,2)
    BEGIN           
       CREATE TABLE #NumPool (RowID         INT IDENTITY(1,1),  --if more than one combination are matched, the selection priority will depend on rowid sequence.
                              KeyField      NVARCHAR(60) DEFAULT(''),  --sku,loc,zone,other. (optional)
                              Num           DECIMAL(14,6),  --qty,cube,weight
                              UnitCount     INT DEFAULT 0,  --number of units of num. e.g. 3 units of UCC with 10 qty(num) 5 units UCC with 8 qty(num)
                              UnitAllocated INT DEFAULT 0
                             )
          
       -- Store all possible combination numbers
       CREATE TABLE #CombinationPool (RowID     INT,
                                      SubSetSum DECIMAL(14,6), 
                                      Subset    NVARCHAR(MAX),
                                      UnitCount INT
                                     )
          
       -- Store SPLIT of #CombinationPool.Subset
       CREATE TABLE #SplitList (RowID     INT,
                                Num       DECIMAL(14,6), 
                                UnitCount INT
                               )            
                                      
       IF OBJECT_ID('tempdb..#NUM_OPTIMIZATION_INPUT') IS NOT NULL
       BEGIN
          INSERT INTO #NumPool (KeyField, Num, UnitCount)
          SELECT KeyField, Num, UnitCount
          FROM #NUM_OPTIMIZATION_INPUT
          ORDER BY RowID
       END      
       
       IF EXISTS(SELECT 1 FROM #NumPool WHERE KeyField <> '' AND KeyField IS NOT NULL)
       BEGIN
       	  SET @c_IncludeKeyField = 'Y'
       END
       
       IF @b_debug = 1
       BEGIN
       	  PRINT '@n_NumRequest= ' +  CAST(@n_NumRequest AS NVARCHAR)
       	  PRINT '@c_OptimizeMode= ' +  @c_OptimizeMode
       	  PRINT '@c_IncludeKeyField= ' + @c_IncludeKeyField
       END       
    END    
        
    --Find the Num(unit) fit the reqeusted num with same num (with keyfield optional)
    IF @n_continue IN(1,2)
    BEGIN
      SELECT TOP 1 @n_Num = Num,
                   @n_RowId = RowID
      FROM #NumPool WITH (NOLOCK)
      WHERE @n_NumRequest % Num = 0
      AND @n_NumRequest / Num <= UnitCount
      AND UnitCount > 0
      ORDER BY UnitCount,RowID  --less unit
                      
      IF ISNULL(@n_Num,0) <> 0
      BEGIN
         SET @c_Found = 'Y'
         SET @n_UnitNeeded = @n_NumRequest / @n_Num
         IF @c_IncludeKeyField = 'Y'
            SET @c_Result = CAST(@n_RowID AS NVARCHAR) + '@' + FORMAT(@n_Num,'0.######') + '*' + CAST(@n_UnitNeeded AS NVARCHAR)          
         ELSE
            SET @c_Result = FORMAT(@n_Num,'0.######') + '*' + CAST(@n_UnitNeeded AS NVARCHAR)               
         
         /*
         UPDATE #NumPool WITH (ROWLOCK)
         SET UnitCount = UnitCount - @n_UnitNeeded, 
             UnitAllocated = UnitAllocated + @n_UnitNeeded
         WHERE RowID = @n_RowID
         */                          
         
         IF @b_debug = 1
         BEGIN
         	 PRINT 'Same Num unit fit - ' + @c_Result
         END
      END   
    END

  	--Build Num combination pool
    IF @n_continue IN(1,2) AND @c_Found = 'N'
    BEGIN                          
       DECLARE CURSOR_COMBINATION CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
          SELECT Num, UnitCount, RowID
          FROM #NumPool WITH (ROWLOCK)
          WHERE UnitCount > 0
          ORDER BY RowID
       
       OPEN CURSOR_COMBINATION            
          
       FETCH NEXT FROM CURSOR_COMBINATION INTO @n_Num, @n_UnitCount, @n_RowID
              
       WHILE (@@FETCH_STATUS <> -1)          
       BEGIN
          SET @n_Count = 1
       
          WHILE (@n_Count <= @n_UnitCount)
          BEGIN
          	 IF @c_IncludeKeyField = 'Y'
          	 BEGIN
                INSERT INTO #CombinationPool 
                VALUES (@n_RowID, @n_Num * @n_Count, 
                        CAST(@n_RowID AS NVARCHAR) + '@' + FORMAT(@n_Num,'0.######') + '*' + CAST(@n_Count AS NVARCHAR), 
                        @n_Count)
                
                DECLARE CURSOR_COMBINATION_INNER CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
                   SELECT RowId, SubSetSum, Subset, UnitCount 
                   FROM #CombinationPool WITH (NOLOCK)
                   WHERE CHARINDEX(CAST(@n_RowID AS NVARCHAR) + '@' + FORMAT(@n_Num,'0.######') + '*', Subset) = 0 
                   AND SubSetSum < @n_NumRequest --skip build combination more than request Num to improve speed
                
                OPEN CURSOR_COMBINATION_INNER               
                
                FETCH NEXT FROM CURSOR_COMBINATION_INNER INTO @n_RowID2, @n_SubSetSum, @c_Subset, @n_SubSetUnitCount
                WHILE (@@FETCH_STATUS <> -1)          
                BEGIN       
                   INSERT INTO #CombinationPool 
                   VALUES (@n_RowID2, @n_SubSetSum + (@n_Num * @n_Count), 
                           @c_Subset + '+' + CAST(@n_RowID AS NVARCHAR) + '@' + FORMAT(@n_Num,'0.######') + '*' + CAST(@n_Count AS NVARCHAR),
                           @n_SubSetUnitCount + @n_Count)
                
                   FETCH NEXT FROM CURSOR_COMBINATION_INNER INTO @n_RowID2, @n_SubSetSum, @c_Subset, @n_SubSetUnitCount
                END --CURSOR_COMBINATION_INNER    
                CLOSE CURSOR_COMBINATION_INNER          
                DEALLOCATE CURSOR_COMBINATION_INNER 
             END
             ELSE
             BEGIN
                INSERT INTO #CombinationPool 
                VALUES (@n_RowID, @n_Num * @n_Count, 
                        FORMAT(@n_Num,'0.######') + '*' + CAST(@n_Count AS NVARCHAR), 
                        @n_Count)
                
                DECLARE CURSOR_COMBINATION_INNER CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
                   SELECT RowID, SubSetSum, Subset, UnitCount 
                   FROM #CombinationPool WITH (NOLOCK)
                   WHERE CHARINDEX(FORMAT(@n_Num,'0.######') + '*', Subset) = 0 
                   AND SubSetSum < @n_NumRequest --skip build combination more than request Num to improve speed
                
                OPEN CURSOR_COMBINATION_INNER               
                
                FETCH NEXT FROM CURSOR_COMBINATION_INNER INTO @n_RowID2, @n_SubSetSum, @c_Subset, @n_SubSetUnitCount
                WHILE (@@FETCH_STATUS <> -1)          
                BEGIN       
                   INSERT INTO #CombinationPool 
                   VALUES (@n_RowID2, @n_SubSetSum + (@n_Num * @n_Count), 
                           @c_Subset + '+' + FORMAT(@n_Num,'0.######') + '*' + CAST(@n_Count AS NVARCHAR),
                           @n_SubSetUnitCount + @n_Count)
                
                   FETCH NEXT FROM CURSOR_COMBINATION_INNER INTO @n_RowID2, @n_SubSetSum, @c_Subset, @n_SubSetUnitCount
                END --CURSOR_COMBINATION_INNER    
                CLOSE CURSOR_COMBINATION_INNER          
                DEALLOCATE CURSOR_COMBINATION_INNER 
             END
       
             SET @n_Count = @n_Count + 1
          END
       
          FETCH NEXT FROM CURSOR_COMBINATION INTO @n_Num, @n_UnitCount, @n_RowID
       END  --CURSOR_COMBINATION  
       CLOSE CURSOR_COMBINATION
       DEALLOCATE CURSOR_COMBINATION    
       
       /*IF @b_debug = 1
       BEGIN
       	  SELECT * FROM #CombinationPool
       END*/
    END

    --Find the num(unit) fit the reqeusted num with less combination 
    IF @n_continue IN(1,2) AND @c_Found = 'N'
    BEGIN
       SET @c_Result = ''
       
       --Exact combination match with less combination  (@c_OptimizationMode 0,1,2,3)
       SELECT TOP 1 @c_Result = Subset
       FROM #CombinationPool WITH (NOLOCK)
       WHERE SubSetSum = @n_NumRequest
       ORDER BY LEN(Subset) - LEN(REPLACE(Subset, '+', '')),   --less combination
                UnitCount, RowID --less unit

       IF @b_debug = 1 AND @c_result <> ''
       BEGIN
       	 PRINT 'combine exact match - ' + @c_Result 
       END
       
       --Match with more than or equal num request with less combination
       IF ISNULL(@c_Result,'') = '' AND @c_OptimizeMode IN('0','1')
       BEGIN
          SELECT TOP 1 @c_Result = Subset
          FROM #CombinationPool WITH (NOLOCK)
          WHERE SubSetSum >= @n_NumRequest
          ORDER BY SubSetSum ASC,
                  LEN(Subset) - LEN(REPLACE(Subset, '+', '')),  --less combination
                  UnitCount, RowID --less unit
                  
          IF @b_debug = 1
          BEGIN
          	 PRINT 'combine match with more - ' + @c_Result
          END                  
       END
       
       --Match with less than or equal num request with less combination
       IF ISNULL(@c_Result,'') = '' AND @c_OptimizeMode IN('0','2')
       BEGIN
          SELECT TOP 1 @c_Result = Subset
          FROM #CombinationPool WITH (NOLOCK)
          WHERE SubSetSum <= @n_NumRequest
          ORDER BY SubSetSum DESC,
                   LEN(Subset) - LEN(REPLACE(Subset, '+', '')), --less combination
                   UnitCount, RowID --less unit

          IF @b_debug = 1
          BEGIN
          	 PRINT 'combine match with less - ' + @c_Result
          END                                     
       END
       
       IF ISNULL(@c_Result,'') <> ''
          SET @c_Found = 'Y'
    END

    --Extract the result into table
    IF @n_continue IN(1,2) AND @c_Found = 'Y'
    BEGIN
       SET @c_TempStr = @c_Result
       
       -- Convert Result string into #SplitList table
       IF @c_IncludeKeyField = 'Y'
       BEGIN
          WHILE CHARINDEX('+', @c_TempStr) > 0
          BEGIN
             SET @n_Pos  = CHARINDEX('+', @c_TempStr)  
             SET @c_Subset = SUBSTRING(@c_TempStr, 1, @n_Pos-1)
             SET @c_TempStr = SUBSTRING(@c_TempStr, @n_Pos+1, LEN(@c_TempStr)-@n_Pos)
             
             SET @n_Pos  = CHARINDEX('@', @c_Subset)  
             SET @n_RowID = CAST(SUBSTRING(@c_Subset, 1, @n_Pos-1) AS INT)
             SET @c_Subset = SUBSTRING(@c_Subset, @n_Pos+1, LEN(@c_Subset)-@n_Pos)             
              
             SET @n_Pos  = CHARINDEX('*', @c_Subset)
             SET @n_Number = CAST(SUBSTRING(@c_Subset, 1, @n_Pos-1) AS DECIMAL(14,6))
             SET @n_UnitCount = CAST(SUBSTRING(@c_Subset, @n_Pos+1, LEN(@c_Subset) - @n_Pos+1) AS INT)
             
             INSERT INTO #SplitList VALUES (@n_RowId, @n_Number, @n_UnitCount) 
          END 

          SET @n_Pos  = CHARINDEX('@', @c_TempStr)  
          SET @n_RowID = CAST(SUBSTRING(@c_TempStr, 1, @n_Pos-1) AS INT)
          SET @c_TempStr = SUBSTRING(@c_TempStr, @n_Pos+1, LEN(@c_TempStr)-@n_Pos)             
          
          SET @n_Pos  = CHARINDEX('*', @c_TempStr)
          SET @n_Number = CAST(SUBSTRING(@c_TempStr, 1, @n_Pos-1) AS DECIMAL(14,6))
          SET @n_UnitCount = CAST(SUBSTRING(@c_TempStr, @n_Pos+1, LEN(@c_TempStr) - @n_Pos+1) AS INT)
          
          INSERT INTO #SplitList VALUES (@n_RowId, @n_Number, @n_UnitCount) 
          -- Clear #CombinationPool  
          /*
          DECLARE CURSOR_SPLITLIST CURSOR FAST_FORWARD READ_ONLY FOR 
          SELECT Num, UnitCount, RowID 
          FROM #SplitList WITH (NOLOCK)
          
          OPEN CURSOR_SPLITLIST
          FETCH NEXT FROM CURSOR_SPLITLIST INTO @n_Num, @n_UnitNeeded, @n_RowID
          
          WHILE (@@FETCH_STATUS <> -1)
          BEGIN
             SELECT @n_UnitCount = UnitCount,
                    @n_Count = UnitCount - @n_UnitNeeded
             FROM #NumPool WITH (NOLOCK)
             WHERE RowID = @n_RowID
          
             UPDATE #NumPool WITH (ROWLOCK)
             SET UnitCount = @n_Count, 
                 UnitAllocated = UnitAllocated + @n_UnitNeeded
             WHERE RowID = @n_RowID
          
             IF @n_Count > 0
             BEGIN
                WHILE (@n_UnitCount > @n_Count)
                BEGIN
                   DELETE FROM #CombinationPool WITH (ROWLOCK)
                   WHERE CHARINDEX(CAST(@n_RowID AS NVARCHAR) + '@' + FORMAT(@n_Num,'0.######') + '*' + CAST(@n_UnitCount AS NVARCHAR), Subset) > 0 
          
                   SET @n_UnitCount = @n_UnitCount - 1
                END
             END -- IF @n_Count > 0
             ELSE
             BEGIN
                DELETE FROM #CombinationPool WITH (ROWLOCK)
                WHERE CHARINDEX(CAST(@n_RowID AS NVARCHAR) + '@' + FORMAT(@n_Num,'0.######') + '*', Subset) > 0       
             END -- IF @n_Count <= 0
          
             FETCH NEXT FROM CURSOR_SPLITLIST INTO @n_Num, @n_UnitNeeded, @n_RowID
          END -- CURSOR_SPLITLIST    
          CLOSE CURSOR_SPLITLIST          
          DEALLOCATE CURSOR_SPLITLIST     
          */      
          
       END
       ELSE
       BEGIN            
          WHILE CHARINDEX('+', @c_TempStr) > 0
          BEGIN
             SET @n_Pos  = CHARINDEX('+', @c_TempStr)  
             SET @c_Subset = SUBSTRING(@c_TempStr, 1, @n_Pos-2)
             SET @c_TempStr = SUBSTRING(@c_TempStr, @n_Pos+2, LEN(@c_TempStr)-@n_Pos)
          
             SET @n_Pos  = CHARINDEX('*', @c_Subset)
             SET @n_Number = CAST(SUBSTRING(@c_Subset, 1, @n_Pos-2) AS DECIMAL(14,6))
             SET @n_UnitCount = CAST(SUBSTRING(@c_Subset, @n_Pos+2, LEN(@c_Subset) - @n_Pos+2) AS INT)
             
             INSERT INTO #SplitList VALUES (0, @n_Number, @n_UnitCount) 
          END 
          
          SET @n_Pos  = CHARINDEX('*', @c_TempStr)
          SET @n_Number = CAST(SUBSTRING(@c_TempStr, 1, @n_Pos-2) AS DECIMAL(14,6))
          SET @n_UnitCount = CAST(SUBSTRING(@c_TempStr, @n_Pos+2, LEN(@c_TempStr) - @n_Pos+2) AS INT)
          
          INSERT INTO #SplitList VALUES (0, @n_Number, @n_UnitCount) 

          -- Clear #CombinationPool  
          /*
          DECLARE CURSOR_SPLITLIST CURSOR FAST_FORWARD READ_ONLY FOR 
          SELECT Num, UnitCount 
          FROM #SplitList WITH (NOLOCK)
          
          OPEN CURSOR_SPLITLIST
          FETCH NEXT FROM CURSOR_SPLITLIST INTO @n_Num, @n_UnitNeeded
          
          WHILE (@@FETCH_STATUS <> -1)
          BEGIN
             SELECT @n_UnitCount = UnitCount,
                    @n_Count = UnitCount - @n_UnitNeeded
             FROM #NumPool WITH (NOLOCK)
             WHERE Num = @n_Num
          
             UPDATE #NumPool WITH (ROWLOCK)
             SET UnitCount = @n_Count, 
                 UnitAllocated = UnitAllocated + @n_UnitNeeded
             WHERE Num = @n_Num
          
             IF @n_Count > 0
             BEGIN
                WHILE (@n_UnitCount > @n_Count)
                BEGIN
                   DELETE FROM #CombinationPool WITH (ROWLOCK)
                   WHERE CHARINDEX(FORMAT(@n_Num,'0.######') + '*' + CAST(@n_UnitCount AS NVARCHAR), Subset) > 0 
          
                   SET @n_UnitCount = @n_UnitCount - 1
                END
             END -- IF @n_Count > 0
             ELSE
             BEGIN
                DELETE FROM #CombinationPool WITH (ROWLOCK)
                WHERE CHARINDEX(FORMAT(@n_Num,'0.######') + '*', Subset) > 0       
             END -- IF @n_Count <= 0
          
             FETCH NEXT FROM CURSOR_SPLITLIST INTO @n_Num, @n_UnitNeeded
          END -- CURSOR_SPLITLIST    
          CLOSE CURSOR_SPLITLIST          
          DEALLOCATE CURSOR_SPLITLIST     
          */      
       END
    END                  
    
    IF @c_IncludeKeyField = 'Y'
    BEGIN
       SELECT NP.KeyField, SL.Num, SL.UnitCount 
       FROM #SplitList SL    
       LEFT JOIN #NumPool NP ON SL.RowID = NP.RowID     
       ORDER BY NP.RowID  
    END
    ELSE
    BEGIN    
       SELECT '', SL.Num, SL.UnitCount 
       FROM #SplitList SL   
       LEFT JOIN #NumPool NP ON SL.Num = NP.Num
       ORDER BY NP.RowID
    END
        
    IF OBJECT_ID('tempdb..#NumPool','u') IS NOT NULL
       DROP TABLE #NumPool;                               

    IF OBJECT_ID('tempdb..#CombinationPool','u') IS NOT NULL
       DROP TABLE #CombinationPool;

    IF OBJECT_ID('tempdb..#SplitList','u') IS NOT NULL
       DROP TABLE #SplitList;          
END

GO
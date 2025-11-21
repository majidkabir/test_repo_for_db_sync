SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store Procedure: isp_StockTake_ExtendedValidation                    */
/* Creation Date:                                                       */
/* Copyright: LF                                                        */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: WMS-13685 Stock Take Extended Validation                    */
/*                                                                      */
/* Called By: ispFinalizeStkTakeCount                                   */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/************************************************************************/
CREATE PROC [dbo].[isp_StockTake_ExtendedValidation] 
   @cStockTakeKey   NVARCHAR(10),
   @nCountNo INT, 
   @cCCValidationRules NVARCHAR(30), 
   @nSuccess   int = 1      OUTPUT, 
   @cErrorMsg  NVARCHAR(250) OUTPUT 
AS 
DECLARE @bInValid bit 

DECLARE @cTableName   NVARCHAR(30), 
        @cDescription NVARCHAR(250), 
        @cColumnName  NVARCHAR(250),
        @cRecFound    int, 
        @cCondition   NVARCHAR(1000), 
        @cType        NVARCHAR(10),
        @cColName     NVARCHAR(128), 
        @cColType     NVARCHAR(128),
        @cWhereCondition NVARCHAR(1000),
        @cCCDetailKey NVARCHAR(10),
        @cSPName      NVARCHAR(100),
        @nErr         INT,
        @n_pos        INT,  
        @n_pos2       INT,  
        @n_pos3       INT,  
        @n_finalpos   INT,  
        @n_opencnt    INT,  
        @n_closecnt   INT,
        @c_CountNo    NVARCHAR(1),
        @c_Storerkey  NVARCHAR(15)  
        
DECLARE @cSQL nvarchar(Max),
        @cSQLArg nvarchar(max) 

DECLARE @n_GroupBy  INT
      , @c_GroupBy  NVARCHAR(MAX)

SET @bInValid = 0
SET @cErrorMsg = ''
SELECT @c_CountNo = LTRIM(RTRIM(CAST(@nCountNo AS NVARCHAR)))

SELECT @c_Storerkey = Storerkey
FROM STOCKTAKESHEETPARAMETERS (NOLOCK)
WHERE StockTakeKey = @cStockTakekey

IF NOT EXISTS(SELECT 1 FROM STORER(NOLOCK) WHERE Storerkey = @c_Storerkey) --could be multi storerkey list
BEGIN
	 SET @c_Storerkey = ''
END

DECLARE CUR_CC_REQUIRED CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
SELECT Code, Description, Long, ISNULL(Notes2,'') 
FROM   CODELKUP WITH (NOLOCK)
WHERE  ListName = @cCCValidationRules
AND    SHORT    = 'REQUIRED'
AND    CHARINDEX(@c_CountNo, UDF01) > 0
AND    Storerkey = CASE WHEN @c_Storerkey <> '' AND ISNULL(Storerkey,'') <> '' THEN @c_Storerkey ELSE Storerkey END
ORDER BY Code

OPEN CUR_CC_REQUIRED

FETCH NEXT FROM CUR_CC_REQUIRED INTO @cTableName, @cDescription, @cColumnName, @cWhereCondition 

WHILE @@FETCH_STATUS <> -1
BEGIN
   SET @cRecFound = 0 
   
   SET @cSQL = N'SELECT @cRecFound = COUNT(1), @cCCdetailkey = MIN(CCDETAIL.CCDetailkey) '
               +'FROM STOCKTAKESHEETPARAMETERS (NOLOCK) '
               +'JOIN CCDETAIL WITH (NOLOCK) ON STOCKTAKESHEETPARAMETERS.StockTakeKey = CCDETAIL.CCKey '
               +'LEFT JOIN LOTATTRIBUTE WITH (NOLOCK) ON CCDETAIL.Lot = LOTATTRIBUTE.Lot '
               +'LEFT JOIN STORER WITH (NOLOCK) ON CCDETAIL.Storerkey = STORER.Storerkey '
               +'LEFT JOIN SKU WITH (NOLOCK) ON CCDETAIL.Storerkey = SKU.Storerkey AND CCDETAIL.Sku = SKU.Sku '
               +'LEFT JOIN LOT WITH (NOLOCK) ON CCDETAIL.Lot = LOT.Lot '
               +'JOIN LOC WITH (NOLOCK) ON CCDETAIL.Loc = LOC.Loc '
               +'LEFT JOIN ID WITH (NOLOCK) ON CCDETAIL.ID = ID.Id '
               +'WHERE STOCKTAKESHEETPARAMETERS.StockTakekey = @cStockTakeKey '
       
   -- Get Column Type
   SET @cTableName = LEFT(@cColumnName, CharIndex('.', @cColumnName) - 1)
   SET @cColName   = SUBSTRING(@cColumnName, 
                     CharIndex('.', @cColumnName) + 1, LEN(@cColumnName) - CharIndex('.', @cColumnName))

   SET @cColType = ''
   SELECT @cColType = DATA_TYPE 
   FROM   INFORMATION_SCHEMA.COLUMNS 
   WHERE  TABLE_NAME = @cTableName
   AND    COLUMN_NAME = @cColName

   IF ISNULL(RTRIM(@cColType), '') = '' 
   BEGIN
      SET @bInValid = 1 
      SET @cErrorMsg = 'Invalid Column Name: ' + @cColumnName 
      GOTO QUIT
   END 

   IF @cColType IN ('char', 'nvarchar', 'varchar') 
      SET @cSQL = @cSQL + master.dbo.fnc_GetCharASCII(13) + ' AND ISNULL(RTRIM(' + @cColumnName + '),'''') = '''' '
   ELSE IF @cColType IN ('float', 'money', 'int', 'decimal', 'numeric', 'tinyint', 'real', 'bigint')
      SET @cSQL = @cSQL + master.dbo.fnc_GetCharASCII(13) + ' AND ' + @cColumnName + ' = 0 '

   SET @cSQL = @cSQL + master.dbo.fnc_GetCharASCII(13) + CASE WHEN LEFT(LTRIM(@cWhereCondition),3) NOT IN ('AND','OR ') AND ISNULL(@cWhereCondition,'') <> '' THEN ' AND ' ELSE ' ' END + RTRIM(@cWhereCondition) --+ ')'       
  
   SET @cSQLArg = N'@cRecFound int OUTPUT, '
                  +'@cCCDetailkey NVARCHAR(10) OUTPUT, '
                  +'@cStockTakeKey NVARCHAR(10) '

   EXEC sp_executesql @cSQL, @cSQLArg, @cRecFound OUTPUT, @cCCDetailKey OUTPUT, @cStockTakeKey 

   IF @cRecFound > 0  
   BEGIN 
      SET @bInValid = 1 
      IF @cTableName IN ('CCDETAIL','SKU','LOT','LOC','ID','LOTATTRIBUTE')
         SET @cErrorMsg = RTRIM(@cErrorMsg) + 'CCDetail# ' + RTRIM(@cCCDetailKey) + '. ' + RTRIM(@cDescription) + ' Is Required! ' + master.dbo.fnc_GetCharASCII(13)
      ELSE
         SET @cErrorMsg = RTRIM(@cErrorMsg) + RTRIM(@cDescription) + ' Is Required! ' + master.dbo.fnc_GetCharASCII(13)
   END 

   FETCH NEXT FROM CUR_CC_REQUIRED INTO @cTableName, @cDescription, @cColumnName, @cWhereCondition  
END 
CLOSE CUR_CC_REQUIRED
DEALLOCATE CUR_CC_REQUIRED 

IF @bInValid = 1
   GOTO QUIT

----------- Check Condition ------

SET @bInValid = 0 

DECLARE CUR_CC_CONDITION CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
SELECT Code, Description, Long, Notes, SHORT, ISNULL(Notes2,'')   
FROM   CODELKUP WITH (NOLOCK)
WHERE  ListName = @cCCValidationRules
AND    SHORT    IN ('CONDITION', 'CONTAINS')
AND    CHARINDEX(@c_CountNo, UDF01) > 0
AND    Storerkey = CASE WHEN @c_Storerkey <> '' AND ISNULL(Storerkey,'') <> '' THEN @c_Storerkey ELSE Storerkey END

OPEN CUR_CC_CONDITION

FETCH NEXT FROM CUR_CC_CONDITION INTO @cTableName, @cDescription, @cColumnName, @cCondition, @cType, @cWhereCondition   

WHILE @@FETCH_STATUS <> -1
BEGIN
   SET @cRecFound = 0   

   SET @cSQL = N'SELECT @cRecFound = COUNT(1), @cCCdetailkey = MIN(CCDETAIL.CCDetailkey) '
               +'FROM STOCKTAKESHEETPARAMETERS (NOLOCK) '
               +'JOIN CCDETAIL WITH (NOLOCK) ON STOCKTAKESHEETPARAMETERS.StockTakeKey = CCDETAIL.CCKey '
               +'LEFT JOIN LOTATTRIBUTE WITH (NOLOCK) ON CCDETAIL.Lot = LOTATTRIBUTE.Lot '
               +'LEFT JOIN STORER WITH (NOLOCK) ON CCDETAIL.Storerkey = STORER.Storerkey '
               +'LEFT JOIN SKU WITH (NOLOCK) ON CCDETAIL.Storerkey = SKU.Storerkey AND CCDETAIL.Sku = SKU.Sku '
               +'LEFT JOIN LOT WITH (NOLOCK) ON CCDETAIL.Lot = LOT.Lot '
               +'JOIN LOC WITH (NOLOCK) ON CCDETAIL.Loc = LOC.Loc '
               +'LEFT JOIN ID WITH (NOLOCK) ON CCDETAIL.ID = ID.Id '
               +'WHERE STOCKTAKESHEETPARAMETERS.StockTakekey = @cStockTakeKey '

   IF @cType = 'CONDITION'
     IF ISNULL(@cCondition,'') <> ''
     BEGIN     	  
     	    SET @n_GroupBy = 0     	    
     	    SET @n_finalpos = 0
 	        SET @n_closecnt = 0
     	    SET @n_opencnt = 0

     	    SET @n_pos = CHARINDEX('GROUP BY',@cCondition,1)
     	    
     	    --find the last group by
     	    WHILE @n_pos > 0
     	    BEGIN
     	    	  SET @n_finalpos = @n_pos
     	    
     	        SET @n_pos = CHARINDEX('GROUP BY',@cCondition, @n_pos + 8)
     	    END
     	    
     	    IF @n_finalpos > 0
     	    BEGIN
     	       SET @n_pos2 = CHARINDEX('(',@cCondition,@n_finalpos)
     	       
     	       --find no of open bracket after group by
     	       WHILE @n_pos2 > 0
     	       BEGIN
     	          SET @n_opencnt = @n_opencnt + 1
     	       
     	          SET @n_pos2 = CHARINDEX('(',@cCondition, @n_pos2 + 1)
     	       END
            
     	       SET @n_pos3 = CHARINDEX(')',@cCondition,@n_finalpos)
     	       
     	       --find no of close bracket after group by
     	       WHILE @n_pos3 > 0
     	       BEGIN
     	       	   SET @n_closecnt = @n_closecnt + 1
     	       
     	           SET @n_pos3 = CHARINDEX(')',@cCondition, @n_pos3 + 1)
     	       END
     	      
     	       IF @n_opencnt = @n_closecnt  --if open & close bracket is tally mean the group by is not from sub-query.
                SET @n_GroupBy = @n_finalpos                                 
         END     
     	   
         SET @c_GroupBy = ''
         --SET @n_GroupBy = CHARINDEX('GROUP BY',@cCondition,1)
         IF  @n_GroupBy > 0 
         BEGIN         	 
            SET @c_GroupBy  = SUBSTRING(@cCondition,@n_GroupBy,LEN(@cCondition)-@n_GroupBy+1)            
            SET @cCondition = SUBSTRING(@cCondition,1,@n_GroupBy  - 1)
         END

         SET @cCondition = REPLACE(LEFT(@cCondition,5),'AND ','AND (') + SUBSTRING(@cCondition,6,LEN(@cCondition)-5)
         SET @cCondition = REPLACE(LEFT(@cCondition,4),'OR ','OR (') + SUBSTRING(@cCondition,5,LEN(@cCondition)-4)
         SET @cSQL = @cSQL + master.dbo.fnc_GetCharASCII(13) + CASE WHEN LEFT(LTRIM(@cCondition),3) NOT IN ('AND','OR ') AND ISNULL(@cCondition,'') <> '' THEN ' AND (' ELSE ' ' END + RTRIM(@cCondition)
         SET @cSQL = @cSQL + master.dbo.fnc_GetCharASCII(13) + CASE WHEN LEFT(LTRIM(@cWhereCondition),3) NOT IN ('AND','OR ') AND ISNULL(@cWhereCondition,'') <> '' THEN ' AND ' ELSE ' ' END + RTRIM(@cWhereCondition) + ')'

         SET @cSQL = @cSQL + @c_GroupBy
      END 
      ELSE
      BEGIN
          IF ISNULL(@cWhereCondition,'') <> ''
          BEGIN
            SET @cWhereCondition = REPLACE(LEFT(@cWhereCondition,5),'AND ','AND (') + SUBSTRING(@cWhereCondition,6,LEN(@cWhereCondition)-5)
            SET @cWhereCondition = REPLACE(LEFT(@cWhereCondition,4),'OR ','OR (') + SUBSTRING(@cWhereCondition,5,LEN(@cWhereCondition)-4)
           SET @cSQL = @cSQL + master.dbo.fnc_GetCharASCII(13) + CASE WHEN LEFT(LTRIM(@cWhereCondition),3) NOT IN ('AND','OR ') AND ISNULL(@cWhereCondition,'') <> '' THEN ' AND (' ELSE ' ' END + RTRIM(@cWhereCondition) + ')'
         END
      END
      --SET @cSQL = @cSQL + master.dbo.fnc_GetCharASCII(13) + ' ' + @cCondition 
   ELSE
   BEGIN --CONTAINS   	
      SET @c_GroupBy = ''
      IF ISNULL(@cWhereCondition,'') <> '' 
      BEGIN
     	   SET @n_GroupBy = 0     	    
     	   SET @n_finalpos = 0
 	       SET @n_closecnt = 0
     	   SET @n_opencnt = 0
         
     	   SET @n_pos = CHARINDEX('GROUP BY',@cWhereCondition,1)
     	   
     	   WHILE @n_pos > 0
     	   BEGIN
     	   	  SET @n_finalpos = @n_pos
     	   
     	      SET @n_pos = CHARINDEX('GROUP BY',@cWhereCondition, @n_pos + 8)
     	   END
     	   
     	   IF @n_finalpos > 0
     	   BEGIN
     	      SET @n_pos2 = CHARINDEX('(',@cWhereCondition,@n_finalpos)
     	      
     	      WHILE @n_pos2 > 0
     	      BEGIN
     	         SET @n_opencnt = @n_opencnt + 1
     	      
     	         SET @n_pos2 = CHARINDEX('(',@cWhereCondition, @n_pos2 + 1)
     	      END
           
     	      SET @n_pos3 = CHARINDEX(')',@cWhereCondition,@n_finalpos)
     	      
     	      WHILE @n_pos3 > 0
     	      BEGIN
     	      	   SET @n_closecnt = @n_closecnt + 1
     	      
     	          SET @n_pos3 = CHARINDEX(')',@cWhereCondition, @n_pos3 + 1)
     	      END
     	     
     	      IF @n_opencnt = @n_closecnt
               SET @n_GroupBy = @n_finalpos                                 
         END     
      	
         --SET @n_GroupBy = CHARINDEX('GROUP BY',@cWhereCondition,1)
         IF  @n_GroupBy > 0  
         BEGIN
            SET @c_GroupBy  = SUBSTRING(@cWhereCondition,@n_GroupBy,LEN(@cWhereCondition)-@n_GroupBy+1)
            SET @cWhereCondition = SUBSTRING(@cWhereCondition,1,@n_GroupBy-1)
         END
      END

      IF ISNULL(@cCondition,'') <> ''
        BEGIN
         SET @cSQL = @cSQL + master.dbo.fnc_GetCharASCII(13) + ' AND (' + @cColumnName + ' IN (' + ISNULL(RTRIM(@cCondition),'') + ')' 
         SET @cSQL = @cSQL + master.dbo.fnc_GetCharASCII(13) + CASE WHEN LEFT(LTRIM(@cWhereCondition),3) NOT IN ('AND','OR ') AND ISNULL(@cWhereCondition,'') <> '' THEN ' AND ' ELSE ' ' END + RTRIM(@cWhereCondition) + ')'
      END
      ELSE
      BEGIN
          IF ISNULL(@cWhereCondition,'') <> ''
          BEGIN
            SET @cWhereCondition = REPLACE(LEFT(@cWhereCondition,5),'AND ','AND (') + SUBSTRING(@cWhereCondition,6,LEN(@cWhereCondition)-5)
            SET @cWhereCondition = REPLACE(LEFT(@cWhereCondition,4),'OR ','OR (') + SUBSTRING(@cWhereCondition,5,LEN(@cWhereCondition)-4)
           SET @cSQL = @cSQL + master.dbo.fnc_GetCharASCII(13) + CASE WHEN LEFT(LTRIM(@cWhereCondition),3) NOT IN ('AND','OR ') AND ISNULL(@cWhereCondition,'') <> '' THEN ' AND (' ELSE ' ' END + RTRIM(@cWhereCondition) + ')'
         END
      END  

      SET @cSQL = @cSQL + @c_GroupBy
                 
      -- Shong002 Bug Fixed
      --SET @cSQL = @cSQL + master.dbo.fnc_GetCharASCII(13) + ' AND ' + @cColumnName + ' IN (' + ISNULL(RTRIM(@cCondition),'') + ')' 
   END 
  
   SET @cSQLArg = N'@cRecFound int OUTPUT, '
                  +'@cCCDetailkey nvarchar(10) OUTPUT, '
                  +'@cStockTakeKey   NVARCHAR(10) '

   EXEC sp_executesql @cSQL, @cSQLArg, @cRecFound OUTPUT, @cCCDetailKey OUTPUT,@cStockTakekey

   IF @cRecFound = 0 AND @cType <> 'CONDITION'
   BEGIN 
      SET @bInValid = 1 
      SET @cErrorMsg = @cErrorMsg + RTRIM(@cDescription) + ' Is Invalid! ' + master.dbo.fnc_GetCharASCII(13)
   END 
   ELSE
   IF @cRecFound > 0 AND @cType = 'CONDITION' AND @cColumnName = 'NOT EXISTS' 
   BEGIN 
      SET @bInValid = 1 
      IF CharIndex('CCDETAIL', @cCondition) > 0 OR CharIndex('SKU', @cCondition) > 0  
         OR CharIndex('LOT', @cCondition) > 0 OR CharIndex('LOC', @cCondition) > 0 OR CharIndex('ID', @cCondition) > 0
         OR CharIndex('LOTATTRIBUTE', @cCondition) > 0
         SET @cErrorMsg = @cErrorMsg + 'CCDetail# ' + RTRIM(@cCCDetailkey) + '. ' + RTRIM(@cDescription) + ' Found! ' + master.dbo.fnc_GetCharASCII(13)
      ELSE
         SET @cErrorMsg = @cErrorMsg + RTRIM(@cDescription) + ' Found! ' + master.dbo.fnc_GetCharASCII(13)
   END 
   ELSE
   IF @cRecFound = 0 AND @cType = 'CONDITION' AND 
      (ISNULL(RTRIM(@cColumnName),'') = '' OR @cColumnName = 'EXISTS')  
   BEGIN 
      SET @bInValid = 1 
      SET @cErrorMsg = @cErrorMsg + RTRIM(@cDescription) + ' Not Found! ' + master.dbo.fnc_GetCharASCII(13)
   END 
   
   /*IF @cRecFound = 0 
   BEGIN 
      SET @bInValid = 1 
      SET @cErrorMsg = @cErrorMsg + @cDescription + ' Is Invalid! ' + master.dbo.fnc_GetCharASCII(13)
   END*/ 

   FETCH NEXT FROM CUR_CC_CONDITION INTO @cTableName, @cDescription, @cColumnName, @cCondition, @cType, @cWhereCondition  
END 
CLOSE CUR_CC_CONDITION
DEALLOCATE CUR_CC_CONDITION 

DECLARE CUR_CC_SPCONDITION CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
SELECT Code, Description, Long 
FROM   CODELKUP WITH (NOLOCK)
WHERE  ListName = @cCCValidationRules
AND    SHORT    = 'STOREDPROC'
AND    Storerkey = CASE WHEN @c_Storerkey <> '' AND ISNULL(Storerkey,'') <> '' THEN @c_Storerkey ELSE Storerkey END

OPEN CUR_CC_SPCONDITION

FETCH NEXT FROM CUR_CC_SPCONDITION INTO @cTableName, @cDescription, @cSPName 

WHILE @@FETCH_STATUS <> -1
BEGIN
   IF EXISTS (SELECT 1 FROM dbo.sysobjects WHERE name = RTRIM(@cSPName) AND type = 'P')  
   BEGIN      
      SET @cSQL = 'EXEC ' + @cSPName + ' @c_StockTakeKey, @n_Count, @b_Success OUTPUT, @n_ErrNo OUTPUT, @c_ErrorMsg OUTPUT '      
   
      EXEC sp_executesql @cSQL     
         , N'@c_StockTakeKey NVARCHAR(10), @n_CountNo INT, @b_Success Int OUTPUT, @n_ErrNo Int OUTPUT, @c_ErrorMsg NVARCHAR(250) OUTPUT'      
         , @cStockTakekey
         , @nCountNo      
         , @nSuccess    OUTPUT      
         , @nErr       OUTPUT      
         , @cErrorMsg    OUTPUT    

      IF @nSuccess <> 1
      BEGIN 
         SET @bInValid = 1      
         CLOSE CUR_CC_SPCONDITION
         DEALLOCATE CUR_CC_SPCONDITION 
         GOTO QUIT
      END 

   END 
   FETCH NEXT FROM CUR_CC_SPCONDITION INTO @cTableName, @cDescription, @cSPName
END 
CLOSE CUR_CC_SPCONDITION
DEALLOCATE CUR_CC_SPCONDITION 

--PRINT @cSQL
--PRINT ''
--PRINT @cErrorMsg

QUIT:
IF @bInValid = 1 
   SET @nSuccess = 0 
ELSE
   SET @nSuccess = 1

-- End Procedure

GO
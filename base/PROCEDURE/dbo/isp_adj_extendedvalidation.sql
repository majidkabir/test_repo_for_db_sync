SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Store Procedure: isp_ADJ_ExtendedValidation                          */  
/* Creation Date:                                                       */  
/* Copyright: LF                                                        */  
/* Written by:                                                          */  
/*                                                                      */  
/* Purpose: Adjustment Extended Validation SOS#311354                   */  
/*                                                                      */  
/* Called By: ispFinalizeADJ                                            */  
/*                                                                      */  
/* PVCS Version: 1.2                                                    */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author    Ver.  Purposes                                */  
/* 24-Nov-2014  NJOW01    1.0   325985-Include lot,loc,id,storer tables */  
/* 10-Feb-2015  NJOW02    1.1   332710-Add lotattribute table AND left  */  
/*                              join                                    */  
/* 06-MAR-2015  YTWan     1.1   SOS#332710 - CR ANF adjustment (both UCC*/  
/*                              adjustment & Inventory adjustment)(Wan01)*/  
/* 19-Jul-2017  JayLim    1.2   Performance tune-reduce cache log (jay01)*/  
/* 11-Feb-2020  NJOW03    1.3   Fix group by                            */  
/* 26-Mar-2020  LZG       1.4   INC1091347-Cater for HAVING clause(ZG01)*/
/************************************************************************/  
CREATE PROC [dbo].[isp_ADJ_ExtendedValidation]   
   @cAdjustmentKey   NVARCHAR(10),   
   @cADJValidationRules NVARCHAR(30),   
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
        @cWhereCondition        NVARCHAR(1000),  
        @cAdjustmentLineNumber  NVARCHAR(5),  
        @cSPName               NVARCHAR(100),  
        @nErr         INT,  
        @n_pos        INT,  --NJOW03  
        @n_pos2       INT,  --NJOW03  
        @n_pos3       INT,  --NJOW03  
        @n_finalpos   INT,  --NJOW03  
        @n_opencnt    INT,  --NJOW03  
        @n_closecnt   INT   --NJOW03  
          
DECLARE @cSQL nvarchar(Max),  
        @cSQLArg nvarchar(max) --(jay01)  
  
--(Wan01) - (START)  
DECLARE @n_GroupBy  INT  
      , @c_GroupBy  NVARCHAR(MAX)  
--(Wan01) - (END)  
  
SET @bInValid = 0  
SET @cErrorMsg = ''  
  
DECLARE CUR_ADJ_REQUIRED CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
SELECT Code, Description, Long, ISNULL(Notes2,'')   
FROM   CODELKUP WITH (NOLOCK)  
WHERE  ListName = @cADJValidationRules  
AND    SHORT    = 'REQUIRED'  
ORDER BY Code  
  
OPEN CUR_ADJ_REQUIRED  
  
FETCH NEXT FROM CUR_ADJ_REQUIRED INTO @cTableName, @cDescription, @cColumnName, @cWhereCondition   
  
WHILE @@FETCH_STATUS <> -1  
BEGIN  
   SET @cRecFound = 0   
   --(jay01)  
   SET @cSQL = N'SELECT @cRecFound = COUNT(1), @cAdjustmentLineNumber = MIN(ADJUSTMENTDETAIL.AdjustmentLineNumber) '  
               +'FROM ADJUSTMENT (NOLOCK) '  
               +'JOIN ADJUSTMENTDETAIL WITH (NOLOCK) ON ADJUSTMENT.AdjustmentKey = ADJUSTMENTDETAIL.AdjustmentKey '  
               +'JOIN STORER WITH (NOLOCK) ON ADJUSTMENTDETAIL.Storerkey = STORER.Storerkey  '  
               +'JOIN SKU WITH (NOLOCK) ON ADJUSTMENTDETAIL.Storerkey = SKU.Storerkey AND ADJUSTMENTDETAIL.Sku = SKU.Sku '  
               +'LEFT JOIN LOT WITH (NOLOCK) ON ADJUSTMENTDETAIL.Lot = LOT.Lot '  
               +'JOIN LOC WITH (NOLOCK) ON ADJUSTMENTDETAIL.Loc = LOC.Loc  '  
               +'LEFT JOIN ID WITH (NOLOCK) ON ADJUSTMENTDETAIL.ID = ID.Id  '  
               +'LEFT JOIN LOTATTRIBUTE (NOLOCK) ON ADJUSTMENTDETAIL.Lot = LOTATTRIBUTE.Lot '  
               +'WHERE ADJUSTMENT.AdjustmentKey= @cAdjustmentKey  '  
         
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
    
   --(jay01)  
   SET @cSQLArg = N'@cRecFound int OUTPUT, '  
                  +'@cAdjustmentLineNumber nvarchar(5) OUTPUT, '  
                  +'@cAdjustmentKey   NVARCHAR(10) '  
  
   EXEC sp_executesql @cSQL, @cSQLArg, @cRecFound OUTPUT, @cAdjustmentLineNumber OUTPUT, @cAdjustmentKey --(jay01)  
  
   IF @cRecFound > 0    
   BEGIN   
      SET @bInValid = 1   
      IF @cTableName IN ('ADJUSTMENTDETAIL','SKU','LOT','LOC','ID','LOTATTRIBUTE')  
         SET @cErrorMsg = RTRIM(@cErrorMsg) + 'Line# ' + RTRIM(@cAdjustmentLineNumber) + '. ' + RTRIM(@cDescription) + ' Is Required! ' + master.dbo.fnc_GetCharASCII(13)  
      ELSE  
         SET @cErrorMsg = RTRIM(@cErrorMsg) + RTRIM(@cDescription) + ' Is Required! ' + master.dbo.fnc_GetCharASCII(13)  
   END   
  
   FETCH NEXT FROM CUR_ADJ_REQUIRED INTO @cTableName, @cDescription, @cColumnName, @cWhereCondition    
END   
CLOSE CUR_ADJ_REQUIRED  
DEALLOCATE CUR_ADJ_REQUIRED   
  
IF @bInValid = 1  
   GOTO QUIT  
  
----------- Check Condition ------  
  
SET @bInValid = 0   
  
DECLARE CUR_ADJ_CONDITION CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
SELECT Code, Description, Long, Notes, SHORT, ISNULL(Notes2,'')     
FROM   CODELKUP WITH (NOLOCK)  
WHERE  ListName = @cADJValidationRules  
AND    SHORT    IN ('CONDITION', 'CONTAINS')  
  
OPEN CUR_ADJ_CONDITION  
  
FETCH NEXT FROM CUR_ADJ_CONDITION INTO @cTableName, @cDescription, @cColumnName, @cCondition, @cType, @cWhereCondition     
  
WHILE @@FETCH_STATUS <> -1  
BEGIN  
   SET @cRecFound = 0   --(Wan01)  
  
   --(jay01)  
   SET @cSQL = N'SELECT @cRecFound = COUNT(1), @cAdjustmentLineNumber = MIN(ADJUSTMENTDETAIL.AdjustmentLineNumber) FROM ADJUSTMENT (NOLOCK) '  
               +'JOIN ADJUSTMENTDETAIL WITH (NOLOCK) ON ADJUSTMENT.AdjustmentKey = ADJUSTMENTDETAIL.AdjustmentKey '  
               +'JOIN STORER WITH (NOLOCK) ON ADJUSTMENTDETAIL.Storerkey = STORER.Storerkey  '  
               +'JOIN SKU WITH (NOLOCK) ON ADJUSTMENTDETAIL.Storerkey = SKU.Storerkey AND ADJUSTMENTDETAIL.Sku = SKU.Sku '  
               +'LEFT JOIN LOT WITH (NOLOCK) ON ADJUSTMENTDETAIL.Lot = LOT.Lot '  
               +'JOIN LOC WITH (NOLOCK) ON ADJUSTMENTDETAIL.Loc = LOC.Loc  '  
               +'LEFT JOIN ID WITH (NOLOCK) ON ADJUSTMENTDETAIL.ID = ID.Id '  
               +'LEFT JOIN LOTATTRIBUTE (NOLOCK) ON ADJUSTMENTDETAIL.Lot = LOTATTRIBUTE.Lot '  
            +'WHERE ADJUSTMENT.AdjustmentKey= @cAdjustmentKey '  
  
   IF @cType = 'CONDITION'  
     IF ISNULL(@cCondition,'') <> ''  
     BEGIN          
          --NJOW03           
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
         --NJOW03  
           
         --(Wan01) - START   
         SET @c_GroupBy = '' 
         
         IF (CHARINDEX('HAVING EXISTS',@cCondition,1) < @n_finalpos AND CHARINDEX('HAVING EXISTS',@cCondition,1) > 0) -- ZG01
            SET @n_GroupBy = CHARINDEX('GROUP BY',@cCondition,1)                                                      -- ZG01

         --SET @n_GroupBy = CHARINDEX('GROUP BY',@cCondition,1)  
         IF  @n_GroupBy > 0   
         BEGIN             
            SET @c_GroupBy  = SUBSTRING(@cCondition,@n_GroupBy,LEN(@cCondition)-@n_GroupBy+1)              
            SET @cCondition = SUBSTRING(@cCondition,1,@n_GroupBy  - 1)  
         END  
         --(Wan01) - END  
  
         SET @cCondition = REPLACE(LEFT(@cCondition,5),'AND ','AND (') + SUBSTRING(@cCondition,6,LEN(@cCondition)-5)  
         SET @cCondition = REPLACE(LEFT(@cCondition,4),'OR ','OR (') + SUBSTRING(@cCondition,5,LEN(@cCondition)-4)  
         SET @cSQL = @cSQL + master.dbo.fnc_GetCharASCII(13) + CASE WHEN LEFT(LTRIM(@cCondition),3) NOT IN ('AND','OR ') AND ISNULL(@cCondition,'') <> '' THEN ' AND (' ELSE ' ' END + RTRIM(@cCondition)  
         SET @cSQL = @cSQL + master.dbo.fnc_GetCharASCII(13) + CASE WHEN LEFT(LTRIM(@cWhereCondition),3) NOT IN ('AND','OR ') AND ISNULL(@cWhereCondition,'') <> '' THEN ' AND ' ELSE ' ' END + RTRIM(@cWhereCondition) + ')'  
  
         --(Wan01) - START  
         SET @cSQL = @cSQL + @c_GroupBy  
         --(Wan01) - END   
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
          --(Wan01) - START  
      SET @c_GroupBy = ''  
      IF ISNULL(@cWhereCondition,'') <> ''   
      BEGIN  
         --NJOW03           
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
         --NJOW03  
         
         --SET @n_GroupBy = CHARINDEX('GROUP BY',@cWhereCondition,1)  
         IF  @n_GroupBy > 0    
         BEGIN  
            SET @c_GroupBy  = SUBSTRING(@cWhereCondition,@n_GroupBy,LEN(@cWhereCondition)-@n_GroupBy+1)  
            SET @cWhereCondition = SUBSTRING(@cWhereCondition,1,@n_GroupBy-1)  
         END  
      END  
      --(Wan01) - END  
  
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
      --(Wan01) - START  
      SET @cSQL = @cSQL + @c_GroupBy  
      --(Wan01) - END   
                   
      -- Shong002 Bug Fixed  
      --SET @cSQL = @cSQL + master.dbo.fnc_GetCharASCII(13) + ' AND ' + @cColumnName + ' IN (' + ISNULL(RTRIM(@cCondition),'') + ')'   
   END   
    
   --(jay01)  
   SET @cSQLArg = N'@cRecFound int OUTPUT, '  
                  +'@cAdjustmentLineNumber nvarchar(5) OUTPUT, '  
                  +'@cAdjustmentKey   NVARCHAR(10) '  
  
   EXEC sp_executesql @cSQL, @cSQLArg, @cRecFound OUTPUT, @cAdjustmentLineNumber OUTPUT,@cAdjustmentKey --(jay01)  
  
   IF @cRecFound = 0 AND @cType <> 'CONDITION'  
   BEGIN   
      SET @bInValid = 1   
      SET @cErrorMsg = @cErrorMsg + RTRIM(@cDescription) + ' Is Invalid! ' + master.dbo.fnc_GetCharASCII(13)  
   END   
   ELSE  
   IF @cRecFound > 0 AND @cType = 'CONDITION' AND @cColumnName = 'NOT EXISTS'   
   BEGIN   
      SET @bInValid = 1   
      IF CharIndex('ADJUSTMENTDETAIL', @cCondition) > 0 OR CharIndex('SKU', @cCondition) > 0    
         OR CharIndex('LOT', @cCondition) > 0 OR CharIndex('LOC', @cCondition) > 0 OR CharIndex('ID', @cCondition) > 0  
         OR CharIndex('LOTATTRIBUTE', @cCondition) > 0  
         SET @cErrorMsg = @cErrorMsg + 'Line# ' + RTRIM(@cAdjustmentLineNumber) + '. ' + RTRIM(@cDescription) + ' Found! ' + master.dbo.fnc_GetCharASCII(13)  
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
  
   FETCH NEXT FROM CUR_ADJ_CONDITION INTO @cTableName, @cDescription, @cColumnName, @cCondition, @cType, @cWhereCondition    
END   
CLOSE CUR_ADJ_CONDITION  
DEALLOCATE CUR_ADJ_CONDITION   
  
DECLARE CUR_ADJ_SPCONDITION CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
SELECT Code, Description, Long   
FROM   CODELKUP WITH (NOLOCK)  
WHERE  ListName = @cADJValidationRules  
AND    SHORT    = 'STOREDPROC'  
  
OPEN CUR_ADJ_SPCONDITION  
  
FETCH NEXT FROM CUR_ADJ_SPCONDITION INTO @cTableName, @cDescription, @cSPName   
  
WHILE @@FETCH_STATUS <> -1  
BEGIN  
   IF EXISTS (SELECT 1 FROM dbo.sysobjects WHERE name = RTRIM(@cSPName) AND type = 'P')    
   BEGIN        
      SET @cSQL = 'EXEC ' + @cSPName + ' @c_AdjustmentKey, @b_Success OUTPUT, @n_ErrNo OUTPUT, @c_ErrorMsg OUTPUT '        
     
      EXEC sp_executesql @cSQL       
         , N'@c_AdjustmentKey NVARCHAR(10), @b_Success Int OUTPUT, @n_ErrNo Int OUTPUT, @c_ErrorMsg NVARCHAR(250) OUTPUT'        
         , @cAdjustmentKey        
         , @nSuccess    OUTPUT        
         , @nErr       OUTPUT        
         , @cErrorMsg    OUTPUT      
  
      IF @nSuccess <> 1  
      BEGIN   
         SET @bInValid = 1        
         CLOSE CUR_ADJ_SPCONDITION  
         DEALLOCATE CUR_ADJ_SPCONDITION   
         GOTO QUIT  
      END   
  
   END   
   FETCH NEXT FROM CUR_ADJ_SPCONDITION INTO @cTableName, @cDescription, @cSPName  
END   
CLOSE CUR_ADJ_SPCONDITION  
DEALLOCATE CUR_ADJ_SPCONDITION   
  
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
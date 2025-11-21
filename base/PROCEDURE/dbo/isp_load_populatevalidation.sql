SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store Procedure: isp_LOAD_PopulateValidation                         */
/* Creation Date:                                                       */
/* Copyright: LF                                                        */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: SOS#335011- Jack Wills MBOL match                           */
/*                                                                      */
/* Called By: ue_sendload at w_populate_load                            */
/*                           w_populate_load_manualorders               */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/************************************************************************/
CREATE PROC [dbo].[isp_LOAD_PopulateValidation] 
      @c_Loadkey        NVARCHAR(10)  
   ,  @c_Orderkeylist   NVARCHAR(MAX)
   ,  @b_Success        INT = 1        OUTPUT  
   ,  @c_ErrMsg         NVARCHAR(250)  OUTPUT 
AS 
DECLARE @b_InValid               BIT 
      , @n_Err                   INT

DECLARE @c_TableName             NVARCHAR(30) 
      , @c_Description           NVARCHAR(250) 
      , @c_ColumnName            NVARCHAR(250)
      , @c_RecFound              INT
      , @c_Condition             NVARCHAR(1000) 
      , @c_Type                  NVARCHAR(10)
      , @c_ColName               NVARCHAR(128) 
      , @c_ColType               NVARCHAR(128)
      , @c_WhereCondition        NVARCHAR(1000)
      , @c_SPName                NVARCHAR(100)

      , @c_SQL                   NVARCHAR(Max)
      , @n_GroupBy               INT
      , @c_GroupBy               NVARCHAR(MAX)      
 
      , @c_LoadValidationRules   NVARCHAR(30)
      , @c_Orderkey              NVARCHAR(10)

SET @b_InValid = 0
SET @c_ErrMsg = ''

SELECT DISTINCT @c_Loadkey AS Loadkey
     , ColValue AS Orderkey 
INTO #TMP_ORDERSLIST
FROM dbo.fnc_DelimSplit('|',@c_Orderkeylist) 
WHERE ISNULL(ColValue,'') <> ''

DECLARE CUR_VALID_RULE CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
SELECT DISTINCT CODELKUP.UDF01
FROM   #TMP_ORDERSLIST 
JOIN   ORDERS   WITH (NOLOCK) ON (#TMP_ORDERSLIST.Orderkey = ORDERS.Orderkey)
JOIN   CODELKUP WITH (NOLOCK) ON (ORDERS.Storerkey = CODELKUP.Storerkey)
WHERE  CODELKUP.ListName = 'VALDNCFG'
AND    CODELKUP.Code = 'LOADPopulateValidation'
AND    (CODELKUP.UDF01 <> '' OR CODELKUP.UDF01 IS NOT NULL)

OPEN CUR_VALID_RULE

FETCH NEXT FROM CUR_VALID_RULE INTO @c_LoadValidationRules 

WHILE @@FETCH_STATUS <> -1
BEGIN

   DECLARE CUR_LOAD_REQUIRED CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT Code, Description, Long, ISNULL(Notes2,'') 
   FROM   CODELKUP WITH (NOLOCK)
   WHERE  ListName = @c_LoadValidationRules
   AND    SHORT    = 'REQUIRED'
   ORDER BY Code

   OPEN CUR_LOAD_REQUIRED

   FETCH NEXT FROM CUR_LOAD_REQUIRED INTO @c_TableName, @c_Description, @c_ColumnName, @c_WhereCondition 

   WHILE @@FETCH_STATUS <> -1
   BEGIN
      SET @c_RecFound = 0 
      
      SET @c_SQL = N'SELECT @c_RecFound = COUNT(1), @c_Orderkey = MIN(ORDERS.Orderkey) 
       FROM LOADPLAN WITH (NOLOCK) 
       JOIN #TMP_ORDERSLIST ON LOADPLAN.Loadkey = #TMP_ORDERSLIST.Loadkey 
       JOIN ORDERS WITH (NOLOCK) ON #TMP_ORDERSLIST.Orderkey = ORDERS.Orderkey  
       WHERE LOADPLAN.Loadkey= N''' +  @c_Loadkey + ''' '
          
      -- Get Column Type
      SET @c_TableName = LEFT(@c_ColumnName, CharIndex('.', @c_ColumnName) - 1)
      SET @c_ColName   = SUBSTRING(@c_ColumnName, 
                        CharIndex('.', @c_ColumnName) + 1, LEN(@c_ColumnName) - CharIndex('.', @c_ColumnName))

      SET @c_ColType = ''
      SELECT @c_ColType = DATA_TYPE 
      FROM   INFORMATION_SCHEMA.COLUMNS 
      WHERE  TABLE_NAME = @c_TableName
      AND    COLUMN_NAME = @c_ColName

      IF ISNULL(RTRIM(@c_ColType), '') = '' 
      BEGIN
         SET @b_InValid = 1 
         SET @c_ErrMsg = 'Invalid Column Name: ' + @c_ColumnName 
         GOTO QUIT
      END 

      IF @c_ColType IN ('char', 'nvarchar', 'varchar') 
         SET @c_SQL = @c_SQL + master.dbo.fnc_GetCharASCII(13) + ' AND ISNULL(RTRIM(' + @c_ColumnName + '),'''') = '''' '
      ELSE IF @c_ColType IN ('float', 'money', 'int', 'decimal', 'numeric', 'tinyint', 'real', 'bigint')
         SET @c_SQL = @c_SQL + master.dbo.fnc_GetCharASCII(13) + ' AND ' + @c_ColumnName + ' = 0 '

      SET @c_SQL = @c_SQL + master.dbo.fnc_GetCharASCII(13) + CASE WHEN LEFT(LTRIM(@c_WhereCondition),3) NOT IN ('AND','OR ') AND ISNULL(@c_WhereCondition,'') <> '' THEN ' AND ' ELSE ' ' END + RTRIM(@c_WhereCondition) --+ ')'       
     
      EXEC sp_executesql @c_SQL, N'@c_RecFound int OUTPUT, @c_Orderkey NVARCHAR(10) OUTPUT', @c_RecFound OUTPUT, @c_Orderkey OUTPUT

      IF @c_RecFound > 0  
      BEGIN 
         SET @b_InValid = 1 
         IF @c_TableName IN ('LOADPLAN','ORDERS')
            SET @c_ErrMsg = RTRIM(@c_ErrMsg) + 'Order# ' + RTRIM(@c_Orderkey) + '. ' + RTRIM(@c_Description) + ' Is Required! ' + master.dbo.fnc_GetCharASCII(13)
         ELSE
            SET @c_ErrMsg = RTRIM(@c_ErrMsg) + RTRIM(@c_Description) + ' Is Required! ' + master.dbo.fnc_GetCharASCII(13)
      END 

      FETCH NEXT FROM CUR_LOAD_REQUIRED INTO @c_TableName, @c_Description, @c_ColumnName, @c_WhereCondition  
   END 
   CLOSE CUR_LOAD_REQUIRED
   DEALLOCATE CUR_LOAD_REQUIRED 

   IF @b_InValid = 1
      GOTO QUIT

   ----------- Check Condition ------

   SET @b_InValid = 0 

   DECLARE CUR_LOAD_CONDITION CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT Code, Description, Long, Notes, SHORT, ISNULL(Notes2,'')   
   FROM   CODELKUP WITH (NOLOCK)
   WHERE  ListName = @c_LoadValidationRules
   AND    SHORT    IN ('CONDITION', 'CONTAINS')

   OPEN CUR_LOAD_CONDITION

   FETCH NEXT FROM CUR_LOAD_CONDITION INTO @c_TableName, @c_Description, @c_ColumnName, @c_Condition, @c_Type, @c_WhereCondition   

   WHILE @@FETCH_STATUS <> -1
   BEGIN
      SET @c_RecFound = 0    

      SET @c_SQL = N'SELECT @c_RecFound = COUNT(1), @c_Orderkey = MIN(ORDERS.Orderkey) 
       FROM LOADPLAN WITH (NOLOCK) 
       JOIN #TMP_ORDERSLIST ON LOADPLAN.Loadkey = #TMP_ORDERSLIST.Loadkey 
       JOIN ORDERS WITH (NOLOCK) ON #TMP_ORDERSLIST.Orderkey = ORDERS.Orderkey  
       WHERE LOADPLAN.Loadkey= N''' +  @c_Loadkey + ''' '
      
      IF @c_Type = 'CONDITION'
        IF ISNULL(@c_Condition,'') <> ''
        BEGIN
            SET @c_GroupBy = ''
            SET @n_GroupBy = CHARINDEX('GROUP BY',@c_Condition,1)
            IF  @n_GroupBy > 0 
            BEGIN
               SET @c_GroupBy  = SUBSTRING(@c_Condition,@n_GroupBy,LEN(@c_Condition)-@n_GroupBy+1)
               SET @c_Condition = SUBSTRING(@c_Condition,1,@n_GroupBy  - 1)
            END
 
            SET @c_Condition = REPLACE(LEFT(@c_Condition,5),'AND ','AND (') + SUBSTRING(@c_Condition,6,LEN(@c_Condition)-5)
            SET @c_Condition = REPLACE(LEFT(@c_Condition,4),'OR ','OR (') + SUBSTRING(@c_Condition,5,LEN(@c_Condition)-4)
            SET @c_SQL = @c_SQL + master.dbo.fnc_GetCharASCII(13) + CASE WHEN LEFT(LTRIM(@c_Condition),3) NOT IN ('AND','OR ') AND ISNULL(@c_Condition,'') <> '' THEN ' AND (' ELSE ' ' END + RTRIM(@c_Condition)
            SET @c_SQL = @c_SQL + master.dbo.fnc_GetCharASCII(13) + CASE WHEN LEFT(LTRIM(@c_WhereCondition),3) NOT IN ('AND','OR ') AND ISNULL(@c_WhereCondition,'') <> '' THEN ' AND ' ELSE ' ' END + RTRIM(@c_WhereCondition) + ')'

            SET @c_SQL = @c_SQL + @c_GroupBy

         END 
         ELSE
         BEGIN
             IF ISNULL(@c_WhereCondition,'') <> ''
             BEGIN
               SET @c_WhereCondition = REPLACE(LEFT(@c_WhereCondition,5),'AND ','AND (') + SUBSTRING(@c_WhereCondition,6,LEN(@c_WhereCondition)-5)
               SET @c_WhereCondition = REPLACE(LEFT(@c_WhereCondition,4),'OR ','OR (') + SUBSTRING(@c_WhereCondition,5,LEN(@c_WhereCondition)-4)
              SET @c_SQL = @c_SQL + master.dbo.fnc_GetCharASCII(13) + CASE WHEN LEFT(LTRIM(@c_WhereCondition),3) NOT IN ('AND','OR ') AND ISNULL(@c_WhereCondition,'') <> '' THEN ' AND (' ELSE ' ' END + RTRIM(@c_WhereCondition) + ')'
            END
         END
 
      ELSE
      BEGIN --CONTAINS
 
         SET @c_GroupBy = ''
         IF ISNULL(@c_WhereCondition,'') <> '' 
         BEGIN
            SET @n_GroupBy = CHARINDEX('GROUP BY',@c_WhereCondition,1)
            IF  @n_GroupBy > 0 
            BEGIN
               SET @c_GroupBy  = SUBSTRING(@c_WhereCondition,@n_GroupBy,LEN(@c_WhereCondition)-@n_GroupBy+1)
               SET @c_WhereCondition = SUBSTRING(@c_WhereCondition,1,@n_GroupBy-1)
            END
         END
 
         IF ISNULL(@c_Condition,'') <> ''
           BEGIN
            SET @c_SQL = @c_SQL + master.dbo.fnc_GetCharASCII(13) + ' AND (' + @c_ColumnName + ' IN (' + ISNULL(RTRIM(@c_Condition),'') + ')' 
            SET @c_SQL = @c_SQL + master.dbo.fnc_GetCharASCII(13) + CASE WHEN LEFT(LTRIM(@c_WhereCondition),3) NOT IN ('AND','OR ') AND ISNULL(@c_WhereCondition,'') <> '' THEN ' AND ' ELSE ' ' END + RTRIM(@c_WhereCondition) + ')'
         END
         ELSE
         BEGIN
             IF ISNULL(@c_WhereCondition,'') <> ''
             BEGIN
               SET @c_WhereCondition = REPLACE(LEFT(@c_WhereCondition,5),'AND ','AND (') + SUBSTRING(@c_WhereCondition,6,LEN(@c_WhereCondition)-5)
               SET @c_WhereCondition = REPLACE(LEFT(@c_WhereCondition,4),'OR ','OR (') + SUBSTRING(@c_WhereCondition,5,LEN(@c_WhereCondition)-4)
              SET @c_SQL = @c_SQL + master.dbo.fnc_GetCharASCII(13) + CASE WHEN LEFT(LTRIM(@c_WhereCondition),3) NOT IN ('AND','OR ') AND ISNULL(@c_WhereCondition,'') <> '' THEN ' AND (' ELSE ' ' END + RTRIM(@c_WhereCondition) + ')'
            END
         END  
 
         SET @c_SQL = @c_SQL + @c_GroupBy
      END 
     
      EXEC sp_executesql @c_SQL, N'@c_RecFound int OUTPUT, @c_Orderkey NVARCHAR(10) OUTPUT', @c_RecFound OUTPUT, @c_Orderkey OUTPUT

      IF @c_RecFound = 0 AND @c_Type <> 'CONDITION'
      BEGIN 
         SET @b_InValid = 1 
         SET @c_ErrMsg = @c_ErrMsg + RTRIM(@c_Description) + ' Is Invalid! ' + master.dbo.fnc_GetCharASCII(13)
      END 
      ELSE
      IF @c_RecFound > 0 AND @c_Type = 'CONDITION' AND @c_ColumnName = 'NOT EXISTS' 
      BEGIN 
         SET @b_InValid = 1 
         IF CharIndex('LOADPLAN', @c_Condition) > 0 OR CharIndex('ORDERS', @c_Condition) > 0  
            SET @c_ErrMsg = @c_ErrMsg + 'Order# ' + RTRIM(@c_Orderkey) + '. ' + RTRIM(@c_Description) + ' Found! ' + master.dbo.fnc_GetCharASCII(13)
         ELSE
            SET @c_ErrMsg = @c_ErrMsg + RTRIM(@c_Description) + ' Found! ' + master.dbo.fnc_GetCharASCII(13)
      END 
      ELSE
      IF @c_RecFound = 0 AND @c_Type = 'CONDITION' AND 
         (ISNULL(RTRIM(@c_ColumnName),'') = '' OR @c_ColumnName = 'EXISTS')  
      BEGIN 
         SET @b_InValid = 1 
         SET @c_ErrMsg = @c_ErrMsg + RTRIM(@c_Description) + ' Not Found! ' + master.dbo.fnc_GetCharASCII(13)
      END 
      

      FETCH NEXT FROM CUR_LOAD_CONDITION INTO @c_TableName, @c_Description, @c_ColumnName, @c_Condition, @c_Type, @c_WhereCondition  
   END 
   CLOSE CUR_LOAD_CONDITION
   DEALLOCATE CUR_LOAD_CONDITION 

   IF @b_InValid = 1
      GOTO QUIT

   ----------- Stored Proc Condition ------

   SET @b_InValid = 0 
   DECLARE CUR_LOAD_SPCONDITION CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT Code, Description, Long 
   FROM   CODELKUP WITH (NOLOCK)
   WHERE  ListName = @c_LoadValidationRules
   AND    SHORT    = 'STOREDPROC'

   OPEN CUR_LOAD_SPCONDITION

   FETCH NEXT FROM CUR_LOAD_SPCONDITION INTO @c_TableName, @c_Description, @c_SPName 

   WHILE @@FETCH_STATUS <> -1
   BEGIN
      IF EXISTS (SELECT 1 FROM dbo.sysobjects WHERE name = RTRIM(@c_SPName) AND type = 'P')  
      BEGIN      
         SET @c_SQL = 'EXEC ' + @c_SPName + ' @c_Loadkey, @c_Orderkeylist NVARCHAR(MAX), @b_Success OUTPUT, @n_Err OUTPUT, @c_ErrMsg OUTPUT '      
      
         EXEC sp_executesql @c_SQL     
            , N'@c_Loadkey NVARCHAR(10), @c_Orderkeylist, @b_Success Int OUTPUT, @n_Err Int OUTPUT, @c_ErrMsg NVARCHAR(250) OUTPUT'      
            , @c_Loadkey  
            , @c_Orderkeylist    
            , @b_Success   OUTPUT      
            , @n_Err       OUTPUT      
            , @c_ErrMsg    OUTPUT    

         IF @b_Success <> 1
         BEGIN 
            SET @b_InValid = 1      
            CLOSE CUR_LOAD_SPCONDITION
            DEALLOCATE CUR_LOAD_SPCONDITION 
            GOTO QUIT
         END 

      END 
      FETCH NEXT FROM CUR_LOAD_SPCONDITION INTO @c_TableName, @c_Description, @c_SPName
   END 
   CLOSE CUR_LOAD_SPCONDITION
   DEALLOCATE CUR_LOAD_SPCONDITION 

   FETCH NEXT FROM CUR_VALID_RULE INTO @c_LoadValidationRules
END
CLOSE CUR_VALID_RULE
DEALLOCATE CUR_VALID_RULE

QUIT:
IF CURSOR_STATUS('LOCAL' , 'CUR_VALID_RULE') in (0 , 1)
BEGIN
   CLOSE CUR_VALID_RULE
   DEALLOCATE CUR_VALID_RULE
END

IF CURSOR_STATUS('LOCAL' , 'CUR_LOAD_REQUIRED') in (0 , 1)
BEGIN
   CLOSE CUR_LOAD_REQUIRED
   DEALLOCATE CUR_LOAD_REQUIRED
END

IF CURSOR_STATUS('LOCAL' , 'CUR_LOAD_CONDITION') in (0 , 1)
BEGIN
   CLOSE CUR_LOAD_CONDITION
   DEALLOCATE CUR_LOAD_CONDITION
END

IF CURSOR_STATUS('LOCAL' , 'CUR_LOAD_SPCONDITION') in (0 , 1)
BEGIN
   CLOSE CUR_LOAD_SPCONDITION
   DEALLOCATE CUR_LOAD_SPCONDITION
END

IF @b_InValid = 1 
   SET @b_Success = 0 
ELSE
   SET @b_Success = 1

-- End Procedure

GO
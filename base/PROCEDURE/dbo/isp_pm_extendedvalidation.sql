SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store Procedure: isp_PM_ExtendedValidation                           */
/* Creation Date:                                                       */
/* Copyright: LF                                                        */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: SOS#358752 - PM_Transaction_Screen                          */
/*                                                                      */
/* Called By: ispFinalizePalletMgmt                                     */
/*                                                                      */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/* 07-Nov-2016  SPChin    1.1   IN00192761 - Fixed                      */
/************************************************************************/
CREATE PROC [dbo].[isp_PM_ExtendedValidation] 
      @c_PMKey                NVARCHAR(10)  
   ,  @c_PMLineNumber         NVARCHAR(10)
   ,  @c_PMValidationRules   	NVARCHAR(30)	--IN00192761 
   ,  @b_Success              INT = 1        OUTPUT  
   ,  @c_ErrMsg               NVARCHAR(250)  OUTPUT 
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
 
      , @c_ToLoc                 NVARCHAR(10)
      , @c_ToID                  NVARCHAR(18)

SET @b_InValid = 0
SET @c_ErrMsg = ''


DECLARE CUR_PM_REQUIRED CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
SELECT Code, Description, Long, ISNULL(Notes2,'') 
FROM   CODELKUP WITH (NOLOCK)
WHERE  ListName = @c_PMValidationRules
AND    SHORT    = 'REQUIRED'
ORDER BY Code

OPEN CUR_PM_REQUIRED

FETCH NEXT FROM CUR_PM_REQUIRED INTO @c_TableName, @c_Description, @c_ColumnName, @c_WhereCondition 

WHILE @@FETCH_STATUS <> -1
BEGIN
   SET @c_RecFound = 0 
   
   SET @c_SQL =N'SELECT @c_RecFound = COUNT(1)
                 FROM PALLETMGMT WITH (NOLOCK) 
                 JOIN PALLETMGMTDETAIL WITH (NOLOCK) ON  (PALLETMGMT.PMKey = PALLETMGMTDETAIL.PMKey) 
                 LEFT JOIN STORER FROMSTORER WITH (NOLOCK) ON (PALLETMGMTDETAIL.FromStorerkey = FROMSTORER.Storerkey)
                 LEFT JOIN STORER TOSTORER   WITH (NOLOCK) ON (PALLETMGMTDETAIL.ToStorerkey = TOSTORER.Storerkey)
                 WHERE PALLETMGMTDETAIL.PMKey = ''' + RTRIM(@c_pmkey) + ''' 
                 AND   PALLETMGMTDETAIL.PMLineNumber = ''' +  + RTRIM(@c_PMLineNumber) + ''''

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
  
   EXEC sp_executesql @c_SQL, N'@c_RecFound INT OUTPUT', @c_RecFound OUTPUT

   IF @c_RecFound > 0  
   BEGIN 
      SET @b_InValid = 1 
      SET @c_ErrMsg = RTRIM(@c_ErrMsg) + 'Pallet Management - PM #:  ' + RTRIM(@c_PMKey) 
                                       + ', PM Line #: ' + RTRIM(@c_PMLineNumber) 
                                       + '. ' + RTRIM(@c_Description) + ' Is Required! ' + master.dbo.fnc_GetCharASCII(13)

   END 

   FETCH NEXT FROM CUR_PM_REQUIRED INTO @c_TableName, @c_Description, @c_ColumnName, @c_WhereCondition  
END 
CLOSE CUR_PM_REQUIRED
DEALLOCATE CUR_PM_REQUIRED 

IF @b_InValid = 1
   GOTO QUIT

----------- Check Condition ------

SET @b_InValid = 0 

DECLARE CUR_PM_CONDITION CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
SELECT Code, Description, Long, Notes, SHORT, ISNULL(Notes2,'')   
FROM   CODELKUP WITH (NOLOCK)
WHERE  ListName = @c_PMValidationRules
AND    SHORT    IN ('CONDITION', 'CONTAINS')

OPEN CUR_PM_CONDITION

FETCH NEXT FROM CUR_PM_CONDITION INTO @c_TableName, @c_Description, @c_ColumnName, @c_Condition, @c_Type, @c_WhereCondition   

WHILE @@FETCH_STATUS <> -1
BEGIN
   SET @c_RecFound = 0    

   SET @c_SQL =N'SELECT @c_RecFound = COUNT(1)
                 FROM PALLETMGMT WITH (NOLOCK) 
                 JOIN PALLETMGMTDETAIL WITH (NOLOCK) ON  (PALLETMGMT.PMKey = PALLETMGMTDETAIL.PMKey) 
                 LEFT JOIN STORER WITH (NOLOCK) ON (PALLETMGMTDETAIL.FromStorerkey = STORER.Storerkey)
                 WHERE PALLETMGMTDETAIL.PMKey = ''' + RTRIM(@c_pmkey) + ''' 
                 AND   PALLETMGMTDETAIL.PMLineNumber = ''' +  + RTRIM(@c_PMLineNumber) + ''''

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

   EXEC sp_executesql @c_SQL, N'@c_RecFound int OUTPUT', @c_RecFound OUTPUT 

   IF @c_RecFound = 0 AND @c_Type <> 'CONDITION'
   BEGIN 
   SET @b_InValid = 1 
      SET @c_ErrMsg = @c_ErrMsg + RTRIM(@c_Description) + ' Is Invalid! ' + master.dbo.fnc_GetCharASCII(13)
   END 
   ELSE
   IF @c_RecFound > 0 AND @c_Type = 'CONDITION' AND @c_ColumnName = 'NOT EXISTS' 
   BEGIN 
      SET @b_InValid = 1 
      SET @c_ErrMsg = RTRIM(@c_ErrMsg) + 'Pallet Management - PM #:  ' + RTRIM(@c_PMKey) 
                                       + ', PM Line #: ' + RTRIM(@c_PMLineNumber) 
                                       + '. ' + RTRIM(@c_Description) + ' Found! ' + master.dbo.fnc_GetCharASCII(13)

   END 
   ELSE
   IF @c_RecFound = 0 AND @c_Type = 'CONDITION' AND 
      (ISNULL(RTRIM(@c_ColumnName),'') = '' OR @c_ColumnName = 'EXISTS')  
   BEGIN 
      SET @b_InValid = 1 
      SET @c_ErrMsg = RTRIM(@c_ErrMsg) + 'Pallet Management - PM #:  ' + RTRIM(@c_PMKey) 
                                       + ', PM Line #: ' + RTRIM(@c_PMLineNumber) 
                                       + '. ' + RTRIM(@c_Description) + ' Not Found! ' + master.dbo.fnc_GetCharASCII(13)
   END 
   

   FETCH NEXT FROM CUR_PM_CONDITION INTO @c_TableName, @c_Description, @c_ColumnName, @c_Condition, @c_Type, @c_WhereCondition  
END 
CLOSE CUR_PM_CONDITION
DEALLOCATE CUR_PM_CONDITION 


IF @b_InValid = 1
   GOTO QUIT

----------- Check STOREDPROC ------
SET @b_InValid = 0 

DECLARE CUR_PM_SPCONDITION CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
SELECT Code, Description, Long 
FROM   CODELKUP WITH (NOLOCK)
WHERE  ListName = @c_PMValidationRules
AND    SHORT    = 'STOREDPROC'

OPEN CUR_PM_SPCONDITION

FETCH NEXT FROM CUR_PM_SPCONDITION INTO @c_TableName, @c_Description, @c_SPName 

WHILE @@FETCH_STATUS <> -1
BEGIN
   IF EXISTS (SELECT 1 FROM dbo.sysobjects WHERE name = RTRIM(@c_SPName) AND type = 'P')  
   BEGIN      
      SET @c_SQL = 'EXEC ' + @c_SPName + ' @c_PMKey, @c_PMLineNumber, @b_Success OUTPUT, @n_Err OUTPUT, @c_ErrMsg OUTPUT '      
   
      EXEC sp_executesql @c_SQL     
         , N'@c_PMKey NVARCHAR(10), @c_PMLineNumber NVARCHAR(10), @b_Success Int OUTPUT, @n_Err Int OUTPUT, @c_ErrMsg NVARCHAR(250) OUTPUT'      
         , @c_PMKey  
         , @c_PMLineNumber
         , @b_Success   OUTPUT      
         , @n_Err       OUTPUT      
         , @c_ErrMsg    OUTPUT    

      IF @b_Success <> 1
      BEGIN 
         SET @b_InValid = 1      
         CLOSE CUR_PM_SPCONDITION
         DEALLOCATE CUR_PM_SPCONDITION 
         GOTO QUIT
      END 

   END 
   FETCH NEXT FROM CUR_PM_SPCONDITION INTO @c_TableName, @c_Description, @c_SPName
END 
CLOSE CUR_PM_SPCONDITION
DEALLOCATE CUR_PM_SPCONDITION 

QUIT:
IF @b_InValid = 1 
   SET @b_Success = 0 
ELSE
   SET @b_Success = 1

-- End Procedure

GO
SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store Procedure: isp_KIT_ExtendedValidation                          */
/* Creation Date: 31-Oct-2019                                           */
/* Copyright: LF                                                        */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-10947 - KIT Finalize Extended Validation                */
/*                                                                      */
/* Called By:                                                           */
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

CREATE PROC [dbo].[isp_KIT_ExtendedValidation] 
   @c_KITKey                NVARCHAR(10), 
   @c_KITValidationRules    NVARCHAR(30), 
   @b_Success               INT = 1       OUTPUT,    -- @b_Success = 0 (Fail), @b_Success = 1 (Success), @b_Success = 2 (Warning)
   @c_ErrMsg                NVARCHAR(255) OUTPUT,
   @c_KITLineNumber         NVARCHAR(5) = ''

AS 
   SET NOCOUNT ON      
   SET ANSI_NULLS OFF      
   SET QUOTED_IDENTIFIER OFF      
   SET CONCAT_NULL_YIELDS_NULL OFF  

DECLARE @bInValid bit 

DECLARE @c_TableName        NVARCHAR(30), 
        @c_Description      NVARCHAR(250), 
        @c_ColumnName       NVARCHAR(250),
        @n_RecFound         INT, 
        @c_Condition        NVARCHAR(1000), 
        @c_Type             NVARCHAR(10),
        @c_ColName          NVARCHAR(128), 
        @c_ColType          NVARCHAR(128),
        @c_SPName           NVARCHAR(100),              
        @n_err              INT,                        
        @c_WhereCondition   NVARCHAR(1000),
        @c_StorerKey        NVARCHAR(15),
        @c_KITLineNumberP   NVARCHAR(5) = ''

DECLARE @c_SQL nvarchar(Max),
        @c_SQLArg nvarchar(max)

SET @bInValid = 0
SET @c_ErrMsg = ''
SET @c_SPName  = ''                                  
SET @c_ErrMsg  = ''                                  
SET @b_Success = 1        

SELECT TOP 1 @c_StorerKey = Storerkey
FROM KIT (NOLOCK)
WHERE KITKey = @c_KITKey

DECLARE CUR_KIT_REQUIRED CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
SELECT Code, Description, Long, ISNULL(Notes2,'')  
FROM   CODELKUP WITH (NOLOCK)
WHERE  ListName = @c_KITValidationRules
AND    SHORT    = 'REQUIRED'
ORDER BY Code

OPEN CUR_KIT_REQUIRED

FETCH NEXT FROM CUR_KIT_REQUIRED INTO @c_TableName, @c_Description, @c_ColumnName, @c_WhereCondition 

WHILE @@FETCH_STATUS <> -1
BEGIN
   SET @n_RecFound = 0 
   
   SET @c_SQL = N' SELECT @n_RecFound = COUNT(1), @c_KITLineNumberP = MIN(KITDETAIL.KITLineNumber) '
                +' FROM KIT WITH (NOLOCK) '
                +' JOIN KITDETAIL WITH (NOLOCK) ON KIT.KITKey = KITDETAIL.KITKey '
                +' JOIN SKU WITH (NOLOCK) ON SKU.Storerkey = KIT.Storerkey AND SKU.SKU = KITDETAIL.SKU   '
                +' LEFT JOIN LOTATTRIBUTE WITH (NOLOCK) ON KITDETAIL.LOT = LOTATTRIBUTE.LOT '
                +' WHERE KIT.KITKey = @c_KITKey ' 

   IF RTRIM(@c_KITLineNumber) <> ''
   BEGIN
      SET @c_SQL = @c_SQL + ' AND KITDETAIL.KITLineNumber =  @c_KITLineNumber  '
   END
                  
   -- Get Column Type
   SET @c_TableName = LEFT(@c_ColumnName, CharIndex('.', @c_ColumnName) - 1)
   SET @c_ColName  = SUBSTRING(@c_ColumnName, 
                     CharIndex('.', @c_ColumnName) + 1, LEN(@c_ColumnName) - CharIndex('.', @c_ColumnName))

   SET @c_ColType = ''
   SELECT @c_ColType = DATA_TYPE 
   FROM   INFORMATION_SCHEMA.COLUMNS 
   WHERE  TABLE_NAME = @c_TableName
   AND    COLUMN_NAME = @c_ColName
   
   IF ISNULL(RTRIM(@c_ColType), '') = '' 
   BEGIN
      SET @bInValid = 1 
      SET @c_ErrMsg = 'Invalid Column Name: ' + @c_ColumnName 
      GOTO QUIT
   END 

   IF @c_ColType IN ('char', 'nvarchar', 'varchar') 
      SET @c_SQL = @c_SQL + master.dbo.fnc_GetCharASCII(13) + ' AND ISNULL(RTRIM(' + @c_ColumnName + '),'''') = '''' '
   ELSE IF @c_ColType IN ('float', 'money', 'int', 'decimal', 'numeric', 'tinyint', 'real', 'bigint')
      SET @c_SQL = @c_SQL + master.dbo.fnc_GetCharASCII(13) + ' AND ' + @c_ColumnName + ' = 0 '
   ELSE IF @c_ColType IN ('datetime')
      SET @c_SQL = @c_SQL + master.dbo.fnc_GetCharASCII(13) + ' AND (' + @c_ColumnName + ' IS NULL OR CONVERT(NVARCHAR(10),' + @c_ColumnName + ',112) = ''19000101'') '    

   SET @c_SQL = @c_SQL + master.dbo.fnc_GetCharASCII(13) + CASE WHEN LEFT(LTRIM(@c_WhereCondition),3) NOT IN ('AND','OR ') AND ISNULL(@c_WhereCondition,'') <> '' THEN ' AND ' ELSE ' ' END + RTRIM(@c_WhereCondition) --+ ')'       

   --(jay01)
   SET @c_SQLArg = N'@n_RecFound int OUTPUT, '
                   +'@c_KITLineNumberP NVARCHAR(5) OUTPUT, '
                   +'@c_KITKey  NVARCHAR(10), '
                   +'@c_KITLineNumber NVARCHAR(5) '

   EXEC sp_executesql @c_SQL, @c_SQLArg, @n_RecFound OUTPUT, @c_KITLineNumberP OUTPUT, @c_KITKey, @c_KITLineNumber

   IF @n_RecFound > 0  
   BEGIN 
      SET @bInValid = 1 
      IF @c_TableName IN ('KIT')
         SET @c_ErrMsg = RTRIM(@c_ErrMsg) + ' KITKey# ' + RTRIM(@c_KITKey) + ' ' +  RTRIM(@c_Description) + ' Is Required! ' + master.dbo.fnc_GetCharASCII(13)
      ELSE IF @c_TableName IN ('KITDETAIL')
         SET @c_ErrMsg = RTRIM(@c_ErrMsg) + ' KITKey# ' + RTRIM(@c_KITKey) + ' KITLineNumber# ' + RTRIM(@c_KITLineNumberP) + ' ' +
                         RTRIM(@c_Description) + ' Is Required! ' + master.dbo.fnc_GetCharASCII(13)
      ELSE
         SET @c_ErrMsg = RTRIM(@c_ErrMsg) + RTRIM(@c_Description) + ' Is Required! ' +  master.dbo.fnc_GetCharASCII(13)
   END 

   FETCH NEXT FROM CUR_KIT_REQUIRED INTO @c_TableName, @c_Description, @c_ColumnName, @c_WhereCondition  
END 
CLOSE CUR_KIT_REQUIRED
DEALLOCATE CUR_KIT_REQUIRED 

IF @bInValid = 1
   GOTO QUIT

----------- Check Condition ------

SET @bInValid = 0 

DECLARE CUR_KIT_CONDITION CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
SELECT Code, Description, Long, Notes, SHORT, ISNULL(Notes2,'')   
FROM   CODELKUP WITH (NOLOCK)
WHERE  ListName = @c_KITValidationRules
AND    SHORT    IN ('CONDITION', 'CONTAINS')

OPEN CUR_KIT_CONDITION

FETCH NEXT FROM CUR_KIT_CONDITION INTO @c_TableName, @c_Description, @c_ColumnName, @c_Condition, @c_Type, @c_WhereCondition  

WHILE @@FETCH_STATUS <> -1
BEGIN
   SET @c_SQL = N' SELECT @n_RecFound = COUNT(1), @c_KITLineNumberP = MIN(KITDETAIL.KITLineNumber) '
                +' FROM KIT WITH (NOLOCK) '
                +' JOIN KITDETAIL WITH (NOLOCK) ON KIT.KITKey = KITDETAIL.KITKey '
                +' JOIN SKU WITH (NOLOCK) ON SKU.Storerkey = KIT.Storerkey AND SKU.SKU = KITDETAIL.SKU   '
                +' LEFT JOIN LOTATTRIBUTE WITH (NOLOCK) ON KITDETAIL.LOT = LOTATTRIBUTE.LOT '
                +' WHERE KIT.KITKey = @c_KITKey ' 

   IF RTRIM(@c_KITLineNumber) <> ''
   BEGIN
      SET @c_SQL = @c_SQL + ' AND KITDETAIL.KITLineNumber =  @c_KITLineNumber  '
   END 

   IF @c_Type = 'CONDITION'
      IF ISNULL(@c_Condition,'') <> ''
      BEGIN
         SET @c_Condition = REPLACE(LEFT(@c_Condition,5),'AND ','AND (') + SUBSTRING(@c_Condition,6,LEN(@c_Condition)-5)
         SET @c_Condition = REPLACE(LEFT(@c_Condition,4),'OR ','OR (') + SUBSTRING(@c_Condition,5,LEN(@c_Condition)-4)
         SET @c_SQL = @c_SQL + master.dbo.fnc_GetCharASCII(13) + CASE WHEN LEFT(LTRIM(@c_Condition),3) NOT IN ('AND','OR ') AND ISNULL(@c_Condition,'') <> '' THEN ' AND (' ELSE ' ' END + RTRIM(@c_Condition)
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
   ELSE
   BEGIN --CONTAINS
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
   END 

   --(jay01)
   SET @c_SQLArg = N'@n_RecFound int OUTPUT, '
                   +'@c_KITLineNumberP NVARCHAR(5) OUTPUT, '
                   +'@c_KITKey  NVARCHAR(10), '
                   +'@c_KITLineNumber NVARCHAR(5) '

   EXEC sp_executesql @c_SQL, @c_SQLArg, @n_RecFound OUTPUT, @c_KITLineNumberP OUTPUT, @c_KITKey, @c_KITLineNumber

   IF @n_RecFound = 0 AND @c_Type <> 'CONDITION'
   BEGIN 
      SET @bInValid = 1 
      SET @c_ErrMsg = @c_ErrMsg + RTRIM(@c_Description) + ' Is Invalid! ' + + master.dbo.fnc_GetCharASCII(13)
   END 
   ELSE
   IF @n_RecFound > 0 AND @c_Type = 'CONDITION' AND @c_ColumnName = 'NOT EXISTS' 
   BEGIN 
      SET @bInValid = 1 
      IF CharIndex('KITDETAIL', @c_Condition) > 0
         SET @c_ErrMsg = @c_ErrMsg + 'Line# ' + RTRIM(@c_KITLineNumberP) + '. ' + RTRIM(@c_Description) + ' Found! ' + master.dbo.fnc_GetCharASCII(13)
      ELSE
         SET @c_ErrMsg = @c_ErrMsg + RTRIM(@c_Description) + ' Found! ' + master.dbo.fnc_GetCharASCII(13)
   END 
   ELSE
   IF @n_RecFound = 0 AND @c_Type = 'CONDITION' AND 
      (ISNULL(RTRIM(@c_ColumnName),'') = '' OR @c_ColumnName = 'EXISTS')  
   BEGIN 
      SET @bInValid = 1 
      SET @c_ErrMsg = @c_ErrMsg + RTRIM(@c_Description) + ' Not Found! ' + + master.dbo.fnc_GetCharASCII(13)
   END 

   FETCH NEXT FROM CUR_KIT_CONDITION INTO @c_TableName, @c_Description, @c_ColumnName, @c_Condition, @c_Type, @c_WhereCondition  
END 
CLOSE CUR_KIT_CONDITION
DEALLOCATE CUR_KIT_CONDITION 

IF @bInValid = 1
   GOTO QUIT

--Calling SP

SET @bInValid = 0
   
DECLARE CUR_KIT_SPCONDITION CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
SELECT Code, Description, Long 
FROM   CODELKUP WITH (NOLOCK)
WHERE  ListName = @c_KITValidationRules
AND    SHORT    = 'STOREDPROC'

OPEN CUR_KIT_SPCONDITION

FETCH NEXT FROM CUR_KIT_SPCONDITION INTO @c_TableName, @c_Description, @c_SPName 

WHILE @@FETCH_STATUS <> -1
BEGIN
   IF EXISTS (SELECT 1 FROM dbo.sysobjects WHERE name = RTRIM(@c_SPName) AND type = 'P')  
   BEGIN      
      SET @c_SQL = 'EXEC ' + @c_SPName + ' @c_KITKey, @b_Success OUTPUT, @n_Err OUTPUT, @c_ErrMsg OUTPUT, @c_KITLineNumber '      
   
      EXEC sp_executesql @c_SQL     
         , N'@c_KITKey NVARCHAR(10), b_Success Int OUTPUT, @n_Err Int OUTPUT, @c_ErrMsg NVARCHAR(250) OUTPUT, @c_KITLineNumber NVARCHAR(5) '      
         , @c_KITKey        
         , @b_Success   OUTPUT      
         , @n_Err       OUTPUT      
         , @c_ErrMsg    OUTPUT    
         , @c_KITLineNumber 

      IF @b_Success <> 1
      BEGIN 
         SET @bInValid = 1      
         CLOSE CUR_KIT_SPCONDITION
         DEALLOCATE CUR_KIT_SPCONDITION 
         GOTO QUIT
      END 

   END 
   FETCH NEXT FROM CUR_KIT_SPCONDITION INTO @c_TableName, @c_Description, @c_SPName
END 
CLOSE CUR_KIT_SPCONDITION
DEALLOCATE CUR_KIT_SPCONDITION 

QUIT:
IF @bInValid = 1 
   SET @b_Success = 0 
ELSE
   SET @b_Success = 1

-- End Procedure

GO
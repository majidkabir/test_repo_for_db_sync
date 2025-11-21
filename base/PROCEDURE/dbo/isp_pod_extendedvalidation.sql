SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store Procedure: isp_POD_ExtendedValidation                          */
/* Creation Date: 14-MAR-2014                                           */
/* Copyright: LF                                                        */
/* Written by:  YTWan                                                   */
/*                                                                      */
/* Purpose: SOS#305034 - FBR - POD Extended Validation Enhancement      */
/*                                                                      */
/* Called By: ntrPODUpdate                                              */
/*                                                                      */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/* 19-Jul-2017  JayLim    1.2   Performance tune-reduce cache log (jay01)*/
/************************************************************************/
CREATE PROC [dbo].[isp_POD_ExtendedValidation] 
            @c_MBOLKey              NVARCHAR(10) 
         ,  @c_MBOLLineNumber       NVARCHAR(5) 
         ,  @c_PODValidationRules   NVARCHAR(30) 
         ,  @n_Success              INT = 1        OUTPUT 
         ,  @c_ErrorMsg             NVARCHAR(250)  OUTPUT 
AS 
DECLARE @b_InValid bit 

DECLARE @c_TableName          NVARCHAR(30) 
      , @c_Description        NVARCHAR(250) 
      , @c_ColumnName         NVARCHAR(250)
      , @c_RecFound           INT 
      , @c_Condition          NVARCHAR(1000)
      , @c_Type               NVARCHAR(10)
      , @c_ColName            NVARCHAR(128) 
      , @c_ColType            NVARCHAR(128)
      , @c_WhereCondition     NVARCHAR(1000)
      , @c_TransferLineNumber NVARCHAR(5)

DECLARE @c_SQL nvarchar(Max),
        @c_SQLArg nvarchar(max) --(jay01)

SET @b_InValid = 0
SET @c_ErrorMsg = ''

DECLARE CUR_POD_REQUIRED CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
SELECT Code, Description, Long, ISNULL(Notes2,'') 
FROM   CODELKUP WITH (NOLOCK)
WHERE  ListName = @c_PODValidationRules
AND    Short    = 'REQUIRED'
ORDER BY Code

OPEN CUR_POD_REQUIRED

FETCH NEXT FROM CUR_POD_REQUIRED INTO @c_TableName, @c_Description, @c_ColumnName, @c_WhereCondition 

WHILE @@FETCH_STATUS <> -1
BEGIN
   SET @c_RecFound = 0 
   
   SET @c_SQL = N'SELECT @c_RecFound = COUNT(1) '
                +' FROM POD WITH (NOLOCK) '
                +' WHERE POD.MBOLKey =  @c_MBOLKey '
                +' AND POD.MBOLLineNumber = @c_MBOLLineNumber ' --(jay01)
    
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
      SET @c_ErrorMsg = 'Invalid Column Name: ' + @c_ColumnName 
      GOTO QUIT
   END 

   IF @c_ColType IN ('char', 'nvarchar', 'varchar') 
      SET @c_SQL = @c_SQL + master.dbo.fnc_GetCharASCII(13) + ' AND (ISNULL(RTRIM(' + @c_ColumnName + '),'''') = '''' '
   ELSE IF @c_ColType IN ('float', 'money', 'int', 'decimal', 'numeric', 'tinyint', 'real', 'bigint')
      SET @c_SQL = @c_SQL + master.dbo.fnc_GetCharASCII(13) + ' AND (' + @c_ColumnName + ' = 0 '
         
   SET @c_SQL = @c_SQL + master.dbo.fnc_GetCharASCII(13) + CASE WHEN LEFT(LTRIM(@c_WhereCondition),3) NOT IN ('AND','OR ') AND ISNULL(@c_WhereCondition,'') <> '' THEN ' AND ' ELSE ' ' END + RTRIM(@c_WhereCondition) + ')'       

   --(jay01)
   SET @c_SQLArg = N'@c_RecFound int OUTPUT, '
                   +' @c_MBOLKey          NVARCHAR(10), '
                   +' @c_MBOLLineNumber   NVARCHAR(5) '

   EXEC sp_executesql @c_SQL, @c_SQLArg, @c_RecFound OUTPUT, @c_MBOLKey, @c_MBOLLineNumber --(jay01)

   IF @c_RecFound > 0  
   BEGIN 
      SET @b_InValid = 1 
      SET @c_ErrorMsg = RTRIM(@c_ErrorMsg) + RTRIM(@c_Description) + ' Is Required! ' + master.dbo.fnc_GetCharASCII(13)
      
   END 

   FETCH NEXT FROM CUR_POD_REQUIRED INTO @c_TableName, @c_Description, @c_ColumnName, @c_WhereCondition  
END 
CLOSE CUR_POD_REQUIRED
DEALLOCATE CUR_POD_REQUIRED 

IF @b_InValid = 1
   GOTO QUIT

----------- Check Condition ------

SET @b_InValid = 0 

DECLARE CUR_POD_CONDITION CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
SELECT Code, Description, Long, ISNULL(Notes,''), SHORT, ISNULL(Notes2,'')  
FROM   CODELKUP WITH (NOLOCK)
WHERE  ListName = @c_PODValidationRules
AND    SHORT    IN ('CONDITION', 'CONTAINS')

OPEN CUR_POD_CONDITION

FETCH NEXT FROM CUR_POD_CONDITION INTO @c_TableName, @c_Description, @c_ColumnName, @c_Condition, @c_Type, @c_WhereCondition  

WHILE @@FETCH_STATUS <> -1
BEGIN   
--   SET @c_SQL = N'SELECT @c_RecFound = COUNT(1), @c_TransferLineNumber = MIN(TRANSFERDETAIL.TransferLineNumber) FROM TRANSFER (NOLOCK) 
--    JOIN TRANSFERDETAIL WITH (NOLOCK) ON TRANSFER.TransferKey = TRANSFERDETAIL.TransferKey 
--    JOIN SKU WITH (NOLOCK) ON TRANSFERDETAIL.FromStorerkey = SKU.Storerkey AND TRANSFERDETAIL.FromSku = SKU.Sku 
--    WHERE TRANSFER.TransferKey= N''' +  @c_MBOLKey + ''' '

   SET @c_SQL = N'SELECT @c_RecFound = COUNT(1) '
                +' FROM POD WITH (NOLOCK) '
                +' WHERE POD.MBOLKey = @c_MBOLKey  '  
                +' AND POD.MBOLLineNumber =  @c_MBOLLineNumber  ' --(jay01)

   IF @c_Type = 'CONDITION'
      IF ISNULL(@c_Condition,'') <> ''
      BEGIN
         SET @c_Condition = REPLACE(LEFT(@c_Condition,5),'AND ','AND (') + SUBSTRING(@c_Condition,6,LEN(@c_Condition)-5)
         SET @c_Condition = REPLACE(LEFT(@c_Condition,4),'OR ','OR (') + SUBSTRING(@c_Condition,5,LEN(@c_Condition)-4)
         SET @c_SQL = @c_SQL + master.dbo.fnc_GetCharASCII(13) 
                    + CASE WHEN LEFT(LTRIM(@c_Condition),3) NOT IN ('AND','OR ') AND ISNULL(@c_Condition,'') <> '' 
                           THEN ' AND (' ELSE ' ' END + RTRIM(@c_Condition)
         SET @c_SQL = @c_SQL + master.dbo.fnc_GetCharASCII(13) 
                    + CASE WHEN LEFT(LTRIM(@c_WhereCondition),3) NOT IN ('AND','OR ') AND ISNULL(@c_WhereCondition,'') <> '' 
                           THEN ' AND ' ELSE ' ' END + RTRIM(@c_WhereCondition) + ')'
      END 
      ELSE
      BEGIN
         IF ISNULL(@c_WhereCondition,'') <> ''
         BEGIN
            SET @c_WhereCondition = REPLACE(LEFT(@c_WhereCondition,5),'AND ','AND (') + SUBSTRING(@c_WhereCondition,6,LEN(@c_WhereCondition)-5)
            SET @c_WhereCondition = REPLACE(LEFT(@c_WhereCondition,4),'OR ','OR (') + SUBSTRING(@c_WhereCondition,5,LEN(@c_WhereCondition)-4)
            SET @c_SQL = @c_SQL + master.dbo.fnc_GetCharASCII(13) 
                       + CASE WHEN LEFT(LTRIM(@c_WhereCondition),3) NOT IN ('AND','OR ') AND ISNULL(@c_WhereCondition,'') <> '' 
                              THEN ' AND (' ELSE ' ' END + RTRIM(@c_WhereCondition) + ')'
         END
      END
   ELSE
   BEGIN --CONTAINS
      IF ISNULL(@c_Condition,'') <> ''
      BEGIN
         SET @c_SQL = @c_SQL + master.dbo.fnc_GetCharASCII(13) 
                    + ' AND (' + @c_ColumnName + ' IN (' + ISNULL(RTRIM(@c_Condition),'') + ')' 
         SET @c_SQL = @c_SQL + master.dbo.fnc_GetCharASCII(13) 
                    + CASE WHEN LEFT(LTRIM(@c_WhereCondition),3) NOT IN ('AND','OR ') AND ISNULL(@c_WhereCondition,'') <> '' 
                           THEN ' AND ' ELSE ' ' END + RTRIM(@c_WhereCondition) + ')'
      END
      ELSE
BEGIN
         IF ISNULL(@c_WhereCondition,'') <> ''
         BEGIN
            SET @c_WhereCondition = REPLACE(LEFT(@c_WhereCondition,5),'AND ','AND (') + SUBSTRING(@c_WhereCondition,6,LEN(@c_WhereCondition)-5)
            SET @c_WhereCondition = REPLACE(LEFT(@c_WhereCondition,4),'OR ','OR (') + SUBSTRING(@c_WhereCondition,5,LEN(@c_WhereCondition)-4)
            SET @c_SQL = @c_SQL + master.dbo.fnc_GetCharASCII(13) 
                       + CASE WHEN LEFT(LTRIM(@c_WhereCondition),3) NOT IN ('AND','OR ') AND ISNULL(@c_WhereCondition,'') <> '' 
                              THEN ' AND (' ELSE ' ' END + RTRIM(@c_WhereCondition) + ')'
         END
      END                   
   END    

   --(jay01)
   SET @c_SQLArg = N'@c_RecFound int OUTPUT, '
                   +' @c_MBOLKey          NVARCHAR(10), '
                   +' @c_MBOLLineNumber   NVARCHAR(5) '

   EXEC sp_executesql @c_SQL, @c_SQLArg , @c_RecFound OUTPUT, @c_MBOLKey, @c_MBOLLineNumber --(jay01)

   IF @c_RecFound = 0 AND @c_Type <> 'CONDITION'
   BEGIN 
      SET @b_InValid = 1 
      SET @c_ErrorMsg = @c_ErrorMsg + RTRIM(@c_Description) + ' Is Invalid! ' + master.dbo.fnc_GetCharASCII(13)
   END 
   ELSE
   IF @c_RecFound > 0 AND @c_Type = 'CONDITION' AND @c_ColumnName = 'NOT EXISTS' 
   BEGIN 
      SET @b_InValid = 1 
      SET @c_ErrorMsg = @c_ErrorMsg + RTRIM(@c_Description) + ' Found! ' + master.dbo.fnc_GetCharASCII(13)
   END 
   ELSE
   IF @c_RecFound = 0 AND @c_Type = 'CONDITION' AND 
      (ISNULL(RTRIM(@c_ColumnName),'') = '' OR @c_ColumnName = 'EXISTS')  
   BEGIN 
      SET @b_InValid = 1 
      SET @c_ErrorMsg = @c_ErrorMsg + RTRIM(@c_Description) + ' Not Found! ' + master.dbo.fnc_GetCharASCII(13)
   END 
   
   FETCH NEXT FROM CUR_POD_CONDITION INTO @c_TableName, @c_Description, @c_ColumnName, @c_Condition, @c_Type, @c_WhereCondition  
END 
CLOSE CUR_POD_CONDITION
DEALLOCATE CUR_POD_CONDITION 


QUIT:
IF @b_InValid = 1 
   SET @n_Success = 0 
ELSE
   SET @n_Success = 1


GO
SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store Procedure: isp_IQC_ExtendedValidation                          */
/* Creation Date:                                                       */
/* Copyright: LF                                                        */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: SOS#328603 - CN_PUMA_add verification for IQC               */
/*                                                                      */
/* Called By: ispFinalizeIQC                                            */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/* 19-Jul-2017  JayLim    1.2   Performance tune-reduce cache log (jay01)*/
/* 26-Jan-2021  LZG       1.3   Go to QUIT when hit matching            */
/*                              condition (ZG01)                        */
/************************************************************************/

CREATE PROC [dbo].[isp_IQC_ExtendedValidation]
      @c_QC_Key               NVARCHAR(10) 
   ,  @c_IQCValidationRules   NVARCHAR(30) 
   ,  @b_Success              INT = 1        OUTPUT 
   ,  @c_ErrMsg               NVARCHAR(250)  OUTPUT
AS
DECLARE @b_InValid            BIT
      , @n_Err                INT

DECLARE @c_TableName          NVARCHAR(30) 
      , @c_Description        NVARCHAR(250) 
      , @c_ColumnName         NVARCHAR(250)
      , @n_RecFound           int 
      , @c_Condition          NVARCHAR(1000) 
      , @c_Type               NVARCHAR(10)
      , @c_ColName            NVARCHAR(128) 
      , @c_ColType            NVARCHAR(128)
      , @c_WhereCondition     NVARCHAR(1000)
      , @c_SPName             NVARCHAR(30)

      , @c_QCLineNo           NVARCHAR(5)

DECLARE @cSQL nvarchar(Max),
        @cSQLArg nvarchar(max) --(jay01)


SET @b_InValid = 0
SET @c_ErrMsg = ''


DECLARE CUR_IQC_REQUIRED CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
SELECT Code, Description, Long, ISNULL(Notes2,'') 
FROM   CODELKUP WITH (NOLOCK)
WHERE  ListName = @c_IQCValidationRules
AND    SHORT    = 'REQUIRED'
ORDER BY Code

OPEN CUR_IQC_REQUIRED

FETCH NEXT FROM CUR_IQC_REQUIRED INTO @c_TableName, @c_Description, @c_ColumnName, @c_WhereCondition 

WHILE @@FETCH_STATUS <> -1
BEGIN
   SET @n_RecFound = 0 

   --(jay01)
   SET @cSQL = N'SELECT @n_RecFound = COUNT(1), @c_QCLineNo = MIN(INVENTORYQCDETAIL.QCLineNo) '
               +' FROM INVENTORYQC WITH (NOLOCK)'
               +' JOIN INVENTORYQCDETAIL WITH (NOLOCK) ON INVENTORYQC.QC_Key = INVENTORYQCDETAIL.QC_Key'
               +' JOIN STORER WITH (NOLOCK) ON INVENTORYQCDETAIL.Storerkey = STORER.Storerkey'
               +' JOIN SKU WITH (NOLOCK) ON INVENTORYQCDETAIL.Storerkey = SKU.Storerkey AND INVENTORYQCDETAIL.Sku = SKU.Sku'
               +' JOIN LOT WITH (NOLOCK) ON INVENTORYQCDETAIL.FromLot = LOT.Lot'
               +' JOIN LOC WITH (NOLOCK) ON INVENTORYQCDETAIL.FromLoc = LOC.Loc'
               +' JOIN ID  WITH (NOLOCK) ON INVENTORYQCDETAIL.FromID = ID.Id'
               +' LEFT JOIN LOC TOLOC WITH (NOLOCK) ON INVENTORYQCDETAIL.ToLoc = TOLOC.Loc'
               +' LEFT JOIN ID  TOID  WITH (NOLOCK) ON INVENTORYQCDETAIL.ToID = ID.ID AND INVENTORYQCDETAIL.ToID <> '''''
               +' WHERE INVENTORYQC.QC_Key= @c_QC_Key '

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
      SET @cSQL = @cSQL + master.dbo.fnc_GetCharASCII(13) + ' AND (ISNULL(RTRIM(' + @c_ColumnName + '),'''') = '''' '
   ELSE IF @c_ColType IN ('float', 'money', 'int', 'decimal', 'numeric', 'tinyint', 'real', 'bigint')
      SET @cSQL = @cSQL + master.dbo.fnc_GetCharASCII(13) + ' AND (' + @c_ColumnName + ' = 0 '

   SET @cSQL = @cSQL + master.dbo.fnc_GetCharASCII(13) + CASE WHEN LEFT(LTRIM(@c_WhereCondition),3) NOT IN ('AND','OR ') AND ISNULL(@c_WhereCondition,'') <> '' THEN ' AND ' ELSE ' ' END + RTRIM(@c_WhereCondition) + ')'

   --(jay01)
   SET @cSQLArg = N'@n_RecFound int OUTPUT, '
                  +'@c_QCLineNo nvarchar(5) OUTPUT, '
                  +'@c_QC_Key  NVARCHAR(10)  '

   EXEC sp_executesql @cSQL, @cSQLArg , @n_RecFound OUTPUT, @c_QCLineNo OUTPUT, @c_QC_Key --(jay01)

   IF @n_RecFound > 0
   BEGIN
      SET @b_InValid = 1
      IF @c_TableName IN ('INVENTORYQCDETAIL','SKU', 'LOT', 'LOC', 'ID', 'TOLOC', 'TOID')
         SET @c_ErrMsg = RTRIM(@c_ErrMsg) + 'Line# ' + RTRIM(@c_QCLineNo) + '. ' + RTRIM(@c_Description) + ' Is Required! ' + master.dbo.fnc_GetCharASCII(13)
      ELSE
         SET @c_ErrMsg = RTRIM(@c_ErrMsg) + RTRIM(@c_Description) + ' Is Required! ' + master.dbo.fnc_GetCharASCII(13)

   END

   FETCH NEXT FROM CUR_IQC_REQUIRED INTO @c_TableName, @c_Description, @c_ColumnName, @c_WhereCondition
END
CLOSE CUR_IQC_REQUIRED
DEALLOCATE CUR_IQC_REQUIRED

IF @b_InValid = 1
   GOTO QUIT

----------- Check Condition ------

SET @b_InValid = 0

DECLARE CUR_IQC_CONDITION CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
SELECT Code, Description, Long, ISNULL(Notes,''), SHORT, ISNULL(Notes2,'')
FROM   CODELKUP WITH (NOLOCK)
WHERE  ListName = @c_IQCValidationRules
AND    SHORT    IN ('CONDITION', 'CONTAINS')

OPEN CUR_IQC_CONDITION

FETCH NEXT FROM CUR_IQC_CONDITION INTO @c_TableName, @c_Description, @c_ColumnName, @c_Condition, @c_Type, @c_WhereCondition

WHILE @@FETCH_STATUS <> -1
BEGIN
   SET @cSQL = N'SELECT @n_RecFound = COUNT(1), @c_QCLineNo = MIN(INVENTORYQCDETAIL.QCLineNo) '
               +' FROM INVENTORYQC WITH (NOLOCK)'
               +' JOIN INVENTORYQCDETAIL WITH (NOLOCK) ON INVENTORYQC.QC_Key = INVENTORYQCDETAIL.QC_Key'
               +' JOIN STORER WITH (NOLOCK) ON INVENTORYQCDETAIL.Storerkey = STORER.Storerkey'
               +' JOIN SKU WITH (NOLOCK) ON INVENTORYQCDETAIL.Storerkey = SKU.Storerkey AND INVENTORYQCDETAIL.Sku = SKU.Sku'
               +' JOIN LOT WITH (NOLOCK) ON INVENTORYQCDETAIL.FromLot = LOT.Lot'
               +' JOIN LOC WITH (NOLOCK) ON INVENTORYQCDETAIL.FromLoc = LOC.Loc'
               +' JOIN ID  WITH (NOLOCK) ON INVENTORYQCDETAIL.FromID = ID.Id'
               +' LEFT JOIN LOC TOLOC WITH (NOLOCK) ON INVENTORYQCDETAIL.ToLoc = TOLOC.Loc'
               +' LEFT JOIN ID  TOID  WITH (NOLOCK) ON INVENTORYQCDETAIL.ToID = ID.ID AND INVENTORYQCDETAIL.ToID <> '''''
               +' WHERE INVENTORYQC.QC_Key= @c_QC_Key '

   IF @c_Type = 'CONDITION'
      IF ISNULL(@c_Condition,'') <> ''
      BEGIN

         SET @c_Condition = REPLACE(LEFT(@c_Condition,5),'AND ','AND (') + SUBSTRING(@c_Condition,6,LEN(@c_Condition)-5)
         SET @c_Condition = REPLACE(LEFT(@c_Condition,4),'OR ','OR (') + SUBSTRING(@c_Condition,5,LEN(@c_Condition)-4)
         SET @cSQL = @cSQL + master.dbo.fnc_GetCharASCII(13) + CASE WHEN LEFT(LTRIM(@c_Condition),3) NOT IN ('AND','OR ') AND ISNULL(@c_Condition,'') <> '' THEN ' AND (' ELSE ' ' END + RTRIM(@c_Condition)
         SET @cSQL = @cSQL + master.dbo.fnc_GetCharASCII(13) + CASE WHEN LEFT(LTRIM(@c_WhereCondition),3) NOT IN ('AND','OR ') AND ISNULL(@c_WhereCondition,'') <> '' THEN ' AND ' ELSE ' ' END + RTRIM(@c_WhereCondition) + ')'

      END
      ELSE
      BEGIN
         IF ISNULL(@c_WhereCondition,'') <> ''
         BEGIN
            SET @c_WhereCondition = REPLACE(LEFT(@c_WhereCondition,5),'AND ','AND (') + SUBSTRING(@c_WhereCondition,6,LEN(@c_WhereCondition)-5)
            SET @c_WhereCondition = REPLACE(LEFT(@c_WhereCondition,4),'OR ','OR (') + SUBSTRING(@c_WhereCondition,5,LEN(@c_WhereCondition)-4)
            SET @cSQL = @cSQL + master.dbo.fnc_GetCharASCII(13) + CASE WHEN LEFT(LTRIM(@c_WhereCondition),3) NOT IN ('AND','OR ') AND ISNULL(@c_WhereCondition,'') <> '' THEN ' AND (' ELSE ' ' END + RTRIM(@c_WhereCondition) + ')'
         END
      END
   ELSE
   BEGIN --CONTAINS
      IF ISNULL(@c_Condition,'') <> ''
      BEGIN
         SET @cSQL = @cSQL + master.dbo.fnc_GetCharASCII(13) + ' AND (' + @c_ColumnName + ' IN (' + ISNULL(RTRIM(@c_Condition),'') + ')'
         SET @cSQL = @cSQL + master.dbo.fnc_GetCharASCII(13) + CASE WHEN LEFT(LTRIM(@c_WhereCondition),3) NOT IN ('AND','OR ') AND ISNULL(@c_WhereCondition,'') <> '' THEN ' AND ' ELSE ' ' END + RTRIM(@c_WhereCondition) + ')'
      END
      ELSE
      BEGIN
         IF ISNULL(@c_WhereCondition,'') <> ''
         BEGIN
            SET @c_WhereCondition = REPLACE(LEFT(@c_WhereCondition,5),'AND ','AND (') + SUBSTRING(@c_WhereCondition,6,LEN(@c_WhereCondition)-5)
            SET @c_WhereCondition = REPLACE(LEFT(@c_WhereCondition,4),'OR ','OR (') + SUBSTRING(@c_WhereCondition,5,LEN(@c_WhereCondition)-4)
            SET @cSQL = @cSQL + master.dbo.fnc_GetCharASCII(13) + CASE WHEN LEFT(LTRIM(@c_WhereCondition),3) NOT IN ('AND','OR ') AND ISNULL(@c_WhereCondition,'') <> '' THEN ' AND (' ELSE ' ' END + RTRIM(@c_WhereCondition) + ')'
         END
      END
   END

   --(jay01)
   SET @cSQLArg = N'@n_RecFound int OUTPUT, '
                  +'@c_QCLineNo nvarchar(5) OUTPUT, '
                  +'@c_QC_Key  NVARCHAR(10)  '

   EXEC sp_executesql @cSQL, @cSQLArg , @n_RecFound OUTPUT, @c_QCLineNo OUTPUT, @c_QC_Key --(jay01)

   IF @n_RecFound = 0 AND @c_Type <> 'CONDITION'
   BEGIN
      SET @b_InValid = 1
      SET @c_ErrMsg = @c_ErrMsg + RTRIM(@c_Description) + ' Is Invalid! ' + master.dbo.fnc_GetCharASCII(13)
   END
   ELSE
   IF @n_RecFound > 0 AND @c_Type = 'CONDITION' AND @c_ColumnName = 'NOT EXISTS'
   BEGIN
      SET @b_InValid = 1

      IF CharIndex('INVENTORYQCDETAIL', @c_Condition) > 0 OR CharIndex('SKU', @c_Condition) > 0
         OR CharIndex('LOT', @c_Condition) > 0 OR CharIndex('LOC', @c_Condition) > 0 OR CharIndex('ID', @c_Condition) > 0
         SET @c_ErrMsg = @c_ErrMsg + 'Line# ' + RTRIM(@c_QCLineNo) + '. ' + RTRIM(@c_Description) + ' Found! ' + master.dbo.fnc_GetCharASCII(13)
      ELSE
         SET @c_ErrMsg = @c_ErrMsg + RTRIM(@c_Description) + ' Found! ' + master.dbo.fnc_GetCharASCII(13)
   END
   ELSE
   IF @n_RecFound = 0 AND @c_Type = 'CONDITION' AND
      (ISNULL(RTRIM(@c_ColumnName),'') = '' OR @c_ColumnName = 'EXISTS')
   BEGIN
      SET @b_InValid = 1
      SET @c_ErrMsg = @c_ErrMsg + RTRIM(@c_Description) + ' Not Found! ' + master.dbo.fnc_GetCharASCII(13)
   END

   FETCH NEXT FROM CUR_IQC_CONDITION INTO @c_TableName, @c_Description, @c_ColumnName, @c_Condition, @c_Type, @c_WhereCondition
END
CLOSE CUR_IQC_CONDITION
DEALLOCATE CUR_IQC_CONDITION

-- ZG01 (Start)
IF @b_InValid = 1  
   GOTO QUIT  
  
----------- Check Condition ------  
  
SET @b_InValid = 0  
-- ZG01 (End)

DECLARE CUR_IQC_SPCONDITION CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
SELECT Code, Description, Long
FROM   CODELKUP WITH (NOLOCK)
WHERE  ListName = @c_IQCValidationRules
AND    SHORT    = 'STOREDPROC'

OPEN CUR_IQC_SPCONDITION

FETCH NEXT FROM CUR_IQC_SPCONDITION INTO @c_TableName, @c_Description, @c_SPName

WHILE @@FETCH_STATUS <> -1
BEGIN
   IF EXISTS (SELECT 1 FROM dbo.sysobjects WHERE name = RTRIM(@c_SPName) AND type = 'P')
   BEGIN
      SET @cSQL = 'EXEC ' + @c_SPName + ' @c_QC_Key, @b_Success OUTPUT, @n_Err OUTPUT, @c_ErrMsg OUTPUT '

      EXEC sp_executesql @cSQL
         , N'@c_QC_Key NVARCHAR(10), @b_Success Int OUTPUT, @n_Err Int OUTPUT, @c_ErrMsg NVARCHAR(250) OUTPUT'
         , @c_QC_Key
         , @b_Success   OUTPUT
         , @n_Err       OUTPUT
         , @c_ErrMsg    OUTPUT

      IF @b_Success <> 1
      BEGIN
         SET @b_InValid = 1
         CLOSE CUR_IQC_SPCONDITION
         DEALLOCATE CUR_IQC_SPCONDITION
         GOTO QUIT
      END

   END
   FETCH NEXT FROM CUR_IQC_SPCONDITION INTO @c_TableName, @c_Description, @c_SPName
END
CLOSE CUR_IQC_SPCONDITION
DEALLOCATE CUR_IQC_SPCONDITION


QUIT:
IF @b_InValid = 1
   SET @b_Success = 0
ELSE
   SET @b_Success = 1

-- End Procedure

GO
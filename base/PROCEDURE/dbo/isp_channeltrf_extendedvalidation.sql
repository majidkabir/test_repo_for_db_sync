SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store Procedure: isp_ChannelTRF_ExtendedValidation                   */
/* Creation Date: 2021-05-19                                            */
/* Copyright: LFL                                                       */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-17048 - Channel Transfer Extended Validation            */
/*                                                                      */
/* Called By: isp_FinalizeChannelTransfer                               */
/*                                                                      */
/* GitLab Version: 1.0                                                  */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/************************************************************************/

CREATE PROC [dbo].[isp_ChannelTRF_ExtendedValidation]
      @c_ChannelTransferKey        NVARCHAR(10)
    , @c_ChannelTRFValidationRules NVARCHAR(30)
    , @b_Success                   INT = 1       OUTPUT
    , @c_ErrorMsg                  NVARCHAR(250) OUTPUT
    , @c_ChannelTransferLineNumber NVARCHAR(5) = ''
AS
BEGIN
   DECLARE @b_InValid BIT
   
   DECLARE @c_TableName             NVARCHAR(30),
           @c_Description           NVARCHAR(250),
           @c_ColumnName            NVARCHAR(250),
           @c_RecFound              INT,
           @c_Condition             NVARCHAR(1000),
           @c_Type                  NVARCHAR(10),
           @c_ColName               NVARCHAR(128),
           @c_ColType               NVARCHAR(128),
           @c_WhereCondition        NVARCHAR(1000),
           @c_ChannelTRFLineNumber  NVARCHAR(5),
           @c_SPName                NVARCHAR(100),
           @n_Err                   INT
   
   DECLARE @c_SQL    NVARCHAR(MAX),
           @c_SQLArg NVARCHAR(MAX)
   
   SET @b_InValid = 0
   SET @c_ErrorMsg = ''
   
   DECLARE CUR_TRF_REQUIRED CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT Code, Description, Long, ISNULL(Notes2,'')
   FROM   CODELKUP WITH (NOLOCK)
   WHERE  ListName = @c_ChannelTRFValidationRules
   AND    SHORT    = 'REQUIRED'
   ORDER BY Code
   
   OPEN CUR_TRF_REQUIRED
   
   FETCH NEXT FROM CUR_TRF_REQUIRED INTO @c_TableName, @c_Description, @c_ColumnName, @c_WhereCondition
   
   WHILE @@FETCH_STATUS <> -1
   BEGIN
      SET @c_RecFound = 0
   
      SET @c_SQL = N'SELECT @c_RecFound = COUNT(1), @c_ChannelTRFLineNumber = MIN(ChannelTransferDetail.ChannelTransferLineNumber) '
                  +' FROM ChannelTransfer (NOLOCK)'
                  +' JOIN ChannelTransferDetail WITH (NOLOCK) ON ChannelTransfer.ChannelTransferKey = ChannelTransferDetail.ChannelTransferKey'
                  +' JOIN STORER WITH (NOLOCK) ON ChannelTransferDetail.FromStorerkey = STORER.Storerkey'
                  +' JOIN SKU WITH (NOLOCK) ON ChannelTransferDetail.FromStorerkey = SKU.Storerkey AND ChannelTransferDetail.FromSku = SKU.Sku'   
                  +' JOIN STORER TOSTORER WITH (NOLOCK) ON ChannelTransferDetail.ToStorerkey = TOSTORER.Storerkey'
                  +' JOIN SKU TOSKU WITH (NOLOCK) ON ChannelTransferDetail.ToSku = TOSKU.Sku'
                  +' WHERE ChannelTransfer.ChannelTransferKey = @c_ChannelTransferKey ' 
       
      IF @c_ChannelTransferLineNumber <> ''
      BEGIN
         SET @c_SQL = @c_SQL  + ' AND ChannelTransferDetail.ChannelTransferLineNumber =  @c_ChannelTransferLineNumber  '   
      END 

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
   
      IF @c_ColType IN ('char', 'NVARCHAR', 'varchar')
         SET @c_SQL = @c_SQL + master.dbo.fnc_GetCharASCII(13) + ' AND (ISNULL(RTRIM(' + @c_ColumnName + '),'''') = '''' '
      ELSE IF @c_ColType IN ('float', 'money', 'INT', 'decimal', 'numeric', 'tinyint', 'real', 'bigint')
         SET @c_SQL = @c_SQL + master.dbo.fnc_GetCharASCII(13) + ' AND (' + @c_ColumnName + ' = 0 '
   
      SET @c_SQL = @c_SQL + master.dbo.fnc_GetCharASCII(13) + CASE WHEN LEFT(LTRIM(@c_WhereCondition),3) NOT IN ('AND','OR ') AND ISNULL(@c_WhereCondition,'') <> '' THEN ' AND ' ELSE ' ' END + RTRIM(@c_WhereCondition) + ')'
   
      
      SET @c_SQLArg = N'@c_RecFound INT OUTPUT, '
                     +' @c_ChannelTRFLineNumber NVARCHAR(5) OUTPUT, '
                     +' @c_ChannelTransferKey   NVARCHAR(10), '
                     +' @c_ChannelTransferLineNumber NVARCHAR(5) '
   
      EXEC sp_executesql @c_SQL, @c_SQLArg, @c_RecFound OUTPUT, @c_ChannelTRFLineNumber OUTPUT, @c_ChannelTransferKey, @c_ChannelTransferLineNumber 
   
      IF @c_RecFound > 0
      BEGIN
         SET @b_InValid = 1
         IF @c_TableName IN ('ChannelTransferDetail','SKU','LOT','TOSKU')
            SET @c_ErrorMsg = RTRIM(@c_ErrorMsg) + 'Line# ' + RTRIM(@c_ChannelTRFLineNumber) + '. ' + RTRIM(@c_Description) + ' Is Required! ' + master.dbo.fnc_GetCharASCII(13)
         ELSE
         SET @c_ErrorMsg = RTRIM(@c_ErrorMsg) + RTRIM(@c_Description) + ' Is Required! ' + master.dbo.fnc_GetCharASCII(13)
      END
   
      FETCH NEXT FROM CUR_TRF_REQUIRED INTO @c_TableName, @c_Description, @c_ColumnName, @c_WhereCondition
   END
   CLOSE CUR_TRF_REQUIRED
   DEALLOCATE CUR_TRF_REQUIRED
   
   IF @b_InValid = 1
      GOTO QUIT
   
   ----------- Check Condition ------
   
   SET @b_InValid = 0

   DECLARE CUR_TRF_CONDITION CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT Code, Description, Long, ISNULL(Notes,''), SHORT, ISNULL(Notes2,'')
   FROM   CODELKUP WITH (NOLOCK)
   WHERE  ListName = @c_ChannelTRFValidationRules
   AND    SHORT    IN ('CONDITION', 'CONTAINS')
   
   OPEN CUR_TRF_CONDITION
   
   FETCH NEXT FROM CUR_TRF_CONDITION INTO @c_TableName, @c_Description, @c_ColumnName, @c_Condition, @c_Type, @c_WhereCondition
   
   WHILE @@FETCH_STATUS <> -1
   BEGIN
      SET @c_SQL = N'SELECT @c_RecFound = COUNT(1), @c_ChannelTRFLineNumber = MIN(ChannelTransferDetail.ChannelTransferLineNumber) '
                  +' FROM ChannelTransfer (NOLOCK)'
                  +' JOIN ChannelTransferDetail WITH (NOLOCK) ON ChannelTransfer.ChannelTransferKey = ChannelTransferDetail.ChannelTransferKey'
                  +' JOIN STORER WITH (NOLOCK) ON ChannelTransferDetail.FromStorerkey = STORER.Storerkey'
                  +' JOIN SKU WITH (NOLOCK) ON ChannelTransferDetail.FromStorerkey = SKU.Storerkey AND ChannelTransferDetail.FromSku = SKU.Sku'
                  +' JOIN STORER TOSTORER WITH (NOLOCK) ON ChannelTransferDetail.ToStorerkey = TOSTORER.Storerkey'
                  +' JOIN SKU TOSKU WITH (NOLOCK) ON ChannelTransferDetail.ToSku = TOSKU.Sku'
                  +' WHERE ChannelTransfer.ChannelTransferKey = @c_ChannelTransferKey '  
   
      IF @c_ChannelTransferLineNumber <> ''
      BEGIN
         SET @c_SQL = @c_SQL  + ' AND ChannelTransferDetail.ChannelTransferLineNumber = @c_ChannelTransferLineNumber  '  
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

      SET @c_SQLArg = N'@c_RecFound INT OUTPUT, '
                     +' @c_ChannelTRFLineNumber NVARCHAR(5) OUTPUT, '
                     +' @c_ChannelTransferKey   NVARCHAR(10), '
                     +' @c_ChannelTransferLineNumber NVARCHAR(5) '
   
      EXEC sp_executesql @c_SQL, @c_SQLArg , @c_RecFound OUTPUT, @c_ChannelTRFLineNumber OUTPUT, @c_ChannelTransferKey, @c_ChannelTransferLineNumber 
   
      IF @c_RecFound = 0 AND @c_Type <> 'CONDITION'
      BEGIN
         SET @b_InValid = 1
         SET @c_ErrorMsg = @c_ErrorMsg + RTRIM(@c_Description) + ' Is Invalid! ' + master.dbo.fnc_GetCharASCII(13)
      END
      ELSE
      IF @c_RecFound > 0 AND @c_Type = 'CONDITION' AND @c_ColumnName = 'NOT EXISTS'
      BEGIN
         SET @b_InValid = 1
   
      IF CharIndex('ChannelTransferDetail', @c_Condition) > 0 OR CharIndex('SKU', @c_Condition) > 0 OR CharIndex('TOSKU', @c_Condition) > 0
         SET @c_ErrorMsg = @c_ErrorMsg + 'Line# ' + RTRIM(@c_ChannelTRFLineNumber) + '. ' + RTRIM(@c_Description) + ' Found! ' + master.dbo.fnc_GetCharASCII(13)
      ELSE
         SET @c_ErrorMsg = @c_ErrorMsg + RTRIM(@c_Description) + ' Found! ' + master.dbo.fnc_GetCharASCII(13)
      END
      ELSE
      IF @c_RecFound = 0 AND @c_Type = 'CONDITION' AND
         (ISNULL(RTRIM(@c_ColumnName),'') = '' OR @c_ColumnName = 'EXISTS')
      BEGIN
   
         SET @b_InValid = 1
         SET @c_ErrorMsg = @c_ErrorMsg + RTRIM(@c_Description) + ' Not Found! ' + master.dbo.fnc_GetCharASCII(13)
      END
   
      FETCH NEXT FROM CUR_TRF_CONDITION INTO @c_TableName, @c_Description, @c_ColumnName, @c_Condition, @c_Type, @c_WhereCondition
   END
   CLOSE CUR_TRF_CONDITION
   DEALLOCATE CUR_TRF_CONDITION
   
   IF @b_InValid = 1
      GOTO QUIT
   
   ----------- Check STORED PROC ------
   
   SET @b_InValid = 0
   
   DECLARE CUR_TRF_SPCONDITION CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT Code, Description, Long
   FROM   CODELKUP WITH (NOLOCK)
   WHERE  ListName = @c_ChannelTRFValidationRules
   AND    SHORT    = 'STOREDPROC'
   
   OPEN CUR_TRF_SPCONDITION
   
   FETCH NEXT FROM CUR_TRF_SPCONDITION INTO @c_TableName, @c_Description, @c_SPName
   
   WHILE @@FETCH_STATUS <> -1
   BEGIN
      IF EXISTS (SELECT 1 FROM dbo.sysobjects WHERE name = RTRIM(@c_SPName) AND type = 'P')
      BEGIN
         SET @c_SQL = 'EXEC ' + @c_SPName + ' @c_TransferKey, @b_Success OUTPUT, @n_ErrNo OUTPUT, @c_ErrorMsg OUTPUT '
                   + ', @c_ChannelTransferLineNumber '
         EXEC sp_executesql @c_SQL
            , N'@c_TransferKey NVARCHAR(10), @b_Success INT OUTPUT, @n_ErrNo INT OUTPUT, @c_ErrorMsg NVARCHAR(250) OUTPUT
            , @c_ChannelTransferLineNumber NVARCHAR(5)'            
            , @c_ChannelTransferKey
            , @b_Success    OUTPUT
            , @n_Err        OUTPUT
            , @c_ErrorMsg   OUTPUT
            , @c_ChannelTransferLineNumber                         
   
         IF @b_Success <> 1
         BEGIN
            SET @b_InValid = 1
            CLOSE CUR_TRF_SPCONDITION
            DEALLOCATE CUR_TRF_SPCONDITION
            GOTO QUIT
         END
   
      END
      FETCH NEXT FROM CUR_TRF_SPCONDITION INTO @c_TableName, @c_Description, @c_SPName
   END
   CLOSE CUR_TRF_SPCONDITION
   DEALLOCATE CUR_TRF_SPCONDITION
   
   QUIT:
   IF @b_InValid = 1
      SET @b_Success = 0
   ELSE
      SET @b_Success = 1
END

GO
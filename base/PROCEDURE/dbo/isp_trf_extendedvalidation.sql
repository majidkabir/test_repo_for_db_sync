SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store Procedure: isp_TRF_ExtendedValidation                          */
/* Creation Date:                                                       */
/* Copyright: LF                                                        */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: ASN Extended Validation SOS#291413                          */
/*                                                                      */
/* Called By: ispFinalizeTransfer                                       */
/*                                                                      */
/* PVCS Version: 1.3                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/* 24-Nov-2014  NJOW01    1.0   325985-Include lot,loc,id,storer tables */
/*                              and add stored proc checking.           */
/* 03-Dec-2014  Leong     1.1   SOS# 327625 - Bug Fix.                  */
/* 11-May-2015  NJOW02    1.2   341115-Left join to lot                 */
/* 02-Feb-2015  YTWan     1.3   SOS#315474 - Project Merlion - Exceed   */
/*                              GTM Kiosk Module (Wan01)                */
/* 19-Jul-2017  JayLim    1.4   Performance tune-reduce cache log (jay01)*/                
/* 28-Jul-2022  NJOW03    1.5   WMS-20353 display error message from    */
/*                              codlekup for Stored proc validation     */
/* 28-Jul-2022  NJOW03    1.5   DEVOPS combine script                   */
/************************************************************************/

CREATE   PROC [dbo].[isp_TRF_ExtendedValidation]
   @cTransferKey   NVARCHAR(10),
   @cTRFValidationRules NVARCHAR(30),
   @nSuccess   int = 1      OUTPUT,
   @cErrorMsg  NVARCHAR(250) OUTPUT
,  @c_TransferLineNumber NVARCHAR(5) = '' --(Wan01) 
AS
DECLARE @bInValid bit

DECLARE @cTableName          NVARCHAR(30),
        @cDescription        NVARCHAR(250),
        @cColumnName         NVARCHAR(250),
        @cRecFound           int,
        @cCondition          NVARCHAR(1000),
        @cType               NVARCHAR(10),
        @cColName            NVARCHAR(128),
        @cColType            NVARCHAR(128),
        @cWhereCondition     NVARCHAR(1000),
        @cTransferLineNumber NVARCHAR(5),
        @cSPName             NVARCHAR(100),
        @nErr                INT

DECLARE @cSQL nvarchar(Max),
        @cSQLArg nvarchar(max)

SET @bInValid = 0
SET @cErrorMsg = ''

DECLARE CUR_TRF_REQUIRED CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
SELECT Code, Description, Long, ISNULL(Notes2,'')
FROM   CODELKUP WITH (NOLOCK)
WHERE  ListName = @cTRFValidationRules
AND    SHORT    = 'REQUIRED'
ORDER BY Code

OPEN CUR_TRF_REQUIRED

FETCH NEXT FROM CUR_TRF_REQUIRED INTO @cTableName, @cDescription, @cColumnName, @cWhereCondition

WHILE @@FETCH_STATUS <> -1
BEGIN
   SET @cRecFound = 0

   SET @cSQL = N'SELECT @cRecFound = COUNT(1), @cTransferLineNumber = MIN(TRANSFERDETAIL.TransferLineNumber) '
               +' FROM TRANSFER (NOLOCK)'
               +' JOIN TRANSFERDETAIL WITH (NOLOCK) ON TRANSFER.TransferKey = TRANSFERDETAIL.TransferKey'
               +' JOIN STORER WITH (NOLOCK) ON TRANSFERDETAIL.FromStorerkey = STORER.Storerkey'
               +' JOIN SKU WITH (NOLOCK) ON TRANSFERDETAIL.FromStorerkey = SKU.Storerkey AND TRANSFERDETAIL.FromSku = SKU.Sku'
               +' LEFT JOIN LOT WITH (NOLOCK) ON TRANSFERDETAIL.FromLot = LOT.Lot'
               +' JOIN LOC WITH (NOLOCK) ON TRANSFERDETAIL.FromLoc = LOC.Loc'
               +' JOIN ID WITH (NOLOCK) ON TRANSFERDETAIL.FromID = ID.Id'
               +' JOIN LOTxLOCxID WITH (NOLOCK) ON  (LOTxLOCxID.LOT = TRANSFERDETAIL.FromLot) '
               +'                               AND (LOTXLOCXID.Loc = TRANSFERDETAIL.FromLoc)'
               +' AND (LOTXLOCXID.id  = TRANSFERDETAIL.FromID)'
               +' JOIN SKUxLOC    WITH (NOLOCK) ON  (SKUxLOC.Storerkey = LOTxLOCxID.Storerkey) '
               +'                               AND (SKUxLOC.Sku = LOTxLOCxID.Sku)'
               +'                               AND (SKUxLOC.Loc = LOTxLOCxID.Loc) '
               +' JOIN LOTATTRIBUTE WITH (NOLOCK)ON (LOTxLOCxID.Lot = LOTATTRIBUTE.Lot)   '   
               +' JOIN STORER TOSTORER WITH (NOLOCK) ON TRANSFERDETAIL.ToStorerkey = TOSTORER.Storerkey'
               +' JOIN SKU TOSKU WITH (NOLOCK) ON TRANSFERDETAIL.ToSku = TOSKU.Sku'
               +' JOIN LOC TOLOC WITH (NOLOCK) ON TRANSFERDETAIL.ToLoc = TOLOC.Loc'
               +' WHERE TRANSFER.TransferKey=   @cTransferKey ' --(jay01)
    
   --(Wan01)  - START
   IF @c_TransferLineNumber <> ''
   BEGIN
      SET @cSQL = @cSQL  + ' AND TRANSFERDETAIL.TransferLineNumber =  @c_TransferLineNumber  '   --(jay01)
   END 
   --(Wan01)  - END

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
      SET @cSQL = @cSQL + master.dbo.fnc_GetCharASCII(13) + ' AND (ISNULL(RTRIM(' + @cColumnName + '),'''') = '''' '
   ELSE IF @cColType IN ('float', 'money', 'int', 'decimal', 'numeric', 'tinyint', 'real', 'bigint')
      SET @cSQL = @cSQL + master.dbo.fnc_GetCharASCII(13) + ' AND (' + @cColumnName + ' = 0 '

   SET @cSQL = @cSQL + master.dbo.fnc_GetCharASCII(13) + CASE WHEN LEFT(LTRIM(@cWhereCondition),3) NOT IN ('AND','OR ') AND ISNULL(@cWhereCondition,'') <> '' THEN ' AND ' ELSE ' ' END + RTRIM(@cWhereCondition) + ')'

   --(jay01)
   SET @cSQLArg = N'@cRecFound int OUTPUT, '
                  +' @cTransferLineNumber nvarchar(5) OUTPUT, '
                  +' @cTransferKey   NVARCHAR(10), '
                  +' @c_TransferLineNumber NVARCHAR(5) '

   EXEC sp_executesql @cSQL, @cSQLArg, @cRecFound OUTPUT, @cTransferLineNumber OUTPUT, @cTransferKey, @c_TransferLineNumber --(jay01)

   IF @cRecFound > 0
   BEGIN
      SET @bInValid = 1
      IF @cTableName IN ('TRANSFERDETAIL','SKU','LOT','LOC','ID','TOSKU','TOLOC','TOID','LOTxLOCxID','SKUxLOC','LOTATTRIBUTE')
         SET @cErrorMsg = RTRIM(@cErrorMsg) + 'Line# ' + RTRIM(@cTransferLineNumber) + '. ' + RTRIM(@cDescription) + ' Is Required! ' + master.dbo.fnc_GetCharASCII(13)
      ELSE
         SET @cErrorMsg = RTRIM(@cErrorMsg) + RTRIM(@cDescription) + ' Is Required! ' + master.dbo.fnc_GetCharASCII(13)

   END

   FETCH NEXT FROM CUR_TRF_REQUIRED INTO @cTableName, @cDescription, @cColumnName, @cWhereCondition
END
CLOSE CUR_TRF_REQUIRED
DEALLOCATE CUR_TRF_REQUIRED

IF @bInValid = 1
   GOTO QUIT

----------- Check Condition ------

SET @bInValid = 0

DECLARE CUR_TRF_CONDITION CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
SELECT Code, Description, Long, ISNULL(Notes,''), SHORT, ISNULL(Notes2,'')
FROM   CODELKUP WITH (NOLOCK)
WHERE  ListName = @cTRFValidationRules
AND    SHORT    IN ('CONDITION', 'CONTAINS')

OPEN CUR_TRF_CONDITION

FETCH NEXT FROM CUR_TRF_CONDITION INTO @cTableName, @cDescription, @cColumnName, @cCondition, @cType, @cWhereCondition

WHILE @@FETCH_STATUS <> -1
BEGIN
   SET @cSQL = N'SELECT @cRecFound = COUNT(1), @cTransferLineNumber = MIN(TRANSFERDETAIL.TransferLineNumber) '
               +' FROM TRANSFER (NOLOCK)'
               +' JOIN TRANSFERDETAIL WITH (NOLOCK) ON TRANSFER.TransferKey = TRANSFERDETAIL.TransferKey'
               +' JOIN STORER WITH (NOLOCK) ON TRANSFERDETAIL.FromStorerkey = STORER.Storerkey'
               +' JOIN SKU WITH (NOLOCK) ON TRANSFERDETAIL.FromStorerkey = SKU.Storerkey AND TRANSFERDETAIL.FromSku = SKU.Sku'
               +' LEFT JOIN LOT WITH (NOLOCK) ON TRANSFERDETAIL.FromLot = LOT.Lot'
               +' JOIN LOC WITH (NOLOCK) ON TRANSFERDETAIL.FromLoc = LOC.Loc'
               +' JOIN ID WITH (NOLOCK) ON TRANSFERDETAIL.FromID = ID.Id' -- SOS# 327625
               +' JOIN LOTxLOCxID WITH (NOLOCK) ON  (LOTxLOCxID.LOT = TRANSFERDETAIL.FromLot) '
               +'                               AND (LOTXLOCXID.Loc = TRANSFERDETAIL.FromLoc)'
               +'                               AND (LOTXLOCXID.id  = TRANSFERDETAIL.FromID)'
               +' JOIN SKUxLOC    WITH (NOLOCK) ON  (SKUxLOC.Storerkey = LOTxLOCxID.Storerkey) '
               +'                               AND (SKUxLOC.Sku = LOTxLOCxID.Sku)'
               +'                               AND (SKUxLOC.Loc = LOTxLOCxID.Loc) '
               +' JOIN LOTATTRIBUTE WITH (NOLOCK)ON (LOTxLOCxID.Lot = LOTATTRIBUTE.Lot)  '
               +' JOIN STORER TOSTORER WITH (NOLOCK) ON TRANSFERDETAIL.ToStorerkey = TOSTORER.Storerkey'
               +' JOIN SKU TOSKU WITH (NOLOCK) ON TRANSFERDETAIL.ToSku = TOSKU.Sku'
               +' JOIN LOC TOLOC WITH (NOLOCK) ON TRANSFERDETAIL.ToLoc = TOLOC.Loc'
               +' WHERE TRANSFER.TransferKey= @cTransferKey '  --(jay01)

   --(Wan01)  - START
   IF @c_TransferLineNumber <> ''
   BEGIN
      SET @cSQL = @cSQL  + ' AND TRANSFERDETAIL.TransferLineNumber = @c_TransferLineNumber  '  
   END 
   --(Wan01)  - END


   IF @cType = 'CONDITION'
        IF ISNULL(@cCondition,'') <> ''
        BEGIN
          SET @cCondition = REPLACE(LEFT(@cCondition,5),'AND ','AND (') + SUBSTRING(@cCondition,6,LEN(@cCondition)-5)
          SET @cCondition = REPLACE(LEFT(@cCondition,4),'OR ','OR (') + SUBSTRING(@cCondition,5,LEN(@cCondition)-4)
         SET @cSQL = @cSQL + master.dbo.fnc_GetCharASCII(13) + CASE WHEN LEFT(LTRIM(@cCondition),3) NOT IN ('AND','OR ') AND ISNULL(@cCondition,'') <> '' THEN ' AND (' ELSE ' ' END + RTRIM(@cCondition)
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
   ELSE
   BEGIN --CONTAINS
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
   END

   --(jay01)
   SET @cSQLArg = N'@cRecFound int OUTPUT, '
                  +' @cTransferLineNumber nvarchar(5) OUTPUT, '
                  +' @cTransferKey   NVARCHAR(10), '
                  +' @c_TransferLineNumber NVARCHAR(5) '

   EXEC sp_executesql @cSQL, @cSQLArg , @cRecFound OUTPUT, @cTransferLineNumber OUTPUT, @cTransferKey, @c_TransferLineNumber --(jay01)

   IF @cRecFound = 0 AND @cType <> 'CONDITION'
   BEGIN
      SET @bInValid = 1
      SET @cErrorMsg = @cErrorMsg + RTRIM(@cDescription) + ' Is Invalid! ' + master.dbo.fnc_GetCharASCII(13)
   END
   ELSE
   IF @cRecFound > 0 AND @cType = 'CONDITION' AND @cColumnName = 'NOT EXISTS'
   BEGIN
      SET @bInValid = 1

 IF CharIndex('TRANSFERDETAIL', @cCondition) > 0 OR CharIndex('SKU', @cCondition) > 0
         OR CharIndex('LOT', @cCondition) > 0 OR CharIndex('LOC', @cCondition) > 0 OR CharIndex('ID', @cCondition) > 0
         OR CharIndex('TOSKU', @cCondition) > 0 OR CharIndex('TOLOC', @cCondition) > 0 OR CharIndex('TOID', @cCondition) > 0
         OR CharIndex('LOTxLOCxID', @cCondition) > 0 OR CharIndex('SKUxLOC', @cCondition) > 0 OR CharIndex('LOTATTRIBUTE', @cCondition) > 0
         SET @cErrorMsg = @cErrorMsg + 'Line# ' + RTRIM(@cTransferLineNumber) + '. ' + RTRIM(@cDescription) + ' Found! ' + master.dbo.fnc_GetCharASCII(13)
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

   FETCH NEXT FROM CUR_TRF_CONDITION INTO @cTableName, @cDescription, @cColumnName, @cCondition, @cType, @cWhereCondition
END
CLOSE CUR_TRF_CONDITION
DEALLOCATE CUR_TRF_CONDITION

IF @bInValid = 1
   GOTO QUIT

----------- Check STORED PROC ------

SET @bInValid = 0

DECLARE CUR_TRF_SPCONDITION CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
SELECT Code, Description, Long
FROM   CODELKUP WITH (NOLOCK)
WHERE  ListName = @cTRFValidationRules
AND    SHORT    = 'STOREDPROC'

OPEN CUR_TRF_SPCONDITION

FETCH NEXT FROM CUR_TRF_SPCONDITION INTO @cTableName, @cDescription, @cSPName

WHILE @@FETCH_STATUS <> -1
BEGIN
   IF EXISTS (SELECT 1 FROM dbo.sysobjects WHERE name = RTRIM(@cSPName) AND type = 'P')
   BEGIN
      SET @cSQL = 'EXEC ' + @cSPName + ' @c_TransferKey, @b_Success OUTPUT, @n_ErrNo OUTPUT, @c_ErrorMsg OUTPUT '
                + ', @c_TransferLineNumber '
      EXEC sp_executesql @cSQL
         , N'@c_TransferKey NVARCHAR(10), @b_Success Int OUTPUT, @n_ErrNo Int OUTPUT, @c_ErrorMsg NVARCHAR(250) OUTPUT
         , @c_TransferLineNumber NVARCHAR(5)'            --(Wan01)
         , @cTransferKey
         , @nSuccess    OUTPUT
         , @nErr        OUTPUT
         , @cErrorMsg   OUTPUT
         , @c_TransferLineNumber                         --(Wan01)

      IF @nSuccess <> 1
      BEGIN
         SET @bInValid = 1        
         SET @cErrorMsg = RTRIM(ISNULL(@cDescription,'')) + ' ' + master.dbo.fnc_GetCharASCII(13) + @cErrorMsg --NJOW03         
         CLOSE CUR_TRF_SPCONDITION
         DEALLOCATE CUR_TRF_SPCONDITION         
         GOTO QUIT
      END

   END
   FETCH NEXT FROM CUR_TRF_SPCONDITION INTO @cTableName, @cDescription, @cSPName
END
CLOSE CUR_TRF_SPCONDITION
DEALLOCATE CUR_TRF_SPCONDITION

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
SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store Procedure: isp_ASN_ExtendedValidation                          */  
/* Creation Date:                                                       */  
/* Copyright: IDS                                                       */  
/* Written by: NJOW                                                     */  
/*                                                                      */  
/* Purpose: ASN Extended Validation SOS#201053                          */  
/*                                                                      */  
/* Called By: ispFinalizeReceipt                                        */  
/*                                                                      */  
/* PVCS Version: 1.2                                                    */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author    Ver.  Purposes                                */  
/* 20-Dec-2011  NJOW01    1.1   Use Short as EXISTS/NOT EXISTS Condition*/  
/* 06-Jan-2012  NJOW02    1.2   232274-Include sku table for validation */  
/* 03-Jan-2014  NJOW03    1.3   297536-Add Where condition and show     */                  
/*                              line number                             */  
/* 16-JAN-2014  YTWan     1.4   SOS#298639 - Washington - Finalize      */  
/*                              Receipt Line (Wan01)                    */  
/* 09-OCT-2014  NJOW04    1.5   Support stored proc calling             */  
/* 19-Jul-2017  JayLim    1.2   Performance tune-reduce cache log (jay01)*/  
/* 27-May-2021  ian/NJOW        To handle errormessage override by      */  
/*                              another SP                              */  
/************************************************************************/  
CREATE PROC [dbo].[isp_ASN_ExtendedValidation]   
   @cReceiptKey   NVARCHAR(10),   
   @cASNValidationRules NVARCHAR(30),   
   @nSuccess   int = 1      OUTPUT,   
   @cErrorMsg  NVARCHAR(250) OUTPUT   
  ,@c_ReceiptLineNumber NVARCHAR(5) = ''      --(Wan01)   
AS   
DECLARE @bInValid bit   
  
DECLARE @cTableName   NVARCHAR(30),   
        @cDescription NVARCHAR(250),   
        @cColumnName  NVARCHAR(250),  
        @cRecFound    INT,   
        @cCondition   NVARCHAR(1000),   
        @cType        NVARCHAR(10),  
        @cColName     NVARCHAR(128),   
        @cColType     NVARCHAR(128),  
        @cWhereCondition     NVARCHAR(1000),  
        @cReceiptLineNumber  NVARCHAR(5),  
        @cSPName             NVARCHAR(100),  --NJOW04          
        @nErr         INT --NJOW04  
  
DECLARE @cSQL          nvarchar(Max),  
        @cSQLArg       NVARCHAR(Max) --(jay01)  
  
SET @bInValid = 0  
SET @cErrorMsg = ''  
SET @c_ReceiptLineNumber = ISNULL(RTRIM(@c_ReceiptLineNumber),'')    --(Wan01)  
  
DECLARE CUR_ASN_REQUIRED CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
SELECT Code, Description, Long, ISNULL(Notes2,'')   
FROM   CODELKUP WITH (NOLOCK)  
WHERE  ListName = @cASNValidationRules  
AND    SHORT    = 'REQUIRED'  
ORDER BY Code  
  
OPEN CUR_ASN_REQUIRED  
  
FETCH NEXT FROM CUR_ASN_REQUIRED INTO @cTableName, @cDescription, @cColumnName, @cWhereCondition   
  
WHILE @@FETCH_STATUS <> -1  
BEGIN  
   SET @cRecFound = 0   
   --(jay01)  
   SET @cSQL = N'SELECT @cRecFound = COUNT(1), @cReceiptLineNumber = MIN(RECEIPTDETAIL.ReceiptLineNumber) '  
               +'FROM RECEIPT (NOLOCK) '  
               +'JOIN RECEIPTDETAIL WITH (NOLOCK) ON RECEIPT.ReceiptKey = RECEIPTDETAIL.ReceiptKey '  
               +'JOIN SKU WITH (NOLOCK) ON RECEIPTDETAIL.Storerkey = SKU.Storerkey AND RECEIPTDETAIL.Sku = SKU.Sku '  
               +'WHERE RECEIPT.ReceiptKey= @cReceiptKey  '  
  
   -- (Wan01) - START    
   IF RTRIM(@c_ReceiptLineNumber) <> ''  
   BEGIN   
      SET @cSQL = @cSQL + ' AND RECEIPTDETAIL.ReceiptLineNumber =  @c_ReceiptLineNumber  ' --(jay01)  
   END  
   -- (Wan01) - END  
         
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
                  +'@cReceiptLineNumber nvarchar(5) OUTPUT, '  
                  +'@cReceiptKey   NVARCHAR(10), '  
                  +'@c_ReceiptLineNumber  NVARCHAR(5) '  
  
   EXEC sp_executesql @cSQL, @cSQLArg , @cRecFound OUTPUT, @cReceiptLineNumber OUTPUT, @cReceiptKey, @c_ReceiptLineNumber --(jay01)  
  
   -- Bug Fixed (Shong001)   
   IF @cRecFound > 0    
   BEGIN   
      SET @bInValid = 1   
      IF @cTableName IN ('RECEIPTDETAIL','SKU')  
         SET @cErrorMsg = RTRIM(@cErrorMsg) + 'Line# ' + RTRIM(@cReceiptLineNumber) + '. ' + RTRIM(@cDescription) + ' Is Required! ' + master.dbo.fnc_GetCharASCII(13)  
      ELSE  
         SET @cErrorMsg = RTRIM(@cErrorMsg) + RTRIM(@cDescription) + ' Is Required! ' + master.dbo.fnc_GetCharASCII(13)  
   END   
  
   FETCH NEXT FROM CUR_ASN_REQUIRED INTO @cTableName, @cDescription, @cColumnName, @cWhereCondition    
END   
CLOSE CUR_ASN_REQUIRED  
DEALLOCATE CUR_ASN_REQUIRED   
  
IF @bInValid = 1  
   GOTO QUIT  
  
----------- Check Condition ------  
  
SET @bInValid = 0   
  
DECLARE CUR_ASN_CONDITION CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
SELECT Code, Description, Long, Notes, SHORT, ISNULL(Notes2,'')     
FROM   CODELKUP WITH (NOLOCK)  
WHERE  ListName = @cASNValidationRules  
AND    SHORT    IN ('CONDITION', 'CONTAINS')  
  
OPEN CUR_ASN_CONDITION  
  
FETCH NEXT FROM CUR_ASN_CONDITION INTO @cTableName, @cDescription, @cColumnName, @cCondition, @cType, @cWhereCondition     
  
WHILE @@FETCH_STATUS <> -1  
BEGIN  
   --(jay01)  
   SET @cSQL = N'SELECT @cRecFound = COUNT(1), @cReceiptLineNumber = MIN(RECEIPTDETAIL.ReceiptLineNumber) '  
               +'FROM RECEIPT (NOLOCK) '  
               +'JOIN RECEIPTDETAIL WITH (NOLOCK) ON RECEIPT.ReceiptKey = RECEIPTDETAIL.ReceiptKey '  
               +'JOIN SKU WITH (NOLOCK) ON RECEIPTDETAIL.Storerkey = SKU.Storerkey AND RECEIPTDETAIL.Sku = SKU.Sku '  
               +'WHERE RECEIPT.ReceiptKey=  @cReceiptKey  '  
  
   -- (Wan01) - START    
   IF RTRIM(@c_ReceiptLineNumber) <> ''  
   BEGIN   
      SET @cSQL = @cSQL + ' AND RECEIPTDETAIL.ReceiptLineNumber =   @c_ReceiptLineNumber  '--(jay01)  
   END  
   -- (Wan01) - END  
     
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
      --SET @cSQL = @cSQL + master.dbo.fnc_GetCharASCII(13) + ' ' + @cCondition   
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
      -- Shong002 Bug Fixed  
      --SET @cSQL = @cSQL + master.dbo.fnc_GetCharASCII(13) + ' AND ' + @cColumnName + ' IN (' + ISNULL(RTRIM(@cCondition),'') + ')'   
   END   
     
   --(jay01)  
   SET @cSQLArg = N'@cRecFound int OUTPUT, '  
                  +'@cReceiptLineNumber nvarchar(5) OUTPUT, '  
                  +'@cReceiptKey   NVARCHAR(10), '  
                  +'@c_ReceiptLineNumber  NVARCHAR(5) '  
  
   EXEC sp_executesql @cSQL, @cSQLArg , @cRecFound OUTPUT, @cReceiptLineNumber OUTPUT, @cReceiptKey,@c_ReceiptLineNumber  --(jay01)  
  
   --NJOW01  
   IF @cRecFound = 0 AND @cType <> 'CONDITION'  
   BEGIN   
      SET @bInValid = 1   
      SET @cErrorMsg = @cErrorMsg + RTRIM(@cDescription) + ' Is Invalid! ' + master.dbo.fnc_GetCharASCII(13)  
   END   
   ELSE  
   IF @cRecFound > 0 AND @cType = 'CONDITION' AND @cColumnName = 'NOT EXISTS'   
   BEGIN   
      SET @bInValid = 1   
      IF CharIndex('RECEIPTDETAIL', @cCondition) > 0 OR CharIndex('SKU', @cCondition) > 0    
         SET @cErrorMsg = @cErrorMsg + 'Line# ' + RTRIM(@cReceiptLineNumber) + '. ' + RTRIM(@cDescription) + ' Found! ' + master.dbo.fnc_GetCharASCII(13)  
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
  
   FETCH NEXT FROM CUR_ASN_CONDITION INTO @cTableName, @cDescription, @cColumnName, @cCondition, @cType, @cWhereCondition    
END   
CLOSE CUR_ASN_CONDITION  
DEALLOCATE CUR_ASN_CONDITION   
  
--ian/NJOW  
IF @bInValid = 1  
   GOTO QUIT  
  
--NJOW04  
DECLARE CUR_ASN_SPCONDITION CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
SELECT Code, Description, Long   
FROM   CODELKUP WITH (NOLOCK)  
WHERE  ListName = @cASNValidationRules  
AND    SHORT    = 'STOREDPROC'  
  
OPEN CUR_ASN_SPCONDITION  
  
FETCH NEXT FROM CUR_ASN_SPCONDITION INTO @cTableName, @cDescription, @cSPName   
  
WHILE @@FETCH_STATUS <> -1  
BEGIN  
   IF EXISTS (SELECT 1 FROM dbo.sysobjects WHERE name = RTRIM(@cSPName) AND type = 'P')    
   BEGIN        
  
      SET @cSQL = 'EXEC ' + @cSPName+ ' @c_ReceiptKey, @b_Success OUTPUT, @n_ErrNo OUTPUT, @c_ErrMsg OUTPUT '            
                 + ',@c_ReceiptLineNumber '  
                                          
      EXEC sp_executesql @cSQL,            
         N'@c_ReceiptKey NVARCHAR(10), @b_Success Int OUTPUT, @n_ErrNo Int OUTPUT, @c_ErrMsg NVARCHAR(250) OUTPUT  
            ,@c_ReceiptLineNumber NVARCHAR(5)',                           
           @cReceiptKey,            
           @nSuccess OUTPUT,            
           @nErr OUTPUT,            
           @cErrorMsg OUTPUT,  
           @c_ReceiptLineNumber                                            
   END  
     
   IF @nSuccess <> 1  
   BEGIN   
      SET @bInValid = 1        
      CLOSE CUR_ASN_SPCONDITION  
      DEALLOCATE CUR_ASN_SPCONDITION   
      GOTO QUIT  
   END   
  
   FETCH NEXT FROM CUR_ASN_SPCONDITION INTO @cTableName, @cDescription, @cSPName  
END   
CLOSE CUR_ASN_SPCONDITION  
DEALLOCATE CUR_ASN_SPCONDITION   
  
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
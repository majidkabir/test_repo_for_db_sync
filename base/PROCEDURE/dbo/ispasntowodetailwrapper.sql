SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************/
/* Store Procedure: ispASNToWODetailWrapper                                */
/* Creation Date: 03-JUN-2016                                              */
/* Copyright: LF                                                           */
/* Written by: YTWan                                                       */
/*                                                                         */
/* Purpose: Populate to Orders Mapping                                     */
/*        : SOS#370728 - Workorder_PopulatefromASN                         */
/*                                                                         */
/* Called By: n_cst_workorderdetail.of_colmapping                          */
/*                                                                         */
/* PVCS Version: 1.0                                                       */
/*                                                                         */
/* Version: 5.4                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date         Author    Ver.  Purposes                                   */
/***************************************************************************/
CREATE PROC [dbo].[ispASNToWODetailWrapper]
           @c_SourceTable        NVARCHAR(30)
         , @c_SourceKey          NVARCHAR(10)
         , @c_SourceLineNumber   NVARCHAR(30) = ''
         , @c_ListName           NVARCHAR(10) 
         , @c_Code               NVARCHAR(30)    
         , @c_Storerkey          NVARCHAR(15)    
         , @c_FromCol            NVARCHAR(60)   OUTPUT 
         , @c_ToCol              NVARCHAR(60)   OUTPUT   
         , @c_FromValue          NVARCHAR(4000) OUTPUT
         , @b_Success            INT            OUTPUT
AS
BEGIN 
   SET NOCOUNT ON      
   SET ANSI_NULLS OFF      
   SET QUOTED_IDENTIFIER OFF      
   SET CONCAT_NULL_YIELDS_NULL OFF 

   DECLARE @n_Cnt             INT
         , @c_SQL             NVARCHAR(4000)
         , @c_SQLParm         NVARCHAR(4000)
         , @c_Where           NVARCHAR(4000)

         , @c_ToTable         NVARCHAR(30)
         , @c_FromColTable    NVARCHAR(30)
         , @c_ToColTable      NVARCHAR(30)
         , @c_KeyCol          NVARCHAR(30)
         , @n_FromColType     INT

         , @c_TableAttribute  NVARCHAR(10)  
         , @c_Rule            NVARCHAR(255)     
         , @c_SPName          NVARCHAR(255) 
         , @c_CustomSQL       NVARCHAR(4000) 


   SET @b_Success = 1

   IF @c_SourceLineNumber = ''
   BEGIN
      SET @c_TableAttribute = 'H'
      SET @c_ToTable        = 'WORKORDER'
      IF @c_SourceTable = 'RECEIPT'
      BEGIN
         SET @c_Where = ' WHERE RECEIPT.ReceiptKey = N''' + @c_SourceKey + ''' '
      END
   END
   ELSE
   BEGIN
      SET @c_TableAttribute = 'D'
      SET @c_ToTable        = 'WORKORDERDETAIL'

      IF @c_SourceTable = 'RECEIPTDETAIL'
      BEGIN
         SET @c_Where = ' WHERE RECEIPTDETAIL.ReceiptKey = N''' + @c_SourceKey 
                      + ''' AND RECEIPTDETAIL.ReceiptLineNumber = N''' + @c_SourceLineNumber + ''' '
      END
   END

   SET @c_FromColTable = @c_SourceTable   
   SET @c_ToColTable   = @c_ToTable


   IF CHARINDEX('.', @c_ToCol) > 0 
   BEGIN
      SET @c_ToColTable = SUBSTRING(@c_ToCol, 1, CHARINDEX('.', @c_ToCol) - 1)
      SET @c_ToCol      = SUBSTRING(@c_ToCol, CHARINDEX('.', @c_ToCol) + 1, LEN(@c_ToCol) -  CHARINDEX('.', @c_ToCol))
   END

   IF CHARINDEX('.', @c_FromCol) > 0 
   BEGIN
      SET @c_FromColTable = SUBSTRING(@c_FromCol, 1, CHARINDEX('.', @c_FromCol) - 1)
      SET @c_FromCol   = SUBSTRING(@c_FromCol, CHARINDEX('.', @c_FromCol) + 1, LEN(@c_FromCol) -  CHARINDEX('.', @c_FromCol))
   END

   IF @c_ToColTable <> @c_ToTable
   BEGIN
      SET @b_Success = 0
      GOTO QUIT
   END

   IF @c_FromColTable <> @c_SourceTable
   BEGIN
      SET @b_Success = 0
      GOTO QUIT
   END

   SET @c_Rule = ''
   SET @c_CustomSQL = ''

   SELECT @c_Rule   = ISNULL(RTRIM(Long),'')
         ,@c_CustomSQL = ISNULL(RTRIM(Notes),'')
   FROM CODELKUP WITH (NOLOCK)
   WHERE ListName = @c_Listname
   AND   Code = @c_Code
   AND   Storerkey = @c_Storerkey
   AND   Short  = @c_TableAttribute

   IF @c_Rule IN ('', 'MAPPING')
   BEGIN
      SET @n_Cnt = 0
      SELECT @n_FromColType = C.xType
            ,@n_Cnt         = 1
      FROM dbo.SysObjects O WITH (NOLOCK)
      JOIN dbo.SysColumns C WITH (NOLOCK) ON (O.Id = C.Id)
      WHERE O.Name = @c_SourceTable 
      AND   C.Name = @c_FromCol 

      IF @n_Cnt = 0
      BEGIN
         SET @b_Success = 0
         GOTO QUIT
      END

      SET @c_SQL = N'SELECT @c_FromValue = CASE @n_FromColType' 
                 +                       ' WHEN 61 THEN CONVERT( NVARCHAR(30), ' + @c_SourceTable + '.' + @c_FromCol + ', 121)'
                 +                       ' ELSE CONVERT( NVARCHAR(MAX), ' + @c_SourceTable + '.' + @c_FromCol + ') END'
                 +                       ' FROM ' +@c_SourceTable + ' WITH (NOLOCK)'
                 + @c_Where

      SET @c_SQLParm =  N'@n_FromColType     INT'
                     +  ',@c_FromValue       NVARCHAR(4000) OUTPUT'


      EXEC sp_ExecuteSQL @c_SQL
                        ,@c_SQLParm
                        ,@n_FromColType
                        ,@c_FromValue        OUTPUT 
      GOTO QUIT
   END


   IF @c_Rule = 'SQL'
   BEGIN
      SET @c_CustomSQL = REPLACE (@c_CustomSQL, 'SELECT', 'SELECT TOP 1 @c_FromValue = ') 

      IF CHARINDEX( 'WHERE', @c_CustomSQL, 1 ) <= 0
      BEGIN 
         SET @c_CustomSQL = @c_CustomSQL + @c_Where
      END

      SET @c_SQL     = N'' + @c_CustomSQL 

      SET @c_SQLParm =  N'@c_ReceiptKey          NVARCHAR(10)'
                     +  ',@c_ReceiptLineNumber   NVARCHAR(30)'
                     +  ',@c_WorkOrderkey        NVARCHAR(10)'
                     +  ',@c_FromValue           NVARCHAR(4000) OUTPUT'

      EXEC sp_ExecuteSQL @c_SQL
                        ,@c_SQLParm
                       , @c_SourceKey
                       , @c_SourceLineNumber
                       , @c_SourceKey
                        ,@c_FromValue        OUTPUT 
      GOTO QUIT
   END

   IF @c_Rule = 'STOREDPROC'
   BEGIN
      SET @c_SPName = @c_CustomSQL
      IF EXISTS (SELECT 1 FROM dbo.sysobjects WHERE name = RTRIM(@c_SPName) AND type = 'P')          
      BEGIN 
         SET @c_SQL = 'EXEC ' + @c_SPName + ' @c_SourceTable, @c_SourceKey, @c_SourceLineNumber '
                              + ', @c_ListName, @c_Code, @c_ToCol, @c_FromValue OUTPUT, @b_Success OUTPUT'          

         SET @c_SQLParm =  N'@c_SourceTable        NVARCHAR(30)'
                        +  ',@c_SourceKey          NVARCHAR(30)'
                        +  ',@c_SourceLineNumber   NVARCHAR(30)'
                        +  ',@c_ListName           NVARCHAR(10)' 
                        +  ',@c_Code               NVARCHAR(30)'
                        +  ',@c_ToCol              NVARCHAR(60)'
                        +  ',@c_FromValue          NVARCHAR(4000) OUTPUT'
                        +  ',@b_Success            INT            OUTPUT'
                            
         EXEC sp_executesql @c_SQL          
                          , @c_SQLParm  
                          , @c_SourceTable                          
                          , @c_SourceKey
                          , @c_SourceLineNumber
                          , @c_ListName
                          , @c_Code
                          , @c_ToCol      
                          , @c_FromValue  OUTPUT          
                          , @b_Success    OUTPUT         

         GOTO QUIT
      END
   END
  
   QUIT:
END

GO
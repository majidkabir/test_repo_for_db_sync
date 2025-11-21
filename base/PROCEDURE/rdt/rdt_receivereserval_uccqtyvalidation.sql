SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_ReceiveReserval_UCCQtyValidation                */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purposes:                                                            */
/* 1) To Retrieve Result set with the given ASN#, LOC, ID, UCC          */
/*                                                                      */
/* Called from: 3                                                       */
/*    1. From PowerBuilder                                              */
/*    2. From scheduler                                                 */
/*    3. From others stored procedures or triggers                      */
/*    4. From interface program. DX, DTS                                */
/*                                                                      */
/* Exceed version: 5.4                                                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/************************************************************************/

CREATE PROC [RDT].[rdt_ReceiveReserval_UCCQtyValidation] (
   @cReceiptKey    NVARCHAR(10),
   @cLOC           NVARCHAR(10),
   @cID            NVARCHAR(18),
   @cUCC           NVARCHAR(20),
   @cStorerkey     NVARCHAR(15),
   @cNewQty        NVARCHAR(4),
   @cReceiptLineNo NVARCHAR(5)    OUTPUT,
   @cResult        NVARCHAR(1)    OUTPUT
) AS
BEGIN
SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF
SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cSQL             NVARCHAR(4000),
           @cSQL1            NVARCHAR(4000),
           @cExecStatements  NVARCHAR(4000),
           @cExecArguments   NVARCHAR(4000),
           @n_debug          INT   

   DECLARE @nTotalExpectedQty INT,
           @nTotalUCCQty      INT,
           @nUCCNoCnt         INT,
           @nNewQty           INT

   SET @n_debug = 0
   SET @cSQL = ''
   SET @cSQL1 = ''
      
   IF @cLOC <> '' AND @cLOC IS NOT NULL
   BEGIN
      SELECT @cSQL = RTRIM(@cSQL) + ' AND UCC.LOC = N''' + RTRIM(@cLOC) + ''''
   END

   IF @cID <> '' AND @cID IS NOT NULL
   BEGIN
      SELECT @cSQL = RTRIM(@cSQL) + ' AND UCC.ID = N''' + RTRIM(@cID) + ''''
   END

   IF (@cUCC <> '' AND @cUCC IS NOT NULL) --AND (@cPrevUCC = '' OR @cPrevUCC IS NULL)
   BEGIN
      SELECT @cSQL = RTRIM(@cSQL) + ' AND UCC.UCCNo = N''' + RTRIM(@cUCC) + ''''
   END
   
-- 
--    IF @cPrevUCC <> '' AND @cPrevUCC IS NOT NULL
--    BEGIN
--         SELECT @cSQL = RTRIM(@cSQL) + ' AND UCC.UCCNo > ''' + RTRIM(@cPrevUCC) + ''''
--    END 

   SELECT @cSQL = RTRIM(@cSQL)

   IF @n_debug = 1
   BEGIN
     Print @cSQL
   END

	SET @cExecStatements = ''
	SET @cExecArguments = ''
   SET @cExecStatements = N'SELECT TOP 1 '
                           + '@cReceiptLineNo = RTRIM(RD.ReceiptLineNumber) '
                           + 'FROM dbo.UCC UCC (NOLOCK) '
                           + 'JOIN dbo.RECEIPTDETAIl RD (NOLOCK) '
                           + ' ON (RD.ReceiptKey = UCC.ReceiptKey AND RD.Storerkey = UCC.Storerkey '
                           + '     AND RD.ReceiptLineNumber = UCC.ReceiptLineNumber) '
                           + 'JOIN dbo.SKU SKU (NOLOCK) ' 
                           + ' ON (RD.SKU = SKU.SKU AND RD.Storerkey = SKU.Storerkey) '
                           + 'JOIN dbo.PACK PACK (NOLOCK) ' 
                           + ' ON (SKU.PackKey = PACK.PackKey) '
                           + 'WHERE UCC.Storerkey = @cStorerkey '  
                           + 'AND   UCC.ReceiptKey = @cReceiptKey '
                           + 'AND   UCC.Status = ''1'' '
                           + @cSQL
                           + ' ORDER BY UCC.UCCNo '

   IF @n_debug = 1
   BEGIN
      PRint @cExecStatements
   END

   SET @cExecArguments = N'@cStorerkey  NVARCHAR(20), ' + 
                          '@cReceiptKey NVARCHAR(10), ' +
                          '@cReceiptLineNo NVARCHAR(5) OUTPUT ' 


   EXEC sp_ExecuteSql @cExecStatements, @cExecArguments 
                     ,@cStorerkey
                     ,@cReceiptKey
                     ,@cReceiptLineNo OUTPUT


--    SELECT @cReceiptLineNo, '@cReceiptLineNo'

	SET @cExecStatements = ''
	SET @cExecArguments = ''
   SET @cExecStatements = N'SELECT '
                           + '@nUCCNoCnt = COUNT(UCC.UCCNo) '
                           + 'FROM dbo.UCC UCC (NOLOCK) '
                           + 'WHERE UCC.Storerkey = @cStorerkey '  
                           + 'AND   UCC.ReceiptKey = @cReceiptKey '
                           + 'AND   UCC.Status = ''1'' '
                           + 'AND   UCC.ReceiptLineNumber = @cReceiptLineNo '
                           + ' GROUP BY UCC.Storerkey, UCC.ReceiptKey, UCC.ReceiptLineNumber '

   IF @n_debug = 1
   BEGIN
      PRint @cExecStatements
   END

   SET @cExecArguments = N'@cStorerkey  NVARCHAR(20), ' + 
                          '@cReceiptKey NVARCHAR(10), ' +
                          '@cReceiptLineNo NVARCHAR(5), ' +
                          '@nUCCNoCnt int OUTPUT '


   EXEC sp_ExecuteSql @cExecStatements, @cExecArguments 
                     ,@cStorerkey
                     ,@cReceiptKey
                     ,@cReceiptLineNo
                     ,@nUCCNoCnt OUTPUT



   IF (@cUCC <> '' AND @cUCC IS NOT NULL) AND (@nUCCNoCnt > 1)
   BEGIN
      SELECT @cSQL1 = ' AND UCC.UCCNo <> N''' + RTRIM(@cUCC) + ''''
   END

--   SELECT @cSQL1, '@cSQL1'

	SET @cExecStatements = ''
	SET @cExecArguments = ''
   SET @cExecStatements = N'SELECT '
                           + '@nTotalUCCQty = SUM(UCC.Qty) '
                           + 'FROM dbo.UCC UCC (NOLOCK) '
                           + 'JOIN dbo.RECEIPTDETAIl RD (NOLOCK) '
                           + ' ON (RD.ReceiptKey = UCC.ReceiptKey AND RD.Storerkey = UCC.Storerkey '
                           + '     AND RD.ReceiptLineNumber = UCC.ReceiptLineNumber) '
                           + 'JOIN dbo.SKU SKU (NOLOCK) ' 
                           + ' ON (RD.SKU = SKU.SKU AND RD.Storerkey = SKU.Storerkey) '
                           + 'JOIN dbo.PACK PACK (NOLOCK) ' 
                           + ' ON (SKU.PackKey = PACK.PackKey) '
                           + 'WHERE UCC.Storerkey = @cStorerkey '  
                           + 'AND   UCC.ReceiptKey = @cReceiptKey '
                           + 'AND   UCC.Status = ''1'' '
                           + 'AND   UCC.ReceiptLineNumber = @cReceiptLineNo '
                           +  @cSQL1
                           + ' GROUP BY UCC.ReceiptKey,UCC.ReceiptLineNumber '

   IF @n_debug = 1
   BEGIN
      PRint @cExecStatements
   END

   SET @cExecArguments = N'@cStorerkey  NVARCHAR(20), ' + 
                          '@cReceiptKey NVARCHAR(10), ' +
                          '@cReceiptLineNo NVARCHAR(5), ' +
                          '@nTotalUCCQty int OUTPUT '


   EXEC sp_ExecuteSql @cExecStatements, @cExecArguments 
                     ,@cStorerkey
                     ,@cReceiptKey
                     ,@cReceiptLineNo
                     ,@nTotalUCCQty OUTPUT


--    SELECT @nTotalUCCQty, '@nTotalUCCQty'


	SET @cExecStatements = ''
	SET @cExecArguments = ''
   SET @cExecStatements = N'SELECT '
                           + '@nTotalExpectedQty = SUM(RD.QtyExpected) '
                           + 'FROM dbo.RECEIPTDETAIl RD (NOLOCK) '
                           + 'WHERE RD.Storerkey = @cStorerkey '  
                           + 'AND   RD.ReceiptKey = @cReceiptKey '
                           + 'AND   RD.ReceiptLineNumber = @cReceiptLineNo '
                           + 'GROUP BY RD.ReceiptLineNumber '

   IF @n_debug = 1
   BEGIN
      PRint @cExecStatements
   END

   SET @cExecArguments = N'@cStorerkey  NVARCHAR(20), ' + 
                          '@cReceiptKey NVARCHAR(10), ' +
                          '@cReceiptLineNo NVARCHAR(5), ' +
                          '@nTotalExpectedQty int OUTPUT '


   EXEC sp_ExecuteSql @cExecStatements, @cExecArguments 
                     ,@cStorerkey
                     ,@cReceiptKey
                     ,@cReceiptLineNo
                     ,@nTotalExpectedQty OUTPUT

--    SELECT @nTotalExpectedQty, '@nTotalExpectedQty'

   
   SELECT @nNewQty = CAST(@cNewQty AS INT) + @nTotalUCCQty

--   SELECT @nNewQty, '@nNewQty'
   
   IF @nNewQty > @nTotalExpectedQty
   BEGIN 
      SELECT @cResult = '0' 
   END
   ELSE
   BEGIN
      SELECT @cResult = '1' 
   END

END


GO
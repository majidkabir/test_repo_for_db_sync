SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_ReceiveReserval_UCCRetrieve                     */
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

CREATE PROC [RDT].[rdt_ReceiveReserval_UCCRetrieve] (
   @cReceiptKey     NVARCHAR(10),
   @cLOC            NVARCHAR(10),
   @cID             NVARCHAR(18),
   @cUCC            NVARCHAR(20),
   @cStorerkey      NVARCHAR(15),
   @cPrevUCC        NVARCHAR(20),
   @nRecCnt         INT,
   @nPrevTotalCount INT,
   @cCurrentUCC     NVARCHAR(20)    OUTPUT,
   @nTotalCount     INT         OUTPUT,
   @cSKU            NVARCHAR(20)    OUTPUT,
   @cSKUDescr       NVARCHAR(60)    OUTPUT,
   @cUOM            NVARCHAR(10)    OUTPUT,
   @nQty            INT         OUTPUT,
   @cPPK            NVARCHAR(6)     OUTPUT,
   @cLottable1      NVARCHAR(18)    OUTPUT,
   @cLottable2      NVARCHAR(18)    OUTPUT,
   @cLottable3      NVARCHAR(18)    OUTPUT,
   @dLottable4      DATETIME    OUTPUT,
   @dLottable5      DATETIME    OUTPUT
) AS
BEGIN
SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF
SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cSQL             NVARCHAR(4000),
           @cExecStatements  NVARCHAR(4000),
           @cExecArguments   NVARCHAR(4000),
           @n_debug          INT   

   SET @n_debug = 0
   SET @nQTY = 0
   SET @cSQL = ''
      
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
    
   IF (@nPrevTotalCount > 1) --AND (@cPrevUCC <> '' AND @cPrevUCC IS NOT NULL)
   BEGIN
        SELECT @cSQL = RTRIM(@cSQL) + ' AND UCC.UCCNo > N''' + RTRIM(@cPrevUCC) + ''''
   END 

   SELECT @cSQL = RTRIM(@cSQL)

   IF @n_debug = 1
   BEGIN
     Print @cSQL
   END

	SET @cExecStatements = ''
	SET @cExecArguments = ''
   SET @cExecStatements = N'SELECT TOP 1 '
                           + '@cSKU = RTRIM(SKU.SKU), '
                           + '@cSKUDescr = RTRIM(SKU.DESCR), '
                           + '@cUOM = RTRIM(PACK.PACKUOM3), ' 
                           + '@cCurrentUCC = RTRIM(UCC.UCCNo), '
                           + '@nQty = UCC.QTY, '
                           + '@cPPK = RTRIM(SKU.PrePackIndicator), '
                           + '@cLottable1 = RTRIM(RD.Lottable01), '
                           + '@cLottable2 = RTRIM(RD.Lottable02), '
                           + '@cLottable3 = RTRIM(RD.Lottable03), '
                           + '@dLottable4 = RTRIM(RD.Lottable04), '
                           + '@dLottable5 = RTRIM(RD.Lottable05) '
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
                          '@cSKU        NVARCHAR(20) OUTPUT, ' + 
                          '@cSKUDescr   NVARCHAR(60) OUTPUT, ' +
                          '@cUOM        NVARCHAR(10) OUTPUT, ' +
                          '@cCurrentUCC NVARCHAR(20) OUTPUT, ' +
                          '@nQty        INT      OUTPUT, ' +
                          '@cPPK        NVARCHAR(6)  OUTPUT, ' +
                          '@cLottable1  NVARCHAR(18) OUTPUT, ' +
                          '@cLottable2  NVARCHAR(18) OUTPUT, ' +
                          '@cLottable3  NVARCHAR(18) OUTPUT, ' +
                          '@dLottable4  datetime OUTPUT, ' +
                          '@dLottable5  datetime OUTPUT  ' 


   EXEC sp_ExecuteSql @cExecStatements, @cExecArguments 
                     ,@cStorerkey
                     ,@cReceiptKey
                     ,@cSKU        OUTPUT
                     ,@cSKUDescr   OUTPUT      
                     ,@cUOM        OUTPUT  
                     ,@cCurrentUCC OUTPUT  
                     ,@nQty        OUTPUT  
                     ,@cPPK        OUTPUT  
                     ,@cLottable1  OUTPUT  
                     ,@cLottable2  OUTPUT  
                     ,@cLottable3  OUTPUT  
                     ,@dLottable4  OUTPUT  
                     ,@dLottable5  OUTPUT  


   SET @nRecCnt = @@ROWCOUNT

   IF (@nRecCnt > 0) AND (@nPrevTotalCount = 0)
   BEGIN
		SET @cExecStatements = ''
		SET @cExecArguments = ''
	   SET @cExecStatements = N'SELECT @nTotalCount = COUNT(UCCNo) '
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
                              + ' GROUP BY UCC.ReceiptKey '
	
	   SET @cExecArguments = N'@cStorerkey  NVARCHAR(20), ' + 
	                          '@cReceiptKey NVARCHAR(10), ' +
	                          '@nTotalCount int      OUTPUT  ' 

		IF @n_debug = 1
		BEGIN
		   PRint @cExecStatements
		END
	
	
	   EXEC sp_ExecuteSql @cExecStatements, @cExecArguments 
	                     ,@cStorerkey
	                     ,@cReceiptKey
                        ,@nTotalCount OUTPUT
	END
   ELSE
   BEGIN
       SET @nTotalCount = @nPrevTotalCount
   END
END


GO
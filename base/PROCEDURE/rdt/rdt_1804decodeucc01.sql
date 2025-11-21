SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_1804DecodeUCC01                                 */
/* Purpose: Decode UCC                                                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Author    Ver.  Purposes                                */
/* 2017-03-24   Ung       1.0   WMS-1371 Created                        */
/************************************************************************/
CREATE PROCEDURE [RDT].[rdt_1804DecodeUCC01]
    @nMobile         INT
   ,@nFunc           INT
   ,@cLangCode       NVARCHAR( 3)
   ,@cStorerKey      NVARCHAR( 15)
   ,@cFacility       NVARCHAR(  5)
   ,@cFromLOC        NVARCHAR( 10)
   ,@cFromID         NVARCHAR( 18)
   ,@cSKU            NVARCHAR( 20)
   ,@nQTY            INT
   ,@cToID           NVARCHAR( 18)
   ,@cToLOC          NVARCHAR( 10)
   ,@cBarcode        NVARCHAR( 60) 
   ,@cUCC            NVARCHAR( 20) OUTPUT
   ,@cUserdefined01  NVARCHAR( 15) OUTPUT
   ,@cUserdefined02  NVARCHAR( 15) OUTPUT
   ,@cUserdefined03  NVARCHAR( 20) OUTPUT
   ,@cUserdefined04  NVARCHAR( 30) OUTPUT
   ,@cUserdefined05  NVARCHAR( 30) OUTPUT
   ,@cUserdefined06  NVARCHAR( 30) OUTPUT
   ,@cUserdefined07  NVARCHAR( 30) OUTPUT
   ,@cUserdefined08  NVARCHAR( 30) OUTPUT
   ,@cUserdefined09  NVARCHAR( 30) OUTPUT
   ,@cUserdefined10  NVARCHAR( 30) OUTPUT
   ,@nErrNo          INT           OUTPUT
   ,@cErrMsg         NVARCHAR( 20) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nTranCount INT
   SET @nTranCount = @@TRANCOUNT

   -- Move To UCC
   IF @nFunc = 1804
   BEGIN
      IF @cBarcode <> ''
      BEGIN
         DECLARE
            @c_oFieled01 NVARCHAR(60), @c_oFieled02 NVARCHAR(20),
            @c_oFieled03 NVARCHAR(20), @c_oFieled04 NVARCHAR(20),
            @c_oFieled05 NVARCHAR(20), @c_oFieled06 NVARCHAR(20),
            @c_oFieled07 NVARCHAR(20), @c_oFieled08 NVARCHAR(20),
            @c_oFieled09 NVARCHAR(20), @c_oFieled10 NVARCHAR(20), 
            @bSuccess    INT

         -- Retain value
         SET @c_oFieled01 = @cBarcode
         SET @c_oFieled08 = '' --@cBatchNo
         SET @c_oFieled09 = '' --@cCaseID

         -- ispMHTLabelNoDecode
         EXEC dbo.ispLabelNo_Decoding_Wrapper
             @c_SPName     = 'ispMHTLabelNoDecode'
            ,@c_LabelNo    = @cBarCode
            ,@c_Storerkey  = @cStorerKey
            ,@c_ReceiptKey = ''
            ,@c_POKey      = ''
            ,@c_LangCode   = @cLangCode
            ,@c_oFieled01  = @c_oFieled01 OUTPUT   -- SKU
            ,@c_oFieled02  = @c_oFieled02 OUTPUT   -- STYLE
            ,@c_oFieled03  = @c_oFieled03 OUTPUT   -- COLOR
            ,@c_oFieled04  = @c_oFieled04 OUTPUT   -- SIZE
            ,@c_oFieled05  = @c_oFieled05 OUTPUT   -- QTY
            ,@c_oFieled06  = @c_oFieled06 OUTPUT   -- CO#
            ,@c_oFieled07  = @c_oFieled07 OUTPUT   -- Lottable01
            ,@c_oFieled08  = @c_oFieled08 OUTPUT   -- Lottable02
            ,@c_oFieled09  = @c_oFieled09 OUTPUT   -- Lottable03
            ,@c_oFieled10  = @c_oFieled10 OUTPUT   -- Lottable04
            ,@b_Success    = @bSuccess    OUTPUT
            ,@n_ErrNo      = @nErrNo      OUTPUT
            ,@c_ErrMsg     = @cErrMsg     OUTPUT

         IF @cErrMsg <> ''
            GOTO Quit

         SET @cUCC = @c_oFieled08 + @c_oFieled09 -- BatchNo + CaseID
         SET @cUserdefined01 = @c_oFieled09 -- CaseID
         SET @cUserdefined02 = @c_oFieled08 -- BatchNo
      END
   END

Quit:

END

GO
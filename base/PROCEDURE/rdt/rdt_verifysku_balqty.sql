SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_VerifySKU_BalQTY                                */
/* Copyright      : LFLogistics                                         */
/*                                                                      */
/* Purpose: Verify pallet Ti Hi setting                                 */
/*                                                                      */
/* Date        Rev  Author       Purposes                               */
/* 21-09-2015  1.0  Ung          SOS347397. Created                     */
/************************************************************************/
            
CREATE PROCEDURE [RDT].[rdt_VerifySKU_BalQTY]
   @nMobile     INT,
   @nFunc       INT,
   @cLangCode   NVARCHAR( 3),
   @nStep       INT, 
   @nInputKey   INT, 
   @cFacility   NVARCHAR( 3), 
   @cStorerKey  NVARCHAR( 15),
   @cSKU        NVARCHAR( 20),
   @cType       NVARCHAR( 15),
   @cLabel      NVARCHAR( 30)  OUTPUT, 
   @cShort      NVARCHAR( 10)  OUTPUT, 
   @cValue      NVARCHAR( MAX) OUTPUT, 
   @nErrNo      INT            OUTPUT,
   @cErrMsg     NVARCHAR( 20)  OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cSUSR4 NVARCHAR(18)   
   
   /***********************************************************************************************
                                                 CHECK
   ***********************************************************************************************/
   IF @cType = 'CHECK'
   BEGIN
      -- Get session info
      DECLARE @cReceiptKey NVARCHAR(10)
      SELECT @cReceiptKey = V_ReceiptKey FROM rdt.rdtMobRec WITH (NOLOCK) WHERE UserName = SUSER_SNAME()
      
      -- Get Bal QTY
      IF @cReceiptKey <> ''
      BEGIN
         DECLARE @nQTYExp INT
         DECLARE @nQTYRcv INT
         DECLARE @nBalQTY INT

         -- Get statistic
         SELECT 
            @nQTYExp = ISNULL( SUM( QTYExpected), 0), 
            @nQTYRcv = ISNULL( SUM( BeforeReceivedQTY), 0)
         FROM ReceiptDetail WITH (NOLOCK)
         WHERE ReceiptKey = @cReceiptKey
            AND StorerKey = @cStorerKey 
            AND SKU = @cSKU
         
         IF @nQTYExp > @nQTYRcv
            SET @cValue = CAST( @nQTYExp - @nQTYRcv AS NVARCHAR(10))
         ELSE
            SET @cValue = '0'
      END
   END

   /***********************************************************************************************
                                                 UPDATE
   ***********************************************************************************************/
   -- Check SKU setting
   IF @cType = 'UPDATE'
   BEGIN
      -- Exit
      GOTO Quit
   END
   
Quit:
   
END

GO
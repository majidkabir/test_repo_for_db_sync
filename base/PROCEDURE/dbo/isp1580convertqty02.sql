SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: isp1580ConvertQty02                                 */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Called from: rdtfnc_PieceReceiving                                   */
/*                                                                      */
/* Date         Rev  Author      Purposes                               */
/* 02-Jun-2020  1.0  Ung         WMS-13066 Created                      */
/************************************************************************/
CREATE PROCEDURE [dbo].[isp1580ConvertQty02]
   @cType         NVARCHAR( 10),
   @cStorerKey    NVARCHAR( 15),
   @cSKU          NVARCHAR( 20),
   @nQTY          INT OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nFunc             INT
   DECLARE @cPackQTYIndicator NVARCHAR( 5)
   DECLARE @cPrePackIndicator NVARCHAR( 1)

   -- Get session info
   SELECT @nFunc = Func FROM rdt.rdtMobRec WITH (NOLOCK) WHERE UserName = SUSER_SNAME()

   -- FN1580 for normal receiving (by prepack)
   -- FN1581 for return (by piece)
   IF @nFunc = 1580 -- Piece receiving
   BEGIN
      -- Get SKU info
      SELECT
         @cPackQTYIndicator = S.PackQTYIndicator,
         @cPrePackIndicator = S.PrePackIndicator
      FROM dbo.Sku S WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
         AND SKU = @cSKU

      -- Check valid prepack indicator
      IF @cPrePackIndicator <> '2'
         SET @cPackQTYIndicator = ''
      ELSE IF RDT.rdtIsValidQTY( @cPackQTYIndicator, 1) <> 1
         SET @cPackQTYIndicator = ''

      IF @cPackQTYIndicator <> ''
      BEGIN
         DECLARE @nPackQTYIndicator INT
         SET @nPackQTYIndicator = CAST( @cPackQTYIndicator AS INT)
         
         IF @cType = 'ToDispQTY'
            SET @nQTY = @nQTY / @nPackQTYIndicator

         IF @cType = 'ToBaseQTY'
            SET @nQTY = @nQTY * @nPackQTYIndicator
      END
   END
   
Quit:

END

GO
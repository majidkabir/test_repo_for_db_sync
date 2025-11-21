SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_539ExtInfo                                      */
/* Purpose: Show balance QTY in UCC after picked                        */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Author    Ver.  Purposes                                */
/* 2016-02-01   Ung       1.0   SOS359990 Created                       */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_539ExtInfo]
   @nMobile        INT, 
   @nFunc          INT, 
   @cLangCode      NVARCHAR( 3), 
   @nStep          INT, 
   @nAfterStep     INT, 
   @nInputKey      INT,  
   @cFacility      NVARCHAR( 15), 
   @cStorerKey     NVARCHAR( 15), 
   @cUCC           NVARCHAR( 20), 
   @cSKU           NVARCHAR( 20), 
   @cExtendedInfo  NVARCHAR( 20) OUTPUT, 
   @nErrNo         INT           OUTPUT, 
   @cErrMsg        NVARCHAR( 20) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   IF @nFunc = 539 -- Verify UCC
   BEGIN
      IF @nAfterStep = 2 -- SKU
      BEGIN
         DECLARE @nQTY       INT
         DECLARE @nQTYBal    INT
         DECLARE @nQTYPicked INT

         -- Get UCC info
         SELECT @nQTY = QTY
         FROM UCC WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
            AND UCCNo = @cUCC

         -- Get QTYPicked info
         SELECT @nQTYPicked = ISNULL( SUM( QTY), 0)
         FROM dbo.PickDetail WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
            AND DropID = @cUCC
            AND Status >= '5'
            AND QTY > 0
         
         SET @nQTYBal = @nQTY - @nQTYPicked
         SET @cExtendedInfo = 'QTY BAL: ' + CAST( @nQTYBal AS NVARCHAR(5))
      END
   END
END

GO
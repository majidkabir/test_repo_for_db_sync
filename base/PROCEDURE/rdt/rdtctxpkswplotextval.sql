SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdtCTXPkSwpLotExtVal                                */
/* Purpose: Validate DropID key-in                                      */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Author    Ver.  Purposes                                */
/* 2013-02-21   Ung       1.0   SOS306868 Created                       */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdtCTXPkSwpLotExtVal]
   @nMobile         INT,
   @nFunc           INT,
   @cLangCode       NVARCHAR( 3),
   @nStep           INT,
   @cStorerKey      NVARCHAR( 15),
   @cFacility       NVARCHAR(  5),
   @cPickSlipNo     NVARCHAR( 10),
   @cLOT            NVARCHAR( 10),
   @cLOC            NVARCHAR( 10),
   @cID             NVARCHAR( 18),
   @cSKU            NVARCHAR( 20),
   @nBalQTY         INT,
   @nActQTY         INT,
   @cDropID         NVARCHAR( 20),
   @nErrNo          INT OUTPUT,
   @cErrMsg         NVARCHAR( 20) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @b_Success   INT
   DECLARE @n_err       INT
   DECLARE @c_errmsg    NVARCHAR( 250)

   -- Dynamic pick and pack
   IF @nFunc = 1640
   BEGIN
      IF @nStep = 5 -- QTY, DropID
      BEGIN
         IF @cDropID = ''
         BEGIN
            SET @nErrNo = 86751
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- Need DropID
         END
      END
   END
END

Quit:

GO
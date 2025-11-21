SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_898ExtInfo04                                    */
/* Copyright      : Maersk                                              */
/* Customer       : Granite                                             */
/*                                                                      */
/* Date       Rev    Author  Purposes                                   */
/* 2024-10-07 1.0.0  NLT013  FCR-926 Created                            */
/* 2025-01-02 1.0.1  JCH507  FCR-1103 Adapt for extscn02                */
/************************************************************************/

CREATE   PROCEDURE [RDT].[rdt_898ExtInfo04]
    @nMobile       INT
   ,@nFunc         INT
   ,@cLangCode     NVARCHAR( 3)
   ,@nStep         INT
   ,@nAfterStep    INT
   ,@nInputKey     INT
   ,@cReceiptKey   NVARCHAR( 10)
   ,@cPOKey        NVARCHAR( 10)
   ,@cLOC          NVARCHAR( 10)
   ,@cToID         NVARCHAR( 18)
   ,@cLottable01   NVARCHAR( 18)
   ,@cLottable02   NVARCHAR( 18)
   ,@cLottable03   NVARCHAR( 18)
   ,@dLottable04   DATETIME
   ,@cUCC          NVARCHAR( 20)
   ,@cSKU          NVARCHAR( 20)
   ,@nQTY          INT
   ,@cParam1       NVARCHAR( 20)
   ,@cParam2       NVARCHAR( 20)
   ,@cParam3       NVARCHAR( 20)
   ,@cParam4       NVARCHAR( 20)
   ,@cParam5       NVARCHAR( 20)
   ,@cOption       NVARCHAR( 1)
   ,@cExtendedInfo NVARCHAR( 20) OUTPUT
   ,@nErrNo       INT            OUTPUT
   ,@cErrMsg      NVARCHAR( 20)  OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   SET @cExtendedInfo = '' --V1.0.1

   DECLARE 
      @cStorerKey       NVARCHAR(20),
      @cFacility        NVARCHAR(10),
      @nScannedUCC      INT,
      @nScn             INT --v1.0.1

   SELECT @cStorerKey = StorerKey,
      @cFacility = Facility,
      @nScn = Scn
   FROM RDT.RDTMOBREC WITH(NOLOCK)
   WHERE Mobile = @nMobile

   IF @nFunc = 898 -- UCC receiving
   BEGIN
      IF @nAfterStep = 6 -- UCC
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
               -- Get total scanned 
               SELECT @nScannedUCC = COUNT( DISTINCT UCC)
               FROM RDT.RDTSTDEVENTLOG WITH(NOLOCK)
               WHERE FunctionID = @nFunc 
                  AND Facility = @cFacility
                  AND StorerKey = @cStorerKey 
                  AND ID = @cToID
                  AND ISNULL(Refno1, '') <> 'CLOSE'
            -- Output balance/total
            SET @cExtendedInfo = 'Scanned UCC: ' +  CAST (@nScannedUCC AS NVARCHAR(5))
         END
      END
      IF @nStep = 10 AND @nScn = 1308 AND @nAfterStep = 99 --ExtScn02 Step10 branch --V1.0.1 start
      BEGIN
         -- Get total scanned 
         SELECT @nScannedUCC = COUNT( DISTINCT UCC)
         FROM RDT.RDTSTDEVENTLOG WITH(NOLOCK)
         WHERE FunctionID = @nFunc 
            AND Facility = @cFacility
            AND StorerKey = @cStorerKey 
            AND ID = @cToID
            AND ISNULL(Refno1, '') <> 'CLOSE'
         -- Output balance/total
         SET @cExtendedInfo = 'Scanned UCC: ' +  CAST (@nScannedUCC AS NVARCHAR(5))
      END --End of @nStep = 99 AND @nScn = 1305
      --v1.0.1 end
   END

Quit:

END

GO
SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_513Confirm01                                          */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Purpose: Move channel QTY, when from staging to normal                     */
/*                                                                            */
/* Date         Author    Ver.  Purposes                                      */
/* 2015-08-13   Ung       1.0   WMS-6866 Created                              */
/******************************************************************************/

CREATE PROCEDURE [RDT].[rdt_513Confirm01]
    @nMobile         INT 
   ,@nFunc           INT 
   ,@cLangCode       NVARCHAR( 3) 
   ,@nStep           INT 
   ,@nInputKey       INT
   ,@cStorerKey      NVARCHAR( 15)
   ,@cFacility       NVARCHAR(  5)
   ,@cFromLOC        NVARCHAR( 10)
   ,@cFromID         NVARCHAR( 18)
   ,@cSKU            NVARCHAR( 20)
   ,@nQTY            INT
   ,@cToID           NVARCHAR( 18)
   ,@cToLOC          NVARCHAR( 10)
   ,@nErrNo          INT           OUTPUT 
   ,@cErrMsg         NVARCHAR( 20) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   -- Handling transaction
   DECLARE @nTranCount INT
   SET @nTranCount = @@TRANCOUNT

   DECLARE @cLOCType    NVARCHAR(10)
   DECLARE @cReceiptKey NVARCHAR(10)
   DECLARE @cChannel    NVARCHAR(20)
   DECLARE @nChannel_ID BIGINT

   -- Move by SKU
   IF @nFunc = 513
   BEGIN
      IF @nStep = 6 -- ToLOC
      BEGIN
         IF @nInputKey = 1 -- Enter
         BEGIN
            SET @cLOCType = ''
            SET @cChannel = ''
            SET @nChannel_ID = 0
            
            -- Get from LOC info
            IF @cFromID <> '' 
               SELECT @cLOCType = LocationType FROM LOC WITH (NOLOCK) WHERE LOC = @cFromLOC 
               
            -- Get from ID info
            IF @cLOCType = 'STAGING'
               SELECT 
                  @cChannel = ISNULL( Channel, ''), 
                  @nChannel_ID = ISNULL( Channel_ID, 0)
               FROM ID WITH (NOLOCK) 
               WHERE ID = @cFromID
                     
            EXECUTE rdt.rdt_Move
               @nMobile     = @nMobile,
               @cLangCode   = @cLangCode,
               @nErrNo      = @nErrNo  OUTPUT,
               @cErrMsg     = @cErrMsg OUTPUT, -- screen limitation, 20 NVARCHAR max
               @cSourceType = 'rdt_513Confirm01',
               @cStorerKey  = @cStorerKey,
               @cFacility   = @cFacility,
               @cFromLOC    = @cFromLOC,
               @cToLOC      = @cToLOC,
               @cFromID     = @cFromID,     -- NULL means not filter by ID. Blank is a valid ID
               @cToID       = @cToID,       -- NULL means not changing ID. Blank consider a valid ID
               @cSKU        = @cSKU,
               @nQTY        = @nQTY, 
               @cChannel    = @cChannel, 
               @nChannel_ID = @nChannel_ID
            
            IF @nErrNo <> 0
               GOTO Quit
         END
      END
   END

Quit:

END

GO
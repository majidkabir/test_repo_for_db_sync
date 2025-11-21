SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdtVFMVSKUExtVal                                    */
/* Purpose: Return process move stock from stage to pick face,          */
/*          check ToLOC must same as assigned pick face                 */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Author    Ver.  Purposes                                */
/* 2013-08-26   Ung       1.0   SOS287899 Created                       */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdtVFMVSKUExtVal]
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

   -- Move by SKU
   IF @nFunc = 513
   BEGIN
      IF @nStep = 6 -- ToLOC
      BEGIN
         IF @nInputKey = 1 -- Enter
         BEGIN
            -- Get Receipt info
            DECLARE @cDocType NVARCHAR(1)
            DECLARE @cRecType NVARCHAR(10)
            SELECT 
               @cDocType = DocType, 
               @cRecType = RecType
            FROM Receipt R WITH (NOLOCK) 
               JOIN ReceiptDetail RD WITH (NOLOCK) ON (R.ReceiptKey = RD.ReceiptKey)
            WHERE R.StorerKey = @cStorerKey
               AND R.Facility = @cFacility
               AND RD.ToLOC = @cFromLOC
               AND RD.ToID = @cFromID
            
            -- Return and retail
            IF @cDocType = 'R' AND @cRecType IN (SELECT Code FROM CodeLKUP WITH (NOLOCK) WHERE ListName = 'RECTYPE' AND Short = 'R' AND StorerKey = @cStorerKey)
            BEGIN
               DECLARE @cPickLOC NVARCHAR( 10)
               DECLARE @cPutawayZone NVARCHAR(10)
               SET @cPickLOC = ''
               SET @cPutawayZone = ''
   
               -- Get SKU info
               SELECT @cPutawayZone = PutawayZone
               FROM SKU WITH (NOLOCK)
               WHERE StorerKey = @cStorerKey
                  AND SKU = @cSKU
   
               -- Find a friend with actual stock
               IF @cPickLOC = ''
                  SELECT TOP 1
                     @cPickLOC = LOC.LOC
                  FROM SKUxLOC SL WITH (NOLOCK)
                     JOIN LOC WITH (NOLOCK) ON (SL.LOC = LOC.LOC)
                  WHERE LOC.Facility = @cFacility
                     AND StorerKey = @cStorerKey
                     AND SKU = @cSKU
                     AND LOC.PutawayZone = @cPutawayZone
                     AND LOC.LocationCategory = 'RESALE'
                     AND LOC.LocationGroup <> 'HIGHVOLUME'
                     AND SL.QTY - SL.QTYPicked > 0
   
               -- Find a friend with pending move in
               IF @cPickLOC = ''
                  SELECT TOP 1
                     @cPickLOC = LOC.LOC
                  FROM LOTxLOCxID LLI WITH (NOLOCK)
                     JOIN LOC WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
                  WHERE LOC.Facility = @cFacility
                     AND StorerKey = @cStorerKey
                     AND SKU = @cSKU
                     AND LOC.PutawayZone = @cPutawayZone
                     AND LOC.LocationCategory = 'RESALE'
                     AND LOC.LocationGroup <> 'HIGHVOLUME'
                     AND LLI.PendingMoveIn > 0
   /*
               -- Find empty and not assigned pick face 
               IF @cPickLOC = ''
                  SELECT TOP 1
                     @cPickLOC = LOC.LOC
                  FROM LOC WITH (NOLOCK) 
                     LEFT JOIN LOTxLOCxID LLI WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
                     LEFT JOIN SKUxLOC SL WITH (NOLOCK) ON (LLI.StorerKey = SL.StorerKey AND LLI.SKU = SL.SKU AND LLI.LOC = SL.LOC)
                  WHERE LOC.Facility = @cFacility
                     AND LOC.PutawayZone = @cPutawayZone
                     AND LOC.LocationCategory = 'RESALE'
                     AND LOC.LocationGroup <> 'HIGHVOLUME'
                  GROUP BY LOC.LOC
                  HAVING SUM( ISNULL( LLI.QTY, 0) - ISNULL( LLI.QTYPicked, 0)) = 0
                     AND SUM( ISNULL( LLI.PendingMoveIn, 0)) = 0
   */
   
               -- Blank ToLOC
               IF @cPickLOC = ''
               BEGIN
                  SET @nErrNo = 82201
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No assign LOC
                  GOTO Quit
               END         
   
               -- Check ToLOC
               IF @cPickLOC <> @cToLOC
               BEGIN
                  SET @nErrNo = 82202
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DiffAssignLOC
                  GOTO Quit
               END         
            END
         END
      END
   END
END

Quit:

GO
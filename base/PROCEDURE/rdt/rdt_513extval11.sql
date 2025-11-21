SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_513ExtVal11                                     */
/* Copyright: LF Logistics                                              */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2022-08-23 1.0  YeeKung   WMS-19594 Created                          */
/* 2023-06-09 1.1  YeeKung   WMS-22752 Add PopUp Scn (yeekung01)        */
/************************************************************************/

CREATE   PROC [RDT].[rdt_513ExtVal11] (
   @nMobile         INT,
   @nFunc           INT,
   @cLangCode       NVARCHAR( 3),
   @nStep           INT,
   @nInputKey       INT,
   @cStorerKey      NVARCHAR( 15),
   @cFacility       NVARCHAR(  5),
   @cFromLOC        NVARCHAR( 10),
   @cFromID         NVARCHAR( 18),
   @cSKU            NVARCHAR( 20),
   @nQTY            INT,
   @cToID           NVARCHAR( 18),
   @cToLOC          NVARCHAR( 10),
   @nErrNo          INT           OUTPUT,
   @cErrMsg         NVARCHAR( 20) OUTPUT
)
AS

SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF
SET CONCAT_NULL_YIELDS_NULL OFF

DECLARE @nMQTY INT
DECLARE @cDefaultUOM   NVARCHAR(5)

   IF @nStep = 4 -- QTY
   BEGIN
      IF @nInputKey = 1 -- ENTER
      BEGIN
         SELECT @nMQTY=I_Field11,
                @cDefaultUOM=V_UOM
         FROM Rdt.rdtmobrec (NOLOCK)
         Where mobile=@nMobile

         IF @cDefaultUOM<>'6' and ISNULL(@nMQTY,'') NOT IN (0,'')
         BEGIN
            SET @nErrNo = 190201 
            SET @cErrMsg = rdt.rdtgetmessage( 60551, @cLangCode, 'DSP') --'InvQtyField'
            GOTO QUIT
         END
      END
   END

   IF @nStep = 6 -- ToLOC
   BEGIN
      IF @nInputKey = 1 -- Enter
      BEGIN
         DECLARE @cLOCCat NVARCHAR(10)
         SELECT @cLOCCat = LocationCategory FROM LOC WITH (NOLOCK) WHERE LOC = @cFromLOC

         -- Receiving stage
         IF @cLOCCat = 'STAGING'
         BEGIN
            -- Check RFPutaway booking
            IF NOT EXISTS( SELECT TOP 1 1
               FROM RFPutaway WITH (NOLOCK)
               WHERE FromLOC = @cFromLOC
                  AND StorerKey = @cStorerKey 
                  AND SKU = @cSKU
                  AND SuggestedLOC = @cToLOC)
            BEGIN
               SET @nErrNo = 190202
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff LOC
               --(yeekung01)
               EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo, @cErrMsg, @cErrMsg
               GOTO QUIT
            END
         END
      END
   END


Quit:


GO
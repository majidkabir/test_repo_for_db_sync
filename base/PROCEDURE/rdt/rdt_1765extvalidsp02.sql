SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_1765ExtValidSP02                                      */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Purpose : This is to workaround TM Replen To, scanned TO LOC, scanned SKU, */
/*           QTY and confirm blocked by rdt_Move due to commingle SKU.        */
/*           So moved this checking up front to parent                        */
/*                                                                            */
/* Date        Rev  Author   Purposes                                         */
/* 30-05-2019  1.0  Ung      WMS-9166 Created                                 */
/******************************************************************************/

CREATE PROC [RDT].[rdt_1765ExtValidSP02] (
   @nMobile        INT,
   @nFunc          INT,
   @cLangCode      NVARCHAR( 3),
   @cUserName      NVARCHAR( 15),
   @cFacility      NVARCHAR( 5),
   @cStorerKey     NVARCHAR( 15),
   @cDROPID        NVARCHAR( 20),
   @nStep          INT,
   @cTaskDetailKey NVARCHAR(10),
   @nQty           INT,
   @nErrNo         INT           OUTPUT,
   @cErrMsg        NVARCHAR( 20) OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cToLOC NVARCHAR( 10)
   DECLARE @cCommingleSKU NVARCHAR(1)
   DECLARE @cSKU NVARCHAR(20)

   IF @nFunc = 1765 -- TM Replen To
   BEGIN
      IF @nStep = 3 -- TO LOC
      BEGIN
         -- Get session info
         SELECT @cToLOC = I_Field04 FROM rdt.rdtMobRec WITH (NOLOCK) WHERE Mobile = @nMobile

         -- Check ToLOC valid
         IF NOT EXISTS( SELECT 1 FROM LOC WITH (NOLOCK) WHERE LOC = @cToLOC AND Facility = @cFacility)
         BEGIN
            SET @nErrNo = 139351
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid ToLOC
            GOTO QUIT
         END

         -- Get LOC info
         SELECT @cCommingleSKU = CommingleSKU FROM LOC WITH (NOLOCK) WHERE LOC = @cToLOC
         
         -- LOC commingle SKU
         IF @cCommingleSKU = '0' -- Non-commingle
         BEGIN
            -- Get task info
            SELECT @cSKU = SKU FROM TaskDetail WITH (NOLOCK) WHERE TaskDetailKey = @cTaskDetailKey

            -- Check LOC have other SKU
            IF EXISTS( SELECT 1 
               FROM dbo.LOTxLOCxID WITH (NOLOCK)
               WHERE LOC = @cToLOC
                  AND StorerKey = @cStorerKey
                  AND SKU <> @cSKU
                  AND QTY > 0)
            BEGIN
               SET @nErrNo = 139352
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LOC not empty
               GOTO QUIT
            END
         END
      END
   END
END

Quit:


GO
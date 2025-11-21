SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_599ExtVal01                                     */
/* Purpose: RDT Receipt Reversal extended validate sp                   */
/*          Check if the pallet id has been moved from original         */
/*          receipt location                                            */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2015-08-21 1.0  James      SOS#338503. Created                       */
/************************************************************************/

CREATE PROC [RDT].[rdt_599ExtVal01] (
   @nMobile                   INT, 
   @nFunc                     INT, 
   @cLangCode                 NVARCHAR( 3), 
   @nStep                     INT, 
   @nInputKey                 INT, 
   @cStorerkey                NVARCHAR( 15), 
   @cReceiptKey               NVARCHAR( 10), 
   @cID                       NVARCHAR( 18), 
   @cSKU                      NVARCHAR( 20), 
   @nQty                      INT, 
   @cOption                   NVARCHAR( 1), 
   @nErrNo                    INT           OUTPUT,  
   @cErrMsg                   NVARCHAR( 20) OUTPUT  
)
AS

   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF

   DECLARE @cToLoc      NVARCHAR( 10), 
           @cLoc        NVARCHAR( 10) 

   IF @nInputKey = 1
   BEGIN
      IF @nStep = 2
      BEGIN
         IF ISNULL( @cID, '') = ''
            GOTO Quit

         SELECT TOP 1 @cLoc = LOC
         FROM dbo.LOTxLOCxID WITH (NOLOCK) 
         WHERE StorerKey = @cStorerKey
         AND   ID = @cID
         AND   Qty > 0

         IF ISNULL( @cLoc, '') <> ''
         BEGIN
            SELECT TOP 1 @cToLoc = ToLoc
            FROM dbo.ReceiptDetail WITH (NOLOCK) 
            WHERE ReceiptKey = @cReceiptKey
            AND   ToID = @cID
            AND   FinalizeFlag = 'Y'

            IF @cToLoc <> @cLoc
            BEGIN
               SET @nErrNo = 56201
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Pallet Moved 
               GOTO Quit
            END
         END
      END
   END
   Quit:  

   

GO
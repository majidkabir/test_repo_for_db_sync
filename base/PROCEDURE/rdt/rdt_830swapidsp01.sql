SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_830SwapIDSP01                                   */
/* Copyright      : LFLogistics                                         */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 13-03-2021  1.0  YeeKung     WMS-16543 Created                       */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_830SwapIDSP01]
   @nMobile       INT,
   @nFunc         INT,
   @cLangCode     NVARCHAR( 3),
   @nStep         INT,
   @nAfterStep    INT,
   @nInputKey     INT,
   @cFacility     NVARCHAR( 5),
   @cStorerKey    NVARCHAR( 15),
   @cPickSlipNo   NVARCHAR( 10),
   @cPickZone     NVARCHAR( 10),
   @cSuggLOC      NVARCHAR( 10),
   @cLOC          NVARCHAR( 10),
   @cDropID       NVARCHAR( 20),
   @cSKU          NVARCHAR( 20),
   @cLottable01   NVARCHAR( 18),
   @cLottable02   NVARCHAR( 18),
   @cLottable03   NVARCHAR( 18),
   @dLottable04   DATETIME,
   @dLottable05   DATETIME,
   @cLottable06   NVARCHAR( 30),
   @cLottable07   NVARCHAR( 30),
   @cLottable08   NVARCHAR( 30),
   @cLottable09   NVARCHAR( 30),
   @cLottable10   NVARCHAR( 30),
   @cLottable11   NVARCHAR( 30),
   @cLottable12   NVARCHAR( 30),
   @dLottable13   DATETIME,
   @dLottable14   DATETIME,
   @dLottable15   DATETIME,
   @nTaskQTY      INT,
   @nQTY          INT,
   @cToLOC        NVARCHAR( 10),
   @cOption       NVARCHAR( 1),
   @cSuggID       NVARCHAR( 20),
   @cID           NVARCHAR( 20),
   @nErrNo        INT           OUTPUT,
   @cErrMsg       NVARCHAR( 20) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF


   DECLARE @csuggeslot NVARCHAR(20),
           @clot       NVARCHAR(20)

   IF @nFunc = 830 -- PickSKU
   BEGIN
      IF EXISTS (SELECT 1 FROM loc (NOLOCK) WHERE loc=@cLOC AND LocationHandling='SHUTTLE')
      BEGIN
         SELECT @csuggeslot= LOT
         FROM dbo.LOTxLOCxID (NOLOCK)
         WHERE loc=@cLOC
         AND qty>0
         AND id=@cSuggID

         SELECT @clot= LOT
         FROM dbo.LOTxLOCxID (NOLOCK)
         WHERE loc=@cLOC
         AND qty>0
         AND id=@cID

         IF (@clot<>@csuggeslot)
         BEGIN      
            SET @nErrNo = 168501       
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff ID      
            GOTO quit      
         END    

         UPDATE pickdetail WITH (ROWLOCK)
         SET id=@cID
         WHERE id=@cSuggID 
         AND lot=@csuggeslot
         AND loc=@cLOC

         IF @@ERROR<>0
         BEGIN      
            SET @nErrNo = 168503      
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff ID      
            GOTO quit      
         END   

         GOTO QUIT
      END
      ELSE
      BEGIN
         -- Validate ID      
         IF @cID <> @cSuggID      
         BEGIN      
            SET @nErrNo = 168502      
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff ID      
            GOTO quit      
         END      
      END
   END


Quit:

END

GO
SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_830ExtVal01                                     */
/* Copyright      : LFLogistics                                         */
/*                                                                      */
/* Purpose: DropID compulsory                                           */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 21-06-2016  1.0  Ung         WMS-1715 Created                        */
/* 22-12-2020  1.1  YeeKung     WMS15995 Add Pickzone (yeekung01)       */  
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_830ExtVal01]
   @nMobile       INT,           
   @nFunc         INT,           
   @cLangCode     NVARCHAR( 3),  
   @nStep         INT,           
   @nInputKey     INT,           
   @cFacility     NVARCHAR( 5),  
   @cStorerKey    NVARCHAR( 15), 
   @cPickSlipNo   NVARCHAR( 10),
   @cPickZone     NVARCHAR( 10),--(yeekung01) 
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
   @nErrNo        INT           OUTPUT,
   @cErrMsg       NVARCHAR( 20) OUTPUT 
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   IF @nFunc = 830 -- PickSKU
   BEGIN
      IF @nStep = 2 -- LOC
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            IF @cDropID = ''
            BEGIN
               SET @nErrNo = 108401
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need DropID
               GOTO Quit
            END
         END
      END
   END
   
Quit:

END

GO
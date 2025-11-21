SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: isp_CV_IKEA                       */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Date       Rev  Author   Purposes                                    */
/*                                                                      */
/*                                                                      */
/************************************************************************/

CREATE PROC [rdt].[isp_CV_IKEA] (
   @nMobile       INT,           
   @nFunc         INT,           
   @cLangCode     NVARCHAR( 3),  
   @nStep         INT,           
   @nInputKey     INT,           
   @cFacility     NVARCHAR( 5),  
   @cStorerKey    NVARCHAR( 15), 
   @cPickSlipNo   NVARCHAR( 10), 
   @cPickZone     NVARCHAR( 10), --(yeekung01)
   @cSuggLOC      NVARCHAR( 10), 
   @cLOC          NVARCHAR( 10), 
   @cDropID       NVARCHAR( 20), 
   @cSKU          NVARCHAR( 20), 
   @cReceiptKey   NVARCHAR( 10), 
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
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE 
      @cPUOM              NVARCHAR( 10),
      @cUserName          NVARCHAR( 18),
      @cInField15         NVARCHAR( 60),
      @cLocationType      NVARCHAR( 10);

   IF @nFunc = 600 -- Normal Receipt
   BEGIN
      IF @nStep = 99 -- Additional Screen
      BEGIN
         IF @nInputKey = 1
         BEGIN
		    IF NOT EXISTS ( SELECT 1
					  FROM dbo.LOC WITH (NOLOCK)
					  WHERE LOC = @cLOC) 
			BEGIN
			   SET @nErrNo = 59416
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid LOC
               GOTO Quit;
			END;
		 END;
      END;
   END;

Quit:
END;

GRANT EXECUTE ON rdt.isp_CV_IKEA TO NSQL 

GO
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/************************************************************************/
/* Store procedure: [[rdt_600ChkConCode]]                               */
/* Copyright: Maersk                                                    */
/*                                                                      */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 21/03/2024 1.0  PPA374     To not allow condition code to be used     */
/* 03/07/2024 1.1  PPA374     To stop using same ID that is in use      */
/************************************************************************/

CREATE   PROC [RDT].[rdt_600ChkConVLT] (
   @nMobile      INT,           
   @nFunc        INT,           
   @cLangCode    NVARCHAR( 3),  
   @nStep        INT,           
   @nInputKey    INT,           
   @cFacility    NVARCHAR( 5),  
   @cStorerKey   NVARCHAR( 15), 
   @cReceiptKey  NVARCHAR( 10), 
   @cPOKey       NVARCHAR( 10), 
   @cLOC         NVARCHAR( 10), 
   @cID          NVARCHAR( 18), 
   @cSKU         NVARCHAR( 20), 
   @cLottable01  NVARCHAR( 18), 
   @cLottable02  NVARCHAR( 18), 
   @cLottable03  NVARCHAR( 18), 
   @dLottable04  DATETIME,      
   @dLottable05  DATETIME,      
   @cLottable06  NVARCHAR( 30), 
   @cLottable07  NVARCHAR( 30), 
   @cLottable08  NVARCHAR( 30), 
   @cLottable09  NVARCHAR( 30), 
   @cLottable10  NVARCHAR( 30), 
   @cLottable11  NVARCHAR( 30), 
   @cLottable12  NVARCHAR( 30), 
   @dLottable13  DATETIME,      
   @dLottable14  DATETIME,      
   @dLottable15  DATETIME,      
   @nQTY         INT,           
   @cReasonCode  NVARCHAR( 10), 
   @cSuggToLOC   NVARCHAR( 10), 
   @cFinalLOC    NVARCHAR( 10), 
   @cReceiptLineNumber NVARCHAR( 10), 
   @nErrNo             INT            OUTPUT, 
   @cErrMsg            NVARCHAR( 20)  OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
      
   IF @nFunc = 600
   BEGIN
      IF @nStep = 6 --QTY
      BEGIN
         IF ISNULL(@cReasonCode,'') <> ''
         BEGIN
            SET @nErrNo = 217970
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --217970KeepCondEmpty
         END
      END
      ELSE IF @nstep = 3 --ID
      BEGIN
         IF len(replace(rtrim(ltrim(@cID)),' ',''))<>10 or (select CHARINDEX (' ',@cID))>0
         BEGIN
            SET @nErrNo = 217971
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --217971BadFormat
         END
         ELSE IF exists (select 1 from RECEIPTDETAIL (NOLOCK) where toid = @cID and storerkey = 'HUSQ')
         BEGIN
            SET @nErrNo = 217972
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --217972IDinUse
         END
      END
   END
END

GO
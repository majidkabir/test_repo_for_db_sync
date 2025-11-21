SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_537DecodeSP01                                   */
/* Copyright      : Maersk                                              */
/*                                                                      */
/* Purpose: Decode 2D barcode to verify L01, L02                        */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2023-08-07 1.0  Ung        WMS-23117 Created                         */
/************************************************************************/

CREATE   PROC [RDT].[rdt_537DecodeSP01] (
   @nMobile       INT,           
   @nFunc         INT,           
   @cLangCode     NVARCHAR( 3),  
   @nStep         INT,           
   @nInputKey     INT,           
   @cFacility     NVARCHAR( 5), 
   @cStorerKey    NVARCHAR( 15), 
   @cReceiptKey   NVARCHAR( 10), 
   @cPOKey        NVARCHAR( 10), 
   @cLOC          NVARCHAR( 10), 
   @cBarcode      NVARCHAR( MAX), 
   @nErrNo        INT                  OUTPUT, 
   @cErrMsg       NVARCHAR( 20)        OUTPUT,
   @cID           NVARCHAR( 18) = ''   OUTPUT, 
   @cLottable01   NVARCHAR( 18) = ''   OUTPUT, 
   @cLottable02   NVARCHAR( 18) = ''   OUTPUT, 
   @cLottable03   NVARCHAR( 18) = ''   OUTPUT, 
   @dLottable04   DATETIME      = NULL OUTPUT, 
   @dLottable05   DATETIME      = NULL OUTPUT, 
   @cLottable06   NVARCHAR( 30) = ''   OUTPUT, 
   @cLottable07   NVARCHAR( 30) = ''   OUTPUT, 
   @cLottable08   NVARCHAR( 30) = ''   OUTPUT, 
   @cLottable09   NVARCHAR( 30) = ''   OUTPUT, 
   @cLottable10   NVARCHAR( 30) = ''   OUTPUT, 
   @cLottable11   NVARCHAR( 30) = ''   OUTPUT, 
   @cLottable12   NVARCHAR( 30) = ''   OUTPUT, 
   @dLottable13   DATETIME      = NULL OUTPUT,      
   @dLottable14   DATETIME      = NULL OUTPUT,      
   @dLottable15   DATETIME      = NULL OUTPUT      
)
AS
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   IF @nFunc = 537 -- Line receiving
   BEGIN
      IF @nStep = 9 -- Data capture
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            -- Scan 2D barcode
            IF @cBarcode = ''
            BEGIN
               SET @nErrNo = 205001
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Need data
               GOTO Quit
            END

            /*
               2D barcode content:
               SKU Code 3007040025 Description MAXI ADULT 4kg Batch No. 241G1RJH04 SSCC No. 031825594000400083 Invoice No. SIP-SA2249454 Factory Code Minos 13007040 Origin South Africa
               
               L01 = 031825594000400083
               L02 = 241G1RJH04
            */
            DECLARE @nStart  INT
            DECLARE @nEnd    INT
            DECLARE @cChkL01 NVARCHAR( 18)
            DECLARE @cChkL02 NVARCHAR( 18)
            
            -- Get SSCC
            SET @nStart = CHARINDEX( 'SSCC No.', @cBarcode)
            IF @nStart > 0
            BEGIN
               SET @nStart += LEN( 'SSCC No.') + 1
               SET @nEnd = CHARINDEX( ' ', @cBarcode, @nStart)
               SET @cChkL01 = SUBSTRING( @cBarcode, @nStart, @nEnd - @nStart)
            END

            -- Check same SSCC
            IF @cChkL01 <> @cLottable01
            BEGIN
               SET @nErrNo = 205002
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Diff SSCC
               GOTO Quit
            END

            -- Get batch
            SET @nStart = CHARINDEX( 'Batch No.', @cBarcode)
            IF @nStart > 0
            BEGIN
               SET @nStart += LEN( 'Batch No.') + 1
               SET @nEnd = CHARINDEX( ' ', @cBarcode, @nStart)
               SET @cChkL02 = SUBSTRING( @cBarcode, @nStart, @nEnd - @nStart)
            END
                     
            -- Check same batch
            IF @cChkL02 <> @cLottable02
            BEGIN
               SET @nErrNo = 205003
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Diff batch
               GOTO Quit
            END
         END
      END
   END

Quit:


GO
SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_860DropIDDecod02                                */
/* Copyright      : LFLogistics                                         */
/*                                                                      */
/* Purpose: Decode dropid                                               */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 11-10-2017  1.0  James       WMS3174.Created                         */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_860DropIDDecod02]
   @nMobile          INT,
   @nFunc            INT, 
   @cLangCode        NVARCHAR( 3), 
   @nStep            INT, 
   @nInputKey        INT, 
   @cStorerkey       NVARCHAR(15),
   @cPickSlipNo      NVARCHAR(10),
   @cDropID          NVARCHAR(60)   OUTPUT,
   @cLOC             NVARCHAR(10)   OUTPUT,
   @cID              NVARCHAR(18)   OUTPUT,
   @cSKU             NVARCHAR(20)   OUTPUT,
   @nQty             INT            OUTPUT, 
   @cLottable01      NVARCHAR( 18)  OUTPUT, 
   @cLottable02      NVARCHAR( 18)  OUTPUT, 
   @cLottable03      NVARCHAR( 18)  OUTPUT, 
   @dLottable04      DATETIME       OUTPUT,  
   @dLottable05      DATETIME       OUTPUT,  
   @cLottable06      NVARCHAR( 30)  OUTPUT,  
   @cLottable07      NVARCHAR( 30)  OUTPUT,  
   @cLottable08      NVARCHAR( 30)  OUTPUT,  
   @cLottable09      NVARCHAR( 30)  OUTPUT,  
   @cLottable10      NVARCHAR( 30)  OUTPUT,  
   @cLottable11      NVARCHAR( 30)  OUTPUT,  
   @cLottable12      NVARCHAR( 30)  OUTPUT,  
   @dLottable13      DATETIME       OUTPUT,   
   @dLottable14      DATETIME       OUTPUT,   
   @dLottable15      DATETIME       OUTPUT,   
   @nErrNo           INT            OUTPUT, 
   @cErrMsg          NVARCHAR(250)  OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE  @nStartPos  INT,
            @nEndPos    INT
             
   DECLARE  @cBarcode NVARCHAR( 60),
            @cCartonBarcode NVARCHAR( 60)

   DECLARE @cErrMsg1    NVARCHAR( 20), 
           @cErrMsg2    NVARCHAR( 20),
           @cErrMsg3    NVARCHAR( 20), 
           @cErrMsg4    NVARCHAR( 20),
           @cErrMsg5    NVARCHAR( 20)

   IF @nStep = 2
   BEGIN
      IF @nInputKey = 1
      BEGIN
         IF ISNULL( @cDropID, '') = ''
         BEGIN
            SET @nErrNo = 115901
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DropID Req
            GOTO Quit
         END

         SET @cCartonBarcode = @cDropID

         IF @cCartonBarcode <> '' AND @cCartonBarcode <> 'NA'
         BEGIN
            /*
            Logic to decode the carton ID.

            1. If can detect [21 in scanned data, take all characters after [21 as carton ID (max 20 characters)
            2. Else try detect 21 at position 17 of scanned data, and take all characters after 21 until next [ as carton ID
            3. Else try detect 21 at position 16 of scanned data, and take all characters after 21 as carton ID (max 20 characters)
            4. Else prompt error ôCTN ID No Read, Key Inö
            */

            SET @cBarcode = @cCartonBarcode
            
            -- Logic 1
            SET @nStartPos = 0
            SET @nEndPos = 0

            SET @nStartPos =  CHARINDEX ( '[21' , @cBarcode) 
            SET @nEndPos = CHARINDEX ( '[' , @cBarcode, @nStartPos + 3) 

            IF ( @nStartPos + 3) > 3 
            BEGIN
               SET @nStartPos = @nStartPos + 3  -- start grep the data after value [21

               IF @nEndPos > 0
                  SET @cCartonBarcode = SUBSTRING( @cBarcode, @nStartPos, @nEndPos - @nStartPos)
               ELSE
                  SET @cCartonBarcode = SUBSTRING( @cBarcode, @nStartPos, 20)

               IF ISNULL( @cCartonBarcode, '') <> ''
               BEGIN
                  SET @cDropID = @cCartonBarcode
                  GOTO Quit
               END
            END

            -- Logic 2
            SET @nStartPos = 0
            SET @nEndPos = 0

            SET @nStartPos = CHARINDEX ( '21' , @cBarcode) 
            SET @nEndPos = CHARINDEX ( '[' , @cBarcode) 

            IF @nStartPos = 17 AND ( @nEndPos > @nStartPos)
            BEGIN
               SET @nStartPos = @nStartPos + 2  -- start grep the data after value 21
               SET @cCartonBarcode = SUBSTRING( @cBarcode, @nStartPos, @nEndPos - @nStartPos)

               IF ISNULL( @cCartonBarcode, '') <> ''
               BEGIN
                  SET @cDropID = @cCartonBarcode
                  GOTO Quit
               END
            END

            -- Logic 3
            IF @nStartPos = 16
            BEGIN
               SET @nStartPos = @nStartPos + 2  -- start grep the data after value 21
               SET @cCartonBarcode = SUBSTRING( @cBarcode, @nStartPos, 20)

               IF ISNULL( @cCartonBarcode, '') <> ''
               BEGIN
                  SET @cDropID = @cCartonBarcode
                  GOTO Quit
               END
            END

            -- Logic 4 prompt error
            SET @cCartonBarcode = ''

            SET @nErrNo = 0
            SET @cErrMsg1 = SUBSTRING( rdt.rdtgetmessage( 115902, @cLangCode, 'DSP'), 7, 14)
            SET @cErrMsg2 = SUBSTRING( rdt.rdtgetmessage( 115903, @cLangCode, 'DSP'), 7, 14)
            SET @cErrMsg3 = ''
            SET @cErrMsg4 = ''
            SET @cErrMsg5 = ''
            EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg1, @cErrMsg2
            IF @nErrNo = 1
            BEGIN
               SET @cErrMsg1 = ''
               SET @cErrMsg2 = ''
            END

            -- Return an error to stop the subsequent process
            SET @nErrNo = 115902
         END
      END
   END

   SET @cDropID = @cCartonBarcode
QUIT:

END -- End Procedure


GO
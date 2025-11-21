SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_JACKWExtValid01                                 */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Validate TOID must start with #1 and 4 digits only          */
/*          verify sku                                                  */
/*                                                                      */
/* Called from: rdtfnc_PieceReceiving                                   */
/*                                                                      */
/* Exceed version: 5.4                                                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 2014-08-28  1.0  James       SOS315958 Created                       */ 
/* 2014-11-03  1.1  James       Remove validate qty (james01)           */ 
/* 2015-08-25  1.2  James       SOS350478 - ID is mandatory (james02)   */
/************************************************************************/

CREATE PROC [RDT].[rdt_JACKWExtValid01] (
   @nMobile      INT,           
   @nFunc        INT,           
   @nStep        INT,           
   @nInputKey    INT,           
   @cLangCode    NVARCHAR( 3),  
   @cStorerkey   NVARCHAR( 15), 
   @cReceiptKey  NVARCHAR( 10), 
   @cPOKey       NVARCHAR( 10), 
   @cExtASN      NVARCHAR( 20), 
   @cToLOC       NVARCHAR( 10), 
   @cToID        NVARCHAR( 18), 
   @cLottable01      NVARCHAR( 18), 
   @cLottable02      NVARCHAR( 18), 
   @cLottable03      NVARCHAR( 18), 
   @dLottable04      DATETIME,  
   @cSKU             NVARCHAR( 20), 
   @cQty             NVARCHAR( 5), 
   @nErrNo           INT           OUTPUT, 
   @cErrMsg          NVARCHAR( 20) OUTPUT 
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   IF @nInputKey = 1
   BEGIN
      IF @nStep = 3 
      BEGIN
         IF ISNULL( @cToID, '') = ''
         BEGIN
            SET @cErrMsg = 'ID IS REQUIRED'
            GOTO Quit
         END
         
         IF SUBSTRING( @cToID, 1, 1) <> '1'
         BEGIN
            SET @cErrMsg = 'ID START WITH #1'
            GOTO Quit
         END
         
         IF LEN( RTRIM( @cToID)) <> 4
         BEGIN
            SET @cErrMsg = 'ID MUST BE 4 DIGITS'
            GOTO Quit
         END
      END
   END

Quit:
END

GO
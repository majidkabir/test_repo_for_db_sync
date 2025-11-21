SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_LottableFormat_L9CartonIDReceive                      */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Purpose: Dynamic lottable                                                  */
/*                                                                            */
/* Date         Author    Ver.  Purposes                                      */
/* 22-12-2016   Ung       1.0   WMS-835 Created                               */
/******************************************************************************/

CREATE PROCEDURE [RDT].[rdt_LottableFormat_L9CartonIDReceive]
   @nMobile          INT,  
   @nFunc            INT,  
   @cLangCode        NVARCHAR( 3),  
   @nInputKey        INT,  
   @cStorerKey       NVARCHAR( 15),  
   @cSKU             NVARCHAR( 20),  
   @cLottableCode    NVARCHAR( 30),   
   @nLottableNo      INT,  
   @cFormatSP        NVARCHAR( 50),   
   @cLottableValue   NVARCHAR( 60),   
   @cLottable        NVARCHAR( 60) OUTPUT,  
   @nErrNo           INT           OUTPUT,  
   @cErrMsg          NVARCHAR( 20) OUTPUT  
/*
    @nMobile          INT
   ,@nFunc            INT
   ,@cLangCode        NVARCHAR( 3)
   ,@nInputKey        INT
   ,@cStorerKey       NVARCHAR( 15)
   ,@cSKU             NVARCHAR( 20)
   ,@cLottableCode    NVARCHAR( 30)
   ,@nLottableNo      INT
   ,@cLottable        NVARCHAR( 30)
   ,@cType            NVARCHAR( 10)
   ,@cSourceKey       NVARCHAR( 15)
   ,@cLottable01Value NVARCHAR( 18)
   ,@cLottable02Value NVARCHAR( 18)
   ,@cLottable03Value NVARCHAR( 18)
   ,@dLottable04Value DATETIME
   ,@dLottable05Value DATETIME
   ,@cLottable06Value NVARCHAR( 30)
   ,@cLottable07Value NVARCHAR( 30)
   ,@cLottable08Value NVARCHAR( 30)
   ,@cLottable09Value NVARCHAR( 30)
   ,@cLottable10Value NVARCHAR( 30)
   ,@cLottable11Value NVARCHAR( 30)
   ,@cLottable12Value NVARCHAR( 30)
   ,@dLottable13Value DATETIME
   ,@dLottable14Value DATETIME
   ,@dLottable15Value DATETIME
   ,@cLottable01      NVARCHAR( 18) OUTPUT
   ,@cLottable02      NVARCHAR( 18) OUTPUT
   ,@cLottable03      NVARCHAR( 18) OUTPUT
   ,@dLottable04      DATETIME      OUTPUT
   ,@dLottable05      DATETIME      OUTPUT
   ,@cLottable06      NVARCHAR( 30) OUTPUT
   ,@cLottable07      NVARCHAR( 30) OUTPUT
   ,@cLottable08      NVARCHAR( 30) OUTPUT
   ,@cLottable09      NVARCHAR( 30) OUTPUT
   ,@cLottable10      NVARCHAR( 30) OUTPUT
   ,@cLottable11      NVARCHAR( 30) OUTPUT
   ,@cLottable12      NVARCHAR( 30) OUTPUT
   ,@dLottable13      DATETIME      OUTPUT
   ,@dLottable14      DATETIME      OUTPUT
   ,@dLottable15      DATETIME      OUTPUT
   ,@nErrNo           INT           OUTPUT
   ,@cErrMsg          NVARCHAR( 20) OUTPUT
*/
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   IF @cLottableValue = ''
   BEGIN
      SET @nErrNo = 105601
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need carton ID
      GOTO Quit
   END

   -- Get carton ID info
   DECLARE @cQTY NVARCHAR(10)
   SELECT 
      @cSKU = SKU, 
      @cQTY = LEFT( Lottable10, 10)
   FROM LOTAttribute WITH (NOLOCK) 
   WHERE StorerKey = @cStorerKey
      AND Lottable09 = @cLottableValue

   -- Check carton received before
   IF @@ROWCOUNT = 0
      GOTO Quit

   -- SKU info
   DECLARE @cBUSR9 NVARCHAR(30)
   DECLARE @cUOM NVARCHAR(10)
   SELECT
      @cBUSR9 = BUSR9, 
      @cUOM = Pack.PackUOM3
   FROM dbo.SKU SKU WITH (NOLOCK)
      JOIN dbo.Pack Pack WITH (NOLOCK) ON (SKU.PackKey = Pack.PackKey)
   WHERE SKU.StorerKey = @cStorerKey
      AND SKU.SKU = @cSKU

   -- Beauty SKU
   IF @cBUSR9 = 'BEAUTY'
   BEGIN
      -- Get mobrec info
      DECLARE @cFacility NVARCHAR(5)
      DECLARE @cReceiptKey NVARCHAR(10)
      DECLARE @cPOKey NVARCHAR(10)
      DECLARE @cLOC NVARCHAR(10)
      DECLARE @cID NVARCHAR(18)
      SELECT 
         @cFacility = Facility, 
         @cReceiptKey = V_ReceiptKey, 
         @cPOKey = V_POKey, 
         @cLOC = V_LOC, 
         @cID = V_ID
      FROM rdt.rdtMobRec WITH (NOLOCK)
      WHERE Mobile = @nMobile
         
      -- Check double scan
      IF EXISTS( SELECT 1 FROM ReceiptDetail WITH (NOLOCK) WHERE ReceiptKey = @cReceiptKey AND Lottable09 = @cLottableValue AND BeforeReceivedQTY > 0)
      BEGIN
         SET @nErrNo = 105602
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Double scanned
         GOTO Quit
      END

      DECLARE @nNOPOFlag INT
      SET @nNOPOFlag = CASE WHEN @cPOkey = 'NOPO' THEN 1 ELSE 0 END
         
      -- Receive
      DECLARE @cRDLineNo NVARCHAR(5)
      EXEC rdt.rdt_Receive_V7
         @nFunc         = @nFunc,
         @nMobile       = @nMobile,
         @cLangCode     = @cLangCode,
         @nErrNo        = @nErrNo OUTPUT,
         @cErrMsg       = @cErrMsg OUTPUT,
         @cStorerKey    = @cStorerKey,
         @cFacility     = @cFacility,
         @cReceiptKey   = @cReceiptKey,
         @cPOKey        = @cPOKey,
         @cToLOC        = @cLOC,
         @cToID         = @cID,
         @cSKUCode      = @cSKU,
         @cSKUUOM       = @cUOM,
         @nSKUQTY       = @cQTY,
         @cUCC          = '',
         @cUCCSKU       = '',
         @nUCCQTY       = '',
         @cCreateUCC    = '',
         @cLottable01   = '',
         @cLottable02   = '',
         @cLottable03   = '',
         @dLottable04   = NULL,
         @dLottable05   = NULL,
         @cLottable06   = '',
         @cLottable07   = '',
         @cLottable08   = '',
         @cLottable09   = @cLottableValue,
         @cLottable10   = '',
         @cLottable11   = '',
         @cLottable12   = '',
         @dLottable13   = NULL,
         @dLottable14   = NULL,
         @dLottable15   = NULL,
         @nNOPOFlag     = @nNOPOFlag,
         @cConditionCode = 'OK',
         @cSubreasonCode = '', 
         @cReceiptLineNumberOutput = @cRDLineNo OUTPUT
            
         IF @nErrNo = 0
         BEGIN
            SET @cLottable = ''
            SET @nErrNo = -1 -- Retain in current screen
         END
   END

Quit:

END

GO
SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_898ExtVal01                                     */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Date       Rev  Author  Purposes                                     */
/* 2015-02-12 1.0  Ung     SOS333395 Created                            */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_898ExtVal01]
    @nMobile      INT
   ,@nFunc        INT
   ,@cLangCode    NVARCHAR( 3)
   ,@nStep        INT
   ,@nInputKey    INT
   ,@cReceiptKey  NVARCHAR( 10)
   ,@cPOKey       NVARCHAR( 10)
   ,@cLOC         NVARCHAR( 10)
   ,@cToID        NVARCHAR( 18)
   ,@cLottable01  NVARCHAR( 18)
   ,@cLottable02  NVARCHAR( 18)
   ,@cLottable03  NVARCHAR( 18)
   ,@dLottable04  DATETIME
   ,@cUCC         NVARCHAR( 20)
   ,@cSKU         NVARCHAR( 20)
   ,@nQTY         INT
   ,@cParam1      NVARCHAR( 20) OUTPUT
   ,@cParam2      NVARCHAR( 20) OUTPUT
   ,@cParam3      NVARCHAR( 20) OUTPUT
   ,@cParam4      NVARCHAR( 20) OUTPUT
   ,@cParam5      NVARCHAR( 20) OUTPUT
   ,@cOption      NVARCHAR( 1)
   ,@nErrNo       INT       OUTPUT
   ,@cErrMsg      NVARCHAR( 20) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   IF @nFunc = 898 -- UCC receiving
   BEGIN
      IF @nStep = 1 -- ASN/PO
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            DECLARE @cUserDefine01 NVARCHAR(30)
            DECLARE @cASNStatus    NVARCHAR(10)
            
            -- Get Receipt info
            SELECT 
               @cUserDefine01 = UserDefine01, 
               @cASNStatus = ASNStatus
            FROM Receipt WITH (NOLOCK) 
            WHERE ReceiptKey = @cReceiptKey
            
            -- Check manual ASN and interface not trigger
            IF @cUserDefine01 = 'ANFPO' AND @cASNStatus <> 'APTCRE'
            BEGIN
               SET @nErrNo = 92951
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --APTCRE not TRIG
            END
         END
      END
   END
   
Quit:

END

GO
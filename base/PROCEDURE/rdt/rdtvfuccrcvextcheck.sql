SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdtVFUCCRcvExtCheck                                 */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Check UCC scan to ID have same SKU, QTY, L02                */
/*                                                                      */
/* Called from:                                                         */
/*                                                                      */
/* Exceed version: 5.4                                                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 12-09-2012  1.0  Ung         SOS255639. Created                      */
/* 09-04-2014  1.1  Ung         SOS308791. Add cross dock ASN           */
/* 02-06-2014  1.2  Ung         SOS313441. Add random check             */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdtVFUCCRcvExtCheck]
    @nMobile      INT
   ,@nFunc        INT
   ,@cLangCode    NVARCHAR( 3)
   ,@cReceiptKey  NVARCHAR( 10) 
   ,@cPOKey       NVARCHAR( 10) 
   ,@cLOC         NVARCHAR( 10) 
   ,@cToID        NVARCHAR( 18) 
   ,@cLottable01  NVARCHAR( 18) 
   ,@cLottable02  NVARCHAR( 18) 
   ,@cLottable03  NVARCHAR( 18) 
   ,@dLottable04  DATETIME  
   ,@cUCC         NVARCHAR( 20) 
   ,@nErrNo       INT       OUTPUT 
   ,@cErrMsg      NVARCHAR( 20) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE @cStorerKey        NVARCHAR( 15)
   DECLARE @nSKUCnt_UCC       INT
   DECLARE @nSKUCnt_ID        INT
   DECLARE @cUCCSKU           NVARCHAR( 20)
   DECLARE @nUCCQTY           INT
   DECLARE @cUCCSwapLOC       NVARCHAR( 30)
   DECLARE @cIDSKU            NVARCHAR( 20)
   DECLARE @nIDQTY            INT
   DECLARE @cIDSwapLOC        NVARCHAR( 30)
   DECLARE @cIDL02            NVARCHAR( 18)
   DECLARE @cDocType          NVARCHAR( 1)
   DECLARE @cIDExternKey      NVARCHAR( 20)
   DECLARE @cUCCExternKey     NVARCHAR( 20)
   DECLARE @cRandomCheck_UCC  NVARCHAR( 1)
   DECLARE @cRandomCheck_ID   NVARCHAR( 1)

   -- Check UCC format
   IF LEN( @cUCC) <> 10 OR LEFT( @cUCC, 2) <> 'VF'
   BEGIN
      SET @nErrNo = 79451
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid format
      GOTO Quit
   END

   -- Get Receipt info
   SELECT 
      @cStorerKey = StorerKey, 
      @cDocType = DocType
   FROM Receipt WITH (NOLOCK) 
   WHERE ReceiptKey = @cReceiptKey

   -- Check UCC belong to this ASN
   IF NOT EXISTS( SELECT TOP 1 1 
      FROM ReceiptDetail RD WITH (NOLOCK) 
         JOIN UCC WITH (NOLOCK) ON (UCC.ExternKey = RD.ExternReceiptKey AND UCC.ExternKey <> '')
      WHERE UCC.StorerKey = @cStorerKey
         AND UCC.UCCNo = @cUCC
         AND RD.ReceiptKey = @cReceiptKey)
   BEGIN
      SET @nErrNo = 79452
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UCC not in ASN
      GOTO Quit
   END 
   
   -- Get UCC info
   SET @cUCCSKU = ''
   SET @nUCCQTY = 0
   SET @cUCCExternKey = ''
   SET @cUCCSwapLOC = ''
   SELECT
      @cUCCSKU = SKU, 
      @nUCCQTY = QTY, 
      @cUCCExternKey = ExternKey, 
      @cUCCSwapLOC = UserDefined06
   FROM dbo.UCC WITH (NOLOCK)
   WHERE StorerKey = @cStorerKey
      AND UCCNo = @cUCC
   
   -- Get any UCC on ID
   SET @cIDSKU = ''
   SET @nIDQTY = 0
   SET @cIDL02 = ''
   SET @cIDExternKey = ''
   SET @cIDSwapLOC = ''
   SELECT TOP 1
      @cIDSKU = UCC.SKU, 
      @nIDQTY = UCC.QTY, 
      @cIDL02 = RD.Lottable02, 
      @cIDExternKey = UCC.ExternKey, 
      @cIDSwapLOC = UserDefined06
   FROM dbo.UCC WITH (NOLOCK)
      JOIN dbo.ReceiptDetail RD WITH (NOLOCK) ON (UCC.ReceiptKey = RD.ReceiptKey AND UCC.ReceiptLineNumber = RD.ReceiptLineNumber)
   WHERE RD.ReceiptKey = @cReceiptKey
      AND RD.ToID = @cToID

   -- Normal ASN
   IF @cDocType <> 'X'
   BEGIN
      -- Check lottable01 in ASN
      IF NOT EXISTS( SELECT TOP 1 1 
         FROM ReceiptDetail WITH (NOLOCK) 
         WHERE ReceiptKey = @cReceiptKey
            AND Lottable01 = @cLottable01)
      BEGIN
         SET @nErrNo = 79453
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --L01 not in ASN
         GOTO Quit
      END 
      
      -- Check lottable02 in ASN
      IF NOT EXISTS( SELECT TOP 1 1 
         FROM ReceiptDetail WITH (NOLOCK) 
         WHERE ReceiptKey = @cReceiptKey
            AND Lottable02 = @cLottable02)
      BEGIN
         SET @nErrNo = 79454
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --L02 not in ASN
         GOTO Quit
      END 
      
      -- Check lottable03 in ASN
      IF NOT EXISTS( SELECT TOP 1 1 
         FROM ReceiptDetail WITH (NOLOCK) 
         WHERE ReceiptKey = @cReceiptKey
            AND Lottable03 = @cLottable03)
      BEGIN
         SET @nErrNo = 79455
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --L03 not in ASN
         GOTO Quit
      END 
   
      -- Check lottable04 in ASN  
      IF ISNULL(@dLottable04, '') <> ''
      BEGIN  
         SET @nErrNo = 79456
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --L04 not empty  
         GOTO Quit  
      END   

      -- ID received
      IF @cIDSwapLOC <> ''
      BEGIN
         -- Check mix SKU UCC
         IF (@cUCCSwapLOC = '1' AND @cIDSwapLOC <> '1') OR
            (@cUCCSwapLOC <> '1' AND @cIDSwapLOC = '1')
         BEGIN
            SET @nErrNo = 79457
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- MixMultiSKUUCC
            GOTO Quit
         END 
         IF @cUCCSwapLOC = '1' GOTO Quit

         -- Check random checking UCC
         IF (@cUCCSwapLOC = '2' AND @cIDSwapLOC <> '2') OR
            (@cUCCSwapLOC <> '2' AND @cIDSwapLOC = '2')
         BEGIN
            SET @nErrNo = 79458
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- MixCheckingUCC
            GOTO Quit
         END
         IF @cUCCSwapLOC = '2' GOTO Quit
         
         -- Check Minor UCC
         DECLARE @nMinority INT
         SET @nMinority = rdt.RDTGetConfig( @nFunc, 'UCCSwapMinorityLevel', @cStorerKey)
         IF @nMinority > 0 
         BEGIN
            IF (@cUCCSwapLOC = '3' AND @cIDSwapLOC <> '3') OR
               (@cUCCSwapLOC <> '3' AND @cIDSwapLOC = '3')
            BEGIN
               SET @nErrNo = 79459
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- MixMinorityUCC
               GOTO Quit
            END
            IF @cUCCSwapLOC = '3' GOTO Quit
         END

         -- Check same SKU
         IF @cIDSKU <> '' AND @cIDSKU <> @cUCCSKU
         BEGIN
            SET @nErrNo = 79460
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- ID,UCC DiffSKU
            GOTO Quit
         END 
         
         -- Check same QTY
         IF @nIDQTY <> 0 AND @nIDQTY <> @nUCCQTY
         BEGIN
            SET @nErrNo = 79461
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- ID,UCC DiffQTY
            GOTO Quit
         END 
      END
   END

   -- Cross dock
   IF @cDocType = 'X'
   BEGIN
      -- ID received
      IF @cIDSwapLOC <> ''
      BEGIN
         -- If random check
         IF EXISTS( SELECT TOP 1 1 FROM dbo.UCC WITH (NOLOCK) WHERE UCCNo = @cUCC AND StorerKey = @cStorerKey AND UserDefined07 = 'RDM')
         BEGIN
            IF EXISTS( SELECT TOP 1 1 FROM dbo.UCC WITH (NOLOCK) WHERE UCCNo = @cUCC AND StorerKey = @cStorerKey AND UserDefined07 = '')
               SET @cUCCSwapLOC = '2' -- Partial check
            ELSE
               SET @cUCCSwapLOC = '1' -- Full check
         END

         -- Full check UCC
         IF (@cUCCSwapLOC = '1' AND @cIDSwapLOC <> '1') OR
            (@cUCCSwapLOC <> '1' AND @cIDSwapLOC = '1')
         BEGIN
            SET @nErrNo = 79462
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- MixFullChkUCC
            GOTO Quit
         END 
         IF @cUCCSwapLOC = '1' GOTO Quit

         -- Partial check UCC
         IF (@cUCCSwapLOC = '2' AND @cIDSwapLOC <> '2') OR
            (@cUCCSwapLOC <> '2' AND @cIDSwapLOC = '2')
         BEGIN
            SET @nErrNo = 79463
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- MixPartialChk
            GOTO Quit
         END
         IF @cUCCSwapLOC = '2' GOTO Quit
         
         -- Check same PO
         IF @cIDExternKey <> '' AND @cIDExternKey <> @cUCCExternKey
         BEGIN
            SET @nErrNo = 79464
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- ID,UCC Diff PO
            GOTO Quit
         END 
      END
   END
   
QUIT:
END -- End Procedure


GO
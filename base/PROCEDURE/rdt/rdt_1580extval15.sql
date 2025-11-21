SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_1580ExtVal15                                    */
/* Copyright: LF Logistics                                              */
/*                                                                      */
/* Purpose: Check TO ID valid.                                          */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2020-04-21 1.0  James      WMS-12984 Created                         */
/************************************************************************/

CREATE PROC [RDT].[rdt_1580ExtVal15] (
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
   @cLottable01  NVARCHAR( 18),
   @cLottable02  NVARCHAR( 18),
   @cLottable03  NVARCHAR( 18),
   @dLottable04  DATETIME,    
   @cSKU         NVARCHAR( 20),
   @nQTY         INT,
   @nErrNo       INT           OUTPUT,
   @cErrMsg      NVARCHAR( 20) OUTPUT          
)
AS
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cReceiptGroup  NVARCHAR( 20)
   DECLARE @cMax        NVARCHAR( MAX)
   DECLARE @cSKUBarcode NVARCHAR( 2000) 
   
   SELECT @cReceiptGroup = ReceiptGroup
   FROM dbo.RECEIPT WITH (NOLOCK)
   WHERE ReceiptKey = @cReceiptKey
   
   IF @nStep = 3 -- ID
   BEGIN
      IF @nInputKey = 1 
      BEGIN
         IF EXISTS ( SELECT 1 FROM dbo.CODELKUP WITH (NOLOCK)
                     WHERE LISTNAME = 'DSRecGroup'
                     AND   Code = @cReceiptGroup
                     AND   Short = 'CTN'
                     AND Storerkey = @cStorerkey)
         BEGIN
            IF EXISTS ( SELECT 1 FROM dbo.ReceiptDetail WITH (NOLOCK)
                        WHERE ReceiptKey = @cReceiptKey
                        AND   StorerKey = @cStorerKey
                        AND   ToID = @cToID
                        AND   ISNULL( UserDefine01, '') <> '')
            BEGIN
               SET @nErrNo = 151051
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- CASEID IN USE 
               GOTO Quit
            END
         END
      END   
   END      

   Quit:


GO
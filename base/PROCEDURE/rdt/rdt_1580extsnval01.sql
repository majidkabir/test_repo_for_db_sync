SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_1580ExtSNVal01                                        */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Date        Rev  Author       Purposes                                     */
/* 27-02-2019  1.0  Ung          WMS-7837 Created                             */
/******************************************************************************/

CREATE PROCEDURE [RDT].[rdt_1580ExtSNVal01]
   @nMobile          INT,
   @nFunc            INT,
   @cLangCode        NVARCHAR( 3),
   @nStep            INT,
   @nInputKey        INT,
   @cFacility        NVARCHAR( 3),
   @cStorerKey       NVARCHAR( 15),
   @cSKU             NVARCHAR( 20),
   @nQTY             INT, 
   @cSerialNo        NVARCHAR( 30),
   @cType            NVARCHAR( 15), --CHECK/INSERT
   @cDocType         NVARCHAR( 10), 
   @cDocNo           NVARCHAR( 20), 
   @nErrNo           INT           OUTPUT,
   @cErrMsg          NVARCHAR( 20) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nRowCount          INT
   DECLARE @cReceiptKey        NVARCHAR(10)
   DECLARE @cChkSKU            NVARCHAR(20)
   DECLARE @cChkStatus         NVARCHAR(10)
   DECLARE @nBeforeReceivedQty INT
   DECLARE @cASNType           NVARCHAR(1)
   DECLARE @cLottable02        NVARCHAR(18)
   DECLARE @cChkL02            NVARCHAR(18)

   IF @nFunc = 1580 -- Piece receiving
   BEGIN
      -- Get Receipt info
      SET @cReceiptKey = @cDocNo

      -- Get ReceiptDetail info
      SELECT 
         @cChkSKU = SKU, 
         @cChkL02 = Lottable02, 
         @nBeforeReceivedQty = BeforeReceivedQty
      FROM ReceiptDetail WITH (NOLOCK)
      WHERE ReceiptKey = @cReceiptKey
         AND StorerKey = @cStorerKey
         -- AND SKU = @cSKU
         AND Lottable06 = @cSerialNo
      SET @nRowCount = @@ROWCOUNT
      
      -- Check SNO in ASN
      IF @nRowCount = 0
      BEGIN
         SET @nErrNo = 134951
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SNO not in ASN
         GOTO Quit
      END
      
      -- Check SNO multi line
      IF @nRowCount > 1
      BEGIN
         SET @nErrNo = 134952
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SNO dup in ASN
         GOTO Quit
      END
      
      -- Check SNO diff SKU
      IF @cChkSKU <> @cSKU
      BEGIN
         SET @nErrNo = 134953
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SNO diff SKU
         GOTO Quit
      END
      
      -- Check SNO received
      IF @nBeforeReceivedQty > 0
      BEGIN
         SET @nErrNo = 134954
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SNO received
         GOTO Quit
      END
      
      -- Get serial no info
      IF @cChkStatus IS NULL
         SELECT @cChkStatus = Status
         FROM SerialNo WITH (NOLOCK) 
         WHERE StorerKey = @cStorerKey
            AND SKU = @cSKU
            AND SerialNo = @cSerialNo

      -- Check serial no received
      IF @cChkStatus = '1'
      BEGIN
         SET @nErrNo = 134955
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SNO received
         GOTO Quit
      END
      
      -- Get Lottable02
      SELECT @cLottable02 = V_Lottable02 FROM rdt.rdtMobRec WITH (NOLOCK) WHERE Mobile = @nMobile
      
      -- Check Lottable02 matches
      IF @cChkL02 <> @cLottable02
      BEGIN
         SET @nErrNo = 134956
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff batch
         GOTO Quit
      END      
   END

Quit:

END


GO
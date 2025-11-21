SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_Receive_ReceiptSerialNo                               */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Date       Rev  Author      Purposes                                       */
/* 2018-08-01 1.0  Ung         WMS-5722 Receive Serial No by batch            */
/* 2019-08-08 1.1  Ung         INC0807312 Renumber error no                   */
/* 2023-03-29 1.2  James       WMS-21943 Add UCCNo param and column (james01) */
/* 2025-02-11 1.3.0 NLT013     UWP-30047 Cannot receive the SerialNo if it is */
/*                             received with other ASN                        */
/* 2025-02-18 1.3.1 NLT013     UWP-30047 Add Configuration DisallowDuplicateSN*/
/******************************************************************************/

CREATE   PROCEDURE [RDT].[rdt_Receive_ReceiptSerialNo] (
   @nFunc               INT,
   @nMobile             INT,
   @cLangCode           NVARCHAR( 3),
   @cStorerKey          NVARCHAR( 15),
   @cFacility           NVARCHAR( 5),
   @cReceiptKey         NVARCHAR( 10),
   @cReceiptLineNumber  NVARCHAR( 5),
   @cSKU                NVARCHAR( 20),
   @cSerialNo           NVARCHAR( 30), 
   @nSerialQTY          INT, 
   @nErrNo              INT           OUTPUT,
   @cErrMsg             NVARCHAR( 20) OUTPUT,
   @cUCCNo              NVARCHAR( 20) = ''
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nRowCount            INT
   DECLARE @nTranCount           INT
   DECLARE @nReceiptSerialNoKey  INT
   DECLARE @cChkSerialSKU        NVARCHAR( 20)
   DECLARE @nChkSerialQTY        INT
   DECLARE @nChkSerialQTYExp     INT
   DECLARE @cDisallowDuplicateSN    NVARCHAR(1)

   -- UWP-30047 Reject the serial no if it was received with other ASN
   SET @cDisallowDuplicateSN = rdt.RDTGetConfig( @nFunc, 'DisallowDuplicateSN', @cStorerKey)

   IF (@cDisallowDuplicateSN = '1')
   BEGIN
      SELECT @nRowCount = COUNT(1)
      FROM dbo.ReceiptSerialNo RSN WITH (NOLOCK)
      INNER JOIN dbo.SerialNo SN WITH (NOLOCK)
         ON RSN.StorerKey = SN.StorerKey
         AND RSN.SerialNo = SN.SerialNo
      WHERE SN.StorerKey = @cStorerKey
         AND SN.Status NOT IN ('0', '9')
         AND SN.SerialNo = @cSerialNo
         AND RSN.ReceiptKey <> @cReceiptKey

      IF @nRowCount > 0
      BEGIN
         SET @nErrNo = 142757
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DuplicateSN
         GOTO Quit
      END
   END
   
   -- Get serial no info
   SELECT 
      @nReceiptSerialNoKey = ReceiptSerialNoKey, 
      @nChkSerialQTYExp = QTYExpected, 
      @cChkSerialSKU = SKU, 
      @nChkSerialQTY = QTY
   FROM ReceiptSerialNo WITH (NOLOCK)
   WHERE ReceiptKey = @cReceiptKey
      AND StorerKey = @cStorerKey
      AND SerialNo = @cSerialNo
   
   SET @nRowCount = @@ROWCOUNT
   SET @nTranCount = @@TRANCOUNT
   
   -- New serial no
   IF @nRowCount = 0
   BEGIN
      -- Handling transaction
      BEGIN TRAN  -- Begin our own transaction
      SAVE TRAN rdt_Receive_ReceiptSerialNo -- For rollback or commit only our own transaction
      
      -- Insert ReceiptSerialNo 
      INSERT INTO ReceiptSerialNo (ReceiptKey, ReceiptLineNumber, StorerKey, SKU, SerialNo, QTYExpected, QTY, UCCNo)
      VALUES (@cReceiptKey, @cReceiptLineNumber, @cStorerKey, @cSKU, @cSerialNo, @nSerialQTY, @nSerialQTY, @cUCCNo)
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 142751
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS RDSNo Fail
         GOTO RollBackTran
      END
      
      COMMIT TRAN rdt_Receive_ReceiptSerialNo
      GOTO Quit
   END
   
   -- Verify serial no
   ELSE IF @nRowCount = 1
   BEGIN
      -- Check SKU matches
      IF @cChkSerialSKU <> @cSKU
      BEGIN
         SET @nErrNo = 142752
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SNO Diff SKU
         GOTO Quit
      END
      
      -- Check QTY matches
      IF @nChkSerialQTYExp <> @nSerialQTY
      BEGIN
         SET @nErrNo = 142753
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SNO Diff QTY
         GOTO Quit
      END
      
      -- Check serial no received
      IF @nChkSerialQTY <> 0
      BEGIN
         SET @nErrNo = 142754
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SNO ady rcv
         GOTO Quit
      END

      -- Update serial no 
      UPDATE ReceiptSerialNo WITH (ROWLOCK) SET
         QTY = @nSerialQTY
      WHERE ReceiptSerialNoKey = @nReceiptSerialNoKey
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 142755
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD RSNO Fail
         GOTO Quit
      END      
   END
   ELSE
   BEGIN
      SET @nErrNo = 142756
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SNOMultiRecord 
      GOTO Quit
   END  
   GOTO Quit

RollBackTran:  
   ROLLBACK TRAN rdt_Receive_ReceiptSerialNo  
Quit:  
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started  
      COMMIT TRAN  
END

GO
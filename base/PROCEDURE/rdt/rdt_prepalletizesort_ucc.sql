SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/
/* Store procedure: rdt_PrePalletizeSort_UCC                            */
/* Copyright      : Maersk                                              */
/*                                                                      */
/* Purpose: Insert new UCC/Update UCC Qty                               */
/*                                                                      */
/* Called From: rdtfnc_PrePalletizeSort                                 */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2023-08-04 1.0  James      WMS-22995 Created                         */
/************************************************************************/

CREATE   PROC [RDT].[rdt_PrePalletizeSort_UCC] (
   @nMobile        INT,
   @nFunc          INT,
   @cLangCode      NVARCHAR( 3),
   @nStep          INT,
   @nInputKey      INT,
   @cFacility      NVARCHAR( 5),
   @cStorerKey     NVARCHAR( 15),
   @cReceiptKey    NVARCHAR( 10),
   @cPOKey         NVARCHAR( 10),
   @cLane          NVARCHAR( 10),
   @cUCC           NVARCHAR( 20),
   @cToID          NVARCHAR( 18),
   @cSKU           NVARCHAR( 20),
   @nQty           INT,
   @tExtUCC        VariableTable READONLY,
   @nErrNo         INT           OUTPUT,
   @cErrMsg        NVARCHAR( 20) OUTPUT
)
AS
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF


   DECLARE @nTranCount     INT

   SET @nTranCount = @@TRANCOUNT    
   BEGIN TRAN    
   SAVE TRAN rdt_PrePalletizeSort_UCC  
   
   IF @nStep = 7
      SET @nQty = 1  -- Only piece scanning
      
   IF NOT EXISTS ( SELECT 1
                   FROM dbo.UCC WITH (NOLOCK)
                   WHERE Storerkey = @cStorerKey
                   AND   UCCNo = @cUCC
                   AND   SKU = @cSKU)
   BEGIN
      -- Insert UCC
      INSERT INTO dbo.UCC (StorerKey, UCCNo, Status, SKU, QTY, LOC, ID, ReceiptKey, ReceiptLineNumber, ExternKey)
      VALUES (@cStorerKey, @cUCC, '0', @cSKU, @nQTY, '', '', @cPOKey, '', '')
      
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 204901
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'INS UCC Fail'
         GOTO RollBackTran
      END
 
   END
   ELSE
   BEGIN
   	UPDATE dbo.UCC SET 
   	   Qty = Qty + @nQty,
   	   EditWho = SUSER_SNAME(),
   	   EditDate = GETDATE()
   	WHERE Storerkey = @cStorerKey
   	AND   UCCNo = @cUCC
   	AND   SKU = @cSKU
   	
   	IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 204902
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'upd UCC Fail'
         GOTO RollBackTran
      END
   END
   
   GOTO Quit

   RollBackTran:
         ROLLBACK TRAN rdt_PrePalletizeSort_UCC
   Quit:
      WHILE @@TRANCOUNT > @nTranCount
         COMMIT TRAN


GO
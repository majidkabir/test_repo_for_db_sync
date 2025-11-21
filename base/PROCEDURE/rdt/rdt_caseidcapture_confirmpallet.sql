SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/************************************************************************/
/* Copyright: LF Logistics                                              */
/* Purpose: Loop cases on pallet, stamp CaseID on PickDetail.DropID     */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author   Purposes                                    */
/* 2017-03-27 1.0  Ung      WMS-1373 Created                            */
/* 2018-05-16 1.1  Ung      WMS-4846 CodeLKUP MHCSSCAN add StorerKey    */
/************************************************************************/
  
CREATE PROCEDURE [RDT].[rdt_CaseIDCapture_ConfirmPallet] (  
   @nMobile    INT,
   @nFunc      INT, 
   @cLangCode  NVARCHAR( 3),
   @cUserName  NVARCHAR( 18),
   @cFacility  NVARCHAR( 5),
   @cStorerKey NVARCHAR( 15),
   @cOrderKey  NVARCHAR( 15),
   @cPalletID  NVARCHAR( 18),
   @nErrNo     INT OUTPUT,   
   @cErrMsg    NVARCHAR( 20) OUTPUT
) AS  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  

   DECLARE @nUCCCount INT
   DECLARE @nCases    INT
   DECLARE @cBrand    NVARCHAR( 10)
   DECLARE @cSKU      NVARCHAR( 20)
   DECLARE @cBatchNo  NVARCHAR( 18)
   DECLARE @cCaseID   NVARCHAR( 18)
   DECLARE @cUCCNo    NVARCHAR( 20)
   DECLARE @nTranCount INT

   SET @nTranCount = @@TRANCOUNT

   -- Get UCC count on pallet
   SELECT @nUCCCount = COUNT(1) FROM UCC WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND ID = @cPalletID AND Status = '1'
   
   -- Get case count on PickDetail
   SELECT @nCases = SUM( A.Cases)
   FROM 
   (
      SELECT SUM( PD.QTY) / Pack.CaseCnt AS Cases
      FROM PickDetail PD WITH (NOLOCK) 
         JOIN SKU WITH (NOLOCK) ON (PD.StorerKey = SKU.StorerKey AND PD.SKU = SKU.SKU)
         JOIN Pack WITH (NOLOCK) ON (Pack.PackKey = SKU.PackKey)
      WHERE PD.OrderKey = @cOrderKey 
         AND PD.ID = @cPalletID 
         AND PD.UOM IN ('1', '2')
         AND PD.Status <> '4'
         AND PD.QTY > 0
         AND Pack.CaseCnt > 0
      GROUP BY SKU.SKU, Pack.CaseCnt
   ) A
   
   -- Check UCC tally cases
   IF @nUCCCount <> @nCases
   BEGIN
      SET @nErrNo = 107301
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --CaseCountDiff
      GOTO Quit
   END

   BEGIN TRAN
   SAVE TRAN rdt_CaseIDCapture_ConfirmPallet
   
   DECLARE @curUCC CURSOR
   SET @curUCC = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT UCCNo, SKU, UserDefined01, UserDefined02
      FROM UCC WITH (NOLOCK) 
      WHERE StorerKey = @cStorerKey 
         AND ID = @cPalletID 
         AND Status = '1'

   OPEN @curUCC
   FETCH NEXT FROM @curUCC INTO @cUCCNo, @cSKU, @cCaseID, @cBatchNo
   WHILE @@FETCH_STATUS = 0
   BEGIN
      -- Get SKU info
      SELECT @cBrand = Class FROM SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU = @cSKU 
   
      -- Check brand need to capture
      IF NOT EXISTS( SELECT 1 FROM CodeLkup WITH (NOLOCK) WHERE ListName = 'MHCSSCAN' AND Code = @cBrand AND StorerKey = @cStorerKey)
      BEGIN
         -- Capture CaseID
         EXECUTE rdt.rdt_CaseIDCapture_Confirm @nMobile, @nFunc, @cLangCode, @cUserName, @cFacility, @cStorerKey
            ,@cOrderKey
            ,@cSKU
            ,@cBatchNo
            ,@cCaseID
            ,@cPalletID
            ,@nErrNo       OUTPUT
            ,@cErrMsg      OUTPUT
         IF @nErrNo <> 0
            GOTO RollBackTran
      END
      
      -- Update UCC
      UPDATE UCC SET 
         Status = '6'
      WHERE StorerKey = @cStorerKey
         AND UCCNo = @cUCCNo
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 107302
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD UCC Fail
         GOTO Quit
      END
      
      FETCH NEXT FROM @curUCC INTO @cUCCNo, @cSKU, @cCaseID, @cBatchNo
   END   

   COMMIT TRAN rdt_CaseIDCapture_ConfirmPallet
   GOTO Quit
   
RollBackTran:
      ROLLBACK TRAN rdt_CaseIDCapture_ConfirmPallet
Quit:
   WHILE @@TRANCOUNT > @nTranCount
      COMMIT TRAN

GO
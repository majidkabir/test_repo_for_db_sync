SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/******************************************************************************/  
/* Store procedure: rdt_1812ExtScn05_Confirm                                  */  
/* Copyright      : MAERSK                                                    */  
/*                                                                            */  
/* Purpose: Create pallet/mbol/packinfo record after key in toloc             */  
/*                                                                            */  
/* Date       Rev  Author   Purposes                                          */  
/* 2024-09-23 1.0  James    WMS-26122 Created                                 */  
/* 2024-11-11 1.1  PXL009   FCR-1125 Merged 1.0 from v0 branch                */
/*                            the original name is rdt_1812ExtScn01_Confirm   */
/******************************************************************************/  
  
CREATE   PROC [rdt].[rdt_1812ExtScn05_Confirm] (  
   @nMobile          INT,             
   @nFunc            INT,             
   @cLangCode        NVARCHAR( 3),    
   @nStep            INT OUTPUT,   
   @nScn             INT OUTPUT,            
   @nInputKey        INT,             
   @cFacility        NVARCHAR( 5),    
   @cStorerKey       NVARCHAR( 15),   
   @cTaskdetailKey   NVARCHAR( 10), 
   @cDropID          NVARCHAR( 20),   
   @nQTY             INT, 
   @cToLOC           NVARCHAR( 10), 
   @cToLane          NVARCHAR( 20),    
   @cInField01       NVARCHAR( 60) OUTPUT,  @cOutField01 NVARCHAR( 60) OUTPUT,  @cFieldAttr01 NVARCHAR( 1) OUTPUT,    
   @cInField02       NVARCHAR( 60) OUTPUT,  @cOutField02 NVARCHAR( 60) OUTPUT,  @cFieldAttr02 NVARCHAR( 1) OUTPUT,    
   @cInField03       NVARCHAR( 60) OUTPUT,  @cOutField03 NVARCHAR( 60) OUTPUT,  @cFieldAttr03 NVARCHAR( 1) OUTPUT,    
   @cInField04       NVARCHAR( 60) OUTPUT,  @cOutField04 NVARCHAR( 60) OUTPUT,  @cFieldAttr04 NVARCHAR( 1) OUTPUT,    
   @cInField05       NVARCHAR( 60) OUTPUT,  @cOutField05 NVARCHAR( 60) OUTPUT,  @cFieldAttr05 NVARCHAR( 1) OUTPUT,    
   @cInField06       NVARCHAR( 60) OUTPUT,  @cOutField06 NVARCHAR( 60) OUTPUT,  @cFieldAttr06 NVARCHAR( 1) OUTPUT,   
   @cInField07       NVARCHAR( 60) OUTPUT,  @cOutField07 NVARCHAR( 60) OUTPUT,  @cFieldAttr07 NVARCHAR( 1) OUTPUT,   
   @cInField08       NVARCHAR( 60) OUTPUT,  @cOutField08 NVARCHAR( 60) OUTPUT,  @cFieldAttr08 NVARCHAR( 1) OUTPUT,   
   @cInField09       NVARCHAR( 60) OUTPUT,  @cOutField09 NVARCHAR( 60) OUTPUT,  @cFieldAttr09 NVARCHAR( 1) OUTPUT,   
   @cInField10       NVARCHAR( 60) OUTPUT,  @cOutField10 NVARCHAR( 60) OUTPUT,  @cFieldAttr10 NVARCHAR( 1) OUTPUT,   
   @cInField11       NVARCHAR( 60) OUTPUT,  @cOutField11 NVARCHAR( 60) OUTPUT,  @cFieldAttr11 NVARCHAR( 1) OUTPUT,   
   @cInField12       NVARCHAR( 60) OUTPUT,  @cOutField12 NVARCHAR( 60) OUTPUT,  @cFieldAttr12 NVARCHAR( 1) OUTPUT,   
   @cInField13       NVARCHAR( 60) OUTPUT,  @cOutField13 NVARCHAR( 60) OUTPUT,  @cFieldAttr13 NVARCHAR( 1) OUTPUT,   
   @cInField14       NVARCHAR( 60) OUTPUT,  @cOutField14 NVARCHAR( 60) OUTPUT,  @cFieldAttr14 NVARCHAR( 1) OUTPUT,   
   @cInField15       NVARCHAR( 60) OUTPUT,  @cOutField15 NVARCHAR( 60) OUTPUT,  @cFieldAttr15 NVARCHAR( 1) OUTPUT,   
   @nErrNo           INT           OUTPUT,   
   @cErrMsg          NVARCHAR( 20) OUTPUT  
)  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE @nTranCount  INT
   DECLARE @nCartonNo   INT
   DECLARE @nPackQty    INT
   DECLARE @cOrderKey   NVARCHAR( 10)
   DECLARE @cSKU        NVARCHAR( 20)
   DECLARE @cUserName   NVARCHAR( 18)
   DECLARE @cPickSlipNo NVARCHAR( 10)
   DECLARE @cLabelNo    NVARCHAR( 20)
   DECLARE @cUserDefined01    NVARCHAR( 15)
   DECLARE @cUserDefined02    NVARCHAR( 15)
   DECLARE @cUserDefined03    NVARCHAR( 20)
   DECLARE @cUserDefined04    NVARCHAR( 30)
   DECLARE @cPalletLineNumber NVARCHAR( 5)
   DECLARE @curPltD     CURSOR
   DECLARE @curMbolD    CURSOR



   -- Handling transaction  
   SET @nTranCount = @@TRANCOUNT  
   BEGIN TRAN  -- Begin our own transaction  
   SAVE TRAN rdt_1812ExtScn05Cfm -- For rollback or commit only our own transaction  

   SELECT @cUserName = UserName
   FROM rdt.RDTMOBREC WITH (NOLOCK)
   WHERE Mobile = @nMobile

   -- Pallet  
   IF NOT EXISTS( SELECT 1 FROM dbo.Pallet WITH (NOLOCK) WHERE PalletKey = @cDropID)  
   BEGIN  
      INSERT INTO dbo.Pallet (PalletKey, StorerKey, Status)  
      VALUES (@cDropID, @cStorerKey, '0')  
      IF @@ERROR <> 0  
      BEGIN  
         SET @nErrNo = 229001  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INSPLTHdrFail  
         GOTO RollBackTran  
      END  
   END  

   SET @curPltD = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
   SELECT PickSlipNo, LabelNo, CartonNo, ISNULL( SUM( Qty), 0)
   FROM dbo.PACKDETAIL WITH (NOLOCK)
   WHERE StorerKey = @cStorerKey
   AND   DropID = @cDropID
   GROUP BY PickSlipNo, LabelNo, CartonNo
   OPEN @curPltD
   FETCH NEXT FROM @curPltD INTO @cPickSlipNo, @cLabelNo, @nCartonNo, @nPackQty
   WHILE @@FETCH_STATUS = 0
   BEGIN
      SELECT TOP 1 @cSKU = SKU
      FROM dbo.PACKDETAIL WITH (NOLOCK)
      WHERE PickSlipNo = @cPickSlipNo
      AND   LabelNo = @cLabelNo
      ORDER BY 1

      SELECT @cOrderKey = OrderKey
      FROM dbo.PACKHEADER WITH (NOLOCK)
      WHERE PickSlipNo = @cPickSlipNo

      -- PalletDetail  
      IF NOT EXISTS( SELECT 1 FROM dbo.PalletDetail WITH (NOLOCK) WHERE PalletKey = @cDropID AND CaseId = @cLabelNo)  
      BEGIN  
         SELECT @cPalletLineNumber = RIGHT( '00000' + CAST( CAST( IsNULL( MAX( PalletLineNumber), 0) AS INT) + 1 AS NVARCHAR( 5)), 5)    
         FROM PalletDetail WITH (NOLOCK)    
         WHERE PalletKey = @cDropID    

         INSERT INTO dbo.PalletDetail (PalletKey, PalletLineNumber, CaseID, StorerKey, SKU, LOC, Qty, Status, UserDefine01, UserDefine03, ArchiveCop)  
         VALUES (@cDropID, @cPalletLineNumber, @cLabelNo, @cStorerKey, @cSKU, ISNULL( @cToLOC, ''), @nPackQty, '9', @cOrderKey, @cToLane, '9')  
         IF @@ERROR <> 0  
         BEGIN  
            SET @nErrNo = 229002  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INSPLTDtlFail  
            GOTO RollBackTran  
         END  
      END  

      FETCH NEXT FROM @curPltD INTO @cPickSlipNo, @cLabelNo, @nCartonNo, @nPackQty
   END

   -- Close pallet  
   IF EXISTS( SELECT 1 FROM dbo.Pallet WITH (NOLOCK) WHERE PalletKey = @cDropID AND Status = '0')  
   BEGIN  
      UPDATE dbo.Pallet SET  
         Status = '9',   
         EditDate = GETDATE(),   
         EditWho = @cUserName  
      WHERE PalletKey = @cDropID  
      IF @@ERROR <> 0  
      BEGIN  
         SET @nErrNo = 229003  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPDPLTHdrFail  
         GOTO RollBackTran  
      END  
   END  
        
   -- Get MBOL info  
   DECLARE @cMBOLKey NVARCHAR( 10) = ''  
   SELECT @cMBOLKey = MBOLKey   
   FROM dbo.MBOL WITH (NOLOCK)   
   WHERE Facility = @cFacility  
   AND   Status < '9'  
   AND   ExternMBOLKey = @cToLane  
        
   -- MBOL  
   IF @cMBOLKey = ''  
   BEGIN  
      DECLARE @nSuccess INT = 1  
      EXECUTE dbo.nspg_getkey  
         'MBOL'  
         , 10  
         , @cMBOLKey    OUTPUT  
         , @nSuccess    OUTPUT  
         , @nErrNo      OUTPUT  
         , @cErrMsg     OUTPUT  
        
      INSERT INTO dbo.MBOL (  
         MBOLKey, ExternMBOLKey, Facility, Status, AddWho, AddDate, EditWho, EditDate)   
      VALUES   
         (@cMBOLKey, @cToLane, @cFacility, '0', 'rdt.' + @cUserName, GETDATE(), 'rdt.' + @cUserName, GETDATE())  
      IF @@ERROR <> 0  
      BEGIN  
         SET @nErrNo = 229004  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS MBOL Fail  
         GOTO RollBackTran  
      END  
   END  

   SET @curMbolD = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
   SELECT DISTINCT PH.OrderKey
   FROM dbo.PackDetail PD WITH (NOLOCK)
   JOIN dbo.PackHeader PH WITH (NOLOCK) ON ( PD.PickSlipNo = PH.PickSlipNo)
   WHERE PD.StorerKey = @cStorerKey
   AND   PD.DropID = @cDropID
   ORDER BY 1
   OPEN @curMbolD
   FETCH NEXT FROM @curMbolD INTO @cOrderKey
   WHILE @@FETCH_STATUS = 0
   BEGIN
      -- MBOLDetail  
      IF NOT EXISTS( SELECT 1 FROM dbo.MBOLDetail WITH (NOLOCK) WHERE MBOLKey = @cMBOLKey AND OrderKey = @cOrderKey)  
      BEGIN  
         INSERT INTO dbo.MBOLDetail   
            (MBOLKey, MBOLLineNumber, OrderKey, LoadKey, AddWho, AddDate, EditWho, EditDate)  
         VALUES   
            (@cMBOLKey, '00000', @cOrderKey, '', 'rdt.' + @cUserName, GETDATE(), 'rdt.' + @cUserName, GETDATE())  
         IF @@ERROR <> 0  
         BEGIN  
            SET @nErrNo = 229005  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS MBDtl Fail  
            GOTO RollbackTran  
         END  
      END  

      FETCH NEXT FROM @curMbolD INTO @cOrderKey
   END

   COMMIT TRAN rdt_1812ExtScn05Cfm -- Only commit change made here  
   GOTO Quit  
  
   RollBackTran:  
      ROLLBACK TRAN rdt_1812ExtScn05Cfm -- Only rollback change made here  
   Fail:  
   Quit:  
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started  
         COMMIT TRAN  
END  
  
SET QUOTED_IDENTIFIER OFF 

GO
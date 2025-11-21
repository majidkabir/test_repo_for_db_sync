SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store procedure: rdt_1628_DropID01                                   */  
/* Copyright      : IDS                                                 */  
/*                                                                      */  
/* Purpose: Nike custom create drop id stored proc                      */  
/*                                                                      */  
/* Called from: rdt_Cluster_Pick_DropID                                 */  
/*                                                                      */  
/* Exceed version: 5.4                                                  */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date        Rev  Author     Purposes                                 */  
/* 04-Apr-2018 1.0  James      WMS4338. Created                         */  
/************************************************************************/  
  
CREATE PROC [RDT].[rdt_1628_DropID01] (  
   @nMobile                   INT,             
   @nFunc                     INT,             
   @cLangCode                 NVARCHAR( 3),    
   @cStorerkey                NVARCHAR( 15),   
   @cUserName                 NVARCHAR( 15),   
   @cFacility                 NVARCHAR( 5),    
   @cLoadKey                  NVARCHAR( 10),   
   @cPickSlipNo               NVARCHAR( 10),   
   @cOrderKey                 NVARCHAR( 10),   
   @cDropID                   NVARCHAR( 20) OUTPUT,   
   @cSKU                      NVARCHAR( 20),   
   @cActionFlag               NVARCHAR( 1),   
   @nErrNo                    INT           OUTPUT,    
   @cErrMsg                   NVARCHAR( 20) OUTPUT     
           
)  
AS  
BEGIN  
   SET NOCOUNT ON    
   SET QUOTED_IDENTIFIER OFF    
   SET ANSI_NULLS OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF    
     
   DECLARE @nTranCount        INT,   
           @nUpdate           INT,   
           @cDropIDType       NVARCHAR( 10),   
           @cLoadPickMethod   NVARCHAR( 10),   
           @cPD_OrderKey      NVARCHAR( 10),   
           @cPD_DropID        NVARCHAR( 20), 
           @cChildID          NVARCHAR( 20), 
           @cKeyName          NVARCHAR( 18), 
           @cCounter          NVARCHAR( 6), 
           @nDropIDQty        INT,
           @bSuccess          INT,
           @nStep             INT



   SELECT @nStep = Step FROM RDT.RDTMOBREC WITH (NOLOCK) WHERE Mobile = @nMobile

   IF ISNULL(@cLoadKey, '') = ''  
      SELECT @cLoadKey = LoadKey   
      FROM dbo.LoadPlanDetail WITH (NOLOCK)   
      WHERE OrderKey = @cOrderKey  
  
   IF ISNULL(@cLoadKey, '') <> ''  
      SELECT @cLoadPickMethod = LoadPickMethod   
      FROM dbo.LoadPlan WITH (NOLOCK)   
      WHERE LoadKey = @cLoadKey  

   IF @cActionFlag = 'R'  
   BEGIN  
      IF @nStep IN ( 6, 15)
         GOTO Quit

      SET @cDropID = ''  
      SELECT TOP 1 @cDropID = DropID   
      FROM RDT.RDTPICKLOCK WITH (NOLOCK)   
      WHERE LoadKey = @cLoadKey  
      AND   AddWho = @cUserName
      AND   Status = '1'
      ORDER BY 1

      IF ISNULL( @cDropID, '') = ''
      BEGIN  
         SET @nErrNo = 122401  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'NO RECORD'  
         GOTO Quit
      END  
   END  

   SET @nTranCount = @@TRANCOUNT  
   BEGIN TRAN  
   SAVE TRAN rdt_1628_DropID01  

   IF @cActionFlag = 'I'  
   BEGIN  
      IF EXISTS (SELECT 1 FROM dbo.DropID WITH (NOLOCK)   
                 WHERE DropID = @cDropID 
                 AND   LoadKey = @cLoadKey  
                 AND   [Status] < '9')  
      BEGIN  
         SET @nErrNo = 122403  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'DROP ID EXISTS'  
         GOTO RollBackTran  
      END  

      SET @cKeyName = 'DRID_' + RTRIM( @cStorerKey)

      INSERT INTO dbo.DropID   
      (DropID, DropIDType, LabelPrinted, ManifestPrinted, [Status], PickSlipNo, LoadKey)  
      VALUES   
      (@cDropID, @cKeyName, '0', '0', '0', @cPickSlipNo, @cLoadKey)  
     
      IF @@ERROR <> 0  
      BEGIN  
         SET @nErrNo = 122404  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'INS DROPID FAIL'  
         GOTO RollBackTran  
      END  
   END  

   IF @cActionFlag = 'U'  
   BEGIN  
      IF NOT EXISTS (SELECT 1 FROM dbo.DropID WITH (NOLOCK)   
                     WHERE DropID = @cDropID
                     AND   LoadKey = @cLoadKey
                     AND   [Status] < '9')  
      BEGIN  
         SET @nErrNo = 122405  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'INVALID DROP ID'  
         GOTO RollBackTran  
      END  
        
      UPDATE dbo.DropID WITH (ROWLOCK) SET   
         [Status] = '9'   
      WHERE LoadKey = @cLoadKey  
      AND   DropID = @cDropID  
      AND   [Status] < '9'  
  
      IF @@ERROR <> 0  
      BEGIN  
         SET @nErrNo = 122406  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UPD DROP ID ERR'  
         GOTO RollBackTran  
      END  

      UPDATE rdt.rdtPickLock WITH (ROWLOCK) SET 
         DROPID = ''
      WHERE LoadKey = @cLoadKey
      AND   DROPID = @cDropID
      AND   [Status] = '1'  
      AND   AddWho = @cUserName

      IF @@ERROR <> 0  
      BEGIN  
         SET @nErrNo = 122409  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UPD DROP ID ERR'  
         GOTO RollBackTran  
      END  

      SET @cDropID = ''
   END  

   IF @cActionFlag = 'D'  
   BEGIN  
      IF NOT EXISTS (SELECT 1 FROM dbo.DropID WITH (NOLOCK)   
                     WHERE DropID = @cDropID)  
      BEGIN  
         SET @nErrNo = 122407  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'INVALID DROPID'  
         GOTO RollBackTran  
      END  
        
      DELETE FROM dbo.DropID   
      WHERE DropID = @cDropID   
  
      IF @@ERROR <> 0  
      BEGIN  
         SET @nErrNo = 122408  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'DEL DROP ID ERR'  
         GOTO RollBackTran  
      END  
   END  

   IF @cActionFlag = 'N'
   BEGIN
      -- If user key in their desired drop id then no need gen new drop id
      SELECT @cDropID = I_Field10 FROM RDT.RDTMOBREC WITH (NOLOCK) WHERE Mobile = @nMobile

      -- If blank then generate a new dropid
      IF ISNULL( @cDropID, '') = ''
      BEGIN
         SET @cKeyName = 'DRID_' + RTRIM( @cStorerKey)
         EXECUTE nspg_getkey
            @KeyName       = @cKeyName,
            @fieldlength   = 6,    
            @keystring     = @cCounter    Output,
            @b_success     = @bSuccess    Output,
            @n_err         = @nErrNo      Output,
            @c_errmsg      = @cErrMsg     Output,
            @b_resultset   = 0,
            @n_batch       = 1

         IF @nErrNo <> 0 OR @bSuccess <> 1
         BEGIN
            SET @nErrNo = 122402  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'GEN NEW ID ERR'  
            GOTO RollBackTran
         END

         SET @cDropID = 'ID' + RTRIM( @cLoadKey) + RIGHT( '00000' + @cCounter, 6)
      END
   END

   GOTO CommitTran  
  
   RollBackTran:  
      ROLLBACK TRAN rdt_1628_DropID01  
  
   CommitTran:  
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started  
         COMMIT TRAN rdt_1628_DropID01  

   Quit:
  
END

GO
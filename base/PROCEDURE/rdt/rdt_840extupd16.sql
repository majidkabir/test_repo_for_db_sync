SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/************************************************************************/    
/* Store procedure: rdt_840ExtUpd16                                     */    
/* Purpose: Turn Off light for ptl station                              */    
/*                                                                      */    
/* Modifications log:                                                   */    
/*                                                                      */    
/* Date        Rev  Author     Purposes                                 */    
/* 2021-07-23  1.0  James      WMS-17435. Created                       */  
/* 2022-07-28  1.1  James      WMS-20111. Add update trackno (james01)  */  
/* 2022-11-07  1.2  James      WMS-21130 Move interface triggering from */
/*                             step 5 to step 4 (james02)               */
/************************************************************************/    
    
CREATE   PROC [RDT].[rdt_840ExtUpd16] (    
   @nMobile     INT,    
   @nFunc       INT,    
   @cLangCode   NVARCHAR( 3),    
   @nStep       INT,    
   @nInputKey   INT,    
   @cStorerkey  NVARCHAR( 15),    
   @cOrderKey   NVARCHAR( 10),    
   @cPickSlipNo NVARCHAR( 10),    
   @cTrackNo    NVARCHAR( 20),    
   @cSKU        NVARCHAR( 20),    
   @nCartonNo   INT,    
   @cSerialNo   NVARCHAR( 30),   
   @nSerialQTY  INT,    
   @nErrNo      INT           OUTPUT,    
   @cErrMsg     NVARCHAR( 20) OUTPUT    
)    
AS    
    
   SET NOCOUNT ON    
   SET QUOTED_IDENTIFIER OFF    
   SET ANSI_NULLS OFF    
    
   DECLARE @cStation             NVARCHAR( 10)  
   DECLARE @bSuccess             INT  
   DECLARE @cExternOrderKey      NVARCHAR( 30)  
   DECLARE @cMBOLKey             NVARCHAR( 10)  
   DECLARE @cShipOrdAfterPackCfm NVARCHAR( 1)  
   DECLARE @cAPP_DB_Name         NVARCHAR( 20) = ''    
   DECLARE @cDataStream          VARCHAR( 10)  = ''    
   DECLARE @nThreadPerAcct       INT = 0    
   DECLARE @nThreadPerStream     INT = 0    
   DECLARE @nMilisecondDelay     INT = 0    
   DECLARE @cIP                  NVARCHAR( 20) = ''    
   DECLARE @cPORT                NVARCHAR( 5)  = ''    
   DECLARE @cPORT2               NVARCHAR( 5)  = ''    
   DECLARE @cIniFilePath         NVARCHAR( 200)= ''    
   DECLARE @cCmdType             NVARCHAR( 10) = ''    
   DECLARE @cTaskType            NVARCHAR( 1)  = ''        
   DECLARE @cOrderLineNumber     NVARCHAR( 5)  = ''  
   DECLARE @nContinue            INT = 0  
   DECLARE @cCommand             NVARCHAR( 1000) = ''  
   DECLARE @nMinCartonNo         INT  
   DECLARE @nMaxCartonNo         INT  
   DECLARE @cShipperKey          NVARCHAR( 15) = ''
   DECLARE @cTrackingNo          NVARCHAR( 20) = ''
   DECLARE @nUpdTrackNo          INT = 0
   DECLARE @cSOStatus            NVARCHAR( 10) = ''
   
   DECLARE @nTranCount  INT  
   SET @nTranCount = @@TRANCOUNT  
   BEGIN TRAN  
   SAVE TRAN rdt_840ExtUpd16  
   
   IF @nStep = 3  -- SKU
   BEGIN
      SELECT @cSOStatus = SOStatus
      FROM dbo.ORDERS WITH (NOLOCK)
      WHERE OrderKey = @cOrderKey

      IF @cSOStatus = 'PENDCANC'      
      BEGIN
         SET @nErrNo = 176405  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'PENDCANC'  
         GOTO RollBackTran  
      END
   END
   
   IF @nStep = 4 -- Carton Type/Weight  
   BEGIN  
      IF @nInputKey = 1  
      BEGIN  
      	SELECT 
      	   @cShipperKey = ShipperKey, 
      	   @cTrackingNo = TrackingNo,
      	   @cSOStatus = SOStatus
      	FROM dbo.ORDERS WITH (NOLOCK)
      	WHERE OrderKey = @cOrderKey

         IF EXISTS ( SELECT 1 FROM dbo.CODELKUP WITH (NOLOCK)
                     WHERE LISTNAME = 'PMADDTRK'
                     AND   Code = @cShipperKey)
         	SET @nUpdTrackNo = 1
                     
         UPDATE dbo.PackInfo SET 
            [Weight] = CASE WHEN [Weight] > 0 THEN [Weight]/1000 ELSE [Weight] END,   
            TrackingNo = CASE WHEN @nUpdTrackNo = 0 THEN TrackingNo ELSE @cTrackingNo END,
            EditWho = SUSER_SNAME(),   
            EditDate = GETDATE()   
         WHERE PickSlipNo = @cPickSlipNo  
         AND   CartonNo = @nCartonNo  
           
         IF @@ERROR <> 0  
         BEGIN  
            SET @nErrNo = 176401  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UPDPKINFO Err'  
            GOTO RollBackTran  
         END  
  
         SELECT @cExternOrderKey = ExternOrderKey  
         FROM dbo.ORDERS WITH (NOLOCK)  
         WHERE OrderKey = @cOrderKey  
           
         UPDATE dbo.PackHeader SET   
            OrderRefNo = SUBSTRING( @cExternOrderKey, 1, 18),  
            EditWho = SUSER_SNAME(),   
            EditDate = GETDATE()   
         WHERE PickSlipNo = @cPickSlipNo  
  
         IF @@ERROR <> 0  
         BEGIN  
            SET @nErrNo = 176402  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UPD REFNO Err'  
            GOTO RollBackTran  
        END  
      END     
   END  
  
   COMMIT TRAN rdt_840ExtUpd16 -- Only commit change made here  
   GOTO Quit  
  
RollBackTran:  
   ROLLBACK TRAN rdt_840ExtUpd16 -- Only rollback change made here  
Quit:  
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started  
      COMMIT TRAN    
  
   IF @nStep = 4    
   BEGIN    
      IF @nInputKey = 1   
      BEGIN    
         SET @cShipOrdAfterPackCfm = rdt.RDTGetConfig( @nFunc, 'ShipOrdAfterPackCfm', @cStorerKey)  
           
         IF EXISTS( SELECT 1 FROM dbo.PackHeader WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND [Status] = '9')  
         BEGIN  
            IF @cShipOrdAfterPackCfm = '1'  
            BEGIN  
               SELECT @cMBOLKey = MBOLKey  
               FROM dbo.ORDERS WITH (NOLOCK)  
               WHERE OrderKey = @cOrderKey  
     
               IF ISNULL( @cMBOLKey, '') = ''  
               BEGIN  
                  SET @nErrNo = 176403  
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'No MBOLKEY'  
                  GOTO Fail  
               END  
  
               SELECT   
                  @nMinCartonNo = MIN( CartonNo),  
                  @nMaxCartonNo = MAX( CartonNo)  
               FROM dbo.PackDetail WITH (NOLOCK)  
               WHERE PickSlipNo = @cPickSlipNo  
                 
               SET @nErrNo = 0  
               EXEC [dbo].[isp_PrintCartonLabel_Interface]        
                            @c_Pickslipno   = @cPickSlipNo           
                        ,   @n_CartonNo_Min = @nMaxCartonNo -- set 2 values same as iml only need 1 carton no      
                        ,   @n_CartonNo_Max = @nMaxCartonNo      
                        ,   @b_Success      = @bSuccess OUTPUT      
                        ,   @n_Err          = @nErrNo   OUTPUT      
                        ,   @c_ErrMsg       = @cErrMsg  OUTPUT     
  
               IF @nErrNo <> 0  
               BEGIN  
                  SET @nErrNo = 176404  
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'BEnd MBOL Err'  
                  GOTO Fail  
               END  
                 
               SELECT TOP 1 @cStation = Station  
               FROM rdt.rdtPTLPieceLog WITH (NOLOCK)  
               WHERE OrderKey = @cOrderKey  
               ORDER BY 1  
           
               -- Clear light  
               EXEC PTL.isp_PTL_TerminateModule  
                   @cStorerKey  
                  ,@nFunc  
                  ,@cStation  
                  ,'STATION'  
                  ,@bSuccess    OUTPUT  
                  ,@nErrNo      --OUTPUT -- Prevent PTL overwrite RDT error  
                  ,@cErrMsg     --OUTPUT -- Prevent PTL overwrite RDT error  
               IF @nErrNo <> 0  
                  GOTO Fail  
            END  
         END  
      END  
   END    
    
Fail:   

GO
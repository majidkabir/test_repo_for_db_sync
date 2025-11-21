SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store procedure: rdt_1637ExtUpd02                                    */  
/* Purpose: LOGITECH Event Tracking                                     */  
/*                                                                      */  
/* Called from: rdtfnc_Scan_To_Container                                */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date       Rev  Author     Purposes                                  */  
/* 2017-05-05 1.0  ChewKP     WMS-1800 Created                          */    
/************************************************************************/  
  
CREATE PROC [RDT].[rdt_1637ExtUpd02] (  
   @nMobile                   INT,             
   @nFunc                     INT,             
   @cLangCode                 NVARCHAR( 3),    
   @nStep                     INT,             
   @nInputKey                 INT,             
   @cStorerkey                NVARCHAR( 15),   
   @cContainerKey             NVARCHAR( 10),   
   @cMBOLKey                  NVARCHAR( 10),   
   @cSSCCNo                   NVARCHAR( 20),   
   @cPalletKey                NVARCHAR( 18),   
   @cTrackNo                  NVARCHAR( 20),   
   @cOption                   NVARCHAR( 1),   
   @nErrNo                    INT           OUTPUT,    
   @cErrMsg                   NVARCHAR( 20) OUTPUT     
)  
AS  
  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
  
   DECLARE @nTranCount     INT,  
           @bSuccess       INT,   
           @cFacility      NVARCHAR( 5),  
           @cOrderKey      NVARCHAR( 10),   
           @cExternOrderKey NVARCHAR(30),  
           @cStatus     NVARCHAR(10),  
           @nRowRef     INT  
             
   SELECT @cFacility = Facility  
   FROM RDT.RDTMOBREC WITH (NOLOCK)   
   WHERE Mobile = @nMobile  
  
   IF @nInputKey = 1  
   BEGIN  
      IF @nStep = 3  
      BEGIN  
        
         IF ISNULL( @cPalletKey, '') = ''  
         BEGIN  
            SET @nErrNo = 108851     
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PALLET ID REQ  
            GOTO RollBackTran  
         END  
  
--         SELECT TOP 1 @cOrderKey = OrderKey   
--         FROM dbo.PickDetail WITH (NOLOCK)   
--         WHERE StorerKey = @cStorerKey  
--         AND   ID = @cPalletKey  
--         AND  [Status] < '9'  
  
         -- Get the mbolkey for this particular pallet id  
--         SELECT @cMBOL4PltID = MbolKey, @cLoadKey = LoadKey    
--         FROM dbo.MBOLDetail WITH (NOLOCK)   
--         WHERE OrderKey = @cOrderKey  
  
         DECLARE CUR_LOOP CURSOR LOCAL READ_ONLY FAST_FORWARD FOR   
           
         SELECT O.OrderKey, O.Status, O.ExternOrderKey  
         FROM dbo.PickDetail PD WITH (NOLOCK)   
         INNER JOIN dbo.Orders O WITH (NOLOCK) ON O.OrderKey = PD.OrderKey   
         WHERE PD.StorerKey = @cStorerKey  
         AND PD.ID = @cPalletKey   
         GROUP BY O.OrderKey, O.Status, O.ExternOrderKey  
         ORDER BY O.OrderKey   
           
         OPEN CUR_LOOP  
         FETCH NEXT FROM CUR_LOOP INTO @cOrderKey, @cStatus, @cExternOrderKey   
         WHILE @@FETCH_STATUS <> -1   
         BEGIN  
                          
            IF NOT EXISTS ( SELECT 1 FROM dbo.DocStatusTrack WITH (NOLOCK)   
                  WHERE StorerKey = @cStorerKey  
                  AND DocumentNo = @cOrderKey   
                  AND TableName = 'EDLD'  
                  AND DocStatus = '9' ) -- @cStatus )   
            BEGIN  
               
--             SELECT @nRowRef = RowRef   
--             FROM dbo.DocStatusTrack WITH (NOLOCK)   
--             WHERE StorerKey = @cStorerKey  
--              AND DocumentNo = @cOrderKey   
--              AND DocStatus = @cStatus  
--               
--             UPDATE dbo.DocStatusTrack WITH (ROWLOCK)   
--             SET DocStatus    = @cStatus   
--                ,TransDate    = GetDate()  
--                ,UserDefine01   = @cExternOrderKey  
--                ,UserDefine02    = @cContainerKey  
--             WHERE RowRef = @nRowRef  
--               
--             IF @@ERROR <> 0   
--             BEGIN  
--                SET @nErrNo = 108852     
--                SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdDocStatusFail  
--                GOTO RollBackTran  
--             END  
             INSERT INTO dbo.DocStatusTrack ( TableName, DocumentNo, StorerKey, DocStatus, TransDate, UserDefine01, UserDefine02, Finalized )   
           VALUES ('EDLD', @cOrderKey, @cStorerKey, '9', GetDate(), @cExternOrderKey, '', '')  
         
       IF @@ERROR <> 0   
             BEGIN  
                SET @nErrNo = 108853     
                SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsDocStatusFail   
                GOTO RollBackTran  
             END  
           END  
--           ELSE  
--           BEGIN  
--       INSERT INTO dbo.DocStatusTrack ( TableName, DocumentNo, StorerKey, DocStatus, TransDate, UserDefine01, UserDefine02, Finalized )   
--       VALUES ('STSORDERS', @cOrderKey, @cStorerKey, @cStatus, GetDate(), @cExternOrderKey, @cContainerKey, 'Y')  
--         
--       IF @@ERROR <> 0   
--             BEGIN  
--                SET @nErrNo = 108853     
--                SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsDocStatusFail   
--                GOTO RollBackTran  
--             END  
--      END  
            FETCH NEXT FROM CUR_LOOP INTO @cOrderKey, @cStatus, @cExternOrderKey   
         END  
         CLOSE CUR_LOOP        
         DEALLOCATE CUR_LOOP  
      END     
   END  
  
   GOTO Quit  
     
   RollBackTran:    
         ROLLBACK TRAN rdt_1637ExtUpd02    
   Quit:    
      WHILE @@TRANCOUNT > @nTranCount    
         COMMIT TRAN    

GO
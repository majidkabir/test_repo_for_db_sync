SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/******************************************************************************/  
/* Store procedure: rdt_1664ExtUpdSP03                                        */    
/* Copyright      : LF                                                        */    
/*                                                                            */    
/* Purpose: LEVIS Scan To MBOL Logic                                          */    
/*                                                                            */    
/* Modifications log:                                                         */    
/* Date        Rev  Author   Purposes                                         */    
/* 2015-09-23  1.0  ChewKP   SOS#353271 Created                               */  
/* 2018-03-16  1.1  Ung      WMS-3774 Change CartonDescription to Barcode     */
/******************************************************************************/    
    
CREATE PROC [RDT].[rdt_1664ExtUpdSP03] (    
   @nMobile     INT,    
   @nFunc       INT,    
   @cLangCode   NVARCHAR( 3),    
   @cUserName   NVARCHAR( 15),    
   @cFacility   NVARCHAR( 5),    
   @cStorerKey  NVARCHAR( 15),    
   @cTrackNo    NVARCHAR( 20),    
   @cMBOLKey    NVARCHAR( 20),  
   @nStep       INT,  
   @cOrderKey   NVARCHAR( 10),  
   @cLabelNo    NVARCHAR( 20), 
   @nErrNo      INT           OUTPUT,    
   @cErrMsg     NVARCHAR( 20) OUTPUT  -- screen limitation, 20 char max    
) AS    
BEGIN    
   SET NOCOUNT ON    
   SET ANSI_NULLS OFF    
   SET QUOTED_IDENTIFIER OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF    
  
   DECLARE @nTranCount         INT  
          ,@nTotalSKUWeight    FLOAT
          ,@cPickSlipNo        NVARCHAR(10)
          ,@nCartonWeight      FLOAT
          ,@nTotalCartonWeight FLOAT
          ,@cUseSequence       INT
          ,@nCartonCount       INT
          ,@cCartonType        NVARCHAR(10) 
          ,@nCartonNo          INT
          ,@cCartonGroup       NVARCHAR(10) 
          ,@nCountCartonType   INT 
     
   SET @nErrNo   = 0    
   SET @cErrMsg  = ''   
   SET @nTotalSKUWeight = 0 
   SET @cPickSlipNo  = 0 
   SET @nTotalCartonWeight = 0 
   SET @nCountCartonType = 0 
 
     
   SET @nTranCount = @@TRANCOUNT  
     
   BEGIN TRAN  
   SAVE TRAN rdt_1664ExtUpdSP03  
     
IF @nFunc = 1664 
BEGIN     
   IF @nStep = 5  
   BEGIN  
         SELECT @cPickSlipNo = PickSlipNo 
         FROM dbo.PackHeader WITH (NOLOCK)
         WHERE OrderKey = @cOrderKey 
         
         SELECT @cCartonGroup = CartonGroup 
         FROM dbo.Storer WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey 
         
         SELECT @nTotalSKUWeight = ISNULL(SUM(SKU.STDGROSSWGT * PD.Qty ) , 0 ) 
         FROM dbo.PickDetail PD WITH (NOLOCK) 
         INNER JOIN dbo.SKU SKU WITH (NOLOCK) ON SKU.SKU = PD.SKU AND SKU.StorerKey = PD.StorerKey
         WHERE PD.OrderKey = @cOrderKey
         AND PD.StorerKey = @cStorerKey
         
--         DECLARE CURSORPACKINFO CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
--         SELECT PI.CartonType , Count (DISTINCT PI.CartonNo) 
--         FROM   PackDetail PD WITH (NOLOCK)    
--         INNER JOIN PackInfo PI WITH (NOLOCK) ON PI.PickSlipNo = PD.PickSlipNo AND PI.CartonNo = PD.CartonNo 
--         WHERE PD.PickSlipNo = @cPickSlipNo
--         GROUP BY PI.CartonType
--         ORDER BY PI.CartonType
--           
--         OPEN CURSORPACKINFO    
--         FETCH NEXT FROM CURSORPACKINFO INTO  @cCartonType, @nCountCartonType
--         WHILE (@@FETCH_STATUS <> -1)    
--         BEGIN    
            
            SET @cUseSequence  = '' 
            SET @nCartonWeight = 0 
            --SET @nTotalCartonWeight = 0 
            
            
            SELECT @cUseSequence = UseSequence
                  ,@nCartonWeight = CartonWeight
            FROM dbo.Cartonization WITH (NOLOCK)
            WHERE (CartonType = @cLabelNo OR Barcode = @cLabelNo)
            AND CartonizationGroup = @cCartonGroup
   
            
            IF @cUseSequence = '1'
            BEGIN
               
               SELECT  @nCartonCount  = CtnCnt1 
               FROM dbo.MBOLDetail WITH (NOLOCK) 
               WHERE MBOLKey = @cMBOLKey
               AND OrderKey = @cOrderKey
      
            END
            ELSE IF @cUseSequence = '2'
            BEGIN
               SELECT  @nCartonCount  = CtnCnt2 
               FROM dbo.MBOLDetail WITH (NOLOCK) 
               WHERE MBOLKey = @cMBOLKey
               AND OrderKey = @cOrderKey
               
            END
            ELSE IF @cUseSequence = '3'
            BEGIN
               SELECT  @nCartonCount  = CtnCnt3 
               FROM dbo.MBOLDetail WITH (NOLOCK) 
               WHERE MBOLKey = @cMBOLKey
               AND OrderKey = @cOrderKey
               
               INSERT INTO TRACEINFO (TracEName , TimeIN, col1 , Col2 , Col3 , Col4, col5 ) 
               VALUES ( '1664' , Getdate() , '111', @nCartonCount , @cUseSequence ,@nCartonWeight , @nTotalSKUWeight  ) 

            END
            ELSE IF @cUseSequence = '4'
            BEGIN
               SELECT  @nCartonCount  = CtnCnt4 
               FROM dbo.MBOLDetail WITH (NOLOCK) 
               WHERE MBOLKey = @cMBOLKey
               AND OrderKey = @cOrderKey
     
            END
            ELSE IF @cUseSequence = '5'
            BEGIN
               SELECT  @nCartonCount  = CtnCnt5 
               FROM dbo.MBOLDetail WITH (NOLOCK) 
               WHERE MBOLKey = @cMBOLKey
               AND OrderKey = @cOrderKey
     
            END
            ELSE IF @cUseSequence = '6'
            BEGIN
               SELECT  @nCartonCount  = UserDefine01 
               FROM dbo.MBOLDetail WITH (NOLOCK) 
               WHERE MBOLKey = @cMBOLKey
               AND OrderKey = @cOrderKey
   
            END
            ELSE IF @cUseSequence = '7'
            BEGIN
               SELECT  @nCartonCount  = UserDefine02 
               FROM dbo.MBOLDetail WITH (NOLOCK) 
               WHERE MBOLKey = @cMBOLKey
               AND OrderKey = @cOrderKey
       
            END
            ELSE IF @cUseSequence = '8'
            BEGIN
               SELECT  @nCartonCount  = UserDefine03 
               FROM dbo.MBOLDetail WITH (NOLOCK) 
               WHERE MBOLKey = @cMBOLKey
               AND OrderKey = @cOrderKey
      
            END
            ELSE IF @cUseSequence = '9'
            BEGIN
               SELECT  @nCartonCount  = UserDefine04 
               FROM dbo.MBOLDetail WITH (NOLOCK) 
               WHERE MBOLKey = @cMBOLKey
               AND OrderKey = @cOrderKey
        
      
            END
            ELSE IF @cUseSequence = '10'
            BEGIN
               SELECT  @nCartonCount  = UserDefine05 
               FROM dbo.MBOLDetail WITH (NOLOCK) 
               WHERE MBOLKey = @cMBOLKey
               AND OrderKey = @cOrderKey
    
      
            END
            ELSE IF @cUseSequence = '11'
            BEGIN
               SELECT  @nCartonCount  = UserDefine09 
               FROM dbo.MBOLDetail WITH (NOLOCK) 
               WHERE MBOLKey = @cMBOLKey
               AND OrderKey = @cOrderKey
               
            END
            ELSE IF @cUseSequence = '12'
            BEGIN
               SELECT  @nCartonCount  = UserDefine10 
               FROM dbo.MBOLDetail WITH (NOLOCK) 
               WHERE MBOLKey = @cMBOLKey
               AND OrderKey = @cOrderKey
            END
         
            SET @nTotalCartonWeight = (ISNULL(@nCartonCount,0) + 1) * ISNULL(@nCartonWeight,0) -- @nTotalCartonWeight + (ISNULL(@nCartonCount,0) * ISNULL(@nCartonWeight,0))
      

            IF @cUseSequence = '1'
            BEGIN
               
               UPDATE dbo.MBOLDetail
                  SET --CtnCnt1 = CtnCnt1 + @nCountCartonType
                     Weight = (@nTotalSKUWeight + @nTotalCartonWeight)
               WHERE MBOLKey = @cMBOLKey
               AND OrderKey = @cOrderKey
      
            END
            ELSE IF @cUseSequence = '2'
            BEGIN
               UPDATE dbo.MBOLDetail
                  SET --CtnCnt2 = CtnCnt2 + @nCountCartonType
                      Weight = (@nTotalSKUWeight + @nTotalCartonWeight)
               WHERE MBOLKey = @cMBOLKey
               AND OrderKey = @cOrderKey
      
            END
            ELSE IF @cUseSequence = '3'
            BEGIN
               UPDATE dbo.MBOLDetail
                  SET --CtnCnt3 = CtnCnt3 + @nCountCartonType
                      Weight = (@nTotalSKUWeight + @nTotalCartonWeight)
               WHERE MBOLKey = @cMBOLKey
               AND OrderKey = @cOrderKey
            END
            ELSE IF @cUseSequence = '4'
            BEGIN
               UPDATE dbo.MBOLDetail
                  SET --CtnCnt4 = CtnCnt4 + @nCountCartonType
                      Weight = (@nTotalSKUWeight + @nTotalCartonWeight)
               WHERE MBOLKey = @cMBOLKey
               AND OrderKey = @cOrderKey
            END
            ELSE IF @cUseSequence = '5'
            BEGIN
               UPDATE dbo.MBOLDetail
                  SET --CtnCnt5 = CtnCnt5 + @nCountCartonType
                      Weight = (@nTotalSKUWeight + @nTotalCartonWeight)
               WHERE MBOLKey = @cMBOLKey
               AND OrderKey = @cOrderKey
            END
            ELSE IF @cUseSequence = '6'
            BEGIN
               
               UPDATE dbo.MBOLDetail
                  SET --UserDefine01 = UserDefine01 + @nCountCartonType
                      Weight = (@nTotalSKUWeight + @nTotalCartonWeight)
               WHERE MBOLKey = @cMBOLKey
               AND OrderKey = @cOrderKey
            END
            ELSE IF @cUseSequence = '7'
            BEGIN
               UPDATE dbo.MBOLDetail
                  SET --UserDefine02 = UserDefine02 + @nCountCartonType
                      Weight = (@nTotalSKUWeight + @nTotalCartonWeight)
               WHERE MBOLKey = @cMBOLKey
               AND OrderKey = @cOrderKey
      
            END
            ELSE IF @cUseSequence = '8'
            BEGIN
               UPDATE dbo.MBOLDetail
                  SET --UserDefine03 = UserDefine03 + @nCountCartonType
                      Weight = (@nTotalSKUWeight + @nTotalCartonWeight)
               WHERE MBOLKey = @cMBOLKey
               AND OrderKey = @cOrderKey
      
            END
            ELSE IF @cUseSequence = '9'
            BEGIN
               UPDATE dbo.MBOLDetail
                  SET --UserDefine04 = UserDefine04 + @nCountCartonType
                      Weight = (@nTotalSKUWeight + @nTotalCartonWeight)
               WHERE MBOLKey = @cMBOLKey
               AND OrderKey = @cOrderKey
      
            END
            ELSE IF @cUseSequence = '10'
            BEGIN
               UPDATE dbo.MBOLDetail
                  SET --UserDefine05 = UserDefine05 + @nCountCartonType
                      Weight = (@nTotalSKUWeight + @nTotalCartonWeight)
               WHERE MBOLKey = @cMBOLKey
               AND OrderKey = @cOrderKey
      
            END
            ELSE IF @cUseSequence = '11'
            BEGIN
               UPDATE dbo.MBOLDetail
                  SET --UserDefine09 = UserDefine09 + @nCountCartonType
                      Weight = (@nTotalSKUWeight + @nTotalCartonWeight)
               WHERE MBOLKey = @cMBOLKey
               AND OrderKey = @cOrderKey
      
            END
            ELSE IF @cUseSequence = '12'
            BEGIN
               UPDATE dbo.MBOLDetail
                  SET --UserDefine10 = UserDefine10 + @nCountCartonType
                      Weight = (@nTotalSKUWeight + @nTotalCartonWeight)
               WHERE MBOLKey = @cMBOLKey
               AND OrderKey = @cOrderKey
      
            END
      
            IF @@ERROR <> 0
            BEGIN
         
                  SET @nErrNo = 94251  
                  SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'UpdMBOLDetFail'  
                  --SET @cErrMsg = 'GenLblSPNotFound'  
                  GOTO RollBackTran  
       
            END
         
--            FETCH NEXT FROM CURSORPACKINFO INTO  @cCartonType, @nCountCartonType
--         END
--         CLOSE CURSORPACKINFO    
--         DEALLOCATE CURSORPACKINFO         
         
      

 
         
--         UPDATE dbo.MBOLDetail
--         SET Weight = @nTotalWeight + @nTotalCartonWeight
--         WHERE MBOLKey = @cMBOLKey
--         AND OrderKey = @cOrderKey 
         
         
         
         
         
   END  
END     
        
              

  
   GOTO QUIT   
     
RollBackTran:  
   ROLLBACK TRAN rdt_1664ExtUpdSP03 -- Only rollback change made here  
  
Quit:  
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started  
      COMMIT TRAN rdt_1664ExtUpdSP03  
    
  
END    

GO
SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Store procedure: rdt_850ExtValidSP01                                 */  
/* Purpose: Validate Pallet DropID                                      */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date       Rev  Author     Purposes                                  */  
/* 2014-02-10 1.0  ChewKP     SOS#293509 Created                        */  
/* 2018-11-19 1.1  Ung        WMS-6932 Add ID param                     */
/* 2019-03-29 1.2  James      WMS-8002 Add TaskDetailKey param (james01)*/
/* 2019-04-22 1.3  James      WMS-7983 Add VariableTable (james02)      */
/************************************************************************/  
  
CREATE PROC [RDT].[rdt_850ExtValidSP01] (  
   @nMobile     INT,  
   @nFunc       INT,   
   @cLangCode   NVARCHAR(3),   
   @nStep       INT,   
   @cStorerKey  NVARCHAR(15),   
   @cFacility   NVARCHAR(5),
   @cRefNo      NVARCHAR( 10),
   @cOrderKey   NVARCHAR( 10),
   @cDropID     NVARCHAR( 20),
   @cLoadKey    NVARCHAR( 10),
   @cPickSlipNo NVARCHAR( 10),
   @nErrNo      INT           OUTPUT,   
   @cErrMsg     NVARCHAR( 20) OUTPUT, 
   @cID         NVARCHAR( 18) = '',
   @cTaskDetailKey   NVARCHAR( 10) = '',
   @tExtValidate   VariableTable READONLY
)  
AS  
  
SET NOCOUNT ON  
SET QUOTED_IDENTIFIER OFF  
SET ANSI_NULLS OFF  
  
IF @nFunc = 850  
BEGIN  
   
    DECLARE @cOrderStatus     NVARCHAR(10)
           ,@cLoadPlanStatus  NVARCHAR(10)
           
    
    SET @nErrNo          = 0
    SET @cErrMSG         = ''
    
    SELECT @cOrderKey = ISNULL(OrderKey,'') 
          ,@cLoadKey = ISNULL(ExternOrderKey,'')
    FROM dbo.PickHeader WITH (NOLOCK) 
    WHERE PickHeaderKey = @cPickSlipNo 
    
    IF @cOrderKey <> ''
    BEGIN
      SELECT @cOrderStatus = Status 
      FROM dbo.Orders WITH (NOLOCK)
      WHERE OrderKey = @cOrderKey
      AND StorerKey = @cStorerKey
      
      IF @cOrderStatus NOT IN ( '1','2','3') 
      BEGIN
           SET @nErrNo = 86251
           SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- InvalidPickSlipNo
           GOTO QUIT
      END
      
      IF @cOrderStatus <> '3'
      BEGIN
         IF NOT EXISTS (SELECT 1 FROM dbo.PickingInfo WITH (NOLOCK)
                        WHERE PickSlipNo = @cPickSlipNo ) 
         BEGIN
            INSERT INTO dbo.PickingInfo ( PickSlipNo , ScanInDate, PickerID, ScanOutDate ) 
            VALUES ( @cPickSlipNo, GetDATE(), suser_sname() , '' ) 
            
            IF @@ERROR <> 0 
            BEGIN
               SET @nErrNo = 86253
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- InsPickInfoFail
               GOTO QUIT
            END
         END
         ELSE
         BEGIN
            UPDATE dbo.PickingInfo WITH (ROWLOCK) 
            SET ScanIndate = GetDATE() 
            WHERE PickslipNo = @cPickslipNo
            
            IF @@ERROR <> 0 
            BEGIN
               SET @nErrNo = 86254
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- UpdPickInfoFail
               GOTO QUIT
            END
            
         END
      END
    
      
    END
    ELSE IF @cLoadKey <> ''
    BEGIN
      SELECT @cLoadPlanStatus = Status 
      FROM dbo.LoadPlan WITH (NOLOCK)
      WHERE LoadKey = @cLoadKey
      AND Facility = @cFacility
      
      IF @cLoadPlanStatus NOT IN ( '1','2','3') 
      BEGIN
           SET @nErrNo = 86252
           SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- InvalidPickSlipNo
           GOTO QUIT
      END
      
      IF @cLoadPlanStatus <> '3'
      BEGIN
         IF NOT EXISTS (SELECT 1 FROM dbo.PickingInfo WITH (NOLOCK)
                        WHERE PickSlipNo = @cPickSlipNo ) 
         BEGIN
            INSERT INTO dbo.PickingInfo ( PickSlipNo , ScanInDate, PickerID, ScanOutDate ) 
            VALUES ( @cPickSlipNo, GetDATE(), suser_sname() , '' ) 
            
            IF @@ERROR <> 0 
            BEGIN
               SET @nErrNo = 86255
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- InsPickInfoFail
               GOTO QUIT
            END
         END
         ELSE
         BEGIN
            UPDATE dbo.PickingInfo WITH (ROWLOCK) 
            SET ScanIndate = GetDATE() 
            WHERE PickslipNo = @cPickslipNo
            
            IF @@ERROR <> 0 
            BEGIN
               SET @nErrNo = 86256
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- UpdPickInfoFail
               GOTO QUIT
            END
            
         END
      END
      
    END
    
    
    
END  
  
  
QUIT:  


  
 

GO
SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/      
/* Store procedure: rdt_841GetOrders08                                  */      
/* Copyright      : LF                                                  */      
/*                                                                      */      
/* Purpose:                                                             */      
/*                                                                      */    
/*                                                                      */      
/* Modifications log:                                                   */      
/* Date        Rev  Author   Purposes                                   */      
/* 2021-07-05  1.0  James    WMS-17437. Created                         */      
/* 2022-07-26  1.1  yeekung  WMS-20327 Support two method (yeekung04)   */ 
/************************************************************************/      
    
CREATE   PROC [RDT].[rdt_841GetOrders08] (      
   @nMobile       INT,      
   @nFunc         INT,      
   @cLangCode     NVARCHAR( 3),      
   @nStep         INT,    
   @nInputKey     INT,    
   @cUserName     NVARCHAR( 15),      
   @cFacility     NVARCHAR( 5),      
   @cStorerKey    NVARCHAR( 15),      
   @cToteno       NVARCHAR( 20),      
   @cWaveKey      NVARCHAR( 10),    
   @cLoadKey      NVARCHAR( 10),      
   @cSKU          NVARCHAR( 20),      
   @cPickslipNo   NVARCHAR( 10),      
   @cTrackNo      NVARCHAR( 20),      
   @cDropIDType   NVARCHAR( 10),      
   @cOrderkey     NVARCHAR( 10) OUTPUT,      
   @nErrNo        INT           OUTPUT,      
   @cErrMsg       NVARCHAR( 20) OUTPUT  -- screen limitation, 20 char max      
) AS      
BEGIN      
   SET NOCOUNT ON      
   SET ANSI_NULLS OFF      
   SET QUOTED_IDENTIFIER OFF      
   SET CONCAT_NULL_YIELDS_NULL OFF      
      
   DECLARE @nTranCount        INT = 0    
   DECLARE @nRowCount         INT = 0    
   DECLARE @nRowRef           INT = 0    
   DECLARE @cOrderWithTrackNo    NVARCHAR(1)
   DECLARE @cUseUdf04AsTrackNo   NVARCHAR(1)
   DECLARE @cPickStatus          NVARCHAR(1)
   
   SET @nErrNo   = 0      
   SET @cErrMsg  = ''      
    
   SET @cOrderWithTrackNo = rdt.RDTGetConfig( @nFunc, 'OrderWithTrackNo', @cStorerkey)    
   SET @cUseUdf04AsTrackNo = rdt.RDTGetConfig( @nFunc, 'UseUdf04AsTrackNo', @cStorerKey)
   SET @cPickStatus = rdt.RDTGetConfig( @nFunc, 'PickStatus', @cStorerKey)   
 
   SET @nTranCount = @@TRANCOUNT    
   BEGIN TRAN    
   SAVE TRAN rdt_841GetOrders08    

   IF @nStep = 1      
   BEGIN    
      IF @nInputKey = 1    
      BEGIN    
         DELETE FROM rdt.rdtECOMMLog WHERE Mobile = @nMobile AND [Status] = '0'

         IF @cToteno<>'' --(scan refno)
         BEGIN 
            IF @cOrderWithTrackNo = '1'   
            BEGIN   
               INSERT INTO rdt.rdtECOMMLog(Mobile, ToteNo, Orderkey, Sku, DropIDType, ExpectedQty, ScannedQty, AddWho, AddDate, EditWho, EditDate)  
               SELECT @nMobile, @cToteNo, PK.Orderkey, PK.SKU, @cDropIDType, SUM(PK.Qty), 0, @cUserName, GETDATE(), @cUserName, GETDATE()  
               FROM dbo.PICKDETAIL PK WITH (NOLOCK)  
               JOIN dbo.Orders O WITH (NOLOCK) ON O.Orderkey = PK.Orderkey  
               WHERE PK.DROPID = @cToteNo  
                 AND (PK.Status >= @cPickStatus OR PK.ShipFlag = '0')
                 AND PK.Status <> '4'
                 AND PK.Status < '9'
                 AND PK.CaseID = ''  
                 AND PK.Qty > 0 
                 AND O.SOStatus NOT IN ( 'PENDPACK', 'HOLD', 'PENDCANC' ) 
                 AND (( @cUseUdf04AsTrackNo = '1' AND ISNULL( O.UserDefine04, '') <> '') OR ( ISNULL(O.TrackingNo ,'') <> '')) 
                 AND EXISTS ( SELECT 1 FROM dbo.CODELKUP C WITH (NOLOCK) WHERE LISTNAME = 'ORDERTYPE' AND Storerkey = @cStorerKey AND O.[Type] = C.Code)
               GROUP BY PK.OrderKey, PK.SKU  
            END  
            ELSE  
            BEGIN  
               INSERT INTO rdt.rdtECOMMLog(Mobile, ToteNo, Orderkey, Sku, DropIDType, ExpectedQty, ScannedQty, AddWho, AddDate, EditWho, EditDate)  
               SELECT @nMobile, @cToteNo, PK.Orderkey, PK.SKU, @cDropIDType, SUM(PK.Qty), 0, @cUserName, GETDATE(), @cUserName, GETDATE()  
               FROM dbo.PICKDETAIL PK WITH (NOLOCK)  
               JOIN dbo.Orders O WITH (NOLOCK) ON O.Orderkey = PK.Orderkey  
               WHERE PK.DROPID = @cToteNo  
                 AND (PK.Status >= @cPickStatus OR PK.ShipFlag = '0')
                 AND PK.Status <> '4'
                 AND PK.Status < '9'
                 AND PK.CaseID = ''  
                 AND PK.Qty > 0 
                 AND O.SOStatus NOT IN ( 'PENDPACK', 'HOLD', 'PENDCANC' ) 
                 AND EXISTS ( SELECT 1 FROM dbo.CODELKUP C WITH (NOLOCK) WHERE LISTNAME = 'ORDERTYPE' AND Storerkey = @cStorerKey AND O.[Type] = C.Code)
               GROUP BY PK.OrderKey, PK.SKU  
            END  
         
            SET @nRowCount = @@ROWCOUNT    
             
            SET @nRowRef = SCOPE_IDENTITY()    
             
            IF @@ERROR <> 0     
            BEGIN      
               SET @nErrNo = 170151       
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Ins Ecomm Fail      
               GOTO RollBackTran      
            END     
    
            IF @nRowCount = 0    
            BEGIN    
               SET @nErrNo = 170152      
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NoRecToProcess      
               GOTO RollBackTran      
            END    
         
            SELECT @cOrderKey = Orderkey        
            FROM rdt.rdtECOMMLog WITH (NOLOCK)
            WHERE RowRef = @nRowRef   
          END
      END    
   END   
   
   IF @nStep =2
   BEGIN
               
      SELECT TOP 1 @cOrderKey =   orderkey      
      FROM rdt.rdtECOMMLog WITH (NOLOCK)
      WHERE [Status] = '0'
      AND sku=@cSKU
      AND  ToteNo = @cToteNo  
      and mobile=@nMobile
   END

   GOTO Quit    
    
    
   RollBackTran:    
      ROLLBACK TRAN rdt_841GetOrders08    
    
   Quit:    
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started    
         COMMIT TRAN rdt_841GetOrders08    
    
   Fail:            
END      

GO
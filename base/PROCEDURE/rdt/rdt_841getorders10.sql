SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/      
/* Store procedure: rdt_841GetOrders10                                  */      
/* Copyright      : LF                                                  */      
/*                                                                      */      
/* Purpose:                                                             */      
/*                                                                      */    
/*                                                                      */      
/* Modifications log:                                                   */      
/* Date        Rev  Author   Purposes                                   */      
/* 2022-02-01  1.0  yeekung    WMS-18630. Created                       */      
/************************************************************************/      
    
CREATE PROC [RDT].[rdt_841GetOrders10] (      
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
	SET @cPickStatus = rdt.RDTGetConfig( @nFunc, 'PickStatus', @cStorerKey)   
 
   SET @nTranCount = @@TRANCOUNT    
   BEGIN TRAN    
   SAVE TRAN rdt_841GetOrders10    

   IF @nStep = 1      
   BEGIN    
      IF @nInputKey = 1    
      BEGIN    
         DELETE FROM rdt.rdtECOMMLog WHERE Mobile = @nMobile AND [Status] = '0'

         IF ISNULL(@cWaveKey,'')<>''
         BEGIN
            INSERT INTO rdt.rdtECOMMLog(Mobile, ToteNo, Orderkey, Sku, DropIDType, ExpectedQty, ScannedQty, AddWho, AddDate, EditWho, EditDate)  
            SELECT @nMobile, @cToteNo, PK.Orderkey, PK.SKU, @cDropIDType, SUM(PK.Qty), 0, @cUserName, GETDATE(), @cUserName, GETDATE()  
            FROM dbo.WaveDetail WD WITH (NOLOCK)  
            INNER JOIN dbo.Orders O WITH (NOLOCK) ON O.Orderkey = WD.OrderKey
            JOIN PICKDETAIL PK (NOLOCK) ON O.orderkey=PK.orderkey
            WHERE WD.WaveKey = @cWaveKey  
               AND O.SOStatus NOT IN ( 'PENDPACK', 'HOLD', 'PENDCANC' ) -- (ChewKP05) 
               AND (PK.Status >= @cPickStatus OR PK.ShipFlag = '0')
               AND PK.Status <> '4'
               AND PK.Status < '9'
               AND PK.CaseID = ''  
               AND PK.Qty > 0 
               AND O.SOStatus NOT IN ( 'PENDPACK', 'HOLD', 'PENDCANC' ) 
            GROUP BY PK.OrderKey, PK.SKU 
         END
         ELSE
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
         END
         SET @nRowCount = @@ROWCOUNT    
             
         SET @nRowRef = SCOPE_IDENTITY()    
             
         IF @@ERROR <> 0     
         BEGIN      
            SET @nErrNo = 188601        
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Ins Ecomm Fail      
            GOTO RollBackTran      
         END     
    
         IF @nRowCount = 0    
         BEGIN    
            SET @nErrNo = 188602      
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NoRecToProcess      
            GOTO RollBackTran      
         END    
         
         SELECT @cOrderKey = Orderkey        
         FROM rdt.rdtECOMMLog WITH (NOLOCK)
         WHERE RowRef = @nRowRef    
      END    
   END    

   GOTO Quit    
    
    
   RollBackTran:    
      ROLLBACK TRAN rdt_841GetOrders10    
    
   Quit:    
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started    
         COMMIT TRAN rdt_841GetOrders10    
    
   Fail:            
END      

GO
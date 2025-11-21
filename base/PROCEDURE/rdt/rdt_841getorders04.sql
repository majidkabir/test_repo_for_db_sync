SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/      
/* Store procedure: rdt_841GetOrders04                                  */      
/* Copyright      : LF                                                  */      
/*                                                                      */      
/* Purpose:                                                             */      
/* Modifications log:                                                   */      
/* Date        Rev  Author   Purposes                                   */      
/* 2019-12-13  1.0  YeeKung  WMS-11372. Created                         */   
/* 2020-04-16  1.1  YeeKung  WMS-12943 Add OrderWithTrackNo (yeekung01) */     
/* 2021-01-06  1.2  James    WMS-15901 Add orders.type (james01)        */
/* 2021-04-16  1.3  James    WMS-16024 Standarized use of TrackingNo    */
/*                           (james02)                                  */
/************************************************************************/      
    
CREATE PROC [RDT].[rdt_841GetOrders04] (      
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
   DECLARE @cSOStatus         NVARCHAR( 10) = ''    
   DECLARE @cErrMsg01         NVARCHAR( 20) = ''    
   DECLARE @cLoc              NVARCHAR( 20) = ''    
   DECLARE @cPDKey            NVARCHAR( 30) = ''    
   DECLARE @cOrderWithTrackNo NVARCHAR(1)   
    
   SET @nErrNo   = 0      
   SET @cErrMsg  = ''      
    
   SET @nTranCount = @@TRANCOUNT    
   BEGIN TRAN    
   SAVE TRAN rdt_841GetOrders04    
    
   IF @nStep = 2      
   BEGIN    
      IF @nInputKey = 1    
      BEGIN    
  
         SET @cOrderWithTrackNo = rdt.RDTGetConfig( @nFunc, 'OrderWithTrackNo', @cStorerkey)    
             
         SELECT TOP 1 @cLoc=PK.Loc,@cPDKey=PK.PickDetailKey    
         FROM dbo.PICKDETAIL PK WITH (NOLOCK)        
         JOIN dbo.Orders O WITH (NOLOCK) ON O.Orderkey = PK.Orderkey AND O.LoadKey = ISNULL(RTRIM(@cLoadKey),'')    
         JOIN dbo.Loc L WITH (NOLOCK) ON L.Loc = PK.Loc      
         WHERE PK.SKU = @cSKU    
            AND PK.Status = '0' AND PK.ShipFlag = '0'    
            AND PK.CaseID = ''    
            AND PK.StorerKey = @cStorerKey    
            AND O.Type IN ( 'DTC', 'TMALL', 'NORMAL', 'COD' , 'SS', 'EX', 'TMALLCN', 'NORMAL1', 'VIP', 
                            'TNF-C', 'TNF-D', 'TNF-E', 'TNF-J', 'TNF-O')    -- (james01)
            AND O.SOStatus NOT IN ( 'PENDPACK', 'HOLD','PENDCANC')    
            AND PK.Qty > 0    
            AND NOT EXISTS ( SELECT 1 FROM rdt.rdtECOMMLog RE WITH (NOLOCK)         
                              WHERE RE.OrderKey = O.OrderKey    
                              AND Status < '9'  )    
         ORDER BY L.locationType    
    
         IF NOT EXISTS (SELECT 1 FROM LOC (NOLOCK) WHERE Locationtype in ('DYNPICKP','DYNPPICK') AND LOC=@cLoc)    
         BEGIN    
            SET @nErrNo = 147101       
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Loctype      
            GOTO RollBackTran      
         END   
           
         IF @cOrderWithTrackNo = '1'       
         BEGIN       
            INSERT INTO rdt.rdtECOMMLog(Mobile, ToteNo, Orderkey, Sku, DropIDType, ExpectedQty, ScannedQty, AddWho, AddDate, EditWho, EditDate)      
            SELECT TOP 1 @nMobile, @cToteNo, PK.Orderkey, PK.SKU, @cDropIDType, SUM(PK.Qty), 0, @cUserName, GETDATE(), @cUserName, GETDATE()     
            FROM dbo.PICKDETAIL PK WITH (NOLOCK)        
            JOIN dbo.Orders O WITH (NOLOCK) ON O.Orderkey = PK.Orderkey AND O.LoadKey = ISNULL(RTRIM(@cLoadKey),'')      
            WHERE PK.SKU = @cSKU    
              AND PK.Pickdetailkey=@cPDKey        
              --AND ISNULL(O.UserDefine04 ,'') <> ''    
              AND ISNULL(O.TrackingNo ,'') <> ''   -- (james02)
            GROUP BY PK.OrderKey, PK.SKU      
         END   
         ELSE  
         BEGIN    
    
            INSERT INTO rdt.rdtECOMMLog(Mobile, ToteNo, Orderkey, Sku, DropIDType, ExpectedQty, ScannedQty, AddWho, AddDate, EditWho, EditDate)      
            SELECT TOP 1 @nMobile, @cToteNo, PK.Orderkey, PK.SKU, @cDropIDType, SUM(PK.Qty), 0, @cUserName, GETDATE(), @cUserName, GETDATE()        
            FROM dbo.PICKDETAIL PK WITH (NOLOCK)        
            JOIN dbo.Orders O WITH (NOLOCK) ON O.Orderkey = PK.Orderkey AND O.LoadKey = ISNULL(RTRIM(@cLoadKey),'')      
            WHERE PK.SKU = @cSKU    
              AND PK.Pickdetailkey=@cPDKey    
            GROUP BY PK.OrderKey, PK.SKU    
         END  
         SET @nRowCount = @@ROWCOUNT    
             
         SET @nRowRef = SCOPE_IDENTITY()    
             
         IF @@ERROR <> 0     
         BEGIN      
            SET @nErrNo = 147102      
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Ins Ecomm Fail      
            GOTO RollBackTran      
         END     
    
         IF @nRowCount = 0    
         BEGIN    
            SET @nErrNo = 147103      
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NoRecToProcess      
            GOTO RollBackTran      
         END    
             
         SELECT @cOrderkey = re.OrderKey    
         FROM RDT.rdtECOMMLog AS re WITH (NOLOCK)    
         WHERE re.RowRef = @nRowRef    
             
      END    
   END    
    
   GOTO Quit    
    
   RollBackTran:    
      ROLLBACK TRAN rdt_841GetOrders04    
    
   Quit:    
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started    
         COMMIT TRAN rdt_841GetOrders04    
    
   Fail:            
END 

GO
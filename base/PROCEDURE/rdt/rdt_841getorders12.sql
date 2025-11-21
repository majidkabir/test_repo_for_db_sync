SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/      
/* Store procedure: rdt_841GetOrders12                                  */      
/* Copyright      : LF                                                  */      
/*                                                                      */      
/* Purpose:                                                             */      
/*                                                                      */    
/*                                                                      */      
/* Modifications log:                                                   */      
/* Date        Rev  Author   Purposes                                   */      
/* 2023-04-10  1.0  yeekung   WMS-22185. Created                        */      
/************************************************************************/      
    
CREATE   PROC [RDT].[rdt_841GetOrders12] (      
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
   DECLARE @curColumn         CURSOR  
   DECLARE @cOrderType        NVARCHAR(20)

   DECLARE @cSQL        NVARCHAR( MAX)  
   DECLARE @cSQLParam   NVARCHAR( MAX)  
   
   SET @nErrNo   = 0      
   SET @cErrMsg  = ''      
    
   SET @cOrderWithTrackNo = rdt.RDTGetConfig( @nFunc, 'OrderWithTrackNo', @cStorerkey)      
 
   SET @nTranCount = @@TRANCOUNT    
   BEGIN TRAN    
   SAVE TRAN rdt_841GetOrders12    

   IF @nStep = 1      
   BEGIN    
      IF @nInputKey = 1    
      BEGIN 

         SET @cSQL =   
         ' INSERT INTO rdt.rdtECOMMLog(Mobile, ToteNo, Orderkey, Sku, DropIDType, ExpectedQty, ScannedQty, AddWho, AddDate, EditWho, EditDate)    
            SELECT @nMobile, @cToteNo, PK.Orderkey, PK.SKU, @cDropIDType, SUM(PK.Qty), 0, @cUserName, GETDATE(), @cUserName, GETDATE()    
            FROM dbo.PICKDETAIL PK WITH (NOLOCK)    
            JOIN dbo.Orders O WITH (NOLOCK) ON O.Orderkey = PK.Orderkey    
            WHERE PK.DROPID = @cToteNo' +  
         ' AND (PK.Status IN (''3'', ''5'') OR PK.ShipFlag = ''P'')  ' +
         ' AND PK.CaseID = ''''' +
         ' AND PK.Qty > 0 ' +
         ' AND O.SOStatus NOT IN ( ''PENDPACK'', ''HOLD'',''PENDCANC'' ) '

         IF @cOrderWithTrackNo = '1'     
         BEGIN     
           SET @cSQL = @cSQL +' AND (( @cUseUdf04AsTrackNo = ''1'' AND ISNULL( O.UserDefine04, '''') <> '''') OR ( ISNULL(O.TrackingNo ,'''') <> ''''))  ' 

         END    

         SET @cSQL = @cSQL +' AND O.Type IN (''DTC'', ''TMALL'', ''NORMAL'', ''COD'', ''SS'',   
                             ''EX'', ''TMALLCN'', ''NORMAL1'', ''VIP'', ''B2C'',''0'''

         SET @curColumn = CURSOR FOR  
         SELECT Code   
         FROM CodeLKUP WITH (NOLOCK)   
         WHERE ListName = 'OTypes'   
            AND StorerKey = @cStorerKey   
            AND Code2 = @nFunc  
     
         OPEN @curColumn  
         FETCH NEXT FROM @curColumn INTO @cOrderType
         WHILE @@FETCH_STATUS <> -1  
         BEGIN
            SET @cSQL = @cSQL + ',' + ''''+@cOrderType + ''''

            FETCH NEXT FROM @curColumn INTO @cOrderType
         END


         SET @cSQL = @cSQL + ')'  

         SET @cSQL = @cSQL + ' GROUP BY PK.OrderKey, PK.SKU '


         SET @cSQLParam =  
            ' @nMobile              INT, ' +   
            ' @cToteNo              NVARCHAR( 20),  ' +   
            ' @cUserName            NVARCHAR( 15), '  +   
            ' @cStorerKey           NVARCHAR(15), '   +   
            ' @cUseUdf04AsTrackNo   NVARCHAR(1),'     +
            ' @cDropIDType          NVARCHAR( 10)'

         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,   
            @nMobile              ,
            @cToteNo              ,
            @cUserName            ,
            @cStorerKey           ,
            @cUseUdf04AsTrackNo   ,
            @cDropIDType 


         IF @@ROWCOUNT = 0 -- No data inserted    
         BEGIN    
            --ROLLBACK TRAN    
            SET @nErrNo = 199151    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'NoRecToProcess'    
            GOTO QUIT    
         END 
      END
   END    

   GOTO Quit    
    
    
   RollBackTran:    
      ROLLBACK TRAN rdt_841GetOrders12    
    
   Quit:    
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started    
         COMMIT TRAN rdt_841GetOrders12    
    
   Fail:            
END      

GO
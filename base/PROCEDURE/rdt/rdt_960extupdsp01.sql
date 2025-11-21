SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store procedure: rdt_960ExtUpdSP01                                   */  
/* Copyright      : IDS                                                 */  
/*                                                                      */  
/* Purpose: ANF SKU Import                                              */  
/*                                                                      */  
/* Modifications log:                                                   */  
/* Date        Rev  Author   Purposes                                   */  
/* 2014-11-14  1.0  ChewKP   Created                                    */  
/************************************************************************/  
  
CREATE PROC [RDT].[rdt_960ExtUpdSP01] (  
   @nMobile     INT,  
   @nFunc       INT,  
   @cLangCode   NVARCHAR( 3),  
   @cUserName   NVARCHAR( 15),  
   @cFacility   NVARCHAR( 5),  
   @cStorerKey  NVARCHAR( 15),  
   @nStep       INT,
   @cTBLSKUDB   NVARCHAR( 20),  
   @cRetailSKU  NVARCHAR( 20), 
   @nErrNo      INT          OUTPUT,  
   @cErrMsg     NVARCHAR( 20) OUTPUT  -- screen limitation, 20 char max  
) AS  
BEGIN  
   SET NOCOUNT ON  
   SET ANSI_NULLS OFF  
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
   
   DECLARE  @nCountTask INT
           ,@nTranCount INT
           ,@c_SQLStatement NVARCHAR( 4000)  
           ,@nRetailSKU_CNT INT  
   
   
   SET @nErrNo   = 0  
   SET @cErrMsg  = '' 
  
   
   SET @nTranCount = @@TRANCOUNT
    
   BEGIN TRAN
   SAVE TRAN ANFSKUImport
   
   
   IF @nFunc = 960
   BEGIN   
      IF @nStep = 1 
      BEGIN 
            
            SELECT @c_SQLStatement = N'SELECT @nRetailSKU_CNT = COUNT(SKU) FROM '   
            SELECT @c_SQLStatement = RTRIM(@c_SQLStatement) + ' ' + RTRIM(@cTBLSKUDB) + '.dbo.SKUANF WITH (NOLOCK) '  
            + ' WHERE RetailSKU = N''' + RTRIM(@cRetailSKU) + ''''  
            EXEC sp_executesql @c_SQLStatement, N'@nRetailSKU_CNT INT OUTPUT', @nRetailSKU_CNT OUTPUT     
         
            --not exists in TBLSKU  
            IF @nRetailSKU_CNT = 0  
            BEGIN  
                SET @nErrNo = 92001  
                SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SKU Not Found  
                GOTO RollBackTran
            END  
        
            --if multi exists in TBLSKU  
            IF @nRetailSKU_CNT > 1  
            BEGIN  
                SET @nErrNo = 92002  
                SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --MultiSKUFound  
                GOTO RollBackTran
            END  
            
            IF EXISTS ( SELECT 1 FROM dbo.SKU WITH (NOLOCK) 
                        WHERE StorerKey = @cStorerKey
                        AND RetailSKU = @cRetailSKU ) 
            BEGIN
                SET @nErrNo = 92003  
                SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SKUExists  
                GOTO RollBackTran
            END
            
            SELECT @c_SQLStatement = N'INSERT INTO dbo.SKU '  
                     + '(StorerKey, Sku, DESCR, SUSR1, SUSR2, SUSR3, '  
                     + 'SUSR4, SUSR5, MANUFACTURERSKU, RETAILSKU, ALTSKU, PACKKey, '  
                     + 'STDGROSSWGT, STDNETWGT, STDCUBE, TARE, CLASS, ACTIVE, '  
                     + 'SKUGROUP, Tariffkey, BUSR1, BUSR2, BUSR3, BUSR4, '  
                     + 'BUSR5, LOTTABLE01LABEL, LOTTABLE02LABEL, LOTTABLE03LABEL, LOTTABLE04LABEL, LOTTABLE05LABEL, '  
                     + 'NOTES1, NOTES2, PickCode, StrategyKey, CartonGroup, PutCode, '  
                     + 'PutawayLoc, PutawayZone, InnerPack, Cube, GrossWgt, NetWgt, '  
                     + 'ABC, CycleCountFrequency, LastCycleCount, ReorderPoint, ReorderQty, StdOrderCost, '  
                     + 'CarryCost, Price, Cost, ReceiptHoldCode, ReceiptInspectionLoc, OnReceiptCopyPackkey, '  
                     + 'TrafficCop, ArchiveCop, IOFlag, TareWeight, LotxIdDetailOtherlabel1, LotxIdDetailOtherlabel2, '  
                     + 'LotxIdDetailOtherlabel3, AvgCaseWeight, TolerancePct, SkuStatus, Length, Width, '  
                     + 'Height, weight, itemclass, ShelfLife, Facility, BUSR6, '  
                     + 'BUSR7, BUSR8, BUSR9, BUSR10, ReturnLoc, ReceiptLoc, XDockReceiptLoc, PrePackIndicator, '  
                     + 'PackQtyIndicator, StackFactor, IVAS, OVAS, Style, Color, Size, Measurement ) '  
                     + 'SELECT N''' + RTRIM(@cStorerKey) + ''' AS STORERKEY, '    
                     + 'Sku, DESCR, SUSR1, SUSR2, SUSR3, '   
                     + 'SUSR4, SUSR5, MANUFACTURERSKU, RETAILSKU, ALTSKU, PACKKey, '  
                     + 'STDGROSSWGT, STDNETWGT, STDCUBE, TARE, CLASS, ACTIVE, '  
                     + 'SKUGROUP, Tariffkey, BUSR1, BUSR2, BUSR3, BUSR4, '  
                     + 'BUSR5, LOTTABLE01LABEL, LOTTABLE02LABEL, LOTTABLE03LABEL, LOTTABLE04LABEL, LOTTABLE05LABEL, '  
                     + 'NOTES1, NOTES2, PickCode, StrategyKey, CartonGroup, PutCode, '  
                     + 'PutawayLoc, PutawayZone, InnerPack, Cube, GrossWgt, NetWgt, '  
                     + 'ABC, CycleCountFrequency, LastCycleCount, ReorderPoint, ReorderQty, StdOrderCost, '  
                     + 'CarryCost, Price, Cost, ReceiptHoldCode, ReceiptInspectionLoc, OnReceiptCopyPackkey, '  
                     + 'TrafficCop, ArchiveCop, IOFlag, TareWeight, LotxIdDetailOtherlabel1, LotxIdDetailOtherlabel2, '  
                     + 'LotxIdDetailOtherlabel3, AvgCaseWeight, TolerancePct, SkuStatus, Length, Width, '  
                     + 'Height, weight, itemclass, ShelfLife, Facility, BUSR6, '  
                     + 'BUSR7, BUSR8, BUSR9, BUSR10, ReturnLoc, ReceiptLoc, XDockReceiptLoc, PrePackIndicator, '   
                     + 'PackQtyIndicator, StackFactor, IVAS, OVAS, Style, Color, Size, Measurement '  
                     + 'FROM '+ RTRIM(@cTBLSKUDB) + '.dbo.SKUANF WITH (NOLOCK) '  
                     + 'WHERE RETAILSKU = RTRIM(@cRetailSKU) '  
        
            EXEC sp_executeSql @c_SQLStatement,  
            N'@cRetailSKU NVARCHAR(60)', @cRetailSKU  
            
            IF @@ERROR <> 0   
            BEGIN  
              
               SET @nErrNo = 92004  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsertSKUFail  
               GOTO RollBackTran
            END          
         
      END
      
   END

   GOTO QUIT
    

   RollBackTran:
   ROLLBACK TRAN ANFSKUImport
    
   Quit:
   WHILE @@TRANCOUNT>@nTranCount -- Commit until the level we started
          COMMIT TRAN ANFSKUImport
   
  
Fail:  
END  

GO
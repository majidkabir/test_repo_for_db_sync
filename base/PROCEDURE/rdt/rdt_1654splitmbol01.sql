SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/      
/* Store procedure: rdt_1654SplitMbol01                                 */      
/* Copyright      : IDS                                                 */      
/*                                                                      */      
/* Called from: rdt_TrackNo_SortToPallet_SplitMbol                      */      
/*                                                                      */      
/* Purpose: Split MBOL record                                           */      
/*                                                                      */      
/* Modifications log:                                                   */      
/* Date        Rev  Author   Purposes                                   */      
/* 2022-10-25  1.0  LZG      WMS-20667. Created                         */    
/* 2023-03-02  1.1  James    WMS-21679 Add new externmbolkey naming rule*/  
/*                           when split lane (james01)                  */  
/* 2023-10-10  1.2  James    WMS-23712 New pallet count formula(james02)*/
/************************************************************************/      
CREATE   PROC [RDT].[rdt_1654SplitMbol01] (      
   @nMobile        INT,  
   @nFunc          INT,  
   @cLangCode      NVARCHAR( 3),  
   @nStep          INT,  
   @nInputKey      INT,  
   @cFacility      NVARCHAR( 5),  
   @cStorerKey     NVARCHAR( 15),  
   @cLane          NVARCHAR( 20) OUTPUT,  
   @tSplitMBOLVar  VariableTable READONLY,  
   @nErrNo         INT           OUTPUT,  
   @cErrMsg        NVARCHAR( 20) OUTPUT  
)  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE @tClosedPallet TABLE (  
       PalletKey NVARCHAR(30) NOT NULL  
   )  
     
   DECLARE @tFullScanOrders TABLE (  
       OrderKey NVARCHAR(10) NOT NULL  
   )  
     
   DECLARE   
       @cNewLane           NVARCHAR(30) = '',  
       @cOrderKey          NVARCHAR(10) = '',  
       @cMBOLKey           NVARCHAR(10) = '',  
       @cSplitMBOLKey      NVARCHAR(10) = '',  
       @cPalletKey         NVARCHAR(30) = '',  
       @cNewPalletKey      NVARCHAR(30) = '',  
       @nQty_Picked        INT,  
       @nQty_Packed        INT,  
       @nCount             INT = 0,  
       @nFullScanCnt       INT = 0,  
       @nMBOLCnt           INT = 0,  
       @nTranCount         INT,  
       @nPltRowRef         INT,
       @cPLTCount          INT = 0  
     
   DECLARE @cExecStatements   NVARCHAR( MAX)  
   DECLARE @cExecArguments    NVARCHAR( MAX)  
     
   SET @nTranCount = @@TRANCOUNT    
   BEGIN TRAN  -- Begin our own transaction    
   SAVE TRAN SplitLaneTran -- For rollback or commit only our own transaction    
     
   SET @cLane = TRIM(@cLane)  
     
   UPDATE TOP (1) M SET UserDefine05 = M.MBOLKey, ExternMBOLKey = TRIM(ExternMBOLKey), TrafficCop = NULL, ArchiveCop = NULL  
   FROM dbo.MBOL M WITH (NOLOCK)  
   JOIN dbo.Orders O WITH (NOLOCK) ON O.MBOLKey = M.MBOLKey  
   WHERE O.StorerKey = @cStorerKey  
   AND TRIM(M.ExternMBOLKey) = @cLane  
     
   IF @@ERROR <> 0    
   BEGIN      
      GOTO RollBackTran_SplitLane    
   END    
                     
   -- Get fully scanned orders  
   INSERT INTO @tFullScanOrders (OrderKey)  
   SELECT DISTINCT MD.OrderKey FROM dbo.MBOL M WITH (NOLOCK)    
   JOIN dbo.MBOLDetail MD WITH (NOLOCK) ON ( MD.MBOLKey = M.MBOLKey)    
   OUTER APPLY (    
       SELECT LabelNo, CaseID, PD.StorerKey FROM PackDetail PD (NOLOCK)    
       JOIN dbo.PackHeader PH WITH (NOLOCK) ON PH.PickSlipNo = PD.PickSlipNo     
       LEFT JOIN dbo.PalletDetail PLD WITH (NOLOCK) ON     
           ( PLD.CaseID = PD.LabelNo AND PLD.StorerKey = PD.StorerKey AND     
           PLD.UserDefine01 = PH.OrderKey AND PLD.UserDefine03 = M.ExternMBOLKey)    
       WHERE PH.OrderKey = MD.OrderKey    
   ) PLD    
   WHERE M.ExternMBOLKey = @cLane  
   AND StorerKey = @cStorerKey  
   GROUP BY MD.OrderKey   
   HAVING COUNT(DISTINCT LabelNo) = COUNT(DISTINCT CaseID)  
     
     
   DECLARE CUR CURSOR FAST_FORWARD READ_ONLY FOR   
     
   SELECT DISTINCT MD.OrderKey, M.MBOLKey, PD.PalletKey FROM dbo.PalletDetail PD WITH (NOLOCK)  
   JOIN dbo.MBOL M WITH (NOLOCK) ON M.ExternMBOLKey = PD.UserDefine03  
   JOIN dbo.MBOLDetail MD WITH (NOLOCK) ON MD.OrderKey = PD.UserDefine01  
   WHERE PD.StorerKey = @cStorerKey  
   AND M.ExternMBOLKey = @cLane  
   AND M.Status < '9'  
     
   OPEN CUR  
   FETCH NEXT FROM CUR INTO @cOrderKey, @cMBOLKey, @cPalletKey  
   WHILE @@FETCH_STATUS <> -1  
   BEGIN  
       SET @cNewPalletKey = ''  
       SET @nQty_Packed = 0  
       SET @nQty_Picked = 0  
     
       -- Skip palletized customer   
       IF EXISTS ( SELECT 1     
               FROM dbo.PalletDetail PD WITH (NOLOCK)    
               JOIN dbo.Orders O WITH (NOLOCK) ON ( PD.UserDefine01 = O.OrderKey AND PD.StorerKey = O.StorerKey)     
               LEFT JOIN dbo.Codelkup CL WITH (NOLOCK) ON O.ConsigneeKey = CL.Code AND O.ShipperKey = CL.Code2 AND O.StorerKey = CL.StorerKey AND CL.ListName = 'NOMIXPLSHP'    
               WHERE O.StorerKey = @cStorerKey    
               AND PD.PalletKey = @cPalletKey    
               AND ISNULL( CL.Code, '') <> '')  
       BEGIN   
           GOTO NEXT_REC  
       END   
     
       SELECT @nQty_Picked = ISNULL( SUM( PD.Qty), 0)     
       FROM dbo.PICKDETAIL PD WITH (NOLOCK)    
       JOIN dbo.ORDERS O WITH (NOLOCK) ON ( PD.OrderKey = O.OrderKey)    
       WHERE O.StorerKey = @cStorerKey    
       AND   O.OrderKey = @cOrderKey  
        
       SELECT @nQty_Packed = ISNULL( SUM( PD.Qty), 0)     
       FROM dbo.PackDetail PD WITH (NOLOCK)    
       JOIN dbo.PackHeader PH WITH (NOLOCK) ON ( PD.PickSlipNo = PH.PickSlipNo)     
       JOIN dbo.Orders O WITH (NOLOCK) ON ( PH.OrderKey = O.OrderKey)    
       WHERE O.StorerKey = @cStorerKey    
       AND   O.OrderKey = @cOrderKey  
     
       -- Split packed and fully scanned order to lane  
       IF @nQty_Picked = @nQty_Packed   
       AND EXISTS (  
           SELECT 1 FROM dbo.Orders WITH (NOLOCK)  
           WHERE OrderKey = @cOrderKey  
           AND Status = '5'  
       )    
       AND EXISTS (  
               SELECT 1 FROM @tFullScanOrders   
               WHERE OrderKey = @cOrderKey  
       )   
       BEGIN   
           -- If full scan check is enabled, then check if order's cartons is fully scanned to pallet  
       --IF (@nCheckCtnFullScan = 1   
       --AND EXISTS (  
       --    SELECT 1 FROM @tFullScanOrders   
       --    WHERE OrderKey = @cOrderKey  
       --))   
       --OR @nCheckCtnFullScan = 0  
       --BEGIN   
         -- Generate new lane   
         IF @cSplitMBOLKey = ''  
         BEGIN   
            SELECT @cExecStatements = N'SELECT @nCount = COUNT(DISTINCT M.MBOLKey) + 1 ' +   
                           ' FROM AUARCHIVE.dbo.V_MBOL M WITH (NOLOCK) '  
                         + ' JOIN AUARCHIVE.dbo.V_Orders O WITH (NOLOCK) ON M.MBOLKey = O.MBOLKey '  
                         + ' WHERE StorerKey = @cStorerKey '  
                         + ' AND M.UserDefine05 = @cMBOLKey '  
                         + ' AND DATEDIFF(MONTH, M.EditDate, GETDATE()) <= 1 '  
  
            SET @cExecArguments =  N'@cStorerKey               NVARCHAR(15)'  
                                + ', @cMBOLKey                 NVARCHAR(10)'  
                                + ', @nCount                   INT   OUTPUT'  
  
            EXEC sp_ExecuteSql   @cExecStatements  
                                 , @cExecArguments  
                                 , @cStorerKey  
                                 , @cMBOLKey  
                                 , @nCount      OUTPUT                                   
                                   
             --SELECT @nCount = COUNT(DISTINCT M.MBOLKey) + 1 FROM AUARCHIVE.dbo.V_MBOL M WITH (NOLOCK)  
             --JOIN AUARCHIVE.dbo.V_Orders O WITH (NOLOCK) ON M.MBOLKey = O.MBOLKey  
             --WHERE StorerKey = @cStorerKey  
             --AND M.UserDefine05 = @cMBOLKey  
             ----AND CHARINDEX('|', M.ExternMBOLKey) > 0  
             --AND DATEDIFF(MONTH, M.EditDate, GETDATE()) <= 1      
           
    --SELECT @nCount = COUNT(DISTINCT M.MBOLKey) + 1 FROM MBOL M WITH (NOLOCK)  
             --JOIN Orders O WITH (NOLOCK) ON M.MBOLKey = O.MBOLKey  
             --WHERE StorerKey = @cStorerKey  
             --AND M.UserDefine05 = @cMBOLKey  
             --AND DATEDIFF(MONTH, M.EditDate, GETDATE()) <= 1  
              
             -- (james01)  
             IF EXISTS ( SELECT 1   
                         FROM dbo.CODELKUP CL WITH (NOLOCK)  
                         JOIN dbo.ORDERS O WITH (NOLOCK) ON ( O.Type = CL.Code2 AND O.StorerKey = CL.StorerKey)  
                         JOIN dbo.MBOL M WITH (NOLOCK) ON ( M.MBOLKey = O.MBOLKey)  
                         WHERE M.ExternMBOLKey = @cLane  
                         AND   CL.ListName = 'LANECONFIG'  
                         AND   CL.StorerKey = @cStorerKey  
                         AND   CL.Code = 'LANEGENTIMESTAMP'  
                         AND   CL.Short = '1')  
                SELECT @cNewLane = ExternMBOLKey + '|' + FORMAT(GETDATE(), 'yyMMddHHmmss')  
                FROM dbo.MBOL WITH (NOLOCK)  
                WHERE MBOLKey = @cMBOLKey  
             ELSE  
                SELECT @cNewLane = ExternMBOLKey + '|' + CAST(@nCount AS NVARCHAR)  
                FROM dbo.MBOL WITH (NOLOCK)  
                WHERE MBOLKey = @cMBOLKey  
           
             EXECUTE nspg_GetKey    
                 'MBOL',    
                 10,    
                 @cSplitMBOLKey OUTPUT,    
                 '',    
                 '',    
                 ''   
                   
             IF @@ERROR <> 0    
             BEGIN      
                GOTO RollBackTran_SplitLane    
             END    
               
             INSERT INTO dbo.MBOL (MBOLKey, ExternMBOLKey, Facility, Status, UserDefine05)  
             SELECT @cSplitMBOLKey, @cNewLane, Facility, Status, @cMBOLKey  
             FROM dbo.MBOL WITH (NOLOCK)  
             WHERE MBOLKey = @cMBOLKey  
               
             IF @@ERROR <> 0    
             BEGIN      
                GOTO RollBackTran_SplitLane    
             END    
         END   
           
         -- If order is not removed from lane yet  
         IF EXISTS (  
             SELECT 1 FROM dbo.MBOLDetail WITH (NOLOCK)  
             WHERE MBOLKey = @cMBOLKey  
             AND OrderKey = @cOrderKey  
         )  
         BEGIN   
             IF OBJECT_ID ('tempdb..#MD') IS NOT NULL   
                 DROP TABLE #MD  
             SELECT * INTO #MD FROM dbo.MBOLDetail WITH (NOLOCK)  
             WHERE MBOLKey = @cMBOLKey  
             AND OrderKey = @cOrderKey  
           
             -- Remove order from old lane  
             DELETE dbo.MBOLDetail   
             WHERE MBOLKey = @cMBOLKey   
             AND OrderKey = @cOrderKey  
               
             IF @@ERROR <> 0    
             BEGIN      
                GOTO RollBackTran_SplitLane    
             END    
         END   
           
         -- Swap lane (START)  
         -- If lane still has order tied to pallet  
         IF EXISTS (  
             SELECT 1 FROM dbo.PalletDetail (NOLOCK)  
             WHERE StorerKey = @cStorerKey  
             AND UserDefine01 = @cOrderKey  
             AND PalletKey = @cPalletKey  
             AND UserDefine03 = @cLane  
         )  
         BEGIN   
            SELECT @cPLTCount = COUNT( DISTINCT PalletKey) + 1 
            FROM dbo.Pallet WITH (NOLOCK) 
            WHERE StorerKey = @cStorerkey 
            AND   [STATUS] = '9' 
            AND   LEFT( PalletKey, LEN( @cPalletKey)) = @cPalletKey

            SELECT @cNewPalletKey = @cPalletKey + '|' + CAST( @cPLTCount AS NVARCHAR) 

             --SET @cNewPalletKey = @cPalletKey + '|' + CAST(@nCount AS NVARCHAR)  
           
             -- Pallet A, Order A, Carton 1      -- Pallet A-1, Order A  
             -- Pallet B, Order A, Carton 2      -- Pallet B-1, Order A  
               
             -- Pallet A, Order C, Carton 1  
             -- Pallet A, Order D, Carton 1  
           
             --SELECT @cStatus = Status   
             --FROM dbo.PalletDetail WITH (NOLOCK)  
             --WHERE PalletKey = @cPalletKey  
             --AND UserDefine01 = @cOrderKey  
           
             IF NOT EXISTS (  
                 SELECT 1 FROM dbo.Pallet WITH (NOLOCK)  
                 WHERE StorerKey = @cStorerKey   
                 AND PalletKey = @cNewPalletKey  
             )  
             BEGIN   
                 INSERT INTO dbo.Pallet   
                 (PalletKey, StorerKey, Status, EffectiveDate, AddDate, AddWho, EditDate, EditWho, TrafficCop, ArchiveCop, Length, Width, Height, GrossWgt, PalletType)   
                 SELECT @cNewPalletKey, StorerKey, '0', EffectiveDate, AddDate, AddWho, EditDate, EditWho, TrafficCop, ArchiveCop, Length, Width, Height, GrossWgt, PalletType  
                 FROM dbo.Pallet WITH (NOLOCK)  
                 WHERE PalletKey = @cPalletKey  
                   
                 IF @@ERROR <> 0    
                 BEGIN      
                    GOTO RollBackTran_SplitLane    
                 END    
             END   
           
             SET @nPltRowRef = 0     
             IF OBJECT_ID ('tempdb..#PLD') IS NOT NULL   
                  DROP TABLE #PLD  
             SELECT IDENTITY(INT,1,1) AS RowRef, * INTO #PLD FROM dbo.PalletDetail WITH (NOLOCK)  
             WHERE PalletKey = @cPalletKey  
             AND UserDefine01 = @cOrderKey   
             AND UserDefine03 = @cLane  
             ORDER BY PalletLineNumber  
           
             WHILE (1 = 1)  
             BEGIN   
               SELECT TOP 1 @nPltRowRef = RowRef FROM #PLD   
               WHERE RowRef > @nPltRowRef  
               ORDER BY RowRef  
                 
               IF @@ROWCOUNT = 0  
               BEGIN  
                  BREAK   
               END  
                 
               INSERT INTO dbo.PalletDetail   
               (PalletKey, PalletLineNumber, CaseId, StorerKey, Sku, Loc, Qty, Status, AddDate, AddWho, EditDate, EditWho, UserDefine01, UserDefine02, UserDefine03, UserDefine04, UserDefine05)    
               SELECT   
               @cNewPalletKey, '0', CaseId, StorerKey, Sku, Loc, Qty, '0', AddDate, AddWho, EditDate, EditWho, UserDefine01, UserDefine02, @cNewLane, UserDefine04, @cPalletKey  
               FROM #PLD  
               WHERE RowRef = @nPltRowRef  
                 
               IF @@ERROR <> 0    
               BEGIN      
                  GOTO RollBackTran_SplitLane    
               END    
               
             END  
              
             IF NOT EXISTS (  
                 SELECT 1 FROM @tClosedPallet  
                 WHERE PalletKey = @cNewPalletKey  
             )   
             BEGIN  
                 INSERT @tClosedPallet (PalletKey) VALUES (@cNewPalletKey)  
             END  
           
             -- Remove from old pallet  
             UPDATE dbo.PalletDetail SET ArchiveCop = '9', TrafficCop = '9'   
             WHERE PalletKey = @cPalletKey  
             AND UserDefine01 = @cOrderKey   
             AND UserDefine03 = @cLane  
           
             IF @@ERROR <> 0    
             BEGIN      
                GOTO RollBackTran_SplitLane    
             END    
               
             DELETE dbo.PalletDetail  
             WHERE PalletKey = @cPalletKey  
             AND UserDefine01 = @cOrderKey   
             AND UserDefine03 = @cLane  
               
             IF @@ERROR <> 0    
             BEGIN      
                GOTO RollBackTran_SplitLane    
             END    
         END   
         -- Swap lane (END)  
           
         -- Insert order to new lane  
         IF @cSplitMBOLKey <> '' AND NOT EXISTS (  
             SELECT 1 FROM dbo.MBOLDetail WITH (NOLOCK)  
             WHERE MBOLKey = @cSplitMBOLKey  
             AND OrderKey = @cOrderKey  
         )  
         BEGIN   
             INSERT dbo.MBOLDetail (MBOLKey, MBOLLineNumber, OrderKey, LoadKey, AddWho, AddDate, EditWho, EditDate, Weight, Cube,    
                OrderDate, ExternOrderKey, DeliveryDate, CtnCnt1, CtnCnt2, CtnCnt3, CtnCnt4, CtnCnt5,    
                UserDefine01, UserDefine02, UserDefine03, UserDefine04, UserDefine05, UserDefine09, UserDefine10)    
             SELECT @cSplitMBOLKey, '00000', OrderKey, LoadKey, AddWho, AddDate, SUSER_SNAME(), GETDATE(), Weight, Cube,    
                OrderDate, ExternOrderKey, DeliveryDate, CtnCnt1, CtnCnt2, CtnCnt3, CtnCnt4, CtnCnt5,    
              UserDefine01, UserDefine02, UserDefine03, UserDefine04, UserDefine05, UserDefine09, UserDefine10  
             FROM #MD  
             WHERE MBOLKey = @cMBOLKey  
             AND OrderKey = @cOrderKey  
               
             IF @@ERROR <> 0    
             BEGIN      
                GOTO RollBackTran_SplitLane    
             END    
         END   
       --END  
       END   
     
       NEXT_REC:  
     
   FETCH NEXT FROM CUR INTO @cOrderKey, @cMBOLKey, @cPalletKey  
   END  
   CLOSE CUR  
   DEALLOCATE CUR  
     
   -- Close cloned pallets which are already closed   
   UPDATE dbo.Pallet SET Status = '9'  
   WHERE PalletKey IN (  
   SELECT PalletKey FROM @tClosedPallet)  
     
   IF @@ERROR <> 0    
   BEGIN      
      GOTO RollBackTran_SplitLane    
   END    
           
   UPDATE dbo.PalletDetail SET Status = '9'  
   WHERE PalletKey IN (  
   SELECT PalletKey FROM @tClosedPallet)  
     
   IF @@ERROR <> 0    
   BEGIN      
      GOTO RollBackTran_SplitLane    
   END    
     
   SET @cLane = @cNewLane  
     
   COMMIT TRAN SplitLaneTran    
    
   GOTO Quit_SplitLane    
    
   RollBackTran_SplitLane:    
      ROLLBACK TRAN -- Only rollback change made here    
   Quit_SplitLane:    
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started    
         COMMIT TRAN    
    
   Quit:    
END  

GO
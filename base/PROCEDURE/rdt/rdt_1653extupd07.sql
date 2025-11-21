SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/************************************************************************/      
/* Store procedure: rdt_1653ExtUpd07                                    */      
/* Copyright      : IDS                                                 */      
/*                                                                      */      
/* Called from: rdtfnc_TrackNo_SortToPallet                             */      
/*                                                                      */      
/* Purpose: Insert into Transmitlog2 table                              */      
/*                                                                      */      
/* Modifications log:                                                   */      
/* Date        Rev  Author   Purposes                                   */      
/* 2023-05-22  1.0  James    WMS-22499. Created                         */    
/* 2023-08-23  1.1  James    WMS-23471 Change pallet label trigger      */    
/*                           condition when close pallet (james01)      */
/************************************************************************/      

CREATE   PROC [RDT].[rdt_1653ExtUpd07] (      
   @nMobile        INT,  
   @nFunc          INT,  
   @cLangCode      NVARCHAR( 3),  
   @nStep          INT,  
   @nInputKey      INT,  
   @cFacility      NVARCHAR( 5),  
   @cStorerKey     NVARCHAR( 15),  
   @cTrackNo       NVARCHAR( 40),  
   @cOrderKey      NVARCHAR( 20),  
   @cPalletKey     NVARCHAR( 20),  
   @cMBOLKey       NVARCHAR( 10),  
   @cLane          NVARCHAR( 20),  
   @tExtValidVar   VariableTable READONLY,  
   @nErrNo         INT           OUTPUT,  
   @cErrMsg        NVARCHAR( 20) OUTPUT  
) AS      
BEGIN      
   SET NOCOUNT ON      
   SET ANSI_NULLS OFF      
   SET QUOTED_IDENTIFIER OFF      
   SET CONCAT_NULL_YIELDS_NULL OFF      
     
   DECLARE @bSuccess    INT  
   DECLARE @nRowRef     INT  
   DECLARE @nPicked     INT = 0  
   DECLARE @nPacked     INT = 0  
   DECLARE @cPickDetailKey NVARCHAR( 10)  
   DECLARE @cWidth         NVARCHAR( 10)  
   DECLARE @cLength        NVARCHAR( 10)  
   DECLARE @fTotalWeight   FLOAT  
   DECLARE @bdebug         INT = 0
   
   DECLARE  
      @c_ExecStatements     NVARCHAR( MAX),   
      @c_ExecArguments      NVARCHAR( MAX),  
      @nExists              INT = 0,   
      @cKey2                NVARCHAR( 30),  
      @cTableName           NVARCHAR( 30),  
      @cOrdChkField         NVARCHAR( 100),  
      @cPltPalletizedField  NVARCHAR( 30),  
      @cPltEditDate         DATETIME,  
      @cMasterPalletKey     NVARCHAR( 20) = '',  
      @cUDF03               NVARCHAR( 60)  

   DECLARE @curPltDtChk    CURSOR
   DECLARE @cBillToKey     NVARCHAR( 15)
   DECLARE @cShort         NVARCHAR( 10)
   DECLARE @cUDF01         NVARCHAR( 5) 
   DECLARE @cChkOrderKey   NVARCHAR( 10)
   DECLARE @cChkPickSlipNo NVARCHAR( 10)
   DECLARE @nMaxCtnNo      INT
   DECLARE @nClosePallet   INT = 1
   DECLARE @nUpdPltType    INT = 0
   DECLARE @nGenTL2        INT = 1
   DECLARE @cUserName      NVARCHAR( 18)
   DECLARE @cWaveKey       NVARCHAR( 10)
   DECLARE @nPickPackMatch INT = 1
   
   SELECT @cUserName = UserName
   FROM rdt.RDTMOBREC WITH (NOLOCK)
   WHERE Mobile = @nMobile
   
   DECLARE @nTranCount INT    
   SET @nTranCount = @@TRANCOUNT    
   BEGIN TRAN    
   SAVE TRAN rdt_1653ExtUpd07    
     
   IF @nStep IN ( 2, 3, 7)  
   BEGIN  
      IF @nInputKey = 1  
      BEGIN  
       IF EXISTS ( SELECT 1 FROM dbo.PickDetail WITH (NOLOCK)   
                   WHERE OrderKey = @cOrderKey   
                   AND  [STATUS] = '3')  
         BEGIN  
          SELECT @nPicked = ISNULL( SUM( Qty), 0)  
          FROM dbo.PICKDETAIL WITH (NOLOCK)  
          WHERE OrderKey = @cOrderKey  
          AND   [Status] <> '4'  
            
          SELECT @nPacked = ISNULL( SUM( PD.Qty), 0)  
          FROM dbo.PackDetail PD WITH (NOLOCK)  
          JOIN dbo.PackHeader PH WITH (NOLOCK) ON ( PD.PickSlipNo = PH.PickSlipNo)  
          WHERE PH.OrderKey = @cOrderKey  
            
          IF @nPicked = @nPacked  
          BEGIN  
           DECLARE @cur_Upd CURSOR  
           SET @cur_Upd = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR  
           SELECT PickDetailKey  
           FROM dbo.PICKDETAIL WITH (NOLOCK)  
           WHERE OrderKey = @cOrderKey  
           AND   [STATUS] = '3'  
           OPEN @cur_Upd  
           FETCH NEXT FROM @cur_Upd INTO @cPickDetailKey  
           WHILE @@FETCH_STATUS = 0  
           BEGIN  
            UPDATE dbo.PICKDETAIL SET   
               [STATUS] = '5',  
               EditWho = SUSER_SNAME(),  
               EditDate = GETDATE()  
            WHERE PickDetailKey = @cPickDetailKey  
              
            IF @@ERROR <> 0  
            BEGIN  
               SET @nErrNo = 201301  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPDStatusErr  
               GOTO RollBackTran  
            END  
              
            FETCH NEXT FROM @cur_Upd INTO @cPickDetailKey  
           END  
           
          END  
       END  
      END   
   END  
   
   IF @nStep IN ( 4, 6)
   BEGIN
   	IF @nInputKey = 1
   	BEGIN
   		SELECT TOP 1 
   		   @cWaveKey = O.UserDefine09, 
   		   @cBillToKey = BillToKey
   		FROM dbo.ORDERS O WITH (NOLOCK)
   		WHERE O.StorerKey = @cStorerKey
   		AND   EXISTS (	SELECT 1 
   			            FROM dbo.PALLETDETAIL PLD WITH (NOLOCK)
   			            WHERE O.StorerKey = PLD.StorerKey AND O.OrderKey = PLD.UserDefine01
   			            AND   PLD.PalletKey = @cPalletKey
   		               AND   (( @nStep = 4 AND [Status] = '9') OR ( @nStep = 6 AND [Status] < '9')))
   		ORDER BY 1
   		
   		SELECT @nMaxCtnNo = COUNT( DISTINCT CartonNo)
   		FROM dbo.PackDetail PD WITH (NOLOCK)
   		JOIN dbo.PackHeader PH WITH (NOLOCK) ON PD.PickSlipNo = PH.PickSlipNo
   		WHERE PH.StorerKey = @cStorerKey
   		AND   EXISTS (	SELECT 1 
   			            FROM dbo.PALLETDETAIL PLD WITH (NOLOCK)
   			            WHERE PH.StorerKey = PLD.StorerKey AND PH.OrderKey = PLD.UserDefine01
   			            AND   PLD.PalletKey = @cPalletKey
   		               AND   (( @nStep = 4 AND [Status] = '9') OR ( @nStep = 6 AND [Status] < '9')))

         SELECT @cBillToKey = BillToKey
      	FROM dbo.ORDERS WITH (NOLOCK)
         WHERE OrderKey = @cOrderKey

      	SELECT 
      	   @cUDF01 = UDF01,  -- # of max allowed carton
      	   @cShort = Short   -- Pallet trigger flag
      	FROM dbo.CODELKUP WITH (NOLOCK)
      	WHERE LISTNAME = 'NOMIXPLSHP'
      	AND   Code = @cBillToKey
      	AND   Storerkey = @cStorerKey

         SET @curPltDtChk = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
      	SELECT DISTINCT UserDefine01
      	FROM dbo.PALLETDETAIL WITH (NOLOCK)
      	WHERE PalletKey = @cPalletKey
      	AND   StorerKey = @cStorerKey
      	AND   (( @nStep = 4 AND [Status] = '9') OR ( @nStep = 6 AND [Status] < '9'))
      	ORDER BY 1
      	OPEN @curPltDtChk
      	FETCH NEXT FROM @curPltDtChk INTO @cChkOrderKey
      	WHILE @@FETCH_STATUS = 0
      	BEGIN
      	   SELECT @cChkPickSlipNo = PickSlipNo
      	   FROM dbo.PackHeader WITH (NOLOCK)
      	   WHERE OrderKey = @cChkOrderKey
      	   	
            SELECT @nPicked = ISNULL( SUM( Qty), 0)  
            FROM dbo.PICKDETAIL WITH (NOLOCK)  
            WHERE OrderKey = @cChkOrderKey  
            AND   [Status] <> '4'  
            
            SELECT @nPacked = ISNULL( SUM( Qty), 0)  
            FROM dbo.PackDetail WITH (NOLOCK)  
            WHERE PickSlipNo = @cChkPickSlipNo

            IF @nPicked <> @nPacked
            BEGIN
               SET @nPickPackMatch = 0
               BREAK
            END
               
      	   FETCH NEXT FROM @curPltDtChk INTO @cChkOrderKey	
      	END

         IF @bdebug = 1
         BEGIN
         	SELECT @cChkOrderKey '@cChkOrderKey', @nPicked '@nPicked', @nPacked '@nPacked', @cUDF01 '@cUDF01', @nMaxCtnNo '@nMaxCtnNo'
         	SELECT @nClosePallet '@nClosePallet', @nUpdPltType '@nUpdPltType', @nGenTL2 '@nGenTL2'
         END
            
         IF @cShort = 'N'
         BEGIN
            -- # of max allowed carton setup
      	   IF ISNULL( @cUDF01, '') <> '' AND CAST( @cUDF01 AS INT) > 0
      	   BEGIN
               -- > allowed max carton
      	   	IF ( CAST( @cUDF01 AS INT) > @nMaxCtnNo) 
               BEGIN
                  -- Orders not fully pack
               	IF @nPickPackMatch = 0
               	BEGIN
               		SET @nClosePallet = 0
               		SET @nUpdPltType = 0
               		SET @nGenTL2 = 0

                     -- Close pallet only need prompt
               	   IF @nStep = 4
               	   BEGIN
                        SET @nErrNo = 201305    
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- '> Max Carton'    
                        GOTO RollBackTran
                     END    
               	END
               	ELSE  -- Orders fully pack
               	BEGIN
                     SET @nClosePallet = 1
                     SET @nUpdPltType = 0
                     SET @nGenTL2 = 0               		
               	END
               END
               ELSE  -- < allowed max carton
               BEGIN
                  SET @nClosePallet = 1
                  SET @nUpdPltType = 1
                  SET @nGenTL2 = 0
               END
      	   END
      	   ELSE
      	   BEGIN -- value not setup
               SET @nClosePallet = 1
               SET @nUpdPltType = 1
               SET @nGenTL2 = 0
      	   END
         END
         ELSE  -- @cShort = 'Y'
         BEGIN
            -- # of max allowed carton setup
      	   IF ISNULL( @cUDF01, '') <> '' AND CAST( @cUDF01 AS INT) > 0
      	   BEGIN
               -- > allowed max carton
      	   	IF ( CAST( @cUDF01 AS INT) > @nMaxCtnNo) 
               BEGIN
                  -- Orders not fully pack
               	IF @nPickPackMatch = 0
               	BEGIN
               		SET @nClosePallet = 0
               		SET @nUpdPltType = 0
               		SET @nGenTL2 = 0
               		   
                     IF @nStep = 4
                     BEGIN
                        SET @nErrNo = 201306    
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- '> Max Carton'    
                        GOTO RollBackTran    
                     END
               	END
               	ELSE  -- Orders fully pack
               	BEGIN
                     SET @nClosePallet = 1
                     SET @nUpdPltType = 0
                     SET @nGenTL2 = 0               		
               	END
               END
               ELSE  -- < allowed max carton
               BEGIN
                  SET @nClosePallet = 1
                  SET @nUpdPltType = 0
                  SET @nGenTL2 = 1
               END
      	   END
      	   ELSE
      	   BEGIN -- value not setup
               SET @nClosePallet = 1
               SET @nUpdPltType = 0
               SET @nGenTL2 = 1
      	   END
         END
   	END
   END
   
   IF @nStep = 4  
   BEGIN  
      IF @nInputKey = 1  
      BEGIN  
      	IF @nClosePallet = 1 AND @nUpdPltType = 1
      	BEGIN
      	   UPDATE dbo.Pallet SET 
      	      PalletType = 'NT', 
      	      TrafficCop = NULL,   -- Pallet closed from main script 
      	      EditWho = @cUserName, 
      	      EditDate = GETDATE()	
      	   WHERE PalletKey = @cPalletKey
      	   
      	   IF @@ERROR <> 0
            BEGIN    
               SET @nErrNo = 201307    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'Upd PltTyp Er'    
               GOTO RollBackTran    
            END   
      	END
      	
         DECLARE @curDelEcomLog  CURSOR  
         SET @curDelEcomLog = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR  
         SELECT RowRef FROM rdt.rdtECOMMLog EL WITH (NOLOCK)  
         WHERE EXISTS ( SELECT 1 FROM MBOLDETAIL MD WITH (NOLOCK)   
                        WHERE EL.Orderkey = MD.OrderKey   
                        AND   MD.MbolKey = @cMBOLKey)  
         OPEN @curDelEcomLog  
         FETCH NEXT FROM @curDelEcomLog INTO @nRowRef  
         WHILE @@FETCH_STATUS = 0  
         BEGIN  
            DELETE rdt.rdtECOMMLOG WHERE RowRef = @nRowRef  
    
            IF @@ERROR <> 0    
            BEGIN    
               SET @nErrNo = 201302    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'DelEcommFail'    
               GOTO RollBackTran    
            END    
  
            FETCH NEXT FROM @curDelEcomLog INTO @nRowRef  
         END  
  
            
      END  
   END  
     
   IF @nStep = 6  
   BEGIN     
      SELECT @fTotalWeight = ISNULL( SUM( Weight), 0)  
      FROM dbo.PackInfo PI WITH (NOLOCK)    
      CROSS APPLY (    
          SELECT DISTINCT PD.StorerKey, PLD.PalletKey   
          FROM dbo.PackDetail PD WITH (NOLOCK)     
          JOIN dbo.PalletDetail PLD WITH (NOLOCK) ON   
            ( PLD.CaseID = PD.LabelNo AND PLD.StorerKey = PD.StorerKey)  
          WHERE PD.LabelNo = PLD.CaseID     
          AND   PLD.StorerKey = PD.StorerKey    
          AND   PD.PickSlipNo = PI.PickSlipNo  
          AND   PD.CartonNo = PI.CartonNo  
      ) PD    
      WHERE PD.StorerKey = @cStorerKey  
      AND PalletKey = @cPalletKey    
  
      UPDATE dbo.Pallet SET  
         GrossWgt = @fTotalWeight,  
         TrafficCop = NULL,  
         EditDate = GETDATE(),  
         EditWho = SUSER_SNAME()  
      WHERE PalletKey = @cPalletKey  
  
      IF @@ERROR <> 0  
      BEGIN  
         SET @nErrNo = 201303  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPDPLDWGT Err  
         GOTO RollBackTran  
      END  
  
      -- Do not trigger pallet label because palletized customer with few cartons can be mixed with normal pallet  
      IF EXISTS (  
         SELECT 1 FROM dbo.PalletDetail PD WITH (NOLOCK)      
         JOIN dbo.ORDERS WITH (NOLOCK) ON ( PD.UserDefine01 = Orders.OrderKey AND PD.StorerKey = Orders.StorerKey)       
         LEFT JOIN dbo.CODELKUP CL WITH (NOLOCK) ON ( Orders.BillToKey = CL.Code)     
         AND Orders.StorerKey = CL.StorerKey AND CL.ListName = 'NOMIXPLSHP'      
         WHERE Orders.StorerKey = @cStorerKey    
         AND   PD.PalletKey = @cPalletKey     
         GROUP BY PD.PalletKey  
         HAVING COUNT(CASE WHEN ISNULL(CL.Code, '') <> '' THEN 1 END) <> COUNT(1)  
      )  
      BEGIN   
         GOTO Quit    
      END   
      -- CHANGES (END)  
  
      DECLARE @tPallets TABLE  
       (    
          Seq       INT IDENTITY(1,1) NOT NULL,    
          PalletKey NVARCHAR(20),    
          EditDate  DATETIME,  
          Status    NVARCHAR(1)  
       )    
   
      -- Assume the pallet contains same palletized customer     
      SELECT TOP 1 @c_ExecStatements =   
         N' SELECT @cOrdChkField = ' + CASE WHEN ISNULL(CL.Long, '') <> '' THEN 'ISNULL(' + CL.Long + ', '''')' ELSE '''''' END  
        + ' FROM dbo.ORDERS WITH (NOLOCK) WHERE OrderKey = ''' + Orders.OrderKey + '''',  
         @cPltPalletizedField = ISNULL(CL.Long, '')  
      FROM dbo.PalletDetail PD WITH (NOLOCK)    
      JOIN dbo.ORDERS WITH (NOLOCK) ON ( PD.UserDefine01 = Orders.OrderKey AND PD.StorerKey = Orders.StorerKey)     
      LEFT JOIN dbo.CODELKUP CL WITH (NOLOCK) ON ( Orders.BillToKey = CL.Code)   
      AND Orders.StorerKey = CL.StorerKey AND CL.ListName = 'NOMIXPLSHP'    
      WHERE Orders.StorerKey = @cStorerKey  
      AND   PD.PalletKey = @cPalletKey    
  
      SET @c_ExecArguments = N'@cOrdChkField NVARCHAR(100) OUTPUT'  
      EXEC sp_ExecuteSql   @c_ExecStatements  
                         , @c_ExecArguments  
                         , @cOrdChkField OUTPUT    
      SET @c_ExecStatements = ''    
      SET @c_ExecArguments = ''  
  
      -- If it's palletized customer           
      IF @cPltPalletizedField <> ''  
      BEGIN            
         -- Get list of pallets in the lane that share the same palletization requirement  
         SELECT @c_ExecStatements = N'SELECT DISTINCT PD.PalletKey, MIN(PD.EditDate), MAX(PD.Status) '   
                                  + ' FROM PalletDetail PD WITH (NOLOCK) '  
                                  + ' JOIN Orders WITH (NOLOCK) ON ( PD.UserDefine01 = Orders.OrderKey AND PD.StorerKey = Orders.StorerKey) '  
                                  + ' JOIN Codelkup CL WITH (NOLOCK) ON ' +   
                                     ' ( Orders.BillToKey = CL.Code AND Orders.StorerKey = CL.StorerKey) '  
                                  + ' WHERE PD.PalletKey <> @cPalletKey '  
                                  + ' AND   CL.ListName = ''NOMIXPLSHP'' '  
                                  + ' AND   PD.UserDefine03 = @cLane '  
                                  + ' AND   Orders.StorerKey = @cStorerKey '  
                                  + ' AND ' + @cPltPalletizedField + ' = @cOrdChkField '  
                                  + ' GROUP BY PD.PalletKey '  
                                  + ' ORDER BY MIN(PD.EditDate) '  
                              
         SET @c_ExecArguments = N'@cPalletKey          NVARCHAR(20)'  
                             + ', @cLane               NVARCHAR(20)'  
                             + ', @cStorerKey          NVARCHAR(15)'  
                             + ', @cOrdChkField        NVARCHAR(100)'  
     
         INSERT INTO @tPallets (PalletKey, EditDate, Status)  
         EXEC sp_ExecuteSql   @c_ExecStatements  
                            , @c_ExecArguments  
                            , @cPalletKey  
                            , @cLane  
                            , @cStorerKey  
                            , @cOrdChkField  
                                
         SELECT @cPltEditDate = MIN(EditDate)   
         FROM dbo.PalletDetail WITH (NOLOCK)  
         WHERE PalletKey = @cPalletKey  
     
         SELECT TOP 1 @nExists = 1, @cMasterPalletKey = PalletKey   
         FROM @tPallets  
         WHERE Status = '9'  
         AND   EditDate < @cPltEditDate  
         ORDER BY Seq   
     
         -- If no pallet is closed before current one, treat it as master pallet   
         IF @nExists = 0
         BEGIN 
            SELECT @cTableName = Code
            FROM dbo.CODELKUP WITH (NOLOCK)
            WHERE ListName = 'LVSPLTLBL'
            AND   Short = 'MASTER' 
            AND   Storerkey = @cStorerkey 
	      
	         SET @cKey2 = ''
         END   
         ELSE 
         BEGIN 
            SELECT @cTableName = Code
            FROM dbo.CODELKUP WITH (NOLOCK)
            WHERE ListName = 'LVSPLTLBL'
            AND   Short = 'CHILD' 
            AND   Storerkey = @cStorerkey
            
	         SET @cKey2 = @cMasterPalletKey

            UPDATE dbo.PalletDetail SET    
               UserDefine05 = @cMasterPalletKey,  
               TrafficCop = NULL,  
               EditDate = GETDATE(),  
               EditWho = SUSER_SNAME()  
            WHERE PalletKey = @cPalletKey  
  
            IF @@ERROR <> 0  
            BEGIN  
               SET @nErrNo = 201308  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PLTDL Err  
               GOTO RollBackTran  
            END  
         END 
         
         IF @nGenTL2 = 1
         BEGIN
            EXECUTE ispGenTransmitLog2     
               @c_TableName      = @cTableName,     
               @c_Key1           = @cLane,     
               @c_Key2           = @cPalletKey,     
               @c_Key3           = @cStorerkey,     
               @c_TransmitBatch  = '',     
               @b_Success        = @bSuccess   OUTPUT,        
               @n_err            = @nErrNo     OUTPUT,        
               @c_errmsg         = @cErrMsg    OUTPUT        
         END
      END      
   END  
     
   GOTO Quit  
     
   RollBackTran:    
         ROLLBACK TRAN rdt_1653ExtUpd07    
   Quit:    
      WHILE @@TRANCOUNT > @nTranCount    
         COMMIT TRAN    
      
END      

GO
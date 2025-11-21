SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/    
/* Store procedure: rdt_1653ExtUpd06                                    */    
/* Copyright      : MAERSK                                              */    
/*                                                                      */    
/* Called from: rdtfnc_TrackNo_SortToPallet                             */    
/*                                                                      */    
/* Purpose: Insert into Transmitlog2 table                              */    
/*                                                                      */    
/* Modifications log:                                                   */    
/* Date        Rev  Author   Purposes                                   */    
/* 2022-10-05  1.0  James    WMS-20667. Created                         */  
/* 2023-10-26  1.1  James    WMS-23879 Skip printing check when         */
/*                           CODELKUP setup (james01)                   */
/* 2023-11-14  1.2  James    WMS-23712 Extend Lane var length (james02) */  
/************************************************************************/    
    
CREATE   PROC [RDT].[rdt_1653ExtUpd06] (    
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
   @cLane          NVARCHAR( 30),
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
   DECLARE @cTransmitLogKey NVARCHAR(10)
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
      @cUDF03               NVARCHAR( 60) = '',
      @cUDF02               NVARCHAR( 60) = '',
      @cKey1                NVARCHAR( 10) = ''
      
   DECLARE @nTranCount INT  
   SET @nTranCount = @@TRANCOUNT  
   BEGIN TRAN  
   SAVE TRAN rdt_1653ExtUpd06  
   
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
      	   			SET @nErrNo = 192551
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPDStatusErr
                     GOTO RollBackTran
      	   		END
      	   		
      	   		FETCH NEXT FROM @cur_Upd INTO @cPickDetailKey
      	   	END
      	  
      	   END
      	END
      END	
   END
   
   IF @nStep = 4
   BEGIN
      IF @nInputKey = 1
      BEGIN
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
               SET @nErrNo = 192552  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'DelEcommFail'  
               GOTO RollBackTran  
            END  

            FETCH NEXT FROM @curDelEcomLog INTO @nRowRef
         END

          
      END
   END
   
   IF @nStep = 6
   BEGIN   
      SELECT @cUDF02 = ISNULL(CL.UDF02, '')  
      FROM dbo.ORDERS O WITH (NOLOCK)   
      JOIN dbo.CODELKUP CL WITH (NOLOCK) ON   
         ( O.ConsigneeKey = CL.Code AND O.ShipperKey = CL.Code2 AND O.StorerKey = CL.StorerKey)  
      WHERE OrderKey = @cOrderKey  
      AND   CL.ListName = 'NOMIXPLSHP'  
      AND   CL.Storerkey = @cStorerKey 
         
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
         SET @nErrNo = 192553
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPDPLDWGT Err
         GOTO RollBackTran
      END

      IF @cUDF02 = ''
      BEGIN
         -- Do not trigger pallet label because palletized customer with few cartons can be mixed with normal pallet
         IF EXISTS (
            SELECT 1 FROM dbo.PalletDetail PD WITH (NOLOCK)    
            JOIN dbo.ORDERS WITH (NOLOCK) ON ( PD.UserDefine01 = Orders.OrderKey AND PD.StorerKey = Orders.StorerKey)     
            LEFT JOIN dbo.CODELKUP CL WITH (NOLOCK) ON ( Orders.ConsigneeKey = CL.Code AND Orders.ShipperKey = CL.Code2)   
            AND Orders.StorerKey = CL.StorerKey AND CL.ListName = 'NOMIXPLSHP'    
            WHERE Orders.StorerKey = @cStorerKey  
            AND   PD.PalletKey = @cPalletKey   
            GROUP BY PD.PalletKey
            HAVING COUNT(CASE WHEN ISNULL(CL.Code, '') <> '' THEN 1 END) <> COUNT(1)
         )
         BEGIN 
            GOTO Quit  
         END 
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
      LEFT JOIN dbo.CODELKUP CL WITH (NOLOCK) ON ( Orders.ConsigneeKey = CL.Code AND Orders.ShipperKey = CL.Code2) 
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
                                     ' ( Orders.ConsigneeKey = CL.Code AND Orders.ShipperKey = CL.Code2 AND Orders.StorerKey = CL.StorerKey) '
                                  + ' WHERE PD.PalletKey <> @cPalletKey '
                                  + ' AND   CL.ListName = ''NOMIXPLSHP'' '
                                  + ' AND   PD.UserDefine03 = @cLane '
                                  + ' AND   Orders.StorerKey = @cStorerKey '
                                  + ' AND ' + @cPltPalletizedField + ' = @cOrdChkField '
                                  + ' GROUP BY PD.PalletKey '
                                  + ' ORDER BY MIN(PD.EditDate) '
                            
         SET @c_ExecArguments = N'@cPalletKey          NVARCHAR(20)'
                             + ', @cLane               NVARCHAR(30)'
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
            SET @cTableName = 'WSCRPLTREQILS'
            SET @cKey2 = ''
         END   
         ELSE 
         BEGIN 
            SET @cTableName = 'WSCRPLTADDILS' 
            SET @cKey2 = @cMasterPalletKey
            
            UPDATE dbo.PalletDetail SET  
               UserDefine05 = @cMasterPalletKey,
               TrafficCop = NULL,
               EditDate = GETDATE(),
               EditWho = SUSER_SNAME()
            WHERE PalletKey = @cPalletKey

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 192554
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PLTDL Err
               GOTO RollBackTran
            END
         END 

         -- Lane value might >10 chars but key1 only able to accept 10 chars
         -- Need trim the Lane value else transmitlogkey not able to retrieve
         IF LEN( @cLane) > 10
            SET @cKey1 = LEFT( @cLane, 10)
         ELSE
         	SET @cKey1 = @cLane
         	
         SET @nErrNo = 0
         EXECUTE ispGenTransmitLog2   
            @c_TableName      = @cTableName,   
            @c_Key1           = @cKey1,   
            @c_Key2           = @cPalletKey,   
            @c_Key3           = @cStorerkey,   
            @c_TransmitBatch  = '',   
            @b_Success        = @bSuccess   OUTPUT,      
            @n_err            = @nErrNo     OUTPUT,      
            @c_errmsg         = @cErrMsg    OUTPUT      

         IF @nErrNo <> 0
            GOTO RollBackTran

         SELECT @cTransmitLogKey = transmitlogkey  
         FROM dbo.TRANSMITLOG2 WITH (NOLOCK)  
         WHERE tablename = @cTableName  
         AND   key1 = @cKey1  
         AND   key2 = @cPalletKey  
         AND   key3 = @cStorerkey  

         SET @nErrNo = 0
         EXEC dbo.isp_QCmd_WSTransmitLogInsertAlert  
            @c_QCmdClass         = '',  
            @c_FrmTransmitlogKey = @cTransmitLogKey,  
            @c_ToTransmitlogKey  = @cTransmitLogKey,  
            @b_Debug             = 0,  
            @b_Success           = @bSuccess    OUTPUT,  
            @n_Err               = @nErrNo      OUTPUT,  
            @c_ErrMsg            = @cErrMsg     OUTPUT  
  
         IF @nErrNo <> 0  
            GOTO RollBackTran  
      END 
   END
   
   GOTO Quit
   
   RollBackTran:  
         ROLLBACK TRAN rdt_1653ExtUpd06  
   Quit:  
      WHILE @@TRANCOUNT > @nTranCount  
         COMMIT TRAN  
    
END    

GO
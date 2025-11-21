SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: rdt_840ExtInsPack05                                */
/*                                                                      */
/* Purpose: Insert/Update packdetail.                                   */
/*          Retrieve tracking no from cartontrack_pool for 2nd carton   */
/*          onwards. 1st carton use orders.userdefine04                 */
/*                                                                      */
/* Called By: RDT Pack By Track No                                      */ 
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/* 2019-03-05   James     1.0   WMS8142 - Created                       */
/* 2021-04-01   YeeKung   1.1   WMS-16717 Add serialno and serialqty    */
/*                              Params (yeekung01)                      */
/* 2021-04-16   James     1.2   WMS-16024 Standarized use of TrackingNo */
/*                              (james01)                               */
/* 2022-07-05   James     1.3   WMS-20115 Get TrackNo by orders.        */
/*                              ordergroup (james02)                    */
/* 2022-10-03   James     1.4   WMS-20920 Add new category for getting  */
/*                              new tracking no (james03)               */
/* 2023-02-13   James     1.5   WMS-21691 Track# assign enhance(james04)*/
/************************************************************************/

CREATE   PROC [RDT].[rdt_840ExtInsPack05] (
   @nMobile                   INT, 
   @nFunc                     INT, 
   @cLangCode                 NVARCHAR( 3), 
   @nStep                     INT, 
   @nInputKey                 INT, 
   @cStorerkey                NVARCHAR( 15), 
   @cOrderKey                 NVARCHAR( 10), 
   @cPickSlipNo               NVARCHAR( 10), 
   @cTrackNo                  NVARCHAR( 20), 
   @cSKU                      NVARCHAR( 20), 
   @nQty                      INT, 
   @nCartonNo                 INT, 
   @cSerialNo                 NVARCHAR( 30), 
   @nSerialQTY                INT,  
   @cLabelNo                  NVARCHAR( 20) OUTPUT, 
   @nErrNo                    INT           OUTPUT, 
   @cErrMsg                   NVARCHAR( 20) OUTPUT  
)
AS
BEGIN

   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nTranCount        INT,
           @nPD_QTY           INT,
           @cReportType       NVARCHAR( 10),
           @cPrintJobName     NVARCHAR( 50),
           @cDataWindow       NVARCHAR( 50),
           @cTargetDB         NVARCHAR( 20),
           @cPaperPrinter     NVARCHAR( 10),
           @cLabelPrinter     NVARCHAR( 10),
           @cPickDetailKey    NVARCHAR( 10), 
           @cCarrierName      NVARCHAR( 30), 
           @cKeyName          NVARCHAR( 30), 
           @cUserName         NVARCHAR( 18), 
           @cLoadKey          NVARCHAR( 10),
           @cRoute            NVARCHAR( 10),
           @cConsigneeKey     NVARCHAR( 15), 
           @cCurLabelNo       NVARCHAR( 20),
           @cCurLabelLine     NVARCHAR( 5), 
           @cPack_LblNo       NVARCHAR( 20), 
           @cPack_SKU         NVARCHAR( 20), 
           @cShipLabel        NVARCHAR( 10),
           @cDelNotes         NVARCHAR( 10),
           @cFacility         NVARCHAR( 5),
           @nPack_QTY         INT, 
           @nPickQty          INT, 
           @nPackQty          INT,
           @nNewCarton        INT,
           @bSuccess          INT,
           @cShipperKey       NVARCHAR( 15),
           @cDefEcomCartonCnt INT,
           @nCurrentCtnNo     INT,
           @nNewCartonNo      INT

   DECLARE @b_success         INT,
           @n_err             INT,
           @c_errmsg          NVARCHAR( 20)

   DECLARE @cOrderGroup       NVARCHAR( 20) = ''
   DECLARE @cECOM_Platform    NVARCHAR( 30) = ''
   DECLARE @cTableName        NVARCHAR( 30) = ''
   
   SET @nTranCount = @@TRANCOUNT    

   BEGIN TRAN    
   SAVE TRAN rdt_840ExtInsPack05    

   SELECT @cUserName = UserName,
          @cFacility = Facility
   FROM rdt.rdtMOBREC WITH (NOLOCK)
   WHERE Mobile = @nMobile

   -- Piece scanning
   SET @nQty = 1
   SET @cLabelNo = ''
   SET @nNewCarton = 0

   IF EXISTS (SELECT 1 FROM rdt.rdtTrackLog WITH (NOLOCK)
               WHERE PickSlipNo = @cPickSlipNo
               AND Storerkey = @cStorerkey
               AND CartonNo = @nCartonNo
               AND UserName = @cUserName
               AND SKU = @cSKU)   -- can scan many sku into 1 carton
   BEGIN
      UPDATE rdt.rdtTrackLog WITH (ROWLOCK) SET
         Qty = ISNULL(Qty, 0) + 1,
         EditWho = @cUserName,
         EditDate = GetDate()
      WHERE PickSlipNo = @cPickSlipNo
      AND Storerkey = @cStorerkey
      AND CartonNo = @nCartonNo
      AND UserName = @cUserName
      AND SKU = @cSKU

      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 135451
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdLog Failed'
         GOTO RollBackTran
      END
   END
   ELSE
   BEGIN
      INSERT INTO rdt.rdtTrackLog ( PickSlipNo, Mobile, UserName, Storerkey, Orderkey, TrackNo, SKU, Qty, CartonNo )
      VALUES (@cPickSlipNo, @nMobile, @cUserName, @cStorerkey, @cOrderKey, @cTrackNo, @cSKU, 1, @nCartonNo  )

      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 135452
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsLog Failed'
         GOTO RollBackTran
      END
   END

      SELECT @cLoadKey = ISNULL(RTRIM(LoadKey),'')
            , @cRoute = ISNULL(RTRIM(Route),'')
            , @cConsigneeKey = ISNULL(RTRIM(ConsigneeKey),'') 
            , @cOrderGroup = OrderGroup 
            , @cECOM_Platform = ECOM_Platform
            , @cShipperKey = ShipperKey
      FROM dbo.Orders WITH (NOLOCK)
      WHERE Orderkey = @cOrderkey
      
   -- Create PackHeader if not yet created
   IF NOT EXISTS (SELECT 1 FROM dbo.PackHeader WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo)
   BEGIN
      INSERT INTO dbo.PACKHEADER
      (PickSlipNo, StorerKey, OrderKey, LoadKey, Route, ConsigneeKey, OrderRefNo, TtlCnts, [STATUS])
      VALUES
      (@cPickSlipNo, @cStorerkey, @cOrderkey, @cLoadKey, @cRoute, @cConsigneeKey, '', 0, '0')

      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 135453
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsPKHDR Failed'
         GOTO RollBackTran
      END
   END

   -- Update PackDetail.Qty if it is already exists
   IF EXISTS (SELECT 1 FROM dbo.PackDetail WITH (NOLOCK)
               WHERE StorerKey = @cStorerkey
               AND PickSlipNo = @cPickSlipNo
               AND CartonNo = @nCartonNo
               AND SKU = @cSKU)   -- can scan many sku into 1 carton
   BEGIN
      UPDATE dbo.PackDetail WITH (ROWLOCK) SET
         Qty = Qty + @nQty,
         EditDate = GETDATE(),
         EditWho = 'rdt.' + sUser_sName()
      WHERE StorerKey = @cStorerkey
      AND PickSlipNo = @cPickSlipNo
      AND CartonNo = @nCartonNo
      AND SKU = @cSKU

      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 135454
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UPDPKDET Failed'
         GOTO RollBackTran
      END
   END
   ELSE     -- Insert new PackDetail
   BEGIN
      -- Check if same carton exists before. Diff sku can scan into same carton
      IF NOT EXISTS (SELECT 1 FROM dbo.PackDetail WITH (NOLOCK)
                  WHERE StorerKey = @cStorerkey
                  AND PickSlipNo = @cPickSlipNo
                  AND CartonNo = @nCartonNo)
      BEGIN
         -- Get tracking no. Customer order can have > 1 carton
         -- If 1st carton then get the tracking no from orders.userdefine04
         IF @nCartonNo = 1
         BEGIN
            --SELECT @cTrackNo = UserDefine04
            SELECT @cTrackNo = TrackingNo -- (james01)
            FROM dbo.Orders WITH (NOLOCK) 
            WHERE StorerKey = @cStorerkey
            AND   OrderKey = @cOrderKey

            IF ISNULL( @cTrackNo, '') = ''
            BEGIN    
               SET @nErrNo = 135455    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'NO TRACKING #'    
               GOTO RollBackTran    
            END    
         END
         ELSE
         BEGIN
            -- If not 1st carton, not exists in packdetail yet, get new tracking no
            IF NOT EXISTS ( SELECT 1 FROM dbo.PackDetail WITH (NOLOCK) 
                            WHERE PickSlipNo = @cPickSlipNo 
                            AND CartonNo = @nCartonNo)
            BEGIN
            	-- Decide whether need send interface to get new tracking no (james02)
            	SELECT @cDefEcomCartonCnt = UDF01 
            	FROM dbo.CODELKUP WITH (NOLOCK) 
            	WHERE ListName = 'WSCOURIER' 
            	AND   Code LIKE '%CourierMultiTrackNo' 
            	AND   Storerkey = @cStorerkey
            	AND   Short = @cShipperKey 
            	AND   code2 = @cECOM_Platform

               SELECT @nCurrentCtnNo = MAX( CartonNo)
               FROM dbo.PackDetail WITH (NOLOCK)
               WHERE PickSlipNo = @cPickSlipNo
               
               IF ( CAST( @cDefEcomCartonCnt AS INT) - @nCurrentCtnNo < 2) OR @cDefEcomCartonCnt is NULL
               BEGIN
               	-- commented (james04)
                --  IF @cECOM_Platform = 'DY'
            		  -- SET @cTableName = 'WSCRPKADDDY'
            	   --ELSE IF @cECOM_Platform = 'JD'
            		  -- SET @cTableName = 'WSCRPKADDJD'
            	   --ELSE IF @cECOM_Platform = 'TM'
            		  -- SET @cTableName = 'WSCRPKADDCN'
                --  ELSE
                --  	SET @cTableName = 'Other'
                  
                  -- (james04)
                  SELECT @cTableName = Long
                  FROM dbo.CODELKUP WITH (NOLOCK)
                  WHERE LISTNAME = 'RDT840TBN'
                  AND   Short = @cECOM_Platform
                  AND   Storerkey = @cStorerkey
                  
                  IF ISNULL( @cTableName, '') = ''
                     SET @cTableName = 'Other'

                  IF @cTableName <> 'Other'
                  BEGIN
                     SET @nNewCartonNo = @nCartonNo + 1
                     SET @bSuccess = 1    
                     EXEC ispGenTransmitLog2    
                         @c_TableName        = @cTableName    
                        ,@c_Key1             = @cOrderKey    
                        ,@c_Key2             = @nNewCartonNo    
                        ,@c_Key3             = @cStorerkey    
                        ,@c_TransmitBatch    = ''    
                        ,@b_Success          = @bSuccess    OUTPUT    
                        ,@n_err              = @nErrNo      OUTPUT    
                        ,@c_errmsg           = @cErrMsg     OUTPUT    
    
                     IF @bSuccess <> 1    
                     BEGIN
                        SET @nErrNo = 135461  
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsTL2Log Err'  
                        GOTO RollBackTran    
                     END
                  END
               END

               IF @cTableName = 'Other'
               BEGIN
                  SET @cTrackNo = ''  
                  EXEC ispAsgnTNo2  
                    @c_OrderKey    = @cOrderKey     
                  , @c_LoadKey     = ''  
                  , @b_Success     = @bSuccess  OUTPUT        
                  , @n_Err         = @nErrNo    OUTPUT        
                  , @c_ErrMsg      = @cErrMsg   OUTPUT        
                  , @b_ChildFlag   = 1  
                  , @c_TrackingNo  = @cTrackNo  OUTPUT   
               END
               ELSE
               BEGIN
                  SET @cTrackNo = ''  
                  SELECT @cTrackNo = CT.TrackingNo
                  FROM dbo.CartonTrack CT WITH (NOLOCK)
                  WHERE CT.LabelNo = @cOrderKey
                  AND   CT.CarrierName = @cShipperKey
                  AND   ISNULL( CT.CarrierRef2, '') = ''
                  AND   CarrierRef1 = @cOrderKey + CAST( @nCurrentCtnNo + 1 AS NVARCHAR( 1))
                  AND   NOT EXISTS ( SELECT 1 FROM dbo.PackDetail PD WITH (NOLOCK)
                                     WHERE PD.StorerKey = @cStorerkey
                                     AND   PD.LabelNo = CT.TrackingNo)
               END
                              
               IF ISNULL( @cTrackNo, '') = ''
               BEGIN
                  SET @nErrNo = 135456
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'GetTrack# Fail'
                  GOTO RollBackTran
               END
               
               UPDATE dbo.CartonTrack SET
                  CarrierRef2 = 'GET'
               WHERE TrackingNo = @cTrackNo
               AND   CarrierName = @cShipperKey
               AND   CarrierRef2 = ''
               
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 135462
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Upd CTTRK Err'
                  GOTO RollBackTran
               END
            END
            ELSE
            BEGIN
               SELECT TOP 1 @cTrackNo = LabelNo
               FROM dbo.PackDetail WITH (NOLOCK)    
               WHERE StorerKey = @cStorerkey    
               AND PickSlipNo = @cPickSlipNo    
               AND CartonNo = @nCartonNo
            END
         END

         SET @cLabelNo = @cTrackNo

         IF ISNULL( @cLabelNo, '') = ''
         BEGIN
            SET @nErrNo = 135457
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'GET LABEL Fail'
            GOTO RollBackTran
         END

         -- CartonNo = 0 & LabelLine = '0000', trigger will auto assign
         INSERT INTO dbo.PackDetail
            (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, QTY, Refno, AddWho, AddDate, EditWho, EditDate, DropID)
         VALUES
            (@cPickSlipNo, 0, @cLabelNo, '00000', @cStorerKey, @cSku, @nQty,
            '', 'rdt.' + sUser_sName(), GETDATE(), 'rdt.' + sUser_sName(), GETDATE(), '')

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 135458
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'INS PACK Fail'
            GOTO RollBackTran
         END
         ELSE
            SELECT @nNewCarton = CartonNo 
            FROM dbo.PackDetail WITH (NOLOCK) 
            WHERE PickSlipNo = @cPickSlipNo
            AND   LabelNo = @cLabelNo
            AND   StorerKey = @cStorerKey
      END
      ELSE
      BEGIN
         SET @cCurLabelNo = ''
         SET @cCurLabelLine = ''

         SELECT TOP 1 @cCurLabelNo = LabelNo FROM dbo.PackDetail WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
         AND PickSlipNo = @cPickSlipNo
         AND CartonNo = @nCartonNo

         SELECT @cCurLabelLine = RIGHT( '00000' + CAST( CAST( IsNULL( MAX( LabelLine), 0) AS INT) + 1 AS NVARCHAR( 5)), 5)
         FROM PACKDETAIL WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
         AND PickSlipNo = @cPickSlipNo
         AND CartonNo = @nCartonNo

         -- need to use the existing labelno
         INSERT INTO dbo.PackDetail
            (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, QTY, Refno, AddWho, AddDate, EditWho, EditDate, DropID)
         VALUES
            (@cPickSlipNo, @nCartonNo, @cCurLabelNo, @cCurLabelLine, @cStorerKey, @cSku, @nQty,
            '', 'rdt.' + sUser_sName(), GETDATE(), 'rdt.' + sUser_sName(), GETDATE(), '')

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 135459
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'INS PACK Fail'
            GOTO RollBackTran
         END
      END
   END

   IF NOT EXISTS (SELECT 1 FROM dbo.PackInfo WITH (NOLOCK)
               WHERE PickSlipNo = @cPickSliPno
               AND CartonNo = @nCartonNo)
   BEGIN
      INSERT INTO dbo.PACKINFO
      (PickSlipNo, CartonNo, CartonType, Cube, Weight, RefNo, TrackingNo)
      VALUES
      (@cPickSlipNo, @nCartonNo, '', 0, 0, @cLabelNo, @cTrackNo)

      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 135460
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'INS PACKInf Fail'
         GOTO RollBackTran
      END
   END

   GOTO Quit
   
   RollBackTran:  
         ROLLBACK TRAN rdt_840ExtInsPack05  
   Quit:  
      WHILE @@TRANCOUNT > @nTranCount  
         COMMIT TRAN  

END

GO
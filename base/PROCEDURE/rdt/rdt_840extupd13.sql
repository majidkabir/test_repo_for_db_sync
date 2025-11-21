SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Store procedure: rdt_840ExtUpd13                                     */  
/* Purpose: Gen tracking no and update orders trackingno/Udf04          */  
/*          Calc and update PackHeader.TotCtnWeight                     */
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date        Rev  Author     Purposes                                 */  
/* 2021-05-07  1.0  James      WMS-16955. Created                       */  
/* 2021-07-26  1.1  James      Bug fix on calc weight (james01)         */
/* 2021-08-23  1.2  James      WMS-17730 Add checking on trackno if it  */
/*                             reaches end of series (james02)          */
/* 2021-10-20  1.3  James      WMS-17435 Add serialno param (james03)   */
/* 2022-08-03  1.4  James      WMS-20379 Add update tracking no based on*/
/*                             certain shipperkey (james04)             */
/************************************************************************/  
  
CREATE   PROC [RDT].[rdt_840ExtUpd13] (  
   @nMobile     INT,  
   @nFunc       INT,  
   @cLangCode   NVARCHAR( 3),  
   @nStep       INT,  
   @nInputKey   INT,  
   @cStorerkey  NVARCHAR( 15),  
   @cOrderKey   NVARCHAR( 10),  
   @cPickSlipNo NVARCHAR( 10),  
   @cTrackNo    NVARCHAR( 20),  
   @cSKU        NVARCHAR( 20),  
   @nCartonNo   INT,  
   @cSerialNo   NVARCHAR( 30),   
   @nSerialQTY  INT,    
   @nErrNo      INT           OUTPUT,  
   @cErrMsg     NVARCHAR( 20) OUTPUT  
)  
AS  
  
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nTranCount           INT
   DECLARE @nExpectedQty         INT
   DECLARE @nPackedQty           INT
   DECLARE @nSuccess             INT
   DECLARE @cUserName            NVARCHAR( 18)
   DECLARE @cTrackingNo          NVARCHAR( 20)
   DECLARE @cKeyName             NVARCHAR( 30)
   DECLARE @cPrefix              NVARCHAR( 30)
   DECLARE @cSuffix              NVARCHAR( 30)
   DECLARE @cShipperKey          NVARCHAR( 15)
   DECLARE @cFacility            NVARCHAR( 5)
   DECLARE @nTempCartonNo        INT 
   DECLARE @cTempSKU             NVARCHAR( 20) 
   DECLARE @nTempQty             INT 
   DECLARE @fSTDGROSSWGT         FLOAT = 0
   DECLARE @fWeight              FLOAT = 0
   DECLARE @fTotalWgt            FLOAT = 0
   DECLARE @fCtnWgt              FLOAT = 0
   DECLARE @cCartonType          NVARCHAR( 10) 
   DECLARE @fTotCtnWeight        FLOAT = 0
   DECLARE @curUpdCtnWgt         CURSOR
   DECLARE @curSKUWgt            CURSOR
   DECLARE @cFieldLength         NVARCHAR( 30)
   DECLARE @cType                NVARCHAR( 20)
   DECLARE @bSuccess             INT
   DECLARE @cAutoMBOLPack        NVARCHAR( 1)
   DECLARE @cExternOrderKey      NVARCHAR( 50)
   DECLARE @curUpdPackInfo       CURSOR
   
   SELECT @cUserName = UserName
   FROM rdt.RDTMOBREC WITH (NOLOCK)
   WHERE Mobile = @nMobile
   
   SET @nTranCount = @@TRANCOUNT  
  
   BEGIN TRAN  
   SAVE TRAN rdt_840ExtUpd13  
         
   IF @nStep = 4  
   BEGIN  
      IF @nInputKey = 1 
      BEGIN  
         SELECT @nExpectedQty = ISNULL(SUM(Qty), 0) FROM PickDetail WITH (NOLOCK)
         WHERE Orderkey = @cOrderkey
            AND Storerkey = @cStorerkey
            AND Status < '9'

         SELECT @nPackedQty = ISNULL(SUM(Qty), 0) FROM dbo.PackDetail WITH (NOLOCK)
         WHERE PickSlipNo = @cPickSlipNo

         IF @nExpectedQty > @nPackedQty
            GOTO Quit

         SELECT @cShipperKey = ShipperKey, 
                @cFacility = Facility,
                @cTrackingNo = TrackingNo, 
                @cExternOrderKey = ExternOrderKey
         FROM dbo.ORDERS WITH (NOLOCK)
         WHERE OrderKey = @cOrderKey
         
         IF ISNULL( @cTrackingNo, '') = ''
         BEGIN
            -- Flying High
            IF EXISTS ( SELECT 1 FROM dbo.CODELKUP WITH (NOLOCK)
                        WHERE LISTNAME = 'COURIER'
                        AND   [Description] = @cShipperKey
                        AND   Storerkey = @cStorerkey
                        AND   code2 = '')
            BEGIN
               SET @cTrackingNo = @cOrderKey
               SET @cType = 'Flying High'
               GOTO UPDATE_TRACKINGNO
            END
         
            -- LBC
            SELECT @cKeyName = code2, 
                   @cFieldLength = UDF01,
                   @cPrefix = UDF02, 
                   @cSuffix = UDF03 
            FROM dbo.CODELKUP WITH (NOLOCK)
            WHERE LISTNAME = 'COURIER'
            AND   [Description] = @cShipperKey
            AND   Storerkey = @cStorerkey
            AND   code2 <> ''
            AND   UDF04 = ''
            AND   UDF05 = @cFacility
         
            IF ISNULL( @cKeyName, '') <> ''
            BEGIN
               IF ISNULL( @cFieldLength, '') <> ''
               BEGIN
                  IF rdt.rdtIsValidQTY( @cFieldLength, 1) = 0
                  BEGIN
                     SET @nErrNo = 167551
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --nCounter Err
                     GOTO Quit
                  END
               END

               SET @nSuccess = 1
               EXECUTE dbo.nspg_getkey
                  @cKeyName
                  , 20
                  , @cTrackingNo       OUTPUT
                  , @nSuccess          OUTPUT
                  , @nErrNo            OUTPUT
                  , @cErrMsg           OUTPUT
               IF @nSuccess <> 1
               BEGIN
                  SET @nErrNo = 167552
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --nspg_getkey
                  GOTO Quit
               END

               IF ISNULL( @cFieldLength, '') <> ''
                  SET @cTrackingNo = RIGHT(@cTrackingNo, CAST( @cFieldLength AS INT))
               ELSE
                  SELECT SUBSTRING(@cTrackingNo, PATINDEX('%[^0]%', @cTrackingNo+'.'), LEN(@cTrackingNo))

               SET @cTrackingNo = RTRIM( @cPrefix) + @cTrackingNo + LTRIM( RTRIM( @cSuffix))
               SET @cType = 'LBC'
               GOTO UPDATE_TRACKINGNO
            END

            -- 2GO COD
            IF EXISTS ( SELECT 1 FROM dbo.ORDERDETAIL WITH (NOLOCK)
                        WHERE OrderKey = @cOrderKey
                        AND   Sku = 'COD'
                        AND   UserDefine02 = 'PN')
            BEGIN
               SELECT @cKeyName = code2, 
                      @cFieldLength = UDF01,
                      @cPrefix = UDF02, 
                      @cSuffix = UDF03 
               FROM dbo.CODELKUP WITH (NOLOCK)
               WHERE LISTNAME = 'COURIER'
               AND   [Description] = @cShipperKey
               AND   Storerkey = @cStorerkey
               AND   code2 <> ''
               AND   UDF04 = '1'
               AND   UDF05 = @cFacility

               IF ISNULL( @cKeyName, '') <> ''
               BEGIN
                  IF ISNULL( @cFieldLength, '') <> ''
                  BEGIN
                     IF rdt.rdtIsValidQTY( @cFieldLength, 1) = 0
                     BEGIN
                        SET @nErrNo = 167553
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --nCounter Err
                        GOTO Quit
                     END
                  END
                           
                  SET @nSuccess = 1
                  EXECUTE dbo.nspg_getkey
                     @cKeyName
                     , 20
                     , @cTrackingNo       OUTPUT
                     , @nSuccess          OUTPUT
                     , @nErrNo            OUTPUT
                     , @cErrMsg           OUTPUT
                  IF @nSuccess <> 1
                  BEGIN
                     SET @nErrNo = 162954
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --nspg_getkey
                     GOTO Quit
                  END

                  IF ISNULL( @cFieldLength, '') <> ''
                     SET @cTrackingNo = RIGHT(@cTrackingNo, CAST( @cFieldLength AS INT))
                  ELSE
                     SELECT SUBSTRING(@cTrackingNo, PATINDEX('%[^0]%', @cTrackingNo+'.'), LEN(@cTrackingNo))

                  SET @cTrackingNo = RTRIM( @cPrefix) + @cTrackingNo + LTRIM( RTRIM( @cSuffix))
                  SET @cType = '2GO COD'
                  GOTO UPDATE_TRACKINGNO
               END
            END
         
            SELECT @cKeyName = code2 
            FROM dbo.CODELKUP WITH (NOLOCK)
            WHERE LISTNAME = 'COURIER'
            AND   [Description] = @cShipperKey
            AND   Storerkey = @cStorerkey
            AND   code2 <> ''
            AND   UDF04 <> ''
            AND   UDF05 = @cFacility
         
            --2GO PickUp
            IF ISNULL( @cKeyName, '') <> ''
            BEGIN
               IF EXISTS ( SELECT 1 FROM dbo.OrderInfo WITH (NOLOCK)
                           WHERE OrderKey = @cOrderKey
                           AND   DeliveryMode LIKE '%Pick Up%')
               BEGIN
                  SELECT @cKeyName = code2, 
                         @cFieldLength = UDF01,
                         @cPrefix = UDF02, 
                         @cSuffix = UDF03 
                  FROM dbo.CODELKUP WITH (NOLOCK)
                  WHERE LISTNAME = 'COURIER'
                  AND   [Description] = @cShipperKey
                  AND   Storerkey = @cStorerkey
                  AND   code2 <> ''
                  AND   UDF04 = '3'
                  AND   UDF05 = @cFacility
            
                  IF ISNULL( @cKeyName, '') <> ''
                  BEGIN
                     IF ISNULL( @cFieldLength, '') <> ''
                     BEGIN
                        IF rdt.rdtIsValidQTY( @cFieldLength, 1) = 0
                        BEGIN
                           SET @nErrNo = 167555
                           SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --nCounter Err
                           GOTO Quit
                        END
                     END
                  
                     SET @nSuccess = 1
                     EXECUTE dbo.nspg_getkey
                        @cKeyName
                        , 20
                        , @cTrackingNo       OUTPUT
                        , @nSuccess          OUTPUT
                        , @nErrNo            OUTPUT
                        , @cErrMsg           OUTPUT
                     IF @nSuccess <> 1
                     BEGIN
                        SET @nErrNo = 162956
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --nspg_getkey
                        GOTO Quit
                     END

                     IF ISNULL( @cFieldLength, '') <> ''
                        SET @cTrackingNo = RIGHT(@cTrackingNo, CAST( @cFieldLength AS INT))
                     ELSE
                        SELECT SUBSTRING(@cTrackingNo, PATINDEX('%[^0]%', @cTrackingNo+'.'), LEN(@cTrackingNo))

                     SET @cTrackingNo = RTRIM( @cPrefix) + @cTrackingNo + LTRIM( RTRIM( @cSuffix))
                     SET @cType = '2GO PickUp'
                     GOTO UPDATE_TRACKINGNO
                  END
               END
               ELSE	-- 2GO Regular
               BEGIN
                  SELECT @cKeyName = code2, 
                         @cFieldLength = UDF01,
                         @cPrefix = UDF02, 
                         @cSuffix = UDF03 
                  FROM dbo.CODELKUP WITH (NOLOCK)
                  WHERE LISTNAME = 'COURIER'
                  AND   [Description] = @cShipperKey
                  AND   Storerkey = @cStorerkey
                  AND   code2 <> ''
                  AND   UDF04 = '2'
                  AND   UDF05 = @cFacility

                  IF ISNULL( @cKeyName, '') <> ''
                  BEGIN
                     IF ISNULL( @cFieldLength, '') <> ''
                     BEGIN
                        IF rdt.rdtIsValidQTY( @cFieldLength, 1) = 0
                        BEGIN
                           SET @nErrNo = 167557
                           SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --nCounter Err
                           GOTO Quit
                        END
                     END
                  
                     SET @nSuccess = 1
                     EXECUTE dbo.nspg_getkey
                        @cKeyName
                        , 20
                        , @cTrackingNo       OUTPUT
                        , @nSuccess          OUTPUT
                        , @nErrNo            OUTPUT
                        , @cErrMsg           OUTPUT
                     IF @nSuccess <> 1
                     BEGIN
                        SET @nErrNo = 162958
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --nspg_getkey
                        GOTO Quit
                     END

                     IF ISNULL( @cFieldLength, '') <> ''
                        SET @cTrackingNo = RIGHT(@cTrackingNo, CAST( @cFieldLength AS INT))
                     ELSE
                        SELECT SUBSTRING(@cTrackingNo, PATINDEX('%[^0]%', @cTrackingNo+'.'), LEN(@cTrackingNo))

                     SET @cTrackingNo = RTRIM( @cPrefix) + @cTrackingNo + LTRIM( RTRIM( @cSuffix))
                     SET @cType = '2GO Regular'
                     GOTO UPDATE_TRACKINGNO
                  END
               END
            END

            UPDATE_TRACKINGNO:
            BEGIN
               --INSERT INTO traceinfo (tracename, timein, Col1, Col2, Col3, Col4, Col5, Step1, Step2) VALUES
               --('rdt_840ExtUpd13', GETDATE(), @nMobile, @cTrackingNo, @cOrderKey, @cPickSlipNo, @cType, @nExpectedQty, @nPackedQty)

               -- (james02)
               IF EXISTS ( SELECT 1 FROM dbo.CODELKUP WITH (NOLOCK)
                           WHERE LISTNAME = 'YLTRACKNO'
                           AND   Long = @cTrackingNo
                           AND   Storerkey = @cStorerkey)
               BEGIN
                  SET @nErrNo = 167567
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Request TrackNo
                  GOTO RollBackTran
               END
                           
               UPDATE dbo.PackInfo SET 
                  TrackingNo = @cTrackingNo,
                  EditWho =  @cUserName,
                  EditDate = GETDATE()
               WHERE PickSlipNo = @cPickSlipNo
            
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 167559
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PackInfo Err
                  GOTO RollBackTran
               END
            
               UPDATE dbo.Orders SET 
                  TrackingNo = @cTrackingNo, 
                  UserDefine05 = @cKeyName,
                  EditWho =  @cUserName,
                  EditDate = GETDATE() 
               WHERE OrderKey = @cOrderKey
            
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 167560
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PackInfo Err
                  GOTO RollBackTran
               END
            END
         END
         /*
         IF EXISTS ( SELECT 1 FROM dbo.PickingInfo WITH (NOLOCK)
                     WHERE PickSlipNo = @cPickSlipNo
                     AND   ISNULL( ScanOutDate, '') <> '')
         BEGIN
            SET @nErrNo = 167565
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PS Scan Out
            GOTO RollBackTran
         END

         IF EXISTS ( SELECT 1 FROM dbo.PackHeader WITH (NOLOCK)
                     WHERE PickSlipNo = @cPickSlipNo
                     AND   STATUS = '9')
         BEGIN
            SET @nErrNo = 167566
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PS Pack Cfm
            GOTO RollBackTran
         END
         */
         SET @curUpdCtnWgt = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
         SELECT CartonNo
         FROM dbo.PACKDetail WITH (NOLOCK)
         WHERE PickSlipNo = @cPickSlipNo
         GROUP BY CartonNo
         ORDER BY CartonNo
         OPEN @curUpdCtnWgt
         FETCH NEXT FROM @curUpdCtnWgt INTO @nTempCartonNo
         WHILE @@FETCH_STATUS = 0
         BEGIN
            SELECT @cCartonType = CartonType 
            FROM dbo.PackInfo WITH (NOLOCK)
            WHERE PickSlipNo = @cPickSlipNo
            AND   CartonNo = @nTempCartonNo

            SELECT @fCtnWgt = CZ.CartonWeight 
            FROM CARTONIZATION CZ WITH (NOLOCK)
            JOIN dbo.STORER ST WITH (NOLOCK) ON ( CZ.CartonizationGroup = ST.CartonGroup)
            WHERE CZ.CartonType = @cCartonType
            AND   ST.StorerKey = @cStorerkey

            SET @fTotalWgt = 0
            SET @curSKUWgt = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
            SELECT SKU, SUM( Qty)
            FROM dbo.PACKDetail WITH (NOLOCK)
            WHERE PickSlipNo = @cPickSlipNo
            AND   CartonNo = @nTempCartonNo
            GROUP BY SKU
            OPEN @curSKUWgt
            FETCH NEXT FROM @curSKUWgt INTO @cTempSKU, @nTempQty
            WHILE @@FETCH_STATUS = 0
            BEGIN
               SELECT @fSTDGROSSWGT = STDGROSSWGT, 
                      @fWeight = [Weight] 
               FROM dbo.SKU WITH (NOLOCK)
               WHERE StorerKey = @cStorerkey
               AND   Sku = @cTempSKU
      
               IF ISNULL( @fWeight, 0) = 0
                  SET @fTotalWgt = @fTotalWgt + (@fSTDGROSSWGT * @nTempQty)
               ELSE
                  SET @fTotalWgt = @fTotalWgt + (@fWeight * @nTempQty)

               FETCH NEXT FROM @curSKUWgt INTO @cTempSKU, @nTempQty
            END
            CLOSE @curSKUWgt
            DEALLOCATE @curSKUWgt
      
            SET @fTotalWgt = @fTotalWgt + @fCtnWgt

            UPDATE dbo.PackInfo SET 
               [Weight] = @fTotalWgt 
            WHERE PickSlipNo = @cPickSlipNo 
            AND   CartonNo = @nTempCartonNo

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 167561
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD CtnWgt Err
               GOTO RollBackTran
            END

            FETCH NEXT FROM @curUpdCtnWgt INTO @nTempCartonNo
         END
         
         -- (james04)
         IF EXISTS ( SELECT 1 FROM dbo.CODELKUP WITH (NOLOCK)
                     WHERE LISTNAME = 'COURIER'
                     AND   [Description] = @cShipperKey
                     AND   Storerkey = @cStorerkey
                     AND   code2 = '')
         BEGIN
            SET @curUpdPackInfo = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
            SELECT CartonNo
            FROM dbo.PackInfo WITH (NOLOCK)
            WHERE PickSlipNo = @cPickSlipNo
            ORDER BY 1
            OPEN @curUpdPackInfo
            FETCH NEXT FROM @curUpdPackInfo INTO @nTempCartonNo
            WHILE @@FETCH_STATUS = 0
            BEGIN
            	UPDATE dbo.PackInfo SET 
            	   TrackingNo = @cExternOrderKey,
            	   EditWho = SUSER_SNAME(),
            	   EditDate = GETDATE()
            	WHERE PickSlipNo = @cPickSlipNo
            	AND   CartonNo = @nTempCartonNo
            	
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 167568
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPDPackInfoErr
                  GOTO RollBackTran
               END
               
            	FETCH NEXT FROM @curUpdPackInfo INTO @nTempCartonNo
            END
            
            UPDATE dbo.ORDERS SET 
            	TrackingNo = @cExternOrderKey,
            	EditWho = SUSER_SNAME(),
            	EditDate = GETDATE()
            WHERE OrderKey = @cOrderKey

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 167569
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD Orders Err
               GOTO RollBackTran
            END
         END
         
         /*
         UPDATE dbo.PackHeader SET 
            TotCtnWeight = @fTotalWgt
         WHERE PickSlipNo = @cPickSlipNo

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 167561
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD CtnWgt Err
            GOTO RollBackTran
         END
         INSERT INTO traceinfo (tracename, TimeIn, Col1, Col2) VALUES ('12345', GETDATE(), @cPickSlipNo, @fTotalWgt)*/
         SET @nErrNo = 0
         EXEC nspGetRight  
               @c_Facility   = @cFacility    
            ,  @c_StorerKey  = @cStorerKey   
            ,  @c_sku        = ''         
            ,  @c_ConfigKey  = 'AutoMBOLPack'   
            ,  @b_Success    = @bSuccess             OUTPUT  
            ,  @c_authority  = @cAutoMBOLPack        OUTPUT   
            ,  @n_err        = @nErrNo               OUTPUT  
            ,  @c_errmsg     = @cErrMsg              OUTPUT  
  
         IF @nErrNo <> 0   
         BEGIN  
            SET @nErrNo = 167562  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- GetRightFail       
            GOTO RollBackTran    
         END  
  
         IF @cAutoMBOLPack = '1'  
         BEGIN  
            SET @nErrNo = 0
            EXEC dbo.isp_QCmd_SubmitAutoMbolPack  
               @c_PickSlipNo= @cPickSlipNo  
            , @b_Success   = @bSuccess    OUTPUT      
            , @n_Err       = @nErrNo      OUTPUT      
            , @c_ErrMsg    = @cErrMsg     OUTPUT   
           
            IF @nErrNo <> 0   
            BEGIN  
               SET @nErrNo = 167563  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- AutoMBOLPack       
               GOTO RollBackTran    
            END     
         END  

         IF EXISTS ( SELECT 1 FROM dbo.PackHeader WITH (NOLOCK) 
                     WHERE PickSlipNo = @cPickSlipNo
                     AND STATUS = '0')
         BEGIN
            UPDATE dbo.PackHeader SET
               STATUS = '9'
            WHERE PickSlipNo = @cPickSlipNo

            IF @@ERROR <> 0
            BEGIN        
               SET @nErrNo = 167564        
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ConfPackFail    
               GOTO RollBackTran  
            END 
         END
      END
   END  



   GOTO Quit  
  
   RollBackTran:  
         ROLLBACK TRAN rdt_840ExtUpd13  
   Quit:  
      WHILE @@TRANCOUNT > @nTranCount  
         COMMIT TRAN  

   Fail:  

GO
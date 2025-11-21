SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_HnMExtendedUpd03                                */
/* Purpose: PPA Update                                                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2014-06-27 1.0  James      SOS#300492. Created                       */
/* 2016-12-14 1.1  James      Add scaninlog (james01)                   */
/* 2017-01-06 1.2  James      Exclude move orders type from creating    */ 
/*                            scaninlog record (james02)                */
/* 2018-01-25 1.3  James      WMS3352-Add                               */   
/*                            isp_AssignPackLabelToOrderByLoad (james03)*/  
/* 2019-05-13 1.4  James      WMS9005-Add print delive note (james04)   */ 
/* 2020-09-05 1.5  James      WMS-15010 Add AutoMBOLPack (james05)      */
/* 2021-01-07 1.6  James      Addhoc fix. Do not packcfm if need capture*/
/*                            packinfo to prevent ttlcnt not update     */
/*                            correctly (james06)                       */
/* 2021-04-01 1.7 YeeKung    WMS-16717 Add serialno and serialqty      */
/*                            Params (yeekung01)                        */
/************************************************************************/

CREATE PROC [RDT].[rdt_HnMExtendedUpd03] (
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

   DECLARE @nTranCount     INT, 
           @nCtnNo         INT, 
           @nExpectedQty   INT, 
           @nPackedQty     INT, 
           @nCtnCount      INT, 
           @cCheckDigit    NVARCHAR( 1), 
           @cTempBarcode   NVARCHAR( 20), 
           @cOrderBoxBarcode  NVARCHAR( 20), 
           @cPackByTrackNotUpdUPC   NVARCHAR( 1), 
           @cOrdType       NVARCHAR( 10),  -- (james02)
           @cDocType       NVARCHAR( 10),  -- (james04)
           @cPreDelNote    NVARCHAR( 10),  -- (james04)
           @cFacility      NVARCHAR( 5),   -- (james04)
           @cPaperPrinter  NVARCHAR( 10),  -- (james04)
           @cAutoMBOLPack  NVARCHAR( 1),   -- (james05)
           @cCapturePackInfo NVARCHAR( 10)
           
   DECLARE @bSuccess             INT, 
           @cAuthority_ScanInLog NVARCHAR( 1)

   SELECT @cPaperPrinter = Printer_Paper, 
          @cFacility = Facility  
   FROM RDT.RDTMOBREC WITH (NOLOCK)   
   WHERE Mobile = @nMobile  

   SET @nTranCount = @@TRANCOUNT    

   BEGIN TRAN    
   SAVE TRAN rdt_HnMExtendedUpd03    
           
   IF @nStep = 1
   BEGIN 
      IF ISNULL( @cPickSlipNo, '') = ''
      BEGIN
         SET @nErrNo = 95401
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'NO PKSLIP'
         GOTO RollBackTran
      END

      IF ISNULL( @cOrderKey, '') = ''
      BEGIN
         SELECT @cOrderKey = OrderKey
         FROM dbo.PickHeader WITH (NOLOCK)
         WHERE PickHeaderKey = @cPickSlipNo

         IF ISNULL( @cOrderKey, '') = ''
         BEGIN
            SET @nErrNo = 95402
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'NO ORDERKEY'
            GOTO RollBackTran
         END
      END

      -- (james02)
      SET @cOrdType = ''
      SET @cDocType = ''
      SELECT @cOrdType = [Type],
             @cDocType = DocType 
      FROM dbo.Orders WITH (NOLOCK)
      WHERE OrderKey = @cOrderKey

      UPDATE dbo.ORDERS WITH (ROWLOCK) SET 
         STATUS = '3',
         EditWho = sUser_sName(),
         EditDate = GetDate()
      WHERE OrderKey = @cOrderKey
      AND Status < '3'

      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 95403
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Upd OdHdr Fail'
         GOTO RollBackTran
      END

      UPDATE dbo.ORDERDETAIL WITH (ROWLOCK) SET 
         STATUS = '3',
         EditWho = sUser_sName(),
         EditDate = GetDate(),
         TrafficCop = NULL
      WHERE OrderKey = @cOrderKey
      AND   STATUS < '3'

      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 95404
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Upd OdDtl Fail'
         GOTO RollBackTran
      END

      UPDATE dbo.LOADPLANDETAIL WITH (ROWLOCK) SET 
         STATUS = '3',
         EditWho = sUser_sName(),
         EditDate = GetDate(),
         TrafficCop = NULL
      WHERE OrderKey = @cOrderKey
      AND STATUS < '5'

      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 95405
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Upd LpDtl Fail'
         GOTO RollBackTran
      END

      -- Check if pickslip already scan in and not yet insert transmitlog3 then start insert
      -- (if orders.doctype = 'E' then scan in will not fire trigger and hence no transmitlog3 record)
      IF EXISTS ( SELECT 1 FROM dbo.PickingInfo WITH (NOLOCK) 
                  WHERE PickSlipNo = @cPickSlipNo
                  AND   ScanInDate IS NOT NULL
                  AND   TrafficCop = 'U') 
      AND @cOrdType NOT IN ( 'R','S')  -- Move orders no need scaninlog (james02)
      BEGIN
         IF NOT EXISTS ( SELECT 1 FROM dbo.TransmitLog3 WITH (NOLOCK) 
                         WHERE TableName = 'ScanInLog'
                         AND   Key1 = @cOrderKey
                         AND   Key3 = @cStorerkey)
         BEGIN
            EXECUTE dbo.nspGetRight 
               @c_Facility    = '',
               @c_StorerKey   = @cStorerKey, 
               @c_SKU         = '', 
               @c_ConfigKey   = 'ScanInLog', 
               @b_success     = @bSuccess                OUTPUT,
               @c_authority   = @cAuthority_ScanInLog    OUTPUT,
               @n_err         = @nErrNo                  OUTPUT,
               @c_errmsg      = @cErrmsg                 OUTPUT

            IF @bSuccess <> 1
            BEGIN
               SET @nErrNo = 95406
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'nspGetRightErr'
               GOTO RollBackTran
            End

            IF @cAuthority_ScanInLog = '1'
            BEGIN
               EXEC dbo.ispGenTransmitLog3 
                  @c_TableName      = 'ScanInLog', 
                  @c_Key1           = @cOrderKey, 
                  @c_Key2           = '' , 
                  @c_Key3           = @cStorerKey, 
                  @c_TransmitBatch  = '', 
                  @b_success        = @bSuccess    OUTPUT, 
                  @n_err            = @nErrNo      OUTPUT, 
                  @c_errmsg         = @cErrMsg     OUTPUT

               IF @bSuccess <> 1
               BEGIN
                  SET @nErrNo = 95407
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'GenTLog3 Fail'
                  GOTO RollBackTran
               End
            END
         END 
      END

      SET @cPreDelNote = rdt.RDTGetConfig( @nFunc, 'PreDelNote', @cStorerKey)
      IF @cPreDelNote = '0'
         SET @cPreDelNote = ''   

      IF @cDocType = 'E' AND @cPreDelNote <> ''
      BEGIN  
         DECLARE @tDELNOTES AS VariableTable  
         INSERT INTO @tDELNOTES (Variable, Value) VALUES ( '@cOrderKey',    @cOrderKey)  
         INSERT INTO @tDELNOTES (Variable, Value) VALUES ( '@cLoadKey',     '')  
         INSERT INTO @tDELNOTES (Variable, Value) VALUES ( '@cType',        '')  
  
         -- Print label  
         EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerkey, '', @cPaperPrinter,   
            @cPreDelNote,  -- Report type  
            @tDELNOTES,    -- Report params  
            'rdt_HnMExtendedUpd03',   
            @nErrNo     OUTPUT,  
            @cErrMsg    OUTPUT   
      END  
   END

   IF @nStep = 3
   BEGIN
      SET @cPackByTrackNotUpdUPC = ''
      SET @cPackByTrackNotUpdUPC = rdt.RDTGetConfig( @nFunc, 'PackByTrackNotUpdUPC', @cStorerKey)

      IF ISNULL( @cPickSlipNo, '') = ''
         SELECT @cPickSlipNo = PickHeaderKey 
         FROM dbo.PickHeader WITH (NOLOCK) 
         WHERE OrderKey = @cOrderkey


      -- 1 orders 1 tracking no    
      -- discrete pickslip, 1 ordes 1 pickslipno    
      SET @nExpectedQty = 0    
      SELECT @nExpectedQty = ISNULL(SUM(Qty), 0) FROM PickDetail WITH (NOLOCK)    
      WHERE Orderkey = @cOrderkey    
         AND Storerkey = @cStorerkey    
         AND Status < '9'    
 
      SET @nPackedQty = 0    
      SELECT @nPackedQty = ISNULL(SUM(Qty), 0) FROM dbo.PackDetail WITH (NOLOCK)    
      WHERE PickSlipNo = @cPickSlipNo    
         AND Storerkey = @cStorerkey    

      -- all SKU and qty has been packed, Update the carton barcode to the PackDetail.UPC for each carton    
      IF @nExpectedQty = @nPackedQty    
      BEGIN    
         SELECT @nCtnCount = ISNULL(COUNT( DISTINCT CartonNo), 0)    
         FROM dbo.PackDetail WITH ( NOLOCK)     
         WHERE Storerkey = @cStorerKey    
            AND PickSlipNo = @cPickSlipNo    
          
         IF @nCtnCount > 0    
         BEGIN    
            DECLARE CUR_PACKDTL CURSOR LOCAL READ_ONLY FAST_FORWARD FOR     
            SELECT DISTINCT CartonNo FROM dbo.PackDetail WITH (NOLOCK)    
            WHERE Storerkey = @cStorerKey    
               AND PickSlipNo = @cPickSlipNo    
            ORDER BY CartonNo    
            OPEN CUR_PACKDTL    
            FETCH NEXT FROM CUR_PACKDTL INTO @nCtnNo    
            WHILE @@FETCH_STATUS <> -1    
            BEGIN    
               -- Generateorder box barcode    
               SET @cTempBarcode = ''    
               SET @cTempBarcode = '021'     
               SET @cTempBarcode = RTRIM(@cTempBarcode) + RTRIM(@cOrderKey)     
               SET @cTempBarcode = RTRIM(@cTempBarcode) + RIGHT( '00' + CAST( @nCtnNo AS NVARCHAR( 2)), 2)    
               SET @cTempBarcode = RTRIM(@cTempBarcode) + RIGHT( '000' + CAST( @nCtnCount AS NVARCHAR( 3)), 3)     
               SET @cTempBarcode = RTRIM(@cTempBarcode) + '1'    
               SET @cCheckDigit = dbo.fnc_CalcCheckDigit_M10(RTRIM(@cTempBarcode), 0)    
               SET @cOrderBoxBarcode = RTRIM(@cTempBarcode) + @cCheckDigit    
                
               UPDATE dbo.PackDetail WITH (ROWLOCK) SET     
                  UPC = CASE WHEN @cPackByTrackNotUpdUPC = '1' THEN UPC ELSE @cOrderBoxBarcode END,     
                  ArchiveCop = NULL,     
                  EditWho = 'rdt.' + sUser_sName(),     
                  EditDate = GETDATE()     
               WHERE PickSlipNo = @cPickSlipNo    
                  AND CartonNo = @nCtnNo    
    
               IF @@ERROR <> 0    
               BEGIN 
                  SET @nErrNo = 95408
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Upd Pack Fail'

                  CLOSE CUR_PACKDTL    
                  DEALLOCATE CUR_PACKDTL    

                  GOTO RollBackTran  
               END    

               FETCH NEXT FROM CUR_PACKDTL INTO @nCtnNo    
            END    
            CLOSE CUR_PACKDTL    
            DEALLOCATE CUR_PACKDTL    

            -- (james03)  
            -- If it is not Sales type order then no need update pickdetail.dropid  
            IF NOT EXISTS ( SELECT 1 FROM dbo.CODELKUP C WITH (NOLOCK)   
                   JOIN dbo.Orders O WITH (NOLOCK) ON (C.Code = O.Type AND C.StorerKey = O.StorerKey)  
                   WHERE C.ListName = 'HMORDTYPE'  
                   AND   C.Short = 'S'  
                   AND   O.OrderKey = @cOrderkey  
                   AND   O.StorerKey = @cStorerKey)  
            BEGIN  
               EXEC [dbo].[isp_AssignPackLabelToOrderByLoad]  
                  @c_Pickslipno  = @cPickSlipNo,  
                  @b_Success     = @bSuccess    OUTPUT,  
                  @n_err         = @nErrNo      OUTPUT,  
                  @c_errmsg      = @cErrMsg     OUTPUT  
  
               IF @bSuccess <> 1      
               BEGIN      
                  SET @nErrNo = 95410      
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Assign Lbl Err'      
                  GOTO RollBackTran      
               END      
            END  

            IF EXISTS ( SELECT 1 FROM dbo.CODELKUP C WITH (NOLOCK)
                        JOIN dbo.Orders O WITH (NOLOCK) ON (C.Code = O.[Type] AND C.StorerKey = O.StorerKey)  
                        WHERE C.ListName = 'HMORDTYPE'
                        AND   C.UDF01 = 'M'
                        AND   O.OrderKey = @cOrderkey
                        AND   O.StorerKey = @cStorerKey)
               SET @cCapturePackInfo = '1'
            ELSE
               SET @cCapturePackInfo = ''

            IF @cCapturePackInfo = ''  -- (james06)
            BEGIN
               -- (james05)
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
                  SET @nErrNo = 95411  
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
                     SET @nErrNo = 95412  
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- AutoMBOLPack       
                     GOTO RollBackTran    
                  END     
               END  
            
               -- Trigger pack confirm    
               UPDATE dbo.PackHeader WITH (ROWLOCK) SET     
                  STATUS = '9',     
                  EditWho = 'rdt.' + sUser_sName(),    
                  EditDate = GETDATE()    
               WHERE PickSlipNo = @cPickSlipNo    
 
               IF @@ERROR <> 0    
               BEGIN
                  SET @nErrNo = 95409
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Cfm Pack Fail'
                  GOTO RollBackTran  
               END
            END
         END
      END
   END   --Step 3

   GOTO Quit
   
   RollBackTran:  
         ROLLBACK TRAN rdt_HnMExtendedUpd03  
   Quit:  
      WHILE @@TRANCOUNT > @nTranCount  
         COMMIT TRAN  

GO
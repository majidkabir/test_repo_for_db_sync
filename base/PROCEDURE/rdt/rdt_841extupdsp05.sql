SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

  
/************************************************************************/      
/* Store procedure: rdt_841ExtUpdSP05                                   */      
/* Copyright      : LF                                                  */      
/*                                                                      */      
/* Purpose: Ecomm Update SP                                             */      
/*                                                                      */      
/* Modifications log:                                                   */      
/* Date        Rev  Author   Purposes                                   */      
/* 2018-09-13  1.0  ChewKP   WMS-6213 Created                           */      
/* 2019-10-23  1.1  James    WMS-10896 Add FragileCHK (james01)         */  
/* 2020-03-25  1.2  James    WMS-12662 Add new VAS display (james02)    */
/* 2020-05-19  1.3  YeeKung  WMS-13131 Add Cartontype param(yeekung01)  */   
/* 2020-09-05  1.4  James    WMS-15010 Add AutoMBOLPack (james02)       */
/* 2021-04-01  1.5  YeeKung  WMS-16718 Add serialno and serialqty       */
/*                           Params (yeekung02)                         */
/* 2021-07-27  1.6  Chermain WMS-17410 Add VariableTable Param (cc01)   */
/************************************************************************/      
    
CREATE PROC [RDT].[rdt_841ExtUpdSP05] (      
   @nMobile       INT,      
   @nFunc         INT,      
   @cLangCode     NVARCHAR( 3),      
   @cUserName     NVARCHAR( 15),      
   @cFacility     NVARCHAR( 5),      
   @cStorerKey    NVARCHAR( 15),      
   @cDropID       NVARCHAR( 20),      
   @cSKU          NVARCHAR( 20),      
   @nStep         INT,      
   @cPickslipNo   NVARCHAR( 10),      
   @cPrevOrderkey NVARCHAR(10),      
   @cTrackNo      NVARCHAR( 20),      
   @cTrackNoFlag  NVARCHAR(1)   OUTPUT,      
   @cOrderKeyOut  NVARCHAR(10)  OUTPUT,      
   @nErrNo        INT           OUTPUT,      
   @cErrMsg       NVARCHAR( 20) OUTPUT,  -- screen limitation, 20 char max  
   @cCartonType   NVARCHAR( 20) ='',  --(yeekung01)  
   @cSerialNo     NVARCHAR( 30), 
   @nSerialQTY    INT,
   @tExtUpd       VariableTable READONLY     
) AS      
BEGIN      
   SET NOCOUNT ON      
   SET ANSI_NULLS OFF      
   SET QUOTED_IDENTIFIER OFF      
   SET CONCAT_NULL_YIELDS_NULL OFF      
      
   DECLARE @nTranCount        INT      
          ,@nSUM_PackQTY      INT      
          ,@nSUM_PickQTY      INT      
          ,@cOrderKey         NVARCHAR(10)      
          ,@bsuccess          INT      
          ,@nCartonNo         INT      
          ,@cLabelLine        NVARCHAR( 5)      
          ,@cLabelNo          NVARCHAR(20)      
          ,@cPackSku          NVARCHAR(20)      
          ,@nPackQty          INT      
          ,@nTotalPackQty     INT      
          ,@nTotalPickQty     INT      
          ,@nTTL_PickedQty    INT      
          ,@nTTL_PackedQty    INT      
          ,@cDropIDType       NVARCHAR(10)      
          ,@cGenTrackNoSP     NVARCHAR(30)      
          ,@cGenLabelNoSP     NVARCHAR(30)      
          ,@cExecStatements   NVARCHAR(4000)      
          ,@cExecArguments    NVARCHAR(4000)      
          ,@cRDTBartenderSP   NVARCHAR(30)      
          ,@cLabelPrinter     NVARCHAR(10)      
          ,@cLoadKey          NVARCHAR(10)      
          ,@cPaperPrinter     NVARCHAR(10)      
          ,@cDataWindow       NVARCHAR(50)      
          ,@cTargetDB         NVARCHAR(20)      
          ,@cOrderType        NVARCHAR(10)      
          ,@cShipperKey       NVARCHAR(10)      
          ,@cWCS              NVARCHAR(1)      
          ,@cPrinter02        NVARCHAR(10)      
          ,@cBrand01          NVARCHAR(10)      
          ,@cBrand02          NVARCHAR(10)      
          ,@cPrinter01        NVARCHAR(10)      
          ,@cSectionKey       NVARCHAR(10)      
          ,@cSOStatus         NVARCHAR(10)      
          ,@cGenPackDetail    NVARCHAR(1)      
          ,@b_success         INT      
          ,@cShowTrackNoScn   NVARCHAR(1)      
          ,@nRowRef           INT      
          ,@cPickDetailKey    NVARCHAR(10)    
          ,@cBarcode          NVARCHAR(60)     
          ,@cDecodeLabelNo    NVARCHAR(20)    
          ,@cPackSwapLot_SP   NVARCHAR(20)     
          ,@cLottable02       NVARCHAR(18)    
          ,@cLoc              NVARCHAR(10)     
          ,@cID               NVARCHAR(18)     
          ,@cLottable01       NVARCHAR(18)     
          ,@cLottable03       NVARCHAR(18)     
          ,@dLottable04       DATETIME    
          ,@dLottable05       DATETIME    
          ,@cSQL              NVARCHAR(1000)         
          ,@cSQLParam         NVARCHAR(1000)          
          ,@cType             NVARCHAR(10)     
          ,@cAutoMBOLPack     NVARCHAR( 1)   -- (james02)
          --,@cBarCode          NVARCHAR(60)     
    
              
              
    
    
   DECLARE @c_oFieled01 NVARCHAR(20), @c_oFieled02 NVARCHAR(20),      
   @c_oFieled03 NVARCHAR(20), @c_oFieled04 NVARCHAR(20),      
   @c_oFieled05 NVARCHAR(20), @c_oFieled06 NVARCHAR(20),      
   @c_oFieled07 NVARCHAR(20), @c_oFieled08 NVARCHAR(20),      
   @c_oFieled09 NVARCHAR(20), @c_oFieled10 NVARCHAR(20)     
    
   DECLARE @tOutBoundList AS VariableTable                
   DECLARE @tOutBoundList2 AS VariableTable             
  
   DECLARE  @nFragileChk   INT  
   DECLARE  @nElectronic   INT  
  
   DECLARE @cErrMsg01        NVARCHAR( 20),  
           @cErrMsg02        NVARCHAR( 20),  
           @cErrMsg03        NVARCHAR( 20),       
           @cErrMsg04        NVARCHAR( 20),  
           @cErrMsg05        NVARCHAR( 20)  
      
   SET @nErrNo   = 0      
   SET @cErrMsg  = ''      
   SET @cWCS     = ''      
   SET @cTrackNoFlag = '0'      
   SET @cOrderKeyOut = ''      
   SET @cBrand01     = ''      
   SET @cBrand02     = ''      
   SET @cPrinter02   = ''      
   SET @cPrinter01   = ''      
   SET @cSectionKey  = ''      
   SET @cShowTrackNoScn = ''      
      
   SET @cDecodeLabelNo = rdt.RDTGetConfig( @nFunc, 'DecodeLabelNo', @cStorerKey)    
   IF @cDecodeLabelNo = '0'    
      SET @cDecodeLabelNo = ''    
      
      
   SET @nTranCount = @@TRANCOUNT      
      
   BEGIN TRAN      
   SAVE TRAN rdt_841ExtUpdSP05      
      
      
   SELECT @cLabelPrinter = Printer      
         ,@cPaperPrinter = Printer_Paper      
         ,@cBarCode      = I_Field04    
   FROM rdt.rdtMobRec WITH (NOLOCK)      
   WHERE Mobile = @nMobile      
      
   SET @cGenPackDetail  = ''      
   SET @cGenPackDetail = rdt.RDTGetConfig( @nFunc, 'GenPackDetail', @cStorerkey)      
      
   IF @nStep = 2      
   BEGIN      
      --SET @cGenLabelNoSP = rdt.RDTGetConfig( @nFunc, 'GenLabelNo', @cStorerkey)      
    
      IF ISNULL(@cDecodeLabelNo,'')  <> ''    
      BEGIN    
    
            --SET @c_oFieled09 = @cDropID    
            --SET @c_oFieled10 = @cTaskDetailKey    
    
            SET @cErrMsg = ''    
            SET @nErrNo = 0    
            EXEC dbo.ispLabelNo_Decoding_Wrapper    
                @c_SPName     = @cDecodeLabelNo    
               ,@c_LabelNo    = @cBarcode    
               ,@c_Storerkey  = @cStorerKey    
               ,@c_ReceiptKey = ''    
               ,@c_POKey      = ''    
               ,@c_LangCode   = @cLangCode    
               ,@c_oFieled01  = @c_oFieled01 OUTPUT   -- SKU    
               ,@c_oFieled02  = @c_oFieled02 OUTPUT   -- STYLE    
               ,@c_oFieled03  = @c_oFieled03 OUTPUT   -- COLOR    
               ,@c_oFieled04  = @c_oFieled04 OUTPUT   -- SIZE    
               ,@c_oFieled05  = @c_oFieled05 OUTPUT   -- QTY    
               ,@c_oFieled06  = @c_oFieled06 OUTPUT   -- LOT    
               ,@c_oFieled07  = @c_oFieled07 OUTPUT   -- Label Type    
               ,@c_oFieled08  = @c_oFieled08 OUTPUT   -- UCC    
               ,@c_oFieled09  = @c_oFieled09 OUTPUT    
               ,@c_oFieled10  = @c_oFieled10 OUTPUT    
               ,@b_Success    = @b_Success   OUTPUT    
               ,@n_ErrNo      = @nErrNo      OUTPUT    
               ,@c_ErrMsg     = @cErrMsg     OUTPUT    
    
            IF @nErrNo <> 0    
               GOTO RollBackTran    
    
            --SET @cSKU  = ISNULL( @c_oFieled01, '')    
            SET @cLottable02  =  ISNULL( @c_oFieled02, '')    
            --SET @nUCCQTY = CAST( ISNULL( @c_oFieled05, '') AS INT)    
            --SET @cUCC    = ISNULL( @c_oFieled08, '')    
         END    
      
      -- check if sku exists in tote      
      IF NOT EXISTS (SELECT 1 FROM rdt.rdtECOMMLog ECOMM WITH (NOLOCK)      
                      WHERE ToteNo = @cDropID      
                      AND SKU = @cSKU      
                      AND AddWho = @cUserName      
           AND Status IN ('0', '1') )      
      BEGIN      
          SET @nErrNo = 129151      
          SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SKuNotIntote      
          GOTO RollBackTran      
      END      
      
          
      
      
      
      IF NOT EXISTS (SELECT 1 FROM rdt.rdtECOMMLog ECOMM WITH (NOLOCK)      
                      WHERE ToteNo = @cDropID      
                      AND ExpectedQty > ScannedQty      
                      AND Status < '5'      
                      AND Orderkey = @cPrevOrderkey      
                      AND AddWho = @cUserName)      
      BEGIN      
          SET @cOrderkey = ''      
      END      
      ELSE      
      BEGIN      
          SET @cOrderkey = @cPrevOrderkey      
      END      
      
      
      
      IF ISNULL(RTRIM(@cOrderkey),'') = ''      
      BEGIN      
         -- processing new order      
         SELECT @cOrderkey   = MIN(RTRIM(ISNULL(Orderkey,'')))      
         FROM rdt.rdtECOMMLog WITH (NOLOCK)      
         WHERE ToteNo = @cDropID      
         AND   Status IN ('0', '1')      
         AND   Sku = @cSKU      
         AND   AddWho = @cUserName      
      
      END      
      ELSE      
      BEGIN      
         IF NOT EXISTS (SELECT 1 FROM rdt.rdtECOMMLog ECOMM WITH (NOLOCK)      
                        WHERE ToteNo = @cDropID      
                        AND Orderkey = @cOrderkey      
                        AND SKU = @cSKU      
                        AND Status < '5'      
                        AND AddWho = @cUserName)      
         BEGIN      
            SET @nErrNo = 129152      
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SKUNotInOrder      
            GOTO RollBackTran      
         END      
      END      
      
      IF NOT EXISTS (SELECT 1 FROM rdt.rdtECOMMLog ECOMM WITH (NOLOCK)      
                     WHERE ToteNo = @cDropID      
                     AND Orderkey = @cOrderkey      
                     AND SKU = @cSKU      
                     AND ExpectedQty > ScannedQty      
                     AND Status < '5'      
                     AND AddWho = @cUserName)      
      BEGIN      
         SET @nErrNo = 129153      
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --QtyExceeded      
         GOTO RollBackTran      
      END      
      
      
      
      DECLARE C_ECOMMLOG1 CURSOR LOCAL FAST_FORWARD READ_ONLY FOR      
      SELECT RowRef      
      FROM rdt.rdtEcommLog WITH (NOLOCK)      
      WHERE ToteNo      = @cDropID      
      AND   Orderkey    = @cOrderkey      
      AND   Sku         = @cSku      
      AND   Status      < '5'      
      AND   AddWho = @cUserName      
      ORDER BY RowRef      
      
      OPEN C_ECOMMLOG1      
      FETCH NEXT FROM C_ECOMMLOG1 INTO  @nRowRef      
      WHILE (@@FETCH_STATUS <> -1)      
      BEGIN      
         /***************************      
         UPDATE rdtECOMMLog      
         ****************************/      
         UPDATE RDT.rdtECOMMLog WITH (ROWLOCK)      
         SET   ScannedQty  = ScannedQty + 1,      
               Status      = '1'    -- in progress      
         WHERE RowRef = @nRowRef      
      
         IF @@ERROR <> 0      
         BEGIN      
            SET @nErrNo = 129154      
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdEcommFail'      
            GOTO RollBackTran      
         END      
      
         FETCH NEXT FROM C_ECOMMLOG1 INTO  @nRowRef      
      
      END      
      CLOSE C_ECOMMLOG1      
      DEALLOCATE C_ECOMMLOG1      
      
      
      IF ISNULL(RTRIM(@cPickSlipno) ,'')=''      
      BEGIN      
          EXECUTE dbo.nspg_GetKey      
          'PICKSLIP',      
          9,      
          @cPickslipno OUTPUT,      
          @b_success OUTPUT,      
          @nErrNo OUTPUT,      
          @cErrMsg OUTPUT      
      
          IF @nErrNo<>0      
          BEGIN      
              SET @nErrNo = 129155      
              SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'GetDetKeyFail'      
              GOTO RollBackTran      
      
          END      
      
          SELECT @cPickslipno = 'P'+@cPickslipno      
      
      
      
          INSERT INTO dbo.PICKHEADER      
            (      
              PickHeaderKey      
             ,ExternOrderKey      
             ,Orderkey      
             ,PickType      
             ,Zone      
             ,TrafficCop      
            )      
          VALUES      
            (      
              @cPickslipno      
             ,''      
             ,@cOrderKey      
             ,'0'      
             ,'D'      
             ,''      
            )      
      
          IF @@ERROR<>0      
          BEGIN      
              SET @nErrNo = 129156      
              SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InstPKHdrFail '      
              GOTO RollBackTran      
      
          END      
      
      
      END --ISNULL(@cPickSlipno, '') = ''      
          
          
      IF NOT EXISTS ( SELECT 1      
                      FROM   dbo.PickingInfo WITH (NOLOCK)      
                      WHERE  PickSlipNo = @cPickSlipNo          )      
      BEGIN      
          INSERT INTO dbo.PickingInfo      
            (      
              PickSlipNo      
             ,ScanInDate      
             ,PickerID      
             ,ScanOutDate      
             ,AddWho      
             ,TrafficCop     
            )      
          VALUES      
            (      
              @cPickSlipNo      
             ,GETDATE()      
             ,@cUserName      
             ,NULL      
             ,@cUserName      
             ,''    
            )      
      
          IF @@ERROR<>0      
          BEGIN      
               SET @nErrNo = 129157      
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'ScanInFail'      
               GOTO RollBackTran      
          END      
      END      
      
      
      
      -- Reuse SP from Function 840 configkey = PackSwapLot_SP    
      SET @cPackSwapLot_SP = rdt.RDTGetConfig( @nFunc, 'PackSwapLot_SP', @cStorerKey)      
          
       
          
      SET @nCartonNo = 0     
      SET @cLoc = ''    
      SET @cID = ''     
      SET @cLottable01 = ''    
      SET @cLottable03 = ''    
      SET @dLottable04 = NULL    
      SET @dLottable05 = NULL    
    
          
      IF ISNULL(@cPackSwapLot_SP, '') NOT IN ('', '0')      
      BEGIN      
         SELECT @cTrackNo = UserDefine04     
         FROM dbo.Orders WITH (NOLOCK)     
         WHERE StorerKey = @cStorerKey    
         AND OrderKey = @cOrderKey     
    
         SET @nErrNo = 0      
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cPackSwapLot_SP) +      
            ' @n_Mobile,     @c_Storerkey,  @c_OrderKey,   @c_TrackNo,    @c_PickSlipNo, ' +      
            ' @n_CartonNo,   @c_LOC,        @c_ID,         @c_SKU, ' +      
            ' @c_Lottable01, @c_Lottable02, @c_Lottable03, @d_Lottable04, @d_Lottable05, ' +      
            ' @c_Barcode,    @b_Success   OUTPUT,  @n_ErrNo OUTPUT,  @c_ErrMsg OUTPUT '      
      
         SET @cSQLParam =      
            '@n_Mobile         INT,           ' +      
            '@c_Storerkey      NVARCHAR( 15),  ' +      
            '@c_OrderKey       NVARCHAR( 10), ' +      
            '@c_TrackNo        NVARCHAR( 20), ' +      
            '@c_PickSlipNo     NVARCHAR( 10), ' +      
            '@n_CartonNo       INT, ' +      
            '@c_LOC            NVARCHAR( 10), ' +      
            '@c_ID             NVARCHAR( 18), ' +      
            '@c_SKU            NVARCHAR( 20), ' +      
            '@c_Lottable01     NVARCHAR( 18), ' +      
            '@c_Lottable02     NVARCHAR( 18), ' +      
            '@c_Lottable03     NVARCHAR( 18), ' +      
            '@d_Lottable04     DATETIME,      ' +      
            '@d_Lottable05     DATETIME,      ' +      
            '@c_Barcode        NVARCHAR( 40), ' +      
            '@b_Success        INT           OUTPUT, ' +      
            '@n_ErrNo      INT           OUTPUT, ' +      
            '@c_ErrMsg         NVARCHAR( 20) OUTPUT  '      
      
         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,      
              @nMobile, @cStorerkey, @cOrderKey, @cTrackNo, @cPickSlipNo, @nCartonNo, @cLOC, @cID, @cSKU,      
              @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,      
              @cBarcode, @bSuccess OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT      
      
         IF @nErrNo <> 0      
            GOTO RollBackTran      
      END      
                
      
      SET @nTotalPickQty = 0      
      SELECT @nTotalPickQty = SUM(PD.QTY)      
      FROM PICKDETAIL PD WITH (NOLOCK)      
      WHERE PD.ORDERKEY = @cOrderKey      
      AND PD.Storerkey = @cStorerkey            
          
      SET @nTotalPackQty = 0      
      SELECT @nTotalPackQty = SUM(ScannedQty)      
      FROM rdt.rdtEcommLog WITH (NOLOCK)      
      WHERE OrderKey = @cORderKey      
          
          
      IF @nTotalPickQty = @nTotalPackQty      
      BEGIN      
               
           SET @cTrackNoFlag = '1'      
           --SET @cOrderKeyOut = @cOrderkey      
               
           SELECT   @cLoadKey = LoadKey    
                  , @cShipperKey = ShipperKey    
           FROM dbo.Orders WITH (NOLOCK)      
           WHERE Storerkey = @cStorerkey      
           AND   Orderkey = @cOrderkey      
    
               
               
           -- PRINT Report     
           DELETE FROM @tOutBoundList    
                   
           INSERT INTO @tOutBoundList (Variable, Value) VALUES ( '@cLoadKey',  @cLoadKey)    
           INSERT INTO @tOutBoundList (Variable, Value) VALUES ( '@cOrderKey', @cOrderKey)    
           INSERT INTO @tOutBoundList (Variable, Value) VALUES ( '@cShipperKey',   @cShipperKey)    
               
               
           -- Print label    
           EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, 0, 1, '', @cStorerKey, @cLabelPrinter, '',     
              'SHIPPLABEL', -- Report type    
              @tOutBoundList, -- Report params    
              'rdt_841ExtUpdSP05',     
              @nErrNo  OUTPUT,    
              @cErrMsg OUTPUT    
                
                 
    
           DELETE FROM @tOutBoundList2    
                   
           INSERT INTO @tOutBoundList2 (Variable, Value) VALUES ( '@cOrderKey',  @cOrderKey)    
           INSERT INTO @tOutBoundList2 (Variable, Value) VALUES ( '@cLoadKey', @cLoadKey)    
           INSERT INTO @tOutBoundList2 (Variable, Value) VALUES ( '@cType',   @cType)    
               
               
           -- Print label    
           EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, 0, 1, '', @cStorerKey, '', @cPaperPrinter,     
              'DELNOTES', -- Report type    
              @tOutBoundList2, -- Report params    
              'rdt_841ExtUpdSP05',     
              @nErrNo  OUTPUT,    
              @cErrMsg OUTPUT    
               
           --SELECT * FROM dbo.PackHeader WITH (NOlOCK) WHERE PickSlipNo = @cPickSlipNo    

            -- (james01)
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
               SET @nErrNo = 129181  
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
                  SET @nErrNo = 129182  
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- AutoMBOLPack       
                  GOTO RollBackTran    
               END     
            END  
            
           UPDATE dbo.PackHeader WITH (ROWLOCK)     
           SET Status = '9'    
               --EditWho = 'rdt.' + sUser_sName(),          
               --EditDate = GETDATE()        
           WHERE PickSlipNo = @cPickSlipNo     
               
           IF @@ERROR <> 0     
           BEGIN    
             SET @nErrNo = 129176      
             SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdPackHdrFail'      
             GOTO RollBackTran      
           END    
               
      END      
    
      /***************************      
      UPDATE rdtECOMMLog      
      ****************************/      
    
      DECLARE C_ECOMMLOG1 CURSOR LOCAL FAST_FORWARD READ_ONLY FOR      
      SELECT RowRef      
      FROM rdt.rdtEcommLog WITH (NOLOCK)      
      WHERE SKU         = @cSKU      
      AND   Orderkey    = @cOrderkey      
      AND   AddWho      = @cUserName      
      AND   Status      < '5'      
      AND   ScannedQty  >= ExpectedQty      
      
      OPEN C_ECOMMLOG1      
      FETCH NEXT FROM C_ECOMMLOG1 INTO  @nRowRef      
      WHILE (@@FETCH_STATUS <> -1)      
      BEGIN      
      
         /****************************      
            rdtECOMMLog      
         ****************************/      
         --update rdtECOMMLog      
         UPDATE RDT.rdtECOMMLog WITH (ROWLOCK)      
         SET   Status      = '9'    -- completed      
         WHERE RowRef = @nRowRef      
      
         IF @@ERROR <> 0      
         BEGIN      
            SET @nErrNo = 129175      
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdEcommFail'      
            GOTO RollBackTran      
         END      
      
         FETCH NEXT FROM C_ECOMMLOG1 INTO  @nRowRef      
      
      END      
      CLOSE C_ECOMMLOG1      
      DEALLOCATE C_ECOMMLOG1     
  
  
  
      SET @nFragileChk = 0  
      SET @nElectronic = 0  
  
      SET @cErrMsg01 = ''  
      SET @cErrMsg02 = ''  
      SET @cErrMsg03 = ''  
      SET @cErrMsg04 = ''  
      SET @cErrMsg05 = ''  
  
  
      IF rdt.RDTGetConfig( @nFunc, 'FRAGILECHK', @cStorerKey) = 1 AND  
         EXISTS ( SELECT 1 FROM dbo.Orders WITH (NOLOCK)  
                  WHERE [Stop] = 'Y'  
                  AND   OrderKey = @cOrderKey  
                  AND   StorerKey = @cStorerKey)  
      BEGIN  
         SET @nErrNo = 0  
         SET @cErrMsg01 = rdt.rdtgetmessage( 129177, @cLangCode, 'DSP')  
         SET @cErrMsg02 = rdt.rdtgetmessage( 129178, @cLangCode, 'DSP')  
         SET @cErrMsg03 = rdt.rdtgetmessage( 129179, @cLangCode, 'DSP')  
  
         SET @nFragileChk = 1  
      END  
  
      IF EXISTS ( SELECT 1 FROM dbo.SKU WITH (NOLOCK)  
                  WHERE StorerKey = @cStorerKey  
                  AND   SKU = @cSKU  
                  AND   SUSR3 = '2')  
         SET @nElectronic = 1  
  
      -- Nothing to display then no need display msg queue  
      IF @nFragileChk = 0 AND @nElectronic = 0  
         GOTO Quit  
        
      -- (james02)  
      IF @nElectronic = 1  
      BEGIN  
         IF @nFragileChk = 0  
            SET @cErrMsg01 = rdt.rdtgetmessage( 129180, @cLangCode, 'DSP')  
         ELSE  
            SET @cErrMsg05 = rdt.rdtgetmessage( 129180, @cLangCode, 'DSP')  
      END  
  
      IF @nFragileChk = 1 OR @nElectronic = 1  
      BEGIN  
         EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT,   
            @cErrMsg01, @cErrMsg02, @cErrMsg03, @cErrMsg04, @cErrMsg05  
         SET @nErrNo = 0   -- Reset error no  
      END  
  
  
   END      
         
            
   GOTO QUIT             
               
RollBackTran:            
   ROLLBACK TRAN rdt_841ExtUpdSP05 -- Only rollback change made here            
            
Quit:            
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started            
      COMMIT TRAN rdt_841ExtUpdSP05            
              
      
END    

GO
SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_840ExtPackCfm04                                 */
/* Purpose: Pack cfm, stamp pickdetail.caseid/labelno and               */
/*          middleware interface                                        */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author     Purposes                                 */
/* 2023-04-12  1.0  James      WMS-22084. Created                       */
/* 2023-08-25  1.1  James      Addhoc fix. Remove middleware interface  */
/*                             trigger (james01)                        */
/************************************************************************/

CREATE   PROC [RDT].[rdt_840ExtPackCfm04] (
   @nMobile          INT,
   @nFunc            INT,
   @cLangCode        NVARCHAR( 3),
   @nStep            INT,
   @nInputKey        INT,
   @cStorerkey       NVARCHAR( 15),
   @cPickslipno      NVARCHAR( 10),
   @nErrNo           INT           OUTPUT,
   @cErrMsg          NVARCHAR( 20) OUTPUT
)
AS

   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nTranCount     INT
   DECLARE @bSuccess       INT
   DECLARE @cAutoMBOLPack  NVARCHAR( 1)
   DECLARE @cFacility      NVARCHAR( 5)
   DECLARE @cAssignPackLabelToOrd   NVARCHAR(1)
   DECLARE @cOrderKey      NVARCHAR( 10)
   DECLARE @curCOO         CURSOR
   DECLARE @cOrderLineNumber  NVARCHAR( 5)
   DECLARE @nQty           INT
   DECLARE @cSKU           NVARCHAR( 20)
   DECLARE @cCOO           NVARCHAR( 10)
   DECLARE @cDropId        NVARCHAR( 20)
   DECLARE @cBillToKey     NVARCHAR( 15)
   DECLARE @cPaperPrinter  NVARCHAR( 10)
   DECLARE @cPackList      NVARCHAR( 10)
   DECLARE @nMaxCtnNo      INT
   DECLARE @cLabelNo       NVARCHAR( 20)
   DECLARE @cExternOrderKey   NVARCHAR( 50)
   DECLARE @cLottableValue    NVARCHAR( 60)
   DECLARE @nCartonNo      INT
   
   SELECT @cFacility = Facility
   FROM RDT.RDTMOBREC WITH (NOLOCK)
   WHERE Mobile = @nMobile

   SELECT TOP 1 @cOrderKey = OrderKey
   FROM dbo.PackHeader WITH (NOLOCK)
   WHERE PickSlipNo = @cPickslipno
   ORDER BY 1
   
   SELECT 
      @cBillToKey = BillToKey,
      @cExternOrderKey = ExternOrderKey
   FROM dbo.ORDERS WITH (NOLOCK) 
   WHERE StorerKey = @cStorerkey
   AND   OrderKey = @cOrderKey
    
   SET @cAssignPackLabelToOrd = rdt.RDTGetConfig( @nFunc, 'AssignPackLabelToOrd', @cStorerKey)

   SET @nTranCount = @@TRANCOUNT

   BEGIN TRAN
   SAVE TRAN rdt_840ExtPackCfm04   

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
      SET @nErrNo = 200751
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
         SET @nErrNo = 200752
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
         SET @nErrNo = 200753
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ConfPackFail
         GOTO RollBackTran
      END
   END

   -- (james01)
   IF @cAssignPackLabelToOrd = '1'
   BEGIN
      -- Update packdetail.labelno = pickdetail.labelno
      -- Get storer config
      DECLARE @cAssignPackLabelToOrdCfg NVARCHAR(1)
      EXECUTE nspGetRight
         @cFacility,
         @cStorerKey,
         '', --@c_sku
         'AssignPackLabelToOrdCfg',
         @bSuccess                 OUTPUT,
         @cAssignPackLabelToOrdCfg OUTPUT,
         @nErrNo                   OUTPUT,
         @cErrMsg                  OUTPUT
      IF @nErrNo <> 0
         GOTO RollBackTran

      -- Assign
      IF @cAssignPackLabelToOrdCfg = '1'
      BEGIN
         -- Update PickDetail, base on PackDetail.DropID
         EXEC isp_AssignPackLabelToOrderByLoad
             @cPickSlipNo
            ,@bSuccess OUTPUT
            ,@nErrNo   OUTPUT
            ,@cErrMsg  OUTPUT
         IF @nErrNo <> 0
            GOTO RollBackTran
      END
   END

   IF EXISTS ( SELECT 1 
               FROM dbo.ORDERS WITH (NOLOCK) 
               WHERE StorerKey = @cStorerkey
               AND   OrderKey = @cOrderKey
               AND   C_Country <> 'AU')
   BEGIN
      SET @curCOO = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
      SELECT OrderLineNumber, SKU, Dropid, SUM( Qty)
      FROM dbo.PICKDETAIL WITH (NOLOCK)
      WHERE Storerkey = @cStorerkey
      AND   OrderKey = @cOrderKey
      GROUP BY OrderLineNumber, SKU, Dropid
      OPEN @curCOO
      FETCH NEXT FROM @curCOO INTO @cOrderLineNumber, @cSKU, @cDropId, @nQty
      WHILE @@FETCH_STATUS = 0
      BEGIN
      	SELECT TOP 1 @cCOO = RefNo
      	FROM dbo.PackDetail WITH (NOLOCK)
      	WHERE PickSlipNo = @cPickslipno
      	AND   LabelNo = @cDropId
      	AND   SKU = @cSKU
      	ORDER BY 1 DESC
      	
         INSERT INTO dbo.OrderDetailRef
         ( Orderkey, OrderLineNumber, RetailSKU, BOMQty, RefType, StorerKey, ParentSKU) VALUES 
         ( @cOrderKey, @cOrderLineNumber, @cSKU, @nQty, UPPER( SUBSTRING( @cCOO, 1, 10)), @cStorerkey, @cDropId)
         	
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 200754
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'INS COO Fail'
            GOTO RollBackTran
         END
         
      	FETCH NEXT FROM @curCOO INTO @cOrderLineNumber, @cSKU, @cDropId, @nQty
      END
   END

   SELECT @nMaxCtnNo = MAX( CartonNo)
   FROM dbo.PackDetail WITH (NOLOCK)
   WHERE PickSlipNo = @cPickslipno
   
   IF EXISTS ( SELECT 1 
               FROM dbo.CODELKUP WITH (NOLOCK)
               WHERE LISTNAME = 'LVSPLTCUST'
               AND   Code = @cBillToKey
               AND   Short = '1'
               AND   Storerkey = @cStorerkey
               AND   ISNULL( UDF01, '') = 'VAS' 
               AND   ISNULL( UDF02, '') = 'LOOSEBULK'
               AND   ISNULL( CAST( UDF03 AS INT), '') < @nMaxCtnNo)          
   BEGIN
   	DECLARE @curInsCtnTrk   CURSOR
   	SET @curInsCtnTrk = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
   	SELECT LabelNo, LottableValue
   	FROM dbo.PackDetail WITH (NOLOCK)
   	WHERE PickSlipNo = @cPickslipno
   	OPEN @curInsCtnTrk
   	FETCH NEXT FROM @curInsCtnTrk INTO @cLabelNo, @cLottableValue
   	WHILE @@FETCH_STATUS = 0
   	BEGIN
         IF NOT EXISTS ( SELECT 1 
         	               FROM dbo.CartonTrack WITH (NOLOCK)
         	               WHERE TrackingNo = @cLottableValue
         	               AND   CarrierName = 'INTERNAL'
         	               AND   Labelno = @cLabelNo
         	               AND   KeyName = @cStorerkey)
         BEGIN
            INSERT INTO dbo.CartonTrack   
               (TrackingNo, CarrierName, KeyName, Labelno, UDF03)   
            VALUES   
               (@cLottableValue, 'INTERNAL', @cStorerKey, @cLabelNo, @cExternOrderKey)  

            IF @@ERROR <> 0  
            BEGIN  
               SET @nErrNo = 200755  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Ins CtnTrk Er  
               GOTO RollBackTran  
            END

            UPDATE dbo.ORDERS SET
               TrackingNo = @cExternOrderKey,
               EditWho = SUSER_SNAME(),
               EditDate = GETDATE()
            WHERE OrderKey = @cOrderKey
            
            IF @@ERROR <> 0  
            BEGIN  
               SET @nErrNo = 200757  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Upd Trk# Fail  
               GOTO RollBackTran  
            END  
         END
         
   	   FETCH NEXT FROM @curInsCtnTrk INTO @cLabelNo, @cLottableValue
   	END  
   END
   ELSE
   BEGIN
      IF EXISTS ( SELECT 1 
                  FROM dbo.CODELKUP WITH (NOLOCK)
                  WHERE LISTNAME = 'LVSPLTCUST'
                  AND   Code = @cBillToKey
                  AND   Short = '1'
                  AND   Storerkey = @cStorerkey
                  AND   ISNULL( UDF01, '') <> 'VAS' 
                  AND   ISNULL( UDF02, '') = 'LOOSEBULK'
                  AND   ISNULL( CAST( UDF03 AS INT), '') < @nMaxCtnNo)          
      BEGIN
         DECLARE @c_ZPLCode   NVARCHAR( MAX)
         	
         DECLARE @curGenZPL   CURSOR
   	   SET @curGenZPL = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
   	   SELECT CartonNo, LabelNo
   	   FROM dbo.PackDetail WITH (NOLOCK)
   	   WHERE PickSlipNo = @cPickslipno
   	   OPEN @curGenZPL
   	   FETCH NEXT FROM @curGenZPL INTO @nCartonNo, @cLabelNo
   	   WHILE @@FETCH_STATUS = 0
   	   BEGIN
            EXEC isp_GenZPL_interface
                 @c_StorerKey    = @cStorerkey        
               , @c_Facility     = @cFacility                         
               , @c_ReportType   = 'ZPLCONFIG'                
               , @c_Param01      = @cPickSlipNo     
               , @c_Param02      = @cLabelNo   
               , @c_Param03      = @nCartonNo   
               , @c_Param04      = @cStorerkey   
               , @c_Param05      = ''        
               , @c_SourceType   = @nFunc  
               , @c_ZPLCode      = @c_ZPLCode   OUTPUT     
               , @b_success      = @bSuccess    OUTPUT            
               , @n_err          = @nErrNo      OUTPUT                
               , @c_errmsg       = @cErrMsg     OUTPUT                            
         
            IF @bSuccess = 0
            BEGIN
               SET @nErrNo = 200756
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Exec ITF Fail
               GOTO RollBackTran
            END
         
            FETCH NEXT FROM @curGenZPL INTO @nCartonNo, @cLabelNo
         END
      END
      --ELSE (Removed due to same interface trigged during extupdsp james01)
      --BEGIN
      --   EXEC [dbo].[isp_Carrier_Middleware_Interface]        
      --        @c_OrderKey    = @cOrderKey     
      --      , @c_Mbolkey     = ''  
      --      , @c_FunctionID  = @nFunc      
      --      , @n_CartonNo    = @nCartonNo  
      --      , @n_Step        = @nStep  
      --      , @b_Success     = @bSuccess  OUTPUT        
      --      , @n_Err         = @nErrNo    OUTPUT        
      --      , @c_ErrMsg      = @cErrMsg   OUTPUT    

      --   IF @bSuccess = 0
      --   BEGIN
      --      SET @nErrNo = 200758 
      --      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Exec ITF Fail'
      --      GOTO RollBackTran
      --   END
      --END
   END
   
   GOTO Quit

   RollBackTran:
         ROLLBACK TRAN rdt_840ExtPackCfm04
   Quit:
      WHILE @@TRANCOUNT > @nTranCount
         COMMIT TRAN

   IF EXISTS ( SELECT 1
               FROM dbo.Storer WITH (NOLOCK)
               WHERE StorerKey = @cBillToKey
               AND   Facility = @cFacility
               AND   [type] = '2'
               AND   SUSR4 IN ( 'C', 'E', 'Y'))
   BEGIN
      SET @cPackList = rdt.RDTGetConfig( @nFunc, 'PackList', @cStorerKey)
      IF @cPackList = '0'
         SET @cPackList = ''

      IF @cPackList = ''
         GOTO Quit_Print

   	SELECT @cPaperPrinter = Printer_Paper
   	FROM rdt.RDTMOBREC WITH (NOLOCK)
   	WHERE Mobile = @nMobile
   	
      DECLARE @tPackList AS VariableTable
      INSERT INTO @tPackList (Variable, Value) VALUES 
         ( '@cPickSlipNo',    @cPickSlipNo), 
         ( '@cOrderKey',      @cOrderKey)

      -- Print packing list
      EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, '', @cPaperPrinter, 
         @cPackList, -- Report type
         @tPackList, -- Report params
         'rdt_840ExtPackCfm04', 
         @nErrNo  OUTPUT,
         @cErrMsg OUTPUT

      IF @nErrNo <> 0
         GOTO Quit_Print   	
   END

   Quit_Print:

GO
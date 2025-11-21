SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_840ExtUpd07                                     */
/* Purpose: Scan in and Update pickdetail.dropid = packdetail.labelno   */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2019-03-08 1.0  James      WMS7181-Created                           */
/* 2019-03-19 1.1  James      Add scan in (james01)                     */
/* 2021-04-01 1.2 YeeKung     WMS-16717 Add serialno and serialqty      */
/*                            Params (yeekung01)                        */
/************************************************************************/

CREATE PROC [RDT].[rdt_840ExtUpd07] (
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

   DECLARE @cAuthority_ScanInLog NVARCHAR( 1)

   DECLARE @nExpectedQty   INT, 
           @nPackedQty     INT,
           @bSuccess       INT,
           @nTranCount     INT,
           @cOrdType       NVARCHAR( 10)

   IF @nStep = 1
   BEGIN 
      IF ISNULL( @cPickSlipNo, '') = ''
      BEGIN
         SET @nErrNo = 135752
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'NO PKSLIP'
         GOTO Quit
      END

      IF ISNULL( @cOrderKey, '') = ''
      BEGIN
         SELECT @cOrderKey = OrderKey
         FROM dbo.PickHeader WITH (NOLOCK)
         WHERE PickHeaderKey = @cPickSlipNo

         IF ISNULL( @cOrderKey, '') = ''
         BEGIN
            SET @nErrNo = 135753
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'NO ORDERKEY'
            GOTO Quit
         END
      END

      -- (james02)
      SET @cOrdType = ''
      SELECT @cOrdType = [Type]
      FROM dbo.Orders WITH (NOLOCK)
      WHERE OrderKey = @cOrderKey

      SET @nTranCount = @@TRANCOUNT    

      BEGIN TRAN    
      SAVE TRAN Step1    

      UPDATE dbo.ORDERS WITH (ROWLOCK) SET 
         STATUS = '3',
         EditWho = sUser_sName(),
         EditDate = GetDate()
      WHERE OrderKey = @cOrderKey
      AND Status < '3'

      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 135754
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Upd OdHdr Fail'
         GOTO Step1_RollBackTran
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
         SET @nErrNo = 135755
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Upd OdDtl Fail'
         GOTO Step1_RollBackTran
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
         SET @nErrNo = 135756
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Upd LpDtl Fail'
         GOTO Step1_RollBackTran
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
               SET @nErrNo = 135757
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'nspGetRightErr'
               GOTO Step1_RollBackTran
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
                  SET @nErrNo = 135758
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'GenTLog3 Fail'
                  GOTO Step1_RollBackTran
               End
            END
         END 
      END

      GOTO Step1_Commit
   
      Step1_RollBackTran:  
            ROLLBACK TRAN Step1  
      Step1_Commit:  
         WHILE @@TRANCOUNT > @nTranCount  
            COMMIT TRAN  
   END

   IF @nStep = 3
   BEGIN
      IF @nInputKey = 1
      BEGIN
         -- 1 orders 1 tracking no    
         -- discrete pickslip, 1 ordes 1 pickslipno    
         SET @nExpectedQty = 0    
         SELECT @nExpectedQty = ISNULL(SUM(Qty), 0) FROM dbo.PickDetail WITH (NOLOCK)    
         WHERE Orderkey = @cOrderkey    
         AND   Storerkey = @cStorerkey    
         AND   Status < '9'    
 
         SET @nPackedQty = 0    
         SELECT @nPackedQty = ISNULL(SUM(Qty), 0) FROM dbo.PackDetail WITH (NOLOCK)    
         WHERE PickSlipNo = @cPickSlipNo    
         AND   Storerkey = @cStorerkey    

         -- all SKU and qty has been packed, Update pickdetail.dropid = packdetail.dropid
         -- For Move orders only
         IF @nExpectedQty = @nPackedQty    
         BEGIN    
            IF EXISTS ( SELECT 1 FROM dbo.CODELKUP C WITH (NOLOCK) 
                        JOIN dbo.Orders O WITH (NOLOCK) ON (C.Code = O.UserDefine03 AND C.StorerKey = O.StorerKey)
                        WHERE C.ListName = 'HMCOSORD'
                        AND   C.UDF01 = 'M'
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
                  SET @nErrNo = 135751    
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Assign Lbl Err'    
                  GOTO Quit    
               END    
            END
         END
      END
   END   --Step 3

   Quit:  

GO
SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*****************************************************************************/
/* Store procedure: rdt_EcommDispatch_Confirm                                */
/* Copyright      : IDS                                                      */
/*                                                                           */
/* Purpose: SOS#175743 - EComm Order Despatch                                */
/*                                                                           */
/* Modifications log:                                                        */
/*                                                                           */
/* Date       Rev  Author   Purposes                                         */
/* 2010-06-16 1.0  AQSKC    Created                                          */
/* 2010-06-24 1.0  AQSKC    Fix checking for SKU not on Order (KC01)         */
/* 2010-07-13 1.0  AQSKC    Add checking for printing of label HDN or DPD    */
/*                          (KC02)                                           */
/* 2010-07-14 1.0  AQSKC    Print DPD Labels based on EU and non-EU country  */
/*                          and add report setup validation (KC03)           */
/* 2010-07-19 1.0  AQSKC    Do not include picks wih status '4' (shortpick)  */
/*                          (Kc04)                                           */
/* 2010-07-19 1.0  AQSKC    Do not update packheader if any pickdetail is    */
/*                          shortpicked (Kc05)                               */
/* 2010-07-22 1.1  Vicky    To cater Paper Printer since printing both Label */
/*                          and Paper Report (Vicky01)                       */
/* 2010-07-26 1.2  AQSKC    Standardize report printing SP (Kc06)            */
/* 2010-07-27 1.2  AQSKC    Bug Fix (Kc07)                                   */
/* 2010-07-28 1.3  Vicky    PackInfo should have PackDetail.RefNo inserted   */
/*                          and not DropID value (Vicky01)                   */
/* 2010-07-28 1.3  AQSKC    Additional parameters for Generate UPI           */
/*                          and request for addtional blank parameter        */
/*                          during call to print HDN/DPD label (Kc08)        */
/* 2010-07-29 1.4  AQSKC    DPD Label printing - cater for future and current*/
/*                          label (Kc09)                                     */
/* 2010-07-29 1.5  AQSKC    Add eventlog (Kc10)                              */
/* 2010-07-29 1.6  Vicky    Update DropID.LabelPrinted & ManifestPrinted = Y */
/*                          after Label & report printed (Vicky02)           */
/* 2010-08-03 1.7  AQSKC    Remove reference to DTSITF db (Kc11)             */
/* 2010-08-05 1.8  AQSKC    Change paramaters when calling isp_GenerateUPI   */
/*                          (Kc12)                                           */
/* 2010-08-06 1.9  AQSKC    Fix Report printing (Kc13)                       */
/* 2010-08-15 2.0  James    MISC fixes (james01)                             */
/* 2010-08-16 2.1  James    Bug fixes (james02)                              */
/* 2010-09-01 2.2  James    Check if SKU over packed (james03)               */
/* 2010-09-22 2.3  James    Change DPD country field mapping (james04)       */
/* 2010-09-23 2.4  AQSKC    Perform validation for DPD label (Kc14)          */
/* 2010-09-28 2.4  James    Combine delivery & return note (james05)         */
/* 2010-10-14 2.5  James    No filter status when get sum(PickQty) (james06) */
/* 2010-10-15 2.6  James    If pickdetail with status = '4' but Qty = 0      */
/*                          then can close packheader (james07)              */
/* 2011-01-13 2.7  James    Change actiontype for eventlog (james08)         */
/* 2011-02-22 2.8  James    Add C&C printing (james09)                       */
/* 2012-08-13 3.0  James    SOS#252750 Refine report selection mtd (james10) */
/* 2014-05-29 3.1  James    SOS311987 - Add extendedupdate sp (james11)      */
/* 2014-08-14 3.2  James    SOS317664 - Add extended printing (james12)      */
/* 2014-08-27 3.3  James    SOS317664 - Generate label no if empty (james12) */
/* 2014-12-16 3.4  James    SOS327809 - Add rdt config to calc qty pick/pack */
/*                          by using tote no (james13)                       */
/* 2015-11-27 3.5  James    Deadlock tuning (james13)                        */
/*****************************************************************************/
CREATE PROC [RDT].[rdt_EcommDispatch_Confirm](
   @nMobile        INT,
   @cPrinter       NVARCHAR(10),
   @cLangCode      NVARCHAR( 3),
   @nErrNo         INT          OUTPUT,
   @cErrMsg        NVARCHAR( 20) OUTPUT, -- screen limitation, 20 NVARCHAR max
   @cOrderkey      NVARCHAR( 10) OUTPUT,
   @cStorerKey     NVARCHAR( 15),
   @cSku           NVARCHAR( 20),
   @cToteNo        NVARCHAR( 18),
   @cDropIDType    NVARCHAR( 10),
   @cPrinter_Paper NVARCHAR( 10),    -- (Vicky01)
   @cPrevOrderkey  NVARCHAR( 10),    -- (Kc07)
   @nFunc          INT,             -- (Kc10)
   @cFacility      NVARCHAR(  5),    -- (Kc10)
   @cUserName      NVARCHAR( 18)     -- (Kc10)
) AS
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nSkuCnt     int
         , @bSuccess    int
         , @nErr        int
         , @nTranCount  int
         , @cPickSlipNo NVARCHAR(10)
         , @nCartonNo   int
         , @cLabelLine  NVARCHAR( 5)
         , @cLabelNo    NVARCHAR(20)
         , @cPackSku    NVARCHAR(20)
         , @nPackQty    int
         , @cDataWindow NVARCHAR(50)
         , @cTargetDB   NVARCHAR(20)
         --, @cPostCode   NVARCHAR(18)        --(Kc12)
         , @cUPI        NVARCHAR(16)
         , @cIncoTerm   NVARCHAR(10)
         , @nTotalPackQty  int
         , @nTotalPickQty  int
         , @cEUCountry     NVARCHAR(10)       --(Kc03)
         , @cReportType    NVARCHAR(10)       --(KC03)
         , @nUnpicked      int               --(Kc05)
         , @cPrintJobName  NVARCHAR(50)       --(Kc06)
         , @cCheckExist    NVARCHAR(1)           --(Kc09)
         , @nTTL_PickedQty INT               -- (james03)
         , @nTTL_PackedQty INT               -- (james03)
         , @cPrintDummy    NVARCHAR(1)           --(Kc14)
         , @cConsigneeKey  NVARCHAR(15)          --(james09)
         , @cExternOrderKey NVARCHAR(20)         --(james09)
         , @cUDF01          NVARCHAR(60)         --(james10)


   DECLARE @cExtendedUpdateSP    NVARCHAR( 20),    -- (james11)
           @cSQL                 NVARCHAR(1000),   -- (james11)
           @cSQLParam            NVARCHAR(1000),   -- (james11)
           @nStep                INT,              -- (james12)
           @nInputKey            INT,              -- (james12)
           @cExtendedPrintSP     NVARCHAR( 20),    -- (james12)
           @cExtendedInfoSP      NVARCHAR( 20),    -- (james12)
           @cPrt_ErrMsg          NVARCHAR( 215),   -- (james12)
           @cOptional_Parm3      NVARCHAR( 20),    -- (james13)
           @nRowRef              INT               -- (james14)


   SET @nSkuCnt      = 0
   SET @cPickSlipNo  = ''
   SET @nCartonNo    = 0
   SET @cLabelLine   = ''
   SET @cLabelNo     = ''
   SET @cPackSku     = ''
   SET @nPackQty     = 0
   SET @cDataWindow  = ''
   SET @cTargetDB    = ''
   --SET @cPostCode    = ''      --(Kc12)
   SET @cUPI         = ''
   SET @cIncoTerm    = ''
   SET @nTotalPackQty = 0
   SET @nTotalPickQty = 0
   SET @cEUCountry   = ''
   SET @cReportType  = ''
   SET @cPrintJobName = ''       --(Kc06)

   /****************************
    VALIDATION
   ****************************/
   --When SKU is blank
   IF @cSku = ''
   BEGIN
   SET @nErrNo = 69869
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SKU/UPC Req
      GOTO Fail
   END

   EXEC RDT.rdt_GETSKUCNT
      @cStorerKey  = @cStorerKey,
      @cSKU        = @cSKU,
      @nSKUCnt     = @nSKUCnt       OUTPUT,
      @bSuccess    = @bSuccess      OUTPUT,
      @nErr        = @nErrNo        OUTPUT,
      @cErrMsg     = @cErrMsg       OUTPUT

   -- Validate SKU/UPC
   IF @nSKUCnt = 0
   BEGIN
      SET @nErrNo = 69870
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid SKU/UPC'
      GOTO Fail
   END

   -- Validate barcode return multiple SKU
   IF @nSKUCnt > 1
   BEGIN
      SET @nErrNo = 69878
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'SameBarCodeSKU'
      GOTO Fail
   END

   -- Return actual SKU If barcode is scanned (SKU.AltSKU, SKU.RetailSKU, SKU.ManufacturerSKU OR UPC.UPC)
   EXEC [RDT].[rdt_GETSKU]
      @cStorerKey  = @cStorerKey,
      @cSKU        = @cSKU          OUTPUT,
      @bSuccess    = @bSuccess      OUTPUT,
      @nErr        = @nErrNo        OUTPUT,
      @cErrMsg     = @cErrMsg       OUTPUT

   -- check if sku exists in tote
   IF NOT EXISTS (SELECT 1 FROM rdt.rdtECOMMLog ECOMM WITH (NOLOCK)
                  WHERE ToteNo = @cToteno
                  AND SKU = @cSKU
                  AND AddWho = @cUserName
                  AND Status IN ('0', '1') )
   BEGIN
      SET @nErrNo = 69893
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SKuNotIntote
      GOTO Fail
   END

   --(Kc07) - start
   --check anymore sku to scan for the order
   IF NOT EXISTS (SELECT 1 FROM rdt.rdtECOMMLog ECOMM WITH (NOLOCK)
                  WHERE ToteNo = @cToteno
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
      WHERE ToteNo = @cToteno
      AND   Status IN ('0', '1')
      AND   Sku = @cSKU
      AND   AddWho = @cUserName
   END
   ELSE
   BEGIN
      IF NOT EXISTS (SELECT 1 FROM rdt.rdtECOMMLog ECOMM WITH (NOLOCK)
                     WHERE ToteNo = @cToteno
                     AND Orderkey = @cOrderkey
                     AND SKU = @cSKU
                     AND Status < '5'
                     AND AddWho = @cUserName)
      BEGIN
         SET @nErrNo = 69871
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SKUNotInOrder
         GOTO Fail
      END
   END

   -- check if sku is in the order and picked
--   IF NOT EXISTS (SELECT 1 FROM dbo.ORDERDETAIL OD WITH (NOLOCK)
--      --(KC01)
--      JOIN dbo.PICKDETAIL PD WITH (NOLOCK) ON (PD.Orderkey = OD.Orderkey AND PD.Orderlinenumber = OD.Orderlinenumber AND PD.Status = '5' AND PD.DropId = @cToteNo)
--      WHERE OD.Orderkey = @cOrderkey AND OD.SKU = @cSKU )
--   BEGIN
--      SET @nErrNo = 69871
--      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SKUNotInOrder
--      GOTO Fail
--   END

   --(Kc07) - end

   -- check if sku has been fully despatched for this order
   IF EXISTS (SELECT 1 FROM rdt.rdtECOMMLog ECOMM WITH (NOLOCK)
              WHERE ToteNo = @cToteno
              AND   Orderkey = @cOrderkey
              AND   SKU = @cSKU
              --AND   ExpectedQty < ScannedQty + 1
              AND   Status < '5'
              AND   AddWho = @cUserName
              GROUP BY ToteNo, SKU
              HAVING SUM( ExpectedQty) < SUM( ScannedQty) + 1)
   BEGIN
      SET @nErrNo = 69872
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --QtyExceeded
      GOTO Fail
   END

   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN  -- Begin our own transaction
   SAVE TRAN rdt_EcommDispatch_Confirm -- For rollback or commit only our own transaction

   /***************************
    UPDATE rdtECOMMLog
   ****************************/
   SELECT @nRowRef = RowRef 
   FROM RDT.rdtECOMMLog WITH (NOLOCK)
   WHERE ToteNo      = @cToteNo
   AND   Orderkey    = @cOrderkey
   AND   Sku         = @cSku
   AND   Status      < '5'
   AND   AddWho      = @cUserName
   AND   ScannedQty < ExpectedQty
   ORDER BY 1

   UPDATE RDT.rdtECOMMLog WITH (ROWLOCK) SET
      ScannedQty  = ScannedQty + 1,
      Status      = '1'    -- in progress
   WHERE RowRef = @nRowRef

   IF @@ERROR <> 0 OR @@ROWCOUNT = 0
   BEGIN
      SET @nErrNo = 69881
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdEcommFail'
      GOTO RollBackTran
   END

   /****************************
    CREATE PACK DETAILS
   ****************************/
   -- check is order fully despatched for this tote
   IF NOT EXISTS (SELECT 1 FROM rdt.rdtECOMMLog ECOMM WITH (NOLOCK)
                  WHERE ToteNo = @cToteno
                  AND Orderkey = @cOrderkey
                  AND ExpectedQty > ScannedQty
                  AND Status < '5'
                  AND AddWho = @cUserName)
   BEGIN
      --BEGIN TRAN

      IF NOT EXISTS (SELECT 1 FROM dbo.PackHeader WITH (NOLOCK) WHERE Orderkey = @cOrderkey)
      BEGIN
         IF NOT EXISTS (SELECT 1 FROM dbo.PickHeader WITH (NOLOCK) WHERE Orderkey = @cOrderkey)
         BEGIN
            /****************************
             PICKHEADER
            ****************************/
            --pickheader record missing
            SELECT @cPickSlipNo = MIN(RTRIM(ISNULL(Pickslipno,'')))
            FROM   dbo.PICKDETAIL PD WITH (NOLOCK)
            WHERE  Orderkey = @cOrderkey
            AND    Status = '5'

            IF ISNULL(@cPickSlipNo,'') = ''
            BEGIN
               EXECUTE dbo.nspg_GetKey
               'PICKSLIP',
               9,
               @cPickslipno OUTPUT,
               @bsuccess   OUTPUT,
               @nerrNo     OUTPUT,
               @cerrmsg    OUTPUT

               SET @cPickslipno = 'P' + @cPickslipno
            END

            INSERT INTO dbo.PICKHEADER (PickHeaderKey, Storerkey, Orderkey, PickType, Zone, TrafficCop, AddWho, AddDate, EditWho, EditDate)
            VALUES (@cPickSlipNo, @cStorerkey, @cOrderKey, '0', 'D', '', sUser_sName(), GETDATE(), sUser_sName(), GETDATE())

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 69883
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsPickHdrFail'
               GOTO RollBackTran
            END
            ELSE
            BEGIN
               UPDATE dbo.PICKDETAIL WITH (ROWLOCK)
               SET  PICKSLIPNO = @cPickslipno,
                    Trafficcop = NULL
               WHERE StorerKey = @cStorerKey
               AND   Orderkey = @cOrderKey
               AND   Status = '5'
               AND   ISNULL(RTrim(Pickslipno),'') = ''

               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 69884
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdPickDetFail'
                  GOTO RollBackTran
               END
            END
         END -- pickheader does not exist

         /****************************
          PACKHEADER
         ****************************/
         INSERT INTO dbo.PackHeader
         (Route, OrderKey, OrderRefNo, Loadkey, Consigneekey, StorerKey, PickSlipNo, AddWho, AddDate, EditWho, EditDate)
         SELECT O.Route, O.OrderKey,SUBSTRING(O.ExternOrderKey, 1, 18), O.LoadKey, O.ConsigneeKey, O.Storerkey,
               PH.PickHeaderkey, sUser_sName(), GETDATE(), sUser_sName(), GETDATE()
         FROM  dbo.PickHeader PH WITH (NOLOCK)
         JOIN  dbo.Orders O WITH (NOLOCK) ON (PH.Orderkey = O.Orderkey)
         WHERE PH.Orderkey = @cOrderkey

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 69880
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'CreatePHdrFail'
            GOTO RollBackTran
         END
      END -- packheader does not exist

      /****************************
       PACKDETAIL
      ****************************/
      SET @cLabelNo = 0
      SET @nCartonNo = 0
      -- need to generate UPI for 1st Tote, and regenerate for subsequent tote
      -- because the total PackQty would differ from original
      SELECT TOP 1 @cPickSlipNo  = PH.PickSlipNo
      FROM  dbo.PACKHEADER PH WITH (NOLOCK)
      WHERE PH.Orderkey = @cOrderkey

      SELECT --@cPostCode = ISNULL(RTRIM(C_ZIP),'')      --(Kc12)
            @cIncoTerm = ISNULL(RTRIM(IncoTerm),'')
      FROM  ORDERS WITH (NOLOCK)
      WHERE Orderkey = @cOrderkey

      SELECT @nPackQty = ISNULL(SUM(ECOMM.ScannedQTY), 0)
      FROM   rdt.rdtECOMMLog ECOMM WITH (NOLOCK)
      WHERE  ToTeNo = @cToteNo
      AND    Orderkey = @cOrderkey
      AND    Status < '5'
      AND    AddWho = @cUserName

      SET @nErrNo = 0                           --(Kc08)
      SET @cErrMsg = ''                         --(Kc08)

      -- Only if ECOMM orders then need to generate UPI (james01)
      --IF EXISTS (SELECT 1 FROM dbo.Codelkup WITH (NOLOCK) WHERE Listname = 'HDNTERMS' AND Code = @cIncoTerm)    -- (james10)
      IF EXISTS (SELECT 1 FROM dbo.Codelkup WITH (NOLOCK) WHERE Listname = 'SHIPPING' AND Code = @cIncoTerm AND UDF01 = 'YODEL')
      BEGIN
         EXEC dbo.isp_GenerateUPI
            --@cPostcode  = @cPostCode             --(Kc12)
            @cOrderkey  = @cOrderkey               --(Kc12)
          , @nPack      = 1   --@nPackQty          --(Kc07)
          , @cUPI       = @cLabelNo output
          , @nErrNo     = @nErrNo   output         --(Kc08)
          , @cErrMsg    = @cErrMsg  output         --(Kc08)

         IF @nErrNo <> 0 OR ISNULL(RTRIM(@cLabelNo),'') = ''
         BEGIN
            SET @nErrNo = @nErrNo                  -- (Kc08) 69903
            SET @cErrMsg = @cErrMsg                -- (Kc08) 'GenUPIFail'
            GOTO RollBackTran
         END
      END
      ELSE  -- (james09)
      --IF RTRIM(UPPER(@cIncoTerm)) = 'CC'      -- (james10)
      IF EXISTS (SELECT 1 FROM dbo.Codelkup WITH (NOLOCK) WHERE Listname = 'SHIPPING' AND Code = @cIncoTerm AND UDF01 = 'C&C')
      BEGIN
         SELECT TOP 1
            @cConsigneeKey = SUBSTRING(ISNULL(Consigneekey,''),4,4)
         FROM dbo.Orders WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
            AND OrderKey = @cOrderKey

         SET @cLabelNo = RTRIM(UPPER(@cIncoTerm)) + RTRIM(@cOrderKey) + RTRIM(UPPER(@cIncoTerm))
      END
      ELSE  -- (james10)
      IF EXISTS (SELECT 1 FROM dbo.Codelkup WITH (NOLOCK) WHERE Listname = 'SHIPPING' AND Code = @cIncoTerm AND UDF01 = 'CITIPOST')
      BEGIN
         SELECT TOP 1 @cLabelNo = SUBSTRING(CLKP.SHORT,1,3) +
                            RIGHT(O.Orderkey,8) +
                            LEFT( UPPER(REPLACE(ISNULL(RTRIM(O.C_Zip),''),' ','')) + '00000000',8)
         FROM ORDERS O WITH (NOLOCK)
         JOIN CODELKUP CLKP WITH (NOLOCK)
              ON (CLKP.ListName = 'SHIPPING')
              AND(CLKP.Code = O.IncoTerm)
              AND(CLKP.UDF01 = 'CITIPOST')
         WHERE O.Storerkey = @cStorerKey
         AND O.Orderkey = @cOrderkey
      END

      -- If label no blank then generate one (james12)
      IF ISNULL( @cLabelNo, '') in ('0', '')
      BEGIN
         EXECUTE dbo.nsp_GenLabelNo
            '',
            @cStorerKey,
            @c_labelno     = @cLabelNo    OUTPUT,
            @n_cartonno    = @nCartonNo   OUTPUT,
            @c_button      = '',
            @b_success     = @bSuccess    OUTPUT,
            @n_err         = @nErrNo      OUTPUT,
            @c_errmsg      = @cErrmsg     OUTPUT

         IF @bSuccess <> 1
         BEGIN
            SET @nErrNo = 71448
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'GenLabelFail'
            GOTO RollBackTran
         END
      END

      DECLARE C_TOTE_DETAIL CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT ECOMM.SKU, ECOMM.ScannedQTY
      FROM   rdt.rdtECOMMLog ECOMM WITH (NOLOCK)
      WHERE  ToTeNo = @cToteNo
      AND    Orderkey = @cOrderkey
      AND    Status < '5'
      AND    AddWho = @cUserName
      ORDER BY SKU

      OPEN C_TOTE_DETAIL
      FETCH NEXT FROM C_TOTE_DETAIL INTO  @cPackSku , @nPackQty
      WHILE (@@FETCH_STATUS <> -1)
      BEGIN
         SET @cLabelLine = '00000'

         IF NOT EXISTS (SELECT 1 FROM dbo.PackDetail WITH (NOLOCK)
                        WHERE PickSlipNo = @cPickSlipNo
                           AND SKU = @cPackSku
                           AND DropID = @cToteNo)
         BEGIN
            -- update the existing packdetail labelno
            UPDATE dbo.Packdetail WITH (ROWLOCK)
            SET   LabelNo  = @cLabelNo
            WHERE PickSlipNo = @cPickSlipNo

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 69890
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdPackDetFail'
               CLOSE C_TOTE_DETAIL
               DEALLOCATE C_TOTE_DETAIL
               GOTO RollBackTran
            END

            -- Check if sku overpacked (james03)
            SELECT @nTTL_PickedQty = ISNULL(SUM(PD.QTY), 0)
            FROM dbo.PickDetail PD WITH (NOLOCK)
            JOIN dbo.Packheader PH WITH (NOLOCK) ON PD.OrderKey = PH.OrderKey
            WHERE PD.StorerKey = @cStorerKey
               AND PD.Status = '5'
               AND PD.SKU = @cPackSku
               AND PH.PickSlipNo = @cPickSlipNo

            SELECT @nTTL_PackedQty = ISNULL(SUM(QTY), 0)
            FROM dbo.PackDetail WITH (NOLOCK)
            WHERE StorerKey = @cStorerKey
               AND PickSlipNo = @cPickSlipNo
               AND SKU = @cPackSku

            IF @nTTL_PickedQty < (@nTTL_PackedQty + @nPackQty)
            BEGIN
               SET @nErrNo = 69908
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'OVER PACKED'
               CLOSE C_TOTE_DETAIL
               DEALLOCATE C_TOTE_DETAIL
               GOTO RollBackTran
            END

            -- Insert PackDetail
            INSERT INTO dbo.PackDetail
               (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, QTY, Refno, DropID, AddWho, AddDate, EditWho, EditDate)
            VALUES
               (@cPickSlipNo, @nCartonNo, @cLabelNo, @cLabelLine, @cStorerKey, @cPackSku, @nPackQty,
               '', @cToteNo, sUser_sName(), GETDATE(), sUser_sName(), GETDATE())

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 69885
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsPackDetFail'
               CLOSE C_TOTE_DETAIL
               DEALLOCATE C_TOTE_DETAIL
               GOTO RollBackTran
            END
            --(Kc10) - start
            ELSE
            BEGIN
               EXEC RDT.rdt_STD_EventLog
                 @cActionType = '8', -- Packing
                 @cUserID     = @cUserName,
                 @nMobileNo   = @nMobile,
                 @nFunctionID = @nFunc,
                 @cFacility   = @cFacility,
                 @cStorerKey  = @cStorerkey,
                 @cSKU        = @cPackSku,
                 @nQty        = @nPackQty,
                 @cRefNo1     = @cToteNo,
                 @cRefNo2     = @cLabelNo,
                 @cRefNo3     = @cPickSlipNo
            END
            --(Kc10) - end

         END --packdetail for sku/order does not exists
         ELSE
         BEGIN
            UPDATE dbo.Packdetail WITH (ROWLOCK)
            SET   QTY      = QTY + @nPackQty,
                  LabelNo  = @cLabelNo
            WHERE PickSlipNo = @cPickSlipNo AND SKU = @cPackSku AND DropID = @cToteNo

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 69907        --(Kc07)
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdPackDetFail'
               CLOSE C_TOTE_DETAIL
               DEALLOCATE C_TOTE_DETAIL
               GOTO RollBackTran
            END
            --(Kc10) - start
            ELSE
            BEGIN
               EXEC RDT.rdt_STD_EventLog
                 @cActionType = '8', -- Packing
                 @cUserID     = @cUserName,
                 @nMobileNo   = @nMobile,
                 @nFunctionID = @nFunc,
                 @cFacility   = @cFacility,
                 @cStorerKey  = @cStorerkey,
                 @cSKU        = @cPackSku,
                 @nQty        = @nPackQty,
                 @cRefNo1     = @cToteNo,
                 @cRefNo2     = @cLabelNo,
                 @cRefNo3     = @cPickSlipNo
            END
            --(Kc10) - end
         END -- packdetail for sku/order exists

         FETCH NEXT FROM C_TOTE_DETAIL INTO  @cPackSku , @nPackQty
      END --while
      CLOSE C_TOTE_DETAIL
      DEALLOCATE C_TOTE_DETAIL

      /****************************
       PACKINFO
      ****************************/
      IF NOT EXISTS (SELECT 1 FROM dbo.PackInfo WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo)
      BEGIN
         INSERT INTO dbo.PackInfo(PickslipNo, CartonNo, CartonType, Refno, AddWho, AddDate, EditWho, EditDate)
         --SELECT DISTINCT PD.PickSlipNo, PD.CartonNo, @cDropIDType, @cToteNo, sUser_sName(), GETDATE(), sUser_sName(), GETDATE()
         SELECT DISTINCT PD.PickSlipNo, PD.CartonNo, @cDropIDType, RefNo, sUser_sName(), GETDATE(), sUser_sName(), GETDATE() -- (Vicky01)
         FROM   PACKHEADER PH WITH (NOLOCK)
         JOIN   PACKDETAIL PD WITH (NOLOCK) ON (PH.PickslipNo = PD.PickSlipNo)
         WHERE  PH.Orderkey = @cOrderkey

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 69886
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsPInfoFail'
            GOTO RollBackTran
         END
      END
      /****************************
       rdtECOMMLog
      ****************************/
      DECLARE CUR_UPD CURSOR LOCAL FOR
      SELECT RowRef FROM RDT.rdtECOMMLog WITH (NOLOCK)
      WHERE ToteNo      = @cToteNo
      AND   Orderkey    = @cOrderkey
      AND   AddWho      = @cUserName
      AND   Status      < '5'
      OPEN CUR_UPD
      FETCH NEXT FROM CUR_UPD INTO @nRowRef
      WHILE @@FETCH_STATUS <> -1
      BEGIN
         --update rdtECOMMLog
         UPDATE RDT.rdtECOMMLog WITH (ROWLOCK) SET
            Status = '9'    -- completed
         WHERE RowRef = @nRowRef

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 69905        --(Kc07)
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdEcommFail'
            CLOSE CUR_UPD
            DEALLOCATE CUR_UPD
            GOTO RollBackTran
         END

         FETCH NEXT FROM CUR_UPD INTO @nRowRef
      END
      CLOSE CUR_UPD
      DEALLOCATE CUR_UPD
   END -- order fully despatched for this tote

   -- (james13)
   IF rdt.RDTGetConfig( @nFunc, 'SkipParkTote', @cStorerKey) IN ('', '0')
   BEGIN
      -- check if total order fully despatched
      SELECT @nTotalPickQty = SUM(ISNULL(PK.Qty,0))
      FROM  dbo.PICKDETAIL PK WITH (nolock)
      WHERE PK.Orderkey = @cOrderkey
   --   AND   PK.Status = '5'            -- (KC04)/(james06)

      SELECT @nTotalPackQty = SUM(ISNULL(PD.Qty,0))
      FROM  dbo.PACKDETAIL PD WITH (NOLOCK)
      JOIN  dbo.PACKHEADER PH WITH (NOLOCK) ON (PD.PickslipNo = PH.PickSlipNo AND PH.Orderkey = @cOrderkey)
   END
   ELSE
   BEGIN
      -- check if total item in this tote fully despatched
      SELECT @nTotalPickQty = SUM(ISNULL(PK.Qty,0))
      FROM  dbo.PICKDETAIL PK WITH (nolock)
      WHERE PK.Orderkey = @cOrderkey
      AND   PK.DropID = @cToteNo

      SELECT @nTotalPackQty = SUM(ISNULL(PD.Qty,0))
      FROM  dbo.PACKDETAIL PD WITH (NOLOCK)
      JOIN  dbo.PACKHEADER PH WITH (NOLOCK) ON (PD.PickslipNo = PH.PickSlipNo AND PH.Orderkey = @cOrderkey)
      WHERE PD.DropID = @cToteNo
   END

   IF @nTotalPickQty = @nTotalPackQty
   BEGIN
   /********************************
         PRINT LABEL
   *********************************/
      SET @cExtendedPrintSP = rdt.rdtGetConfig( @nFunc, 'ExtendedPrintSP', @cStorerKey)
      IF @cExtendedPrintSP = '0'
         SET @cExtendedPrintSP = ''

      -- Extended print (james12)
      IF @cExtendedPrintSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedPrintSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedPrintSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cOrderkey, @cSku, @cToteNo, @cDropIDType, @cPrevOrderkey,
                 @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
               '@nMobile         INT, '            +
               '@nFunc           INT, '            +
               '@cLangCode       NVARCHAR( 3), '   +
               '@nStep           INT, '            +
               '@nInputKey       INT, '            +
               '@cStorerkey      NVARCHAR( 15), '  +
               '@cOrderkey       NVARCHAR( 10), '  +
               '@cSku            NVARCHAR( 20), '  +
               '@cToteNo         NVARCHAR( 18), '  +
               '@cDropIDType     NVARCHAR( 10), '  +
               '@cPrevOrderkey   NVARCHAR( 10), '  +
               '@nErrNo          INT   OUTPUT, '   +
               '@cErrMsg         NVARCHAR( 215)  OUTPUT'

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cOrderkey, @cSku, @cToteNo, @cDropIDType, @cPrevOrderkey,
               @nErrNo OUTPUT, @cPrt_ErrMsg OUTPUT

            -- if printing fail still need to carry on the packing. no need rollback
            IF @nErrNo <> 0
            BEGIN
               SET @cErrMsg = @cPrt_ErrMsg

               --update rdtECOMMLog with the errmsg from printing
               UPDATE RDT.rdtECOMMLog WITH (ROWLOCK)
                  SET   ErrMsg = @cPrt_ErrMsg
               WHERE ToteNo      = @cToteNo
               AND   Orderkey    = @cOrderkey
               AND   AddWho      = @cUserName
               AND   Status      < '5'

               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 71449
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdEcommFail'
                  GOTO RollBackTran
               END
            END
         END
      END
      ELSE
      BEGIN
         -- (james10) start
         SET @cReportType = ''

         SELECT @cUDF01 = UDF01
         FROM dbo.CODELKUP WITH (NOLOCK)
         WHERE ListName = 'SHIPPING'
            AND Code = @cIncoTerm

         If ISNULL(@cUDF01, '') = 'YODEL'
         BEGIN
            SET @cReportType = 'BAGLABEL'
         END

         If ISNULL(@cUDF01, '') = 'C&C'
         BEGIN
            SET @cReportType = 'CCBAGLABEL'
         END

         If ISNULL(@cUDF01, '') = 'CITIPOST'
         BEGIN
            SET @cReportType = 'CITIPOST'
         END

         If ISNULL(@cUDF01, '') = 'DPD'
         BEGIN
            SELECT TOP 1 @cEUCountry = ISNULL(RTRIM(EUCountry),'N')
            FROM dbo.REPDPDCNT REPDPDCNT WITH (NOLOCK)         --(Kc11)
            JOIN dbo.ORDERS ORDERS WITH (NOLOCK) ON (ORDERS.CountryDestination = REPDPDCNT.IATAcode)
            WHERE ORDERS.Orderkey = @cOrderkey

            IF @cEUCountry = 'N'
            BEGIN
               SET @cReportType = 'NDPDLABEL'  -- (International DPD)
               SET @nErrNo = 0
               SET @cErrMsg = ''
               -- check dpd label data for international and europe
               -- if either has any validation issue, need to print dummy label instead
               EXEC dbo.isp_CheckDPDInternational
                     @c_StorerKey = @cStorerkey,
                     @c_OrderKey  = @cOrderkey,
                     @b_success   = @bSuccess OUTPUT,
                     @n_err       = @nErrNo   OUTPUT,
                     @c_errmsg    = @cErrMsg  OUTPUT

               IF @nErrNo <> 0
               BEGIN
                  SET @cReportType = 'DPDLABEL'
               END
               ELSE
               BEGIN
                  SET @nErrNo = 0
                  SET @cErrMsg = ''
                  -- check dpd label data - if any invalid need to print dummy label instead
                  EXEC dbo.isp_CheckDPDEurope
                        @c_StorerKey = @cStorerkey,
                        @c_OrderKey  = @cOrderkey,
                        @b_success   = @bSuccess OUTPUT,
                        @n_err       = @nErrNo   OUTPUT,
                        @c_errmsg    = @cErrMsg  OUTPUT

                  IF @nErrNo <> 0
                  BEGIN
                     SET @cReportType = 'DPDLABEL'
                  END
               END
            END
            ELSE
            BEGIN
               SET @cReportType = 'EDPDLABEL'  -- (Europe DPD)
               SET @nErrNo = 0
               SET @cErrMsg = ''
               -- check dpd label data - if any invalid need to print dummy label instead
               EXEC dbo.isp_CheckDPDEurope
                     @c_StorerKey = @cStorerkey,
                     @c_OrderKey  = @cOrderkey,
                     @b_success   = @bSuccess OUTPUT,
                     @n_err       = @nErrNo   OUTPUT,
                     @c_errmsg    = @cErrMsg  OUTPUT

               IF @nErrNo <> 0
               BEGIN
                  SET @cReportType = 'DPDLABEL'
               END
            END
         END

         IF ISNULL(@cReportType, '') = ''
         BEGIN
            SET @cPrintDummy = '0'
            SELECT @cPrintDummy = ISNULL(RTRIM(sValue), '0')
            FROM dbo.StorerConfig WITH (NOLOCK)
            WHERE Configkey = 'PRINT_DUMMYDPD'
            AND   Storerkey = @cStorerKey

            SET @cReportType = ''
            IF @cPrintDummy = '1'
            BEGIN
               -- if DPD Dummy label setup then print DPD Dummy first (james01)
               IF EXISTS (SELECT 1 FROM RDT.RDTReport WITH (NOLOCK)
                  WHERE StorerKey = @cStorerKey
                     AND ReportType = 'DPDLABEL')
               BEGIN
                  SET @cReportType = 'DPDLABEL'
               END
            END
         END

         -- Print Dummy DPD label if no report type matches
         IF ISNULL(@cReportType, '') = ''
         BEGIN
            SET @cReportType = 'DPDLABEL'
         END
         -- (james10) end

         SET @cPrintJobName = 'PRINT_BAGLABEL'           --(Kc06)

         SELECT @cDataWindow = ISNULL(RTRIM(DataWindow), ''),
                @cTargetDB = ISNULL(RTRIM(TargetDB), '')
         FROM RDT.RDTReport WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
         AND ReportType = @cReportType

         --(Kc03) - start
         IF ISNULL(RTRIM(@cDataWindow),'') = ''
         BEGIN
            SET @nErrNo = 69894
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'DLabelNOTSetup'
            GOTO RollBackTran
         END

         IF ISNULL(RTRIM(@cTargetDB),'') = ''
         BEGIN
            SET @nErrNo = 69895
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'NoDLabelTgetDB'
            GOTO RollBackTran
         END
         --(Kc03) - end

         --(Kc06) - start
         SET @nErrNo = 0
         -- (Kc13)
         IF @cReportType = 'DPDLABEL'
         BEGIN
            EXEC RDT.rdt_BuiltPrintJob
            @nMobile,
            @cStorerKey,
            @cReportType,
            @cPrintJobName,
            @cDataWindow,
            @cPrinter,
            @cTargetDB,
            @cLangCode,
            @nErrNo  OUTPUT,
            @cErrMsg OUTPUT,
            @cStorerKey,
            @cOrderkey
         END
         ELSE
         IF @cReportType = 'NDPDLABEL'
         BEGIN
            SELECT @cDataWindow = ISNULL(RTRIM(DataWindow), ''),
                   @cTargetDB = ISNULL(RTRIM(TargetDB), '')
            FROM RDT.RDTReport WITH (NOLOCK)
            WHERE StorerKey = @cStorerKey
            AND ReportType = 'NDPDLABEL'

            EXEC RDT.rdt_BuiltPrintJob
            @nMobile,
            @cStorerKey,
            'NDPDLABEL',
            @cPrintJobName,
            @cDataWindow,
            @cPrinter,
            @cTargetDB,
            @cLangCode,
            @nErrNo  OUTPUT,
            @cErrMsg OUTPUT,
            @cStorerKey,
            @cOrderkey

            SELECT @cDataWindow = ISNULL(RTRIM(DataWindow), ''),
                   @cTargetDB = ISNULL(RTRIM(TargetDB), '')
            FROM RDT.RDTReport WITH (NOLOCK)
            WHERE StorerKey = @cStorerKey
            AND ReportType = 'EDPDLABEL'

            EXEC RDT.rdt_BuiltPrintJob
            @nMobile,
            @cStorerKey,
            'EDPDLABEL',
            @cPrintJobName,
            @cDataWindow,
            @cPrinter,
            @cTargetDB,
            @cLangCode,
            @nErrNo  OUTPUT,
            @cErrMsg OUTPUT,
            @cStorerKey,
            @cOrderkey

         END
         ELSE
         IF @cReportType = 'CITIPOST'
         BEGIN
            EXEC RDT.rdt_BuiltPrintJob
            @nMobile,
            @cStorerKey,
            @cReportType,
            @cPrintJobName,
            @cDataWindow,
            @cPrinter,
            @cTargetDB,
            @cLangCode,
            @nErrNo  OUTPUT,
            @cErrMsg OUTPUT,
            @cStorerKey,
            @cOrderkey
         END
         ELSE
         BEGIN
            EXEC RDT.rdt_BuiltPrintJob
               @nMobile,
               @cStorerKey,
               @cReportType,
               @cPrintJobName,
               @cDataWindow,
               @cPrinter,
               @cTargetDB,
               @cLangCode,
               @nErrNo  OUTPUT,
               @cErrMsg OUTPUT,
               @cStorerKey,
               @cOrderkey,
               ' ',        --(Kc08)
               ' '         --(jamesxx)
         END

         IF @nErrNo <> 0            --(Kc06)
         BEGIN
            GOTO RollBackTran
         END
         ELSE
         BEGIN
            SET @nTotalPickQty = 0
            SET @nTotalPackQty = 0
            SELECT @nTotalPickQty = SUM(ISNULL(PK.Qty,0))
            FROM  dbo.PICKDETAIL PK WITH (nolock)
            WHERE PK.Orderkey = @cOrderkey

            SELECT @nTotalPackQty = SUM(ISNULL(PD.Qty,0))
            FROM  dbo.PACKDETAIL PD WITH (NOLOCK)
            JOIN  dbo.PACKHEADER PH WITH (NOLOCK) ON (PD.PickslipNo = PH.PickSlipNo AND PH.Orderkey = @cOrderkey)

            -- (Kc05) Start
            SET @nUnpicked = 0
            SELECT @nUnpicked = Count(1)
            FROM  dbo.PICKDETAIL PK WITH (nolock)
            WHERE PK.Orderkey = @cOrderkey
            AND   PK.Status < '5'
            AND   PK.Qty > 0     --(james07)
            -- (Kc05) end

            IF @nUnpicked = 0
            BEGIN
               -- make sure pick = pack then only confirm pack
               IF @nTotalPickQty = @nTotalPackQty
               BEGIN
                  UPDATE dbo.PACKHeader WITH (ROWLOCK)
                  SET   Status = '9', ArchiveCop=NULL
                  WHERE Orderkey = @cOrderkey
                  AND   Status = '0'

                  IF @@ERROR <> 0
                  BEGIN
                     SET @nErrNo = 69887
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdPackHdrFail'
                     GOTO RollBackTran
                  END
               END

               -- (Vicky02) - Start
               UPDATE DROPID WITH (ROWLOCK)
                 SET LabelPrinted = 'Y',
                     PickSlipNo = CASE WHEN ISNULL( PickSlipno, '') = '' THEN @cPickSlipno ELSE PickSlipno END -- (james01)
               WHERE Dropid = @cToteNo
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 70136
                  SET @cErrMsg = rdt.rdtgetmessage( 70136, @cLangCode, 'DSP') --'UpdDropIdFailed'
                  GOTO RollBackTran
               END
               -- (Vicky02) - End
            END
         END


         /********************************
            PRINT Manifest Report
         *********************************/
         SET @cReportType = 'BAGMANFEST'                 --(Kc06)
         SET @cPrintJobName = 'PRINT_BAGMANFEST'         --(Kc06)

         SELECT @cDataWindow = ISNULL(RTRIM(DataWindow), ''),
                @cTargetDB = ISNULL(RTRIM(TargetDB), '')
         FROM RDT.RDTReport WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
         AND ReportType = @cReportType                   --(Kc06)

         --(Kc03) - start
         IF ISNULL(RTRIM(@cDataWindow),'') = ''
         BEGIN
            SET @nErrNo = 69896
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'ManfstNOTSetup'
            GOTO RollBackTran
         END

         IF ISNULL(RTRIM(@cTargetDB),'') = ''
         BEGIN
            SET @nErrNo = 69897
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'NoManfstTgetDB'
            GOTO RollBackTran
         END
         --(Kc03) - end

         -- (james13)
         IF rdt.RDTGetConfig( @nFunc, 'SkipParkTote', @cStorerKey) IN ('', '0')
            SET @cOptional_Parm3 = ' '
         ELSE
            SET @cOptional_Parm3 = @cToteNo

         --(Kc06) - start
         SET @nErrNo = 0
         EXEC RDT.rdt_BuiltPrintJob
            @nMobile,
            @cStorerKey,
            @cReportType,
            @cPrintJobName,
            @cDataWindow,
            @cPrinter_Paper,
            @cTargetDB,
            @cLangCode,
            @nErrNo  OUTPUT,
            @cErrMsg OUTPUT,
            @cStorerKey,
            @cOrderkey,
            ' ',         --(jamesxx)
            @cOptional_Parm3           --(james13)

         IF @nErrNo <> 0               --(Kc06)
         BEGIN
            GOTO RollBackTran
         END
         ELSE
         BEGIN
            -- (Vicky02) - Start
            UPDATE DROPID WITH (ROWLOCK)
              SET ManifestPrinted = 'Y',
                  PickSlipNo = CASE WHEN ISNULL( PickSlipno, '') = '' THEN @cPickSlipno ELSE PickSlipno END -- (james01)
            WHERE Dropid = @cToteNo
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 70136
               SET @cErrMsg = rdt.rdtgetmessage( 70136, @cLangCode, 'DSP') --'UpdDropIdFailed'
               GOTO RollBackTran
            END
         -- (Vicky02) - End
         END
      END   -- End of extended print   (james12)
   END -- order fully despatch on 1 or more totes

   -- (james11)
   SET @cExtendedUpdateSP = ''
   SET @cExtendedUpdateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedUpdateSP', @cStorerkey)
   IF @cExtendedUpdateSP NOT IN ('0', '')
   BEGIN
      SET @nErrNo = 0
      SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
         ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cOrderkey, @cSku, @cToteNo, @cDropIDType, @cPrevOrderkey, ' +
         ' @nErrNo OUTPUT, @cErrMsg OUTPUT '

      SET @cSQLParam =
         '@nMobile                   INT, '           +
         '@nFunc                     INT, '           +
         '@cLangCode                 NVARCHAR( 3), '  +
         '@nStep                     INT, '           +
         '@nInputKey                 INT, '           +
         '@cStorerkey                NVARCHAR( 15), ' +
         '@cOrderkey                 NVARCHAR( 10), ' +
         '@cSku                      NVARCHAR( 20), ' +
         '@cToteNo                   NVARCHAR( 18), ' +
         '@cDropIDType               NVARCHAR( 10), ' +
         '@cPrevOrderkey             NVARCHAR( 10), ' +
         '@nErrNo                    INT           OUTPUT,  ' +
         '@cErrMsg                   NVARCHAR( 20) OUTPUT   '

      EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
           @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cOrderkey, @cSku, @cToteNo,  @cDropIDType, @cPrevOrderkey,
           @nErrNo OUTPUT, @cErrMsg OUTPUT

      IF @nErrNo <> 0
      BEGIN
         SET @nErrNo = 71446
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'ExtendUpd Fail'
         GOTO RollBackTran
      END
   END

   GOTO Quit

   ROLLBACKTRAN:
   BEGIN

      DECLARE CUR_UPD CURSOR LOCAL FOR
      SELECT RowRef FROM RDT.rdtECOMMLog WITH (NOLOCK)
      WHERE ToteNo      = @cToteNo
      AND   Orderkey    = @cOrderkey
      AND   AddWho      = @cUserName
      AND   Status      < '5'
      OPEN CUR_UPD
      FETCH NEXT FROM CUR_UPD INTO @nRowRef
      WHILE @@FETCH_STATUS <> -1
      BEGIN
         --update rdtECOMMLog
         UPDATE RDT.rdtECOMMLog WITH (ROWLOCK) SET
            Status      = '5',   -- error
            ErrMsg      = @cErrMsg
         WHERE RowRef = @nRowRef

         IF @@ERROR <> 0
         BEGIN
            CLOSE CUR_UPD
            DEALLOCATE CUR_UPD
            SET @nErrNo = 69906
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdEcommFail'
            BREAK
         END

         FETCH NEXT FROM CUR_UPD INTO @nRowRef
      END
      CLOSE CUR_UPD
      DEALLOCATE CUR_UPD

      ROLLBACK TRAN rdt_EcommDispatch_Confirm
   END

   QUIT:  
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started  
         COMMIT TRAN rdt_EcommDispatch_Confirm -- Only commit change made in here  

   FAIL:  

GO
SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: rdt_840ExtInsPack19                                */
/* Copyright      : Maersk                                              */
/*                                                                      */
/* Purpose: Insert/Update packdetail.                                   */
/*          Print sku label                                             */
/*                                                                      */
/* Called By: RDT Pack By Track No                                      */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/* 2023-03-31   James     1.0   WMS-22084. Created                      */
/* 2023-09-13   James     1.1   WMS-23401 Enhance ZPL print (james01)   */
/* 2023-12-15   JihHaur   1.2   JSM-197652 Hit PACK IN 1 CARTON even    */
/*                              just start first scanning   (JH01)      */
/* 2024-06-18   James     1.3   WMS-24295 Stamp PackDetail.UPC RDT      */
/*                              UserName (james02)                      */
/*                              Allow auto increase ctn no (james02)    */
/* 2024-11-08   PXL009    1.4   FCR-1118 Merged 1.3 from v0 branch      */
/************************************************************************/

CREATE   PROC [RDT].[rdt_840ExtInsPack19] (
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
           @cBillToKey        NVARCHAR( 15),
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
           @nNewCartonNo      INT,
           @cLabelLine        NVARCHAR( 5)

   DECLARE @b_success         INT,
           @n_err             INT,
           @c_errmsg          NVARCHAR( 20)

   DECLARE @cData1            NVARCHAR( 60)
   DECLARE @cRefType          NVARCHAR( 10)
   DECLARE @nRowCount         INT
   DECLARE @cOrderLineNumber  NVARCHAR( 5)
   DECLARE @nOriginalQty      INT
   DECLARE @cOrdType          NVARCHAR( 10)
   DECLARE @cC_Country        NVARCHAR( 30)
   DECLARE @cC_ISOCntryCode   NVARCHAR( 10)
   DECLARE @cStartNo          NVARCHAR( 10)
   DECLARE @cEndNo            NVARCHAR( 10)
   DECLARE @cCOO              NVARCHAR( 10) = ''
   DECLARE @nIsPrintCtnLbl    INT = 0
   DECLARE @cPreCtnLbl        NVARCHAR( 10)
   DECLARE @tPreCtnLbl        VariableTable
   DECLARE @cVASSSCC          NVARCHAR( 10)
   DECLARE @cLottableValue    NVARCHAR( 60)
   DECLARE @nCheckDigit       INT
   DECLARE @cErrMsg1          NVARCHAR( 20)
   DECLARE @cExternOrderKey   NVARCHAR( 50)

   DECLARE @nCHKCartonNo      INT = 0            --TSY01
   DECLARE @cDropID           NVARCHAR( 50)      --TSY01
   DECLARE @cDropIDCheck      NVARCHAR( 1) = '0' --TSY01
   DECLARE @nNewCtn           INT = 0
   DECLARE @cLottable01       NVARCHAR( 18)

   SET @nTranCount = @@TRANCOUNT

   BEGIN TRAN
   SAVE TRAN rdt_840ExtInsPack19

   SELECT @cUserName = UserName,
          @cFacility = Facility,
          @cData1    = I_Field02,
          @cLabelPrinter = Printer,
          @cPaperPrinter = Printer_Paper
         ,@cDropID = V_CaseID  --TSY01
   FROM rdt.rdtMOBREC WITH (NOLOCK)
   WHERE Mobile = @nMobile

   SET @cDropIDCheck = rdt.RDTGetConfig( @nFunc, 'CHKDropIDSKUQTY', @cStorerKey)

   --TSY01 START Look for Latest non closed Carton of the user
   --SET @nCHKCartonNo = 0
   --SELECT @nCHKCartonNo = MAX(PD.CARTONNO)
   --FROM dbo.PackDetail PD WITH (NOLOCK)
   --LEFT JOIN dbo.PackInfo PIF WITH (NOLOCK)
   --     ON PD.PickSlipNo = PIF.PickSlipNo and PD.CARTONNO = PIF.CARTONNO
   --WHERE PD.PickSlipNo = @cPickSlipNo
   --AND PD.Storerkey = @cStorerkey
   --AND PD.AddWho = 'rdt.' + @cUserName
   --AND ISNULL(PIF.PickSlipNo,'') = ''

   ----If Latest Carton <> current carton, 0 for trigger to create new carton
   --IF ISNULL(@nCHKCartonNo,0) <> @nCartonNo
   --   SET @nCartonNo = ISNULL(@nCHKCartonNo,0)

   --TSY01 END Look for Latest non closed Carton of the user

   -- (james02)
   -- This pickslip never packed anything before, set carton no = 0
   IF NOT EXISTS ( SELECT 1 FROM dbo.PackHeader WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo)
      SET @nNewCtn = 1
   ELSE
   BEGIN
      -- Get latest carton no for this carton
      SELECT @nCartonNo = MAX( CartonNo)
      FROM dbo.PackDetail WITH (NOLOCK)
      WHERE PickSlipNo = @cPickSlipNo
      AND   UPC = @cUserName

      -- New user packing new tote then get new carton no
      IF ISNULL( @nCartonNo, 0) = 0
         SET @nNewCtn = 1
      ELSE
      BEGIN
         -- Check if this carton already stamp with carton type
         -- If yes then get new carton no else continue using existing carton no
         IF EXISTS( SELECT 1
                    FROM dbo.PackInfo WITH (NOLOCK)
                    WHERE PickSlipNo = @cPickSlipNo
                    AND   CartonNo = @nCartonNo
                    AND   ISNULL( CartonType, '') <> '')
            SET @nNewCtn = 1
      END

      IF @nNewCtn = 1
      BEGIN
         SET @nCartonNo = 0
      END
   END

   IF EXISTS ( SELECT 1
               FROM dbo.ORDERS O WITH (NOLOCK)
               WHERE O.OrderKey = @cOrderKey
               AND   EXISTS ( SELECT 1
                              FROM dbo.CODELKUP CLK WITH (NOLOCK)
                              WHERE CLK.LISTNAME = 'STFCART'
                              AND   CLK.Code = O.ShipperKey
                              AND   CLK.Storerkey = O.StorerKey)) AND @nCartonNo <> 1 AND @nCartonNo <> 0 /*JH01*/
   BEGIN
      SET @nErrNo = 0
      SET @cErrMsg1 = 'PACK IN 1 CARTON'
      EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg1
      IF @nErrNo = 1
         SET @cErrMsg1 = ''
      SET @nErrNo = 198762
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Pack In 1 Ctn'
      GOTO RollBackTran
   END

   -- Piece scanning
   SET @nQty = 1
   SET @cLabelNo = ''
   SET @nNewCarton = 0

   --TSY01 START SET LABELNO TO EXISTING LABELNO

   IF ISNULL(@nCartonNo,0) <> 0 AND
      EXISTS (SELECT TOP 1 1
              FROM PACKDETAIL WITH (NOLOCK)
              WHERE PickSlipNo = @cPickSlipNo
              AND Storerkey = @cStorerkey
              AND CartonNo = @nCartonNo)
      SELECT @cLabelNo = LabelNo
      FROM PACKDETAIL PD WITH (NOLOCK)
      WHERE PickSlipNo = @cPickSlipNo
      AND Storerkey = @cStorerkey
      AND CartonNo = @nCartonNo

   --TSY01 END SET LABELNO TO EXISTING LABELNO

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
         SET @nErrNo = 198751
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
         SET @nErrNo = 198752
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsLog Failed'
         GOTO RollBackTran
      END
   END

   SELECT @cLoadKey = ISNULL(RTRIM(LoadKey),'')
         , @cRoute = ISNULL(RTRIM(Route),'')
         , @cConsigneeKey = ISNULL(RTRIM(ConsigneeKey),'')
         , @cBillToKey = ISNULL(RTRIM(BillToKey),'')
         , @cShipperKey = ShipperKey
         , @cOrdType = [Type]
         , @cC_Country = C_Country
         , @cC_ISOCntryCode = C_ISOCntryCode
         , @cExternOrderKey = ExternOrderKey
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
         SET @nErrNo = 198753
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsPKHDR Failed'
         GOTO RollBackTran
      END
   END

   -- Retrieve VASSSCC
   SELECT @cVASSSCC = Code
   FROM dbo.CODELKUP WITH (NOLOCK)
   WHERE listname = 'VASSSCC'
   AND   Storerkey = @cStorerkey

   -- Update PackDetail.Qty if it is already exists
   IF EXISTS (SELECT 1 FROM dbo.PackDetail WITH (NOLOCK)
               WHERE StorerKey = @cStorerkey
               AND PickSlipNo = @cPickSlipNo
               AND CartonNo = @nCartonNo
               AND RefNo2 = CASE WHEN @cDropIDCheck = '1' THEN ISNULL(@cDropID,'') ELSE RefNo2 END --TSY01
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
      AND RefNo2 = CASE WHEN @cDropIDCheck = '1' THEN ISNULL(@cDropID,'') ELSE RefNo2 END --TSY01

      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 198754
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
       SELECT
          @cStartNo = UDF01,
          @cEndNo = UDF02,
          @cKeyName = UDF03
       FROM dbo.CODELKUP WITH (NOLOCK)
       WHERE LISTNAME = 'LVSCTNNO'
       AND   Code = @cOrdType
       AND   ((Short = @cC_Country) OR (Short = @cC_ISOCntryCode))
       AND   Storerkey = @cStorerkey

       SET @nRowCount =  @@ROWCOUNT

       IF @nRowCount > 0
         BEGIN
            DECLARE @cRunningNo NVARCHAR( 10)
            EXECUTE dbo.nspg_GetKey
               @cKeyName,
               10 ,
               @cRunningNo        OUTPUT,
               @b_success         OUTPUT,
               @n_err             OUTPUT,
               @c_errmsg          OUTPUT

            IF @b_success <> 1
            BEGIN
               SET @nErrNo = 198755
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'GET LABEL Fail'
               GOTO RollBackTran
            END

            --SELECT 79305000 + (NCOUNTER % (79330000 - 79305000) )
            SET @cLabelNo = CAST( @cStartNo AS INT) + ( CAST( @cRunningNo AS INT) % (CAST( @cEndNo AS INT) - CAST( @cStartNo AS INT)) )
         END
         ELSE
         BEGIN
            -- Get new LabelNo
            --EXECUTE isp_GenUCCLabelNo
            --         @cStorerKey,
            --         @cLabelNo     OUTPUT,
            --         @bSuccess     OUTPUT,
            --         @nErrNo       OUTPUT,
            --         @cErrMsg      OUTPUT

            EXECUTE nspg_GetKey  
               @KeyName       = 'LVSPACKNO',   
               @fieldlength   = 10 ,  
               @keystring     = @cLabelNo   OUTPUT,  
               @b_Success     = @bSuccess   OUTPUT,  
               @n_err         = @n_err      OUTPUT,  
               @c_errmsg      = @c_errmsg   OUTPUT
               
            IF @bSuccess <> 1
            BEGIN
               SET @nErrNo = 198756
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'GET LABEL Fail'
               GOTO RollBackTran
            END
         END

         IF ISNULL( @cLabelNo, '') = ''
         BEGIN
            SET @nErrNo = 198757
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'GET LABEL Fail'
            GOTO RollBackTran
         END

         IF @nStep = 9
         BEGIN
            SELECT DISTINCT @cLottable01 = LOTTABLE01
            FROM dbo.LOTATTRIBUTE LA WITH (NOLOCK)
            JOIN dbo.LOTXLOCXID LLI WITH (NOLOCK) ON ( LLI.LOT = LA.LOT)
            WHERE LLI.StorerKey = @cStorerKey
            AND   LLI.SKU = @cSKU
            AND   LLI.QTY > 0

            SET @nRowCount = @@ROWCOUNT

            IF @nRowCount = 1 AND
               ISNULL( @cLottable01, '') <> '' AND
               EXISTS( SELECT 1
                        FROM dbo.CODELKUP WITH (NOLOCK)
                        WHERE LISTNAME = 'LVSCOO'
                        AND   Code = @cLottable01
                        AND   Storerkey = @cStorerKey
                        AND   LEN( Code) = 2)
               SET @cCOO = @cLottable01
            ELSE
               SET @cCOO = SUBSTRING( @cData1, 1, 10)
         END

         -- Check if this sku has already capture COO before
         -- Capture COO only happened 1 time per sku
         -- Posible for same sku packed into 2 carton
         IF @cCOO = ''
         BEGIN
            SELECT TOP 1 @cCOO = RefNo
            FROM dbo.PackDetail WITH (NOLOCK)
            WHERE PickSlipNo = @cPickSlipNo
            AND   SKU = @cSKU
            ORDER BY 1 DESC
         END

         SET @cLottableValue = RTRIM( @cVASSSCC) + RIGHT( @cLabelNo, 9)

         SET @nCheckDigit = dbo.fnc_CalcCheckDigit_M10( @cLottableValue, 0)

         SET @cLottableValue = @cLottableValue + CAST( @nCheckDigit AS NVARCHAR( 1))

         -- CartonNo = 0 & LabelLine = '0000', trigger will auto assign
         INSERT INTO dbo.PackDetail
            (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, QTY,
            Refno, UPC, AddWho, AddDate, EditWho, EditDate, DropID, LOTTABLEVALUE, Refno2)  --TSY01
         VALUES
            (@cPickSlipNo, 0, @cLabelNo, '00000', @cStorerKey, @cSku, @nQty,
            ISNULL( @cCOO, ''), @cUserName, 'rdt.' + sUser_sName(), GETDATE(), 'rdt.' + sUser_sName(), GETDATE(), '', @cLottableValue, @cDropID) --TSY01

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 198758
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'INS PACK Fail'
            GOTO RollBackTran
         END
         ELSE
            SELECT @nNewCarton = CartonNo
            FROM dbo.PackDetail WITH (NOLOCK)
            WHERE PickSlipNo = @cPickSlipNo
            AND   LabelNo = @cLabelNo
            AND   StorerKey = @cStorerKey

         -- Create a dummy label and a cartontrack record
         IF EXISTS ( SELECT 1
                     FROM dbo.CODELKUP WITH (NOLOCK)
                     WHERE LISTNAME = 'LVSPLTCUST'
                     AND   Code = @cBillToKey
                     AND   Short = '1'
                     AND   Storerkey = @cStorerkey
                     AND   ISNULL( UDF01, '') <> 'VAS'
                     AND ( ISNULL( UDF02, '') IN ( 'BULK', 'OVERSEAS')))
         BEGIN
          DECLARE @c_ZPLCode   NVARCHAR( MAX)

            -- EXEC isp_GenZPL_interface 'LVS', '', 'ZPLCONFIG','P000008985', '0000002227', '1','LVS','','MANUAL',  @ZPLCODE OUTPUT,0,0,''
            EXEC isp_GenZPL_interface
                 @c_StorerKey    = @cStorerkey
               , @c_Facility     = @cFacility
               , @c_ReportType   = 'ZPLCONFIG'
               , @c_Param01      = @cPickSlipNo
               , @c_Param02      = @cLabelNo
               , @c_Param03      = @nNewCarton
               , @c_Param04      = @cStorerkey
               , @c_Param05      = ''
               , @c_SourceType   = @nFunc
               , @c_ZPLCode      = @c_ZPLCode   OUTPUT
               , @b_success      = @bSuccess    OUTPUT
               , @n_err          = @nErrNo      OUTPUT
               , @c_errmsg       = @cErrMsg     OUTPUT

            IF @bSuccess = 0
            BEGIN
               SET @nErrNo = 198759
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Exec ITF Fail
               GOTO RollBackTran
            END

            SET @nIsPrintCtnLbl = 1
         END

        IF EXISTS ( SELECT 1
                     FROM dbo.CODELKUP WITH (NOLOCK)
                     WHERE LISTNAME = 'LVSPLTCUST'
                     AND   Code = @cBillToKey
                   AND   Short = '1'
                     AND   Storerkey = @cStorerkey
                     AND   ISNULL( UDF01, '') = 'VAS'
                     AND   ISNULL( UDF02, '') = 'BULK')
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
                  SET @nErrNo = 198763
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
                  SET @nErrNo = 198764
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Upd Trk# Fail
                  GOTO RollBackTran
               END
            END
         END
      END
      ELSE
      BEGIN
         SET @cCurLabelNo = ''
         SET @cCurLabelLine = ''

         SELECT TOP 1 @cCurLabelNo = LabelNo
         FROM dbo.PackDetail WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
         AND   PickSlipNo = @cPickSlipNo
         AND   CartonNo = @nCartonNo

         SELECT @cCurLabelLine = RIGHT( '00000' + CAST( CAST( IsNULL( MAX( LabelLine), 0) AS INT) + 1 AS NVARCHAR( 5)), 5)
         FROM dbo.PackDetail WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
         AND   PickSlipNo = @cPickSlipNo
         AND   CartonNo = @nCartonNo

         IF @nStep = 9
            SET @cCOO = SUBSTRING( @cData1, 1, 10)
         ELSE
         BEGIN
            -- Check if this sku has already capture COO before
            -- Capture COO only happened 1 time per sku
            -- Posible for same sku packed into 2 carton
            SELECT TOP 1 @cCOO = RefNo
            FROM dbo.PackDetail WITH (NOLOCK)
            WHERE StorerKey = @cStorerKey
            AND   PickSlipNo = @cPickSlipNo
            AND   SKU = @cSKU
            ORDER BY 1

         END

         SET @cLottableValue = RTRIM( @cVASSSCC) + RIGHT( @cCurLabelNo, 9)

         SET @nCheckDigit = dbo.fnc_CalcCheckDigit_M10( @cLottableValue, 0)

         SET @cLottableValue = @cLottableValue + CAST( @nCheckDigit AS NVARCHAR( 1))

         -- need to use the existing labelno
         INSERT INTO dbo.PackDetail
            (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, QTY,
            Refno, UPC, AddWho, AddDate, EditWho, EditDate, DropID, LOTTABLEVALUE, Refno2) --TSY01
         VALUES
            (@cPickSlipNo, @nCartonNo, @cCurLabelNo, @cCurLabelLine, @cStorerKey, @cSku, @nQty,
            ISNULL( @cCOO, ''), @cUserName, 'rdt.' + sUser_sName(), GETDATE(), 'rdt.' + sUser_sName(), GETDATE(), '', @cLottableValue, @cDropID) --TSY01

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 198760
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'INS PACK Fail'
            GOTO RollBackTran
         END

         SET @cLabelNo = @cCurLabelNo
      END
   END

   GOTO Quit

   RollBackTran:
         ROLLBACK TRAN rdt_840ExtInsPack19
   Quit:
      WHILE @@TRANCOUNT > @nTranCount
         COMMIT TRAN

   IF EXISTS ( SELECT 1
               FROM dbo.STORER WITH (NOLOCK)
               WHERE StorerKey = @cBillToKey
               AND   Facility = @cFacility
               AND   [type] = '2'
               AND   LabelPrice = 'Y')
   BEGIN
    IF NOT EXISTS ( SELECT 1
                FROM dbo.CODELKUP WITH (NOLOCK)
                WHERE LISTNAME = 'PriceLBL2'
                AND   Code = @cConsigneeKey
                AND   StorerKey = @cStorerkey)
      BEGIN
       DECLARE @cPriceLabel1   NVARCHAR( 10)
       DECLARE @tPriceLabel1   VariableTable

         SET @cPriceLabel1 = rdt.RDTGetConfig( @nFunc, 'PriceLbl01', @cStorerKey)
         IF @cPriceLabel1 = '0'
            SET @cPriceLabel1 = ''

         IF @cPriceLabel1 <> ''
         BEGIN
            INSERT INTO @tPriceLabel1 (Variable, Value) VALUES ( '@cPickSlipNo',    @cPickSlipNo)
            INSERT INTO @tPriceLabel1 (Variable, Value) VALUES ( '@cOrderkey',      @cOrderkey)
            INSERT INTO @tPriceLabel1 (Variable, Value) VALUES ( '@nCartonNo',      @nCartonNo)
            INSERT INTO @tPriceLabel1 (Variable, Value) VALUES ( '@cLabelNo',       @cLabelNo)
            INSERT INTO @tPriceLabel1 (Variable, Value) VALUES ( '@cSKU',           @cSKU)

            -- Print label
            EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, 0, 1, '', @cStorerKey, @cLabelPrinter, '',
               @cPriceLabel1, -- Report type
               @tPriceLabel1, -- Report params
               'rdt_840ExtInsPack19',
               @nErrNo  OUTPUT,
               @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Fail
         END
      END
      ELSE
      BEGIN
       DECLARE @cPriceLabel2   NVARCHAR( 10)
       DECLARE @tPriceLabel2   VariableTable

         SET @cPriceLabel2 = rdt.RDTGetConfig( @nFunc, 'PriceLbl02', @cStorerKey)
         IF @cPriceLabel2 = '0'
            SET @cPriceLabel2 = ''

         IF @cPriceLabel2 <> ''
         BEGIN
            INSERT INTO @tPriceLabel2 (Variable, Value) VALUES ( '@cPickSlipNo',    @cPickSlipNo)
            INSERT INTO @tPriceLabel2 (Variable, Value) VALUES ( '@cOrderkey',      @cOrderkey)
            INSERT INTO @tPriceLabel2 (Variable, Value) VALUES ( '@nCartonNo',      @nCartonNo)
            INSERT INTO @tPriceLabel2 (Variable, Value) VALUES ( '@cLabelNo',       @cLabelNo)
            INSERT INTO @tPriceLabel2 (Variable, Value) VALUES ( '@cSKU',           @cSKU)

              -- Print label
            EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, 0, 1, '', @cStorerKey, @cLabelPrinter, '',
               @cPriceLabel2, -- Report type
               @tPriceLabel2, -- Report params
               'rdt_840ExtInsPack19',
               @nErrNo  OUTPUT,
               @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Fail
         END
      END
   END

   IF @nIsPrintCtnLbl = 1
   BEGIN
      SET @cPreCtnLbl = rdt.RDTGetConfig( @nFunc, 'PreCtnLbl', @cStorerKey)
      IF @cPreCtnLbl = '0'
         SET @cPreCtnLbl = ''

      IF @cPreCtnLbl <> ''
      BEGIN
         INSERT INTO @tPreCtnLbl (Variable, Value) VALUES ( '@cPickSlipNo',    @cPickSlipNo)
         INSERT INTO @tPreCtnLbl (Variable, Value) VALUES ( '@cOrderkey',      @cOrderkey)
         INSERT INTO @tPreCtnLbl (Variable, Value) VALUES ( '@nCartonNo',      @nNewCarton)
         INSERT INTO @tPreCtnLbl (Variable, Value) VALUES ( '@cLabelNo',       @cLabelNo)

         -- Print label
         EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, 0, 1, '', @cStorerKey, @cLabelPrinter, '',
            @cPreCtnLbl, -- Report type
            @tPreCtnLbl, -- Report params
            'rdt_840ExtInsPack19',
            @nErrNo  OUTPUT,
            @cErrMsg OUTPUT
      END
   END
   Fail:
END

GO
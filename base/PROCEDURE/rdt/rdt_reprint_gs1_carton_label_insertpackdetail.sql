SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_Reprint_GS1_Carton_Label_InsertPackDetail       */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Reprint GS1 lable and insert PackDetail                     */
/*                                                                      */
/* Called from: rdtfnc_Reprint_GS1_Carton_Label                         */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author    Purposes                                  */
/* 24-Jun-2011 1.0  James     Created                                   */
/************************************************************************/

CREATE PROC [RDT].[rdt_Reprint_GS1_Carton_Label_InsertPackDetail] (
   @nMobile                INT,
   @cFacility              NVARCHAR( 5),
   @cStorerKey             NVARCHAR( 15),
   @cDropID                NVARCHAR( 18),
   @cOrderKey              NVARCHAR( 10),
   @cPickSlipType          NVARCHAR( 10),
   @cPickSlipNo            NVARCHAR( 10), -- can be conso ps# or discrete ps#; depends on pickslip type
   @cBuyerPO               NVARCHAR( 20),
   @cFilePath1             NVARCHAR( 20),
   @cFilePath2             NVARCHAR( 20),
   @n_PrePack              INT,
   @cUserName              NVARCHAR( 18),
   @cGS1TemplatePath_Final NVARCHAR( 120),
   @cPrinter               NVARCHAR( 20),
   @cLangCode              VARCHAR (3),
   @nErrNo                 INT          OUTPUT,
   @cErrMsg                NVARCHAR( 20) OUTPUT  -- screen limitation, 20 char max
) AS
BEGIN

   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF

   DECLARE
      @b_success      INT,
      @n_err          INT,
      @c_errmsg       NVARCHAR( 255)

   DECLARE
      @cPickHeaderKey NVARCHAR( 10),
      @cLabelLine     NVARCHAR( 5),
      @cComponentSku  NVARCHAR( 20),
      @nComponentQTY  INT,
      @nTranCount     INT,
      @cYYYY          NVARCHAR( 4),
      @cMM            NVARCHAR( 2),
      @cDD            NVARCHAR( 2),
      @cHH            NVARCHAR( 2),
      @cMI            NVARCHAR( 2),
      @cSS            NVARCHAR( 2),
      @cDateTime      NVARCHAR( 17),
      @cSPID          NVARCHAR( 5),
      @cFileName      NVARCHAR( 215),
      @cWorkFilePath  NVARCHAR( 120),
      @cMoveFilePath  NVARCHAR( 120),
      @cFilePath      NVARCHAR( 120),
      @nSumQtyPicked  INT,
      @nSumQtyPacked  INT,
      @nMax_CartonNo  INT,
      @cPackkey       NVARCHAR( 10),
      @nTotalLoop     INT,
      @nUPCCaseCnt    INT,
      @cParentSKU     NVARCHAR( 20),
      @nTotalBOMQty   INT,
      @nCaseCnt       INT,
      @cPDPackkey     NVARCHAR( 10),
      @cPalletID      NVARCHAR( 10),
      @nPDQTY         INT,
      @nCartonNo      INT,
      @cLabelNo       NVARCHAR( 20),
      @cMS            NVARCHAR( 3),
      @dTempDateTime DATETIME

   SET @nTranCount = @@TRANCOUNT

   BEGIN TRAN
   SAVE TRAN GS1_InsertPackDetail

   SET @nCartonNo = 0

   --- GET USERNAME ---
   SELECT @cUserName = UserName FROM RDT.RDTMOBREC WITH (NOLOCK)
   WHERE MOBILE = @nMobile

   SET @cLabelLine = '00000'

   SET @nTotalLoop = 0
   -- Get the next label no

   --SOS# 183480
   INSERT INTO dbo.GS1LOG
   ( MobileNo, UserName, TraceName
   , PickSlipNo, OrderKey, DropId
   , StorerKey, Facility, Col1, Col2, Col3, Col10 )
   VALUES(@nMobile, @cUserName, 'GS1SubSP'
         , @cPickSlipNo, @cOrderkey, @cDropID
         , @cStorerkey, @cFacility, @cPickSlipType, @n_PrePack, @@SPID, '*')

   DECLARE CUR_INSPACKDETAILBOM CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
   SELECT DISTINCT LA.Lottable03 FROM dbo.PickDetail PD WITH (NOLOCK)
   INNER JOIN dbo.LOTATTRIBUTE LA (NOLOCK) ON (LA.Storerkey = PD.Storerkey AND LA.SKU = PD.SKU AND
                                               LA.LOT = PD.LOT)
   WHERE PD.StorerKey = @cStorerkey
   AND   PD.Orderkey = @cOrderkey
   AND   PD.DropID = @cDropID
   OPEN CUR_INSPACKDETAILBOM
   FETCH NEXT FROM CUR_INSPACKDETAILBOM INTO @cParentSKU
   WHILE @@FETCH_STATUS <> - 1
   BEGIN
      SET @nTotalLoop   = 0 -- SOS# 183480
      SET @nUPCCaseCnt  = 0 -- SOS# 183480
      SET @nPDQTY       = 0 -- SOS# 183480
      SET @nTotalBOMQty = 0 -- SOS# 183480

      SELECT @nUPCCaseCnt = ISNULL(PACK.CaseCnt, 0)
      FROM dbo.PACK PACK WITH (NOLOCK)
      JOIN dbo.UPC UPC WITH (NOLOCK) ON (UPC.Packkey = PACK.Packkey)
      WHERE UPC.SKU = @cParentSKU
      AND   UPC.Storerkey = @cStorerkey
      AND   UPC.UOM = 'CS'

      SELECT @nPDQTY = SUM(PD.QTY)
      FROM dbo.PickDetail PD WITH (NOLOCK, INDEX(IDX_PICKDETAIL_DropID))
      JOIN dbo.Lotattribute LA WITH (NOLOCK) ON (PD.Storerkey = LA.Storerkey and PD.SKU = LA.SKU AND
                                                      PD.LOT = LA.Lot)
      WHERE PD.DropID = @cDropID
      AND   LA.Lottable03 = @cParentSKU
      AND   PD.Storerkey = @cStorerkey
      AND   PD.Orderkey = @cOrderkey

      SELECT @nTotalBOMQty = SUM(BOM.QTY)
      FROM dbo.BillOfMaterial BOM WITH (NOLOCK)
      WHERE BOM.Storerkey = @cStorerKey
      AND   BOM.SKU = @cParentSKU

      --SOS# 183480
      INSERT INTO dbo.GS1LOG
      ( MobileNo, UserName, TraceName
      , PickSlipNo, OrderKey, DropId
      , StorerKey, Facility, Col1, Col2, Col3
      , Col4, Col5, Col6, Col7, Col10 )
      VALUES(@nMobile, @cUserName, 'GS1SubSP'
         , @cPickSlipNo, @cOrderkey, @cDropID
         , @cStorerkey, @cFacility, @cPickSlipType, @n_PrePack, @@SPID
         , @cParentSKU, @nTotalBOMQty, @nUPCCaseCnt, @nPDQTY, '**')

      IF @nTotalBOMQty > 0 AND @nUPCCaseCnt > 0 -- SOS# 183480
      BEGIN
         SELECT @nTotalLoop = CEILING(@nPDQTY / (@nTotalBOMQty * @nUPCCaseCnt))
      END

      WHILE @nTotalLoop > 0
      BEGIN
         EXECUTE [RDT].[rdt_GenUCCLabelNo]
             @cStorerKey,
             @nMobile,
             @cLabelNo OUTPUT,
             @cLangCode,
             @nErrNo   OUTPUT,
             @cErrMsg  OUTPUT

         --SOS# 183480
         INSERT INTO dbo.GS1LOG
         ( MobileNo, UserName, TraceName
         , PickSlipNo, OrderKey, DropId
         , StorerKey, Facility, Col1, Col2, Col3
         , Col4, Col5, Col6, Col7, Col10 )
         VALUES(@nMobile, @cUserName, 'GS1SubSP'
         , @cPickSlipNo, @cOrderkey, @cDropID
         , @cStorerkey, @cFacility, @cLabelNo, @nErrNo, ''
         , '', '', '', '', 'UCCLBL')

         IF @nErrNo <> 0
         BEGIN
            SET @nErrNo = 68748
            SET @cErrMsg = rdt.rdtgetmessage( 68748, @cLangCode, 'DSP') --'Gen LBLNo Fail'
            GOTO RollBackTran
         END

         DECLARE CUR_BOM CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
         SELECT ComponentSKU, QTY from dbo.BILLOFMATERIAL WITH (NOLOCK)
         WHERE SKU = @cParentSKU
         AND StorerKey = @cStorerKey -- (james01)
         OPEN CUR_BOM
         FETCH NEXT FROM CUR_BOM INTO @cComponentSKU, @nComponentQTY
         WHILE @@FETCH_STATUS <> - 1
         BEGIN
            IF NOT EXISTS ( SELECT 1 FROM dbo.PackDetail WITH (NOLOCK)
                      WHERE Pickslipno = @cPickSlipNo
                      AND Storerkey    = @cStorerKey
                      AND SKU          = @cComponentSku
                      AND LabelNo      = @cLabelNo)
            BEGIN
               INSERT INTO dbo.PackDetail
                  (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, QTY, Refno, AddWho, AddDate, EditWho, EditDate)
               VALUES
                  (@cPickSlipNo, @nCartonNo, @cLabelNo, @cLabelLine, @cStorerKey, @cComponentSku, @nComponentQTY, 
                   @cDropID, @cUserName, GETDATE(), @cUserName, GETDATE())

               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 68749
                  SET @cErrMsg = rdt.rdtgetmessage( 68749, @cLangCode, 'DSP') --'InsPackDFail'
                  GOTO RollBackTran
               END
            END

            FETCH NEXT FROM CUR_BOM INTO @cComponentSKU, @nComponentQTY
         END
         CLOSE CUR_BOM
         DEALLOCATE CUR_BOM

         -----SOS# 183480 Start
         INSERT INTO dbo.DropIDDetail
         (DROPID, CHILDID, AddWho, EditWho, ArchiveCop)
         VALUES (@cDropID, @cLabelNo, @cUserName, @cUserName, 'd')

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 68750
            SET @cErrMsg = rdt.rdtgetmessage( 68750, @cLangCode, 'DSP') --'InsDropIDDet'
            GOTO RollBackTran
         END
         -----SOS# 183480 End

         SET @nTotalLoop = @nTotalLoop - 1
      END -- @nTotalLoop > 0

      FETCH NEXT FROM CUR_INSPACKDETAILBOM INTO @cParentSKU
   END -- CUR_INSPACKDETAILBOM
   CLOSE CUR_INSPACKDETAILBOM
   DEALLOCATE CUR_INSPACKDETAILBOM

   SET @cLabelNo = ''

   DECLARE CUR_GSILABEL CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
   SELECT DISTINCT PD.LabelNo , PD.CartonNo FROM dbo.PackDetail PD WITH (NOLOCK)
   INNER JOIN dbo.PACKHEADER PH WITH (NOLOCK)
   ON PD.PickslipNo = PH.PickslipNO
   WHERE PH.Orderkey = @cOrderkey
   AND PD.RefNo = @cDropID
   OPEN CUR_GSILABEL
   FETCH NEXT FROM CUR_GSILABEL INTO @cLabelNo, @nCartonNo
   WHILE @@FETCH_STATUS <> - 1
   BEGIN

      SET @dTempDateTime = GetDate()

      SET @cYYYY = RIGHT( '0' + ISNULL(RTRIM( DATEPART( yyyy, @dTempDateTime)), ''), 4)
      SET @cMM = RIGHT( '0' + ISNULL(RTRIM( DATEPART( mm, @dTempDateTime)), ''), 2)
      SET @cDD = RIGHT( '0' + ISNULL(RTRIM( DATEPART( dd, @dTempDateTime)), ''), 2)
      SET @cHH = RIGHT( '0' + ISNULL(RTRIM( DATEPART( hh, @dTempDateTime)), ''), 2)
      SET @cMI = RIGHT( '0' + ISNULL(RTRIM( DATEPART( mi, @dTempDateTime)), ''), 2)
      SET @cSS = RIGHT( '0' + ISNULL(RTRIM( DATEPART( ss, @dTempDateTime)), ''), 2)
      SET @cMS = RIGHT( '0' + ISNULL(RTRIM( DATEPART( ms, @dTempDateTime)), ''), 3)

      SET @cDateTime = @cYYYY + @cMM + @cDD + @cHH + @cMI + @cSS + @cMS

      SET @cSPID = @@SPID
      SET @cFilename = ISNULL(RTRIM(@cPrinter), '') + '_' + @cDateTime + '_' + ISNULL(RTRIM(@cLabelNo), '') + '.XML'
      SET @cFilePath = ISNULL(RTRIM(@cFilePath1), '') + ISNULL(RTRIM(@cFilePath2), '')
      SET @cWorkFilePath = ISNULL(RTRIM(@cFilePath), '') + 'Working'

      -- Clear the XML record
      DELETE FROM RDT.RDTGSICartonLabel_XML with (rowlock) WHERE [SPID] = @@SPID

      EXEC dbo.isp_GSICartonLabel_NTT
         ''
         , @cOrderKey
         , @cGS1TemplatePath_Final
         , @cPrinter
         , @cFileName
         , @nCartonNo
         , @cDropID 

      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 70666
         SET @cErrMsg = rdt.rdtgetmessage( 70666, @cLangCode, 'DSP') --'GenGSILabelFail'
         GOTO RollBackTran
      END

      --SOS# 183480
      INSERT INTO dbo.GS1LOG
      ( MobileNo, UserName, TraceName
      , PickSlipNo, OrderKey, DropId
      , StorerKey, Facility, Col1, Col2, Col3
      , Col4, Col5, Col6, Col7, Col10 )
      VALUES(@nMobile, @cUserName, 'GS1SubSP'
            , @cPickSlipNo, @cOrderkey, @cDropID
            , @cStorerkey, @cFacility, @nCartonNo, @nErrNo, ''
            , '', '', '', '', 'GS1LBL')

      -- Check the last char of the file path consists of '\'
      IF SUBSTRING(ISNULL(RTRIM(@cFilePath), ''), LEN(ISNULL(RTRIM(@cFilePath), '')), 1) <> '\'
      BEGIN
         SET @cFilePath = ISNULL(RTRIM(@cFilePath), '') + '\'
      END

      SET @cMoveFilePath = ISNULL(RTRIM(@cFilePath), '')

      EXECUTE [RDT].[rdt_PrintGSILabel]
         @@SPID,
         @cWorkFilePath,
         @cMoveFilePath,
         @cFileName,
         @cLangCode,
         @nErrNo   OUTPUT,
         @cErrMsg  OUTPUT

      IF @nErrNo <> 0
      BEGIN
         SET @nErrNo = 66281
         SET @cErrMsg = rdt.rdtgetmessage( 66281, @cLangCode, 'DSP') --'GSILBLCrtFail'
         GOTO RollBackTran
      END

      --SOS# 183480
      INSERT INTO dbo.GS1LOG
      ( MobileNo, UserName, TraceName
      , PickSlipNo, OrderKey, DropId
      , StorerKey, Facility, Col1, Col2, Col3
      , Col4, Col5, Col6, Col7, Col10 )
      VALUES(@nMobile, @cUserName, 'GS1SubSP'
            , @cPickSlipNo, @cOrderkey, @cDropID
            , @cStorerkey, @cFacility, '', @nErrNo, @@SPID
            , '', '', '', '', 'PrtGS1LBL')

      FETCH NEXT FROM CUR_GSILABEL INTO @cLabelNo, @nCartonNo
   END -- WHILE @nMax_CartonNo > 0
   CLOSE CUR_GSILABEL
   DEALLOCATE CUR_GSILABEL

   GOTO Quit

   RollBackTran:
      ROLLBACK TRAN GS1_InsertPackDetail

   Quit:
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
         COMMIT TRAN GS1_InsertPackDetail
END

GO
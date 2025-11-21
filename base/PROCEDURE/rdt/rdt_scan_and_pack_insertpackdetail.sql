SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_Scan_And_Pack_InsertPackDetail                  */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Insert PackDetail after each scan of Case ID                */
/*                                                                      */
/* Called from: rdtfnc_Scan_And_Pack                                    */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author    Purposes                                  */
/* 14-Apr-2009 1.0  James     Created                                   */
/* 15-Jun-2009 1.1  James     Add TraceInfo                             */
/* 18-Jun-2009 1.2  KKY       Added debug flag to Traceinfo             */
/* 25-Jun-2009 1.3  Leong     SOS# 140526 - Bug Fix for GS1 path        */
/* 26-Jun-2009 1.4  KKY       Added carton no to filename               */
/*                            Added filename and carton # to traceinfo  */
/* 29-Jun-2009 1.5  KKY       Start Modified to have millisecond and    */
/*                            getchar() into a var  (KY20090629)        */
/* 30-Jun-2009 1.6  Vicky     SOS#140289 - Should include casecnt during*/
/*                            scanning (Vicky01)                        */
/* 08-Jul-2009 1.7  Vicky     Assign CartonNo = 0 to let PackDetailAdd  */
/*                            trigger to assign CartonNo to prevent     */
/*                            same CartonNo being assigned to 2         */
/*                            different LabelNo (Vicky02)               */
/* 13-Aug-2009 1.8  James     SOS144772 - Change xml filename to format */
/*                            PrinterID_YYYYMMDDHHmmsss_Labelno(james01)*/
/* 22-Oct-2009 1.9  James     Bug fix. (james02)                        */
/* 17-Mar-2010 1.10 James     SOS149590 - Change the destination of the */
/*                            xml based on folder setup in codelkup.long*/
/*                            = subfolder name (james03)                */
/* 02-Jun-2010 1.11 Shong     Skip to Print GS1 Label If exists in      */
/*                            Codelkup ListName = 'SKIPGS1LBL'          */
/* 31-Mar-2011 1.12 Shong     TCP Printing Features for Bartender       */
/* 21-Jun-2011 1.13 James     SOS217551 - Cater for non bom (james06)   */
/* 06-Jan-2012 1.14 Ung       SOS231812 Standarize print GS1 to use     */
/*                            Exceed logic                              */
/************************************************************************/

CREATE PROC [RDT].[rdt_Scan_And_Pack_InsertPackDetail] (
  @nMobile        INT
 ,@cFacility      NVARCHAR(5)
 ,@cStorerKey     NVARCHAR(15)
 ,@cMBOLKey       NVARCHAR(10)
 ,@cLoadKey       NVARCHAR(10)
 ,@cOrderKey      NVARCHAR(10)
 ,@cPickSlipType  NVARCHAR(10)
 ,@cPickSlipNo    NVARCHAR(10)	-- can be conso ps# or discrete ps#; depends on pickslip type
 ,@cDiscrete_PickSlipNo NVARCHAR(10)
 ,@cBuyerPO       NVARCHAR(20)
 ,@cFilePath1     NVARCHAR(20)
 ,@cFilePath2     NVARCHAR(20)
 ,@cSKU           NVARCHAR(20)	-- If PrePackByBOM turned on then this is UPC_SKU else this is SKU code
 ,@nQTY           INT	-- 1 qty = 1 case
 ,@cPrepackByBOM  NVARCHAR(1)
 ,@cUserName      NVARCHAR(18)
 , --@cTemplateID          NVARCHAR( 20),
   --@cGS1TemplatePath     NVARCHAR( 120), -- SOS# 140526
  @cGS1TemplatePath_Final NVARCHAR(120)	-- (Vicky01)
 ,@cPrinter       NVARCHAR(20)
 ,@cLangCode      NVARCHAR(3)
 ,@nCaseCnt       INT	-- (Vicky01)
 ,@nCartonNo      INT OUTPUT
 ,@cLabelNo       NVARCHAR(20) OUTPUT
 ,@nErrNo         INT OUTPUT
 ,@cErrMsg        NVARCHAR(20) OUTPUT -- screen limitation, 20 char max
) AS
BEGIN
    SET NOCOUNT ON
    SET QUOTED_IDENTIFIER OFF
    SET ANSI_NULLS OFF

    DECLARE @b_success       INT
           ,@n_err           INT
           ,@c_errmsg        NVARCHAR(255)

    DECLARE @cPickHeaderKey  NVARCHAR(10)
           ,@cLabelLine      NVARCHAR(5)
           ,@cComponentSku   NVARCHAR(20)
           ,@nComponentQTY   INT
           ,@nTranCount      INT
           ,@cYYYY           NVARCHAR(4)
           ,@cMM             NVARCHAR(2)
           ,@cDD             NVARCHAR(2)
           ,@cHH             NVARCHAR(2)
           ,@cMI             NVARCHAR(2)
           ,@cSS             NVARCHAR(2)
           ,@cDateTime       NVARCHAR(17)	--KY20090629 Changed 14 to 17 char to accomodate milliseconds
           ,@cSPID           NVARCHAR(5)
           ,@cFileName       NVARCHAR(215)
           ,@cWorkFilePath   NVARCHAR(120)
           ,@cMoveFilePath   NVARCHAR(120)
           ,@cFilePath       NVARCHAR(120)
           ,@nSumQtyPicked   INT
           ,@nSumQtyPacked   INT
           ,@nMax_CartonNo   INT	-- (Vicky02)
           ,@cPrinterFolder  NVARCHAR(50) -- (james03)

    --  KY20090629
    DECLARE @cMS             NVARCHAR(3)
           ,@dTempDateTime   DATETIME

    DECLARE @c_TCP_Authority NVARCHAR(1)

    DECLARE @n_debug         INT

    SET @n_debug = 0

    IF @n_debug = 1
    BEGIN
        DECLARE @d_starttime  DATETIME
               ,@d_endtime    DATETIME
               ,@d_step1      DATETIME
               ,@d_step2      DATETIME
               ,@d_step3      DATETIME
               ,@d_step4      DATETIME
               ,@d_step5      DATETIME
               ,@c_col1       NVARCHAR(20)
               ,@c_col2       NVARCHAR(20)
               ,@c_col3       NVARCHAR(20)
               ,@c_col4       NVARCHAR(20)
               ,@c_col5       NVARCHAR(20)
               ,@c_TraceName  NVARCHAR(80)

        SET @c_col1 = ''
        SET @c_col1 = @cOrderKey
        SET @c_col2 = @cSKU
        SET @c_col3 = @nQTY
        SET @c_col4 = @cPrinter

        SET @d_starttime = GETDATE()

        SET @c_TraceName = 'rdt_Scan_And_Pack_InsertPackDetail'
    END

    SET @nTranCount = @@TRANCOUNT

    BEGIN TRAN
    SAVE TRAN Scan_And_Pack_InsertPackDetail

    IF @cPrepackByBOM = '1'
    BEGIN
        SET @d_step1 = GETDATE()

        SET @nCartonNo = 0 -- (Vicky02)

        -- Get the next label no
        EXECUTE [RDT].[rdt_GenUCCLabelNo]
        @cStorerKey,
        @nMobile,
        @cLabelNo OUTPUT,
        @cLangCode,
        @nErrNo OUTPUT,
        @cErrMsg OUTPUT

        IF @nErrNo <> 0
        BEGIN
            SET @nErrNo = 66282
            SET @cErrMsg = rdt.rdtgetmessage(66282 ,@cLangCode ,'DSP') --'Gen LBLNo Fail'
            GOTO RollBackTran
        END

        IF @n_debug = 1
        BEGIN
            SET @d_step1 = GETDATE() - @d_step1
            SET @c_col1 = 'Gen UCC LabelNo'
            SET @d_endtime = GETDATE()
            INSERT INTO TraceInfo
            VALUES
              (
                RTRIM(@c_TraceName)
               ,@d_starttime
               ,@d_endtime
               ,CONVERT(CHAR(12) ,@d_endtime - @d_starttime ,114)
               ,CONVERT(CHAR(12) ,@d_step1 ,114)
               ,CONVERT(CHAR(12) ,@d_step2 ,114)
               ,CONVERT(CHAR(12) ,@d_step3 ,114)
               ,CONVERT(CHAR(12) ,@d_step4 ,114)
               ,CONVERT(CHAR(12) ,@d_step5 ,114)
                --,@c_Col1,@c_Col2,@c_Col3,@c_Col4,@c_Col5)
               ,@c_Col1
               ,SUBSTRING(@cFilename ,1 ,20)
               ,SUBSTRING(@cFilename ,21 ,20)
               ,SUBSTRING(@cFilename ,41 ,20)
               ,CONVERT(VARCHAR(20) ,@nCartonNo)
              )

            SET @d_step1 = NULL
            SET @d_step2 = NULL
            SET @d_step3 = NULL
            SET @d_step4 = NULL
            SET @d_step5 = NULL

            SET @d_step2 = GETDATE()
        END

        DECLARE CUR_INSPACKDETAIL  CURSOR LOCAL READ_ONLY FAST_FORWARD
        FOR
            SELECT ComponentSku, QTY
            FROM   dbo.BILLOFMATERIAL WITH (NOLOCK)
            WHERE  StorerKey = @cStorerKey
            AND    Sku = @cSKU
            ORDER BY Sequence

        OPEN CUR_INSPACKDETAIL
        FETCH NEXT FROM CUR_INSPACKDETAIL INTO @cComponentSku, @nComponentQTY
        WHILE @@FETCH_STATUS <> - 1
        BEGIN
            SET @cLabelLine = '00000' -- (Vicky02)

            -- Last check for qtypicked > qtypacked
            SELECT @nSumQtyPicked = ISNULL(SUM(PD.QTY) ,0)
            FROM   dbo.PickDetail PD WITH (NOLOCK)
            WHERE  PD.OrderKey = @cOrderKey
            AND    EXISTS (
                       SELECT 1
                       FROM   dbo.BillOfMaterial BOM WITH (NOLOCK)
                       WHERE  BOM.StorerKey = @cStorerKey
                       AND    BOM.SKU = @cSKU
                       AND    BOM.ComponentSku = PD.SKU
                   ) -- TLTING

            SELECT @nSumQtyPacked = ISNULL(SUM(PD.QTY) ,0)
            FROM   dbo.PackDetail PD WITH (NOLOCK)
            WHERE  PD.PickSlipNo = @cDiscrete_PickSlipNo
            AND    EXISTS (
                       SELECT 1
                       FROM   dbo.BillOfMaterial BOM WITH (NOLOCK)
                       WHERE  BOM.StorerKey = @cStorerKey
                       AND    BOM.SKU = @cSKU
                       AND    BOM.ComponentSku = PD.SKU
                   ) -- TLTING

            IF @nSumQtyPicked > @nSumQtyPacked
            BEGIN
                -- Insert PackDetail
                INSERT INTO dbo.PackDetail
                  (
                    PickSlipNo
                   ,CartonNo
                   ,LabelNo
                   ,LabelLine
                   ,StorerKey
                   ,SKU
                   ,QTY
                   ,Refno
                   ,AddWho
                   ,AddDate
                   ,EditWho
                   ,EditDate
                  )
                VALUES
               	(@cDiscrete_PickSlipNo, @nCartonNo, 	 @cLabelNo, @cLabelLine,
               	 @cStorerKey, 				@cComponentSku, (@nQTY * @nComponentQTY * @nCaseCnt), -- (Vicky01)
               	 CASE WHEN @cPickSlipType = 'CONSO'
               	 		THEN @cPickSlipNo ELSE ''
               	 END, 'rdt.' + sUser_sName(), GETDATE(), 'rdt.' + sUser_sName(), GETDATE())

                IF @@ERROR <> 0
                BEGIN
                    SET @nErrNo = 66766
                    SET @cErrMsg = rdt.rdtgetmessage(66766 ,@cLangCode ,'DSP') --'InsPackDFail'
                    GOTO RollBackTran
                END
            END
            ELSE
            BEGIN
                SET @nErrNo = 66768
                SET @cErrMsg = rdt.rdtgetmessage(66768 ,@cLangCode ,'DSP') --'SKUFullyPacked'
                GOTO RollBackTran
            END

            FETCH NEXT FROM CUR_INSPACKDETAIL INTO @cComponentSku, @nComponentQTY
        END
        CLOSE CUR_INSPACKDETAIL
        DEALLOCATE CUR_INSPACKDETAIL
   END -- IF @cPrepackByBOM = '1'
   ELSE
   BEGIN
      SET @nCartonNo = 0 -- (Vicky02)

      -- Get the next label no
      EXECUTE [RDT].[rdt_GenUCCLabelNo]
         @cStorerKey,
         @nMobile,
         @cLabelNo OUTPUT,
         @cLangCode,
         @nErrNo   OUTPUT,
         @cErrMsg  OUTPUT

      IF @nErrNo <> 0
      BEGIN
         SET @nErrNo = 66282
         SET @cErrMsg = rdt.rdtgetmessage( 66282, @cLangCode, 'DSP') --'Gen LBLNo Fail'
         GOTO RollBackTran
      END

      SET @cLabelLine = '00000' -- (Vicky02)

      -- Insert PackDetail
      INSERT INTO dbo.PackDetail
         (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, QTY, AddWho, AddDate, EditWho, EditDate, Refno)  --(james02)
      VALUES
         (@cDiscrete_PickSlipNo, @nCartonNo, @cLabelNo, @cLabelLine, @cStorerKey, @cSKU, @nCaseCnt, 'rdt.' + sUser_sName(), GETDATE(), 'rdt.' + sUser_sName(), GETDATE(),
         CASE WHEN @cPickSlipType = 'CONSO' THEN @cPickSlipNo ELSE '' END) --(james02)

      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 66767
         SET @cErrMsg = rdt.rdtgetmessage( 66767, @cLangCode, 'DSP') --'InsPackDFail'
         GOTO RollBackTran
      END
   END


  -- (Vicky02) Start - Retrieve CartonNo
  SELECT @nMax_CartonNo = MAX(CartonNo)
  FROM   dbo.PACKDETAIL WITH (NOLOCK)
  WHERE  PickSlipNo = @cDiscrete_PickSlipNo
  AND LabelNo = @cLabelNo
  AND StorerKey = @cStorerKey

  SET @nCartonNo = @nMax_CartonNo
  -- (Vicky02) End - Retrieve CartonNo

/*
  SET @dTempDateTime = GETDATE()

  SET @cYYYY = RIGHT('0' + ISNULL(RTRIM(DATEPART(yyyy ,@dTempDateTime)) ,'') ,4)
  SET @cMM = RIGHT('0' + ISNULL(RTRIM(DATEPART(mm ,@dTempDateTime)) ,'') ,2)
  SET @cDD = RIGHT('0' + ISNULL(RTRIM(DATEPART(dd ,@dTempDateTime)) ,'') ,2)
  SET @cHH = RIGHT('0' + ISNULL(RTRIM(DATEPART(hh ,@dTempDateTime)) ,'') ,2)
  SET @cMI = RIGHT('0' + ISNULL(RTRIM(DATEPART(mi ,@dTempDateTime)) ,'') ,2)
  SET @cSS = RIGHT('0' + ISNULL(RTRIM(DATEPART(ss ,@dTempDateTime)) ,'') ,2)
  SET @cMS = RIGHT('0' + ISNULL(RTRIM(DATEPART(ms ,@dTempDateTime)) ,'') ,3)

  SET @cDateTime = @cYYYY + @cMM + @cDD + @cHH + @cMI + @cSS + @cMS
  --   KY20090629 End Modified to have millisecond and getchar() into a var

  SET @cSPID = @@SPID

  SET @cFilename = ISNULL(RTRIM(@cPrinter) ,'') + '_' + @cDateTime + '_' +
      ISNULL(RTRIM(@cLabelNo) ,'') + '.XML'
  SET @cFilePath = ISNULL(RTRIM(@cFilePath1) ,'') + ISNULL(RTRIM(@cFilePath2) ,'')
  SET @cWorkFilePath = ISNULL(RTRIM(@cFilePath) ,'') + 'Working'

  -- Clear the XML record
  DELETE
  FROM   RDT.RDTGSICartonLabel_XML WITH (ROWLOCK)
  WHERE  [SPID] = @@SPID

  IF @n_debug = 1
  BEGIN
      SET @d_step2 = GETDATE() - @d_step2
      SET @c_col1 = 'Insert PackDetail'
      SET @d_endtime = GETDATE()
      INSERT INTO TraceInfo
      VALUES
        (
          RTRIM(@c_TraceName)
         ,@d_starttime
         ,@d_endtime
         ,CONVERT(CHAR(12) ,@d_endtime - @d_starttime ,114)
         ,CONVERT(CHAR(12) ,@d_step1 ,114)
         ,CONVERT(CHAR(12) ,@d_step2 ,114)
         ,CONVERT(CHAR(12) ,@d_step3 ,114)
         ,CONVERT(CHAR(12) ,@d_step4 ,114)
         ,CONVERT(CHAR(12) ,@d_step5 ,114)
          --,@c_Col1,@c_Col2,@c_Col3,@c_Col4,@c_Col5)
         ,@c_Col1
         ,SUBSTRING(@cFilename ,1 ,20)
         ,SUBSTRING(@cFilename ,21 ,20)
         ,SUBSTRING(@cFilename ,41 ,20)
         ,CONVERT(VARCHAR(20) ,@nCartonNo)
        )

      SET @d_step1 = NULL
      SET @d_step2 = NULL
      SET @d_step3 = NULL
      SET @d_step4 = NULL
      SET @d_step5 = NULL

      SET @d_step3 = GETDATE()
  END

  EXEC dbo.isp_GSICartonLabel
       @cMBOLKey
      ,@cOrderKey
      ,@cGS1TemplatePath_Final -- (Vicky01)
      ,@cPrinter
      ,@cFileName
      ,@nCartonNo

  IF @n_debug = 1
  BEGIN
      SET @d_step3 = GETDATE() - @d_step3
      SET @c_col1 = 'Gen GSI Carton Label'
      SET @d_endtime = GETDATE()
      INSERT INTO TraceInfo
      VALUES
        (
          RTRIM(@c_TraceName)
         ,@d_starttime
         ,@d_endtime
         ,CONVERT(CHAR(12) ,@d_endtime - @d_starttime ,114)
         ,CONVERT(CHAR(12) ,@d_step1 ,114)
         ,CONVERT(CHAR(12) ,@d_step2 ,114)
         ,CONVERT(CHAR(12) ,@d_step3 ,114)
         ,CONVERT(CHAR(12) ,@d_step4 ,114)
         ,CONVERT(CHAR(12) ,@d_step5 ,114)
          --,@c_Col1,@c_Col2,@c_Col3,@c_Col4,@c_Col5)
         ,@c_Col1
         ,SUBSTRING(@cFilename ,1 ,20)
         ,SUBSTRING(@cFilename ,21 ,20)
         ,SUBSTRING(@cFilename ,41 ,20)
         ,CONVERT(VARCHAR(20) ,@nCartonNo)
        )

      SET @d_step1 = NULL
      SET @d_step2 = NULL
      SET @d_step3 = NULL
      SET @d_step4 = NULL
      SET @d_step5 = NULL

      SET @d_step4 = GETDATE()
  END

  -- Check the last char of the file path consists of '\'
  IF SUBSTRING(ISNULL(RTRIM(@cFilePath) ,'') ,LEN(ISNULL(RTRIM(@cFilePath) ,'')) ,1) <> '\'
      SET @cFilePath = ISNULL(RTRIM(@cFilePath) ,'') + '\'

  -- (james03) start
  SELECT @cPrinterFolder = Long
  FROM   dbo.CODELKUP WITH (NOLOCK)
  WHERE  Short = 'REQUIRED'
  AND    Listname = 'PRNFDLKUP'
  AND    Code = @cPrinter

  IF ISNULL(@cPrinterFolder,'') = ''
  BEGIN
     SET @cMoveFilePath = ISNULL(RTRIM(@cFilePath), '')
  END
  ELSE
  BEGIN
     SET @cMoveFilePath = ISNULL(RTRIM(@cFilePath), '') + RTRIM(@cPrinterFolder) + '\'
  END
*/
  IF NOT EXISTS(
         SELECT 1
         FROM   dbo.CODELKUP c WITH (NOLOCK)
         WHERE  c.LISTNAME = 'SKIPGS1LBL'
         AND    Code = @cDiscrete_PickSlipNo
     )
  BEGIN
      -- Get GS1 templabe path
      DECLARE @cGS1TemplatePath NVARCHAR(120)
      SET @cGS1TemplatePath = ''
      SELECT @cGS1TemplatePath = NSQLDescrip FROM RDT.NSQLCONFIG WITH (NOLOCK) WHERE ConfigKey = 'GS1TemplatePath'

      DECLARE @cGS1BatchNo NVARCHAR(10) 
      EXEC isp_GetGS1BatchNo 5,  @cGS1BatchNo OUTPUT 
      SET    @cErrMsg = @cGS1BatchNo

      -- Print GS1 label
      SELECT @b_success = 0
      EXEC dbo.isp_PrintGS1Label
         @c_PrinterID        = @cPrinter,
         @c_BtwPath          = @cGS1TemplatePath,
         @b_Success          = @b_success OUTPUT,
         @n_Err              = @nErrNo  OUTPUT,
         @c_Errmsg           = @cErrMsg OUTPUT,
         @c_LabelNo          = @cLabelNo
      IF @nErrNo <> 0 OR @b_success = 0
      BEGIN
          SET @nErrNo = 66281
          SET @cErrMsg = rdt.rdtgetmessage(66281 ,@cLangCode ,'DSP') --'GSILBLCrtFail'
          GOTO RollBackTran
      END
/*
      -- SHONG01
      -- Get Printer TCP
      SELECT @b_success = 0
      SET @c_TCP_Authority = '0'
      EXECUTE dbo.nspGetRight
         @cFacility,   -- facility
         @cStorerkey,  -- Storerkey
         NULL,          -- Sku
         'BartenderTCP',-- Configkey
         @b_success    output,
         @c_TCP_Authority  output,
         @n_err        output,
         @c_errmsg     output

      IF @c_TCP_Authority = '1'
      BEGIN
         EXECUTE [RDT].[rdt_Scan_And_Pack_TCP_GSILabel]
         @@SPID,
         @cPrinter,
         @nErrNo OUTPUT,
         @cErrMsg OUTPUT
      END
      ELSE
      BEGIN
         EXECUTE [RDT].[rdt_Scan_And_Pack_PrintGSILabel]
         @@SPID,
         @cWorkFilePath,
         @cMoveFilePath,
         @cFileName,
         @cLangCode,
         @nErrNo OUTPUT,
         @cErrMsg OUTPUT

         IF @nErrNo <> 0
         BEGIN
             SET @nErrNo = 66281
             SET @cErrMsg = rdt.rdtgetmessage(66281 ,@cLangCode ,'DSP') --'GSILBLCrtFail'
             GOTO RollBackTran
         END
      END
*/
  END

  IF @n_debug = 1
  BEGIN
      SET @d_step4 = GETDATE() - @d_step4
      SET @c_col1 = 'Print GSI Label'
      SET @d_endtime = GETDATE()
      INSERT INTO TraceInfo
      VALUES
        (
          RTRIM(@c_TraceName)
         ,@d_starttime
         ,@d_endtime
         ,CONVERT(CHAR(12) ,@d_endtime - @d_starttime ,114)
         ,CONVERT(CHAR(12) ,@d_step1 ,114)
         ,CONVERT(CHAR(12) ,@d_step2 ,114)
         ,CONVERT(CHAR(12) ,@d_step3 ,114)
         ,CONVERT(CHAR(12) ,@d_step4 ,114)
         ,CONVERT(CHAR(12) ,@d_step5 ,114)
          --,@c_Col1,@c_Col2,@c_Col3,@c_Col4,@c_Col5)
         ,@c_Col1
         ,SUBSTRING(@cFilename ,1 ,20)
         ,SUBSTRING(@cFilename ,21 ,20)
         ,SUBSTRING(@cFilename ,41 ,20)
         ,CONVERT(VARCHAR(20) ,@nCartonNo)
        )

      SET @d_step1 = NULL
      SET @d_step2 = NULL
      SET @d_step3 = NULL
      SET @d_step4 = NULL
      SET @d_step5 = NULL
  END

	GOTO Quit

	RollBackTran:
	ROLLBACK TRAN Scan_And_Pack_InsertPackDetail

	Quit:
	WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
	    COMMIT TRAN Scan_And_Pack_InsertPackDetail
END

GO
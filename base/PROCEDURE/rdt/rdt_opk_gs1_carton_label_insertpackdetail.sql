SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_OPK_GS1_Carton_Label_InsertPackDetail           */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Insert PackDetail after each scan of Case ID                */
/*                                                                      */
/* Called from: rdtfnc_TM_OrderPicking                                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author    Purposes                                  */
/* 20-May-2010 1.0  ChewKP    Created                                   */
/* 31-Mar-2011 1.0  Shong     TCP Printing Features for Bartender       */
/* 06-Jan-2012 1.2  Ung       Standarize print GS1 to use Exceed logic  */
/*                            US Production                             */   
/************************************************************************/
CREATE PROC [RDT].[rdt_OPK_GS1_Carton_Label_InsertPackDetail] (
   @nMobile       INT
  ,@cFacility     NVARCHAR(5)
  ,@cStorerKey    NVARCHAR(15)
  ,@cDropID       NVARCHAR(18)
  ,@cOrderKey     NVARCHAR(10)
  ,@cPickSlipNo   NVARCHAR(10)	-- can be conso ps# or discrete ps#; depends on pickslip type
  ,@cFilePath1    NVARCHAR(20)
  ,@cFilePath2    NVARCHAR(20)
  ,@cGS1TemplatePath_Final   NVARCHAR(120)
  ,@cPrinterID      NVARCHAR(20)
  ,@cLangCode     NVARCHAR(3)
  ,@cTaskdetailkey  NVARCHAR(10)
  ,@cPrepackByBOM   NVARCHAR(1)
  ,@cUserName       NVARCHAR(18)
  ,@nErrNo  INT  OUTPUT
  ,@cErrMsg NVARCHAR(20)   OUTPUT -- screen limitation, 20 char max
) AS
BEGIN
    SET NOCOUNT ON
    SET QUOTED_IDENTIFIER OFF
    SET ANSI_NULLS OFF
    SET CONCAT_NULL_YIELDS_NULL OFF

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
           ,@cDateTime       NVARCHAR(17)
           ,@cSPID           NVARCHAR(5)
           ,@cFileName       NVARCHAR(215)
           ,@cWorkFilePath   NVARCHAR(120)
           ,@cMoveFilePath   NVARCHAR(120)
           ,@cFilePath       NVARCHAR(120)
           ,@nSumQtyPicked   INT
           ,@nSumQtyPacked   INT
           ,@nMax_CartonNo   INT
           ,@cPackkey        NVARCHAR(10)
           ,@nTotalLoop      INT
           ,@nUPCCaseCnt     INT
           ,@cParentSKU      NVARCHAR(20)
           ,@nTotalBOMQty    INT
           ,@nCaseCnt        INT
           ,@cPDPackkey      NVARCHAR(10)
           ,@cPalletID       NVARCHAR(10)
           ,@nPDQTY          INT
           ,@nCartonNo       INT
           ,@cLabelNo        NVARCHAR(20)
           ,@cSku            NVARCHAR(20)
           ,@nQTY            INT


    DECLARE @cMS             NVARCHAR(3)
           ,@dTempDateTime   DATETIME

    DECLARE @n_debug         INT

    SET @n_debug = 0

    DECLARE @t_Result TABLE (LabelNo NVARCHAR(20) ,CartonNo INT)

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
        SET @c_col4 = @cPrinterID

        SET @d_starttime = GETDATE()

        SET @c_TraceName = 'rdt_OPK_GS1_Carton_Label_InsertPackDetail'
    END

    SET @nTranCount = @@TRANCOUNT

    BEGIN TRAN
    SAVE TRAN GS1_InsertPackDetail

    BEGIN
        SET @d_step1 = GETDATE()
        SET @nCartonNo = 0

        IF @cPrepackByBOM = '1'
        BEGIN
            SET @cLabelLine = '00000'
            SET @nTotalLoop = 0
            -- Get the next label no

            IF @n_debug = 1
            BEGIN
                SET @d_step1 = GETDATE() - @d_step1
                SET @c_col1 = 'INSERT PACKDETAIL'
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



            DECLARE CUR_INSPACKDETAILBOM CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
               SELECT DISTINCT LA.Lottable03
                FROM   dbo.PickDetail PD WITH (NOLOCK)
                INNER JOIN dbo.LOTATTRIBUTE LA(NOLOCK)
                      ON  (LA.Storerkey = PD.Storerkey AND LA.SKU = PD.SKU AND LA.LOT = PD.LOT)
                WHERE  PD.StorerKey = @cStorerkey
                AND    PD.Orderkey = @cOrderkey
                AND    PD.DropID = @cDropID
                AND    PD.TaskDetailKey = @cTaskdetailkey

            OPEN CUR_INSPACKDETAILBOM
            FETCH NEXT FROM CUR_INSPACKDETAILBOM INTO @cParentSKU
            WHILE @@FETCH_STATUS <> - 1
            BEGIN
                SELECT @nUPCCaseCnt = ISNULL(PACK.CaseCnt ,0)
                FROM   dbo.PACK PACK WITH (NOLOCK)
                JOIN dbo.UPC UPC WITH (NOLOCK) ON  (UPC.Packkey = PACK.Packkey)
                WHERE  UPC.SKU = @cParentSKU
                AND    UPC.Storerkey = @cStorerkey
                AND    UPC.UOM = 'CS'

                SELECT @nPDQTY = SUM(PD.QTY)
                FROM   dbo.PickDetail PD WITH (NOLOCK ,INDEX(IDX_PICKDETAIL_DropID))
                JOIN dbo.Lotattribute LA WITH (NOLOCK)
                      ON  (PD.Storerkey = LA.Storerkey AND PD.SKU = LA.SKU AND PD.LOT = LA.Lot)
                WHERE  PD.DropID = @cDropID
                AND    LA.Lottable03 = @cParentSKU
                AND    PD.Storerkey = @cStorerkey
                AND    PD.Orderkey = @cOrderkey
                AND    PD.TaskDetailKey = @cTaskdetailkey

                SELECT @nTotalBOMQty = SUM(BOM.QTY)
                FROM   dbo.BillOfMaterial BOM WITH (NOLOCK)
                WHERE  BOM.Storerkey = @cStorerKey
                AND    BOM.SKU = @cParentSKU

                SELECT @nTotalLoop = CEILING(@nPDQTY /(@nTotalBOMQty * @nUPCCaseCnt))

                WHILE @nTotalLoop > 0
                BEGIN
                    EXECUTE [RDT].[rdt_GenUCCLabelNo]
                    @cStorerKey,
                    @nMobile,
                    @cLabelNo OUTPUT,
                    @cLangCode,
                    @nErrNo OUTPUT,
                    @cErrMsg OUTPUT

                    IF ISNULL(@nErrNo ,0) <> 0
                    BEGIN
                        SET @nErrNo = 69491
                        SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'Gen LBLNo Fail'
                        GOTO RollBackTran
                    END

                    INSERT INTO dbo.DropIDDetail
                      ( DROPID ,CHILDID ,AddWho )
                    VALUES
                      ( @cDropID ,@cLabelNo ,@cUserName )

                    IF @@ERROR <> 0
                    BEGIN
                        SET @nErrNo = 69493
                        SET @cErrMsg = rdt.rdtgetmessage(69493 ,@cLangCode ,'DSP') --'InsDropIDDet'
                        GOTO RollBackTran
                    END

                    DECLARE CUR_BOM  CURSOR LOCAL READ_ONLY FAST_FORWARD
                    FOR
                        SELECT ComponentSKU ,QTY
                        FROM   dbo.BILLOFMATERIAL WITH (NOLOCK)
                        WHERE  SKU = @cParentSKU
                        AND    Storerkey = @cStorerKey
                    OPEN CUR_BOM
                    FETCH NEXT FROM CUR_BOM INTO @cComponentSKU, @nComponentQTY
                    WHILE @@FETCH_STATUS <> - 1
                    BEGIN
                        IF NOT EXISTS (
                               SELECT 1
                               FROM   dbo.PackDetail WITH (NOLOCK)
                               WHERE  Pickslipno = @cPickSlipNo
                               AND    Storerkey = @cStorerKey
                               AND    SKU = @cComponentSku
                               AND    LabelNo = @cLabelNo
                           )
                        BEGIN
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
                               ,DropID
                              )
                            VALUES
                              (
                                @cPickSlipNo
                               ,@nCartonNo
                               ,@cLabelNo
                               ,@cLabelLine
                               ,@cStorerKey
                               ,@cComponentSku
                               ,@nComponentQTY
                               ,@cDropID
                               ,@cUserName
                               ,GETDATE()
                               ,@cUserName
                               ,GETDATE()
                               ,@cDropID
                              )

                            IF @@ERROR <> 0
                            BEGIN
                                SET @nErrNo = 69492
                                SET @cErrMsg = rdt.rdtgetmessage(69492 ,@cLangCode ,'DSP') --'InsPackDFail'
                                GOTO RollBackTran
                            END

                            INSERT INTO @t_Result
                            SELECT LabelNo
                                  ,CartonNo
                            FROM   dbo.PackDetail
                            WHERE  LabelNo = @cLabelNo
                            AND    Storerkey = @cStorerKey
                            AND    SKU = @cComponentSku
                            AND    PickSlipNo = @cPickSlipNo

                            IF @@ERROR <> 0
                            BEGIN
                                SET @nErrNo = 69490
                                SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'InsPackDFail'
                                GOTO RollBackTran
                            END
                        END
                        FETCH NEXT FROM CUR_BOM INTO @cComponentSKU, @nComponentQTY
                    END
                    CLOSE CUR_BOM
                    DEALLOCATE CUR_BOM

                    SET @nTotalLoop = @nTotalLoop - 1
                END

                FETCH NEXT FROM CUR_INSPACKDETAILBOM INTO @cParentSKU
            END

            CLOSE CUR_INSPACKDETAILBOM
            DEALLOCATE CUR_INSPACKDETAILBOM
        END-- IF @cPrepackByBOM = '1'
        ELSE
        BEGIN
            -- Get Pack info Non-Prepack
            SET @cLabelLine = '00000'
            SET @nTotalLoop = 0

            SELECT @nTotalLoop = PD.QTY / PACK.Casecnt
            FROM   PickDetail PD(NOLOCK)
                   INNER JOIN SKU SKU(NOLOCK)
                        ON  (SKU.SKU = PD.SKU AND SKU.STORERKEY = PD.STORERKEY)
                   INNER JOIN PACK PACK(NOLOCK)
                        ON  (PACK.PACKKEY = SKU.PACKKEY)
            WHERE  PD.TaskDetailKey = @cTaskdetailkey
            AND    PD.Storerkey = @cStorerKey
            AND    PD.DROPID = @cDropID
            AND    PD.Orderkey = @cOrderKey
            SET @nTotalLoop = ISNULL(@nTotalLoop ,0)

            WHILE @nTotalLoop > 0
            BEGIN
                EXECUTE [RDT].[rdt_GenUCCLabelNo]
                @cStorerKey,
                @nMobile,
                @cLabelNo OUTPUT,
                @cLangCode,
                @nErrNo OUTPUT,
                @cErrMsg OUTPUT

                IF @nErrNo <> 0
                BEGIN
                    SET @nErrNo = 69495
                    SET @cErrMsg = rdt.rdtgetmessage(69495 ,@cLangCode ,'DSP') --'Gen LBLNo Fail'
                    GOTO RollBackTran
                END


                INSERT INTO dbo.DropIDDetail
                  ( DROPID ,CHILDID ,AddWho )
                VALUES
                  ( @cDropID ,@cLabelNo ,@cUserName )

                IF @@ERROR <> 0
                BEGIN
                    SET @nErrNo = 69497
                    SET @cErrMsg = rdt.rdtgetmessage(69497 ,@cLangCode ,'DSP') --'InsDropIDDet'
                    GOTO RollBackTran
                END


                DECLARE CUR_BOM  CURSOR LOCAL READ_ONLY FAST_FORWARD
                FOR
                    SELECT SKU ,QTY
                    FROM   dbo.PICKDETAIL PD WITH (NOLOCK)
                    WHERE  PD.TaskDetailKey = @cTaskdetailkey
                    AND    PD.Storerkey = @cStorerKey
                    AND    PD.DropID = @cDropID
                    AND    PD.Orderkey = @cOrderKey

                OPEN CUR_BOM
                FETCH NEXT FROM CUR_BOM INTO @cSKU, @nQTY
                WHILE @@FETCH_STATUS <> - 1
                BEGIN
                    IF NOT EXISTS (SELECT 1
                           FROM   dbo.PackDetail WITH (NOLOCK)
                           WHERE  Pickslipno = @cPickSlipNo
                           AND    Storerkey = @cStorerKey
                           AND    SKU = @cSKU
                           AND    LabelNo = @cLabelNo
                       )
                    BEGIN
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
                           ,DropID
                          )
                        VALUES
                          (
                            @cPickSlipNo
                           ,@nCartonNo
                           ,@cLabelNo
                           ,@cLabelLine
                           ,@cStorerKey
                           ,@cSKU
                           ,@nQTY
                           ,@cDropID
                           ,@cUserName
                           ,GETDATE()
                           ,@cUserName
                           ,GETDATE()
                           ,@cDropID
                          )

                        IF @@ERROR <> 0
                        BEGIN
                            SET @nErrNo = 69496
                            SET @cErrMsg = rdt.rdtgetmessage(69496 ,@cLangCode ,'DSP') --'InsPackDFail'
                            GOTO RollBackTran
                        END

                        INSERT INTO @t_Result
                        SELECT LabelNo
                              ,CartonNo
                        FROM   dbo.PackDetail
                        WHERE  LabelNo = @cLabelNo
                        AND    Storerkey = @cStorerKey
                        AND    SKU = @cSKU
                        AND    PickSlipNo = @cPickSlipNo

                        IF @@ERROR <> 0
                        BEGIN
                            SET @nErrNo = 69490
                            SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'InsPackDFail'
                            GOTO RollBackTran
                        END
                    END
                    FETCH NEXT FROM CUR_BOM INTO @cSKU, @nQTY
                END
                CLOSE CUR_BOM
                DEALLOCATE CUR_BOM

                SET @nTotalLoop = @nTotalLoop - 1
            END
        END -- IF @cPrepackByBOM = '0'
    END



    -- 'LOOP TO PRINT LABEL BY CARTON NO'
    IF @n_debug = 1
    BEGIN
        SET @d_step1 = GETDATE() - @d_step1
        SET @c_col1 = 'LOOP PACKDETAIL START'
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

   SET @n_debug = 0

   -- Get GS1 template file
   DECLARE @cGS1TemplatePath NVARCHAR(120)
   SET @cGS1TemplatePath = ''
   SELECT @cGS1TemplatePath = NSQLDescrip FROM RDT.NSQLCONFIG WITH (NOLOCK) WHERE ConfigKey = 'GS1TemplatePath'


   DECLARE @cGS1BatchNo NVARCHAR(10) 
   EXEC isp_GetGS1BatchNo 5,  @cGS1BatchNo OUTPUT 
   

    SET @cLabelNo = ''
    DECLARE CUR_GSILABEL  CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
    SELECT LabelNo ,CartonNo
    FROM   @t_Result

    OPEN CUR_GSILABEL
    FETCH NEXT FROM CUR_GSILABEL INTO @cLabelNo, @nCartonNo
    WHILE @@FETCH_STATUS <> - 1
    BEGIN
         -- Print GS1 label
         SET @cErrMsg = @cGS1BatchNo
         SET @b_success = 0
         EXEC dbo.isp_PrintGS1Label
            @c_PrinterID = @cPrinterID,
            @c_BtwPath   = @cGS1TemplatePath,
            @b_Success   = @b_success OUTPUT,
            @n_Err       = @nErrNo    OUTPUT,
            @c_Errmsg    = @cErrMsg   OUTPUT,
            @c_LabelNo   = @cLabelNo
         IF @nErrNo <> 0 OR @b_success = 0
         BEGIN
            SET @nErrNo = 69494
            SET @cErrMsg = rdt.rdtgetmessage(69494 ,@cLangCode ,'DSP') --'GSILBLCrtFail'
            GOTO RollBackTran
         END

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
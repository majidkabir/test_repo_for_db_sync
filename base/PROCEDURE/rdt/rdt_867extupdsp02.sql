SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_867ExtUpdSP02                                   */
/* Copyright      : LF                                                  */
/*                                                                      */
/* Purpose: Pick By TrackNo Extended Update                             */
/*                                                                      */
/* Modifications log:                                                   */
/* Date        Rev  Author   Purposes                                   */
/* 2017-09-25  1.0  ChewKP   WMS-2992 Created                           */
/* 2020-02-24  1.1  Leong    INC1049672 - Revise BT Cmd parameters.     */
/************************************************************************/

CREATE PROC [RDT].[rdt_867ExtUpdSP02] (
  @nMobile        INT,
  @nFunc          INT,
  @nStep          INT,
  @cLangCode      NVARCHAR( 3),
  @cUserName      NVARCHAR( 18),
  @cFacility      NVARCHAR( 5),
  @cStorerKey     NVARCHAR( 15),
  @cOrderKey      NVARCHAR( 10),
  @cSKU           NVARCHAR( 20),
  @cTracKNo       NVARCHAR( 18),
  @cSerialNo      NVARCHAR( 30),
  @nErrNo         INT           OUTPUT,
  @cErrMsg        NVARCHAR( 20) OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nTranCount        INT
          ,@cOrderLineNumber  NVARCHAR(5)
          ,@nQty              INT
          ,@cSerialNoKey      NVARCHAR(10)
          ,@bsuccess          INT

   DECLARE @cLabelType  AS NVARCHAR(10)
         , @cLoadKey    AS NVARCHAR(10)
         , @cShipperKey AS NVARCHAR(10)
         , @cLabelPrinter  NVARCHAR(10)
         , @cPaperPrinter  NVARCHAR(10)

   SET @nErrNo    = 0
   SET @cErrMsg   = ''
   SET @nTranCount = @@TRANCOUNT

   BEGIN TRAN
   SAVE TRAN rdt_867ExtUpdSP02

   IF @nFunc = 867
   BEGIN
      IF @nStep = 4
      BEGIN
         SELECT @cLabelPrinter = Printer
            , @cPaperPrinter = Printer_Paper
         FROM rdt.rdtMobrec WITH (NOLOCK)
         WHERE Mobile = @nMobile

         SET @nErrNo     = 0
         SET @cERRMSG    = ''
         SET @cLabelType = 'SHIPPLABEL'
         SET @cLoadKey   = ''
         SET @cShipperKey  = ''

         SELECT  @cLoadKey = LoadKey
               , @cShipperKey = ShipperKey
         FROM dbo.Orders WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
         AND OrderKey = @cOrderKey

         IF EXISTS ( SELECT 1 FROM dbo.BartenderLabelCfg WITH (NOLOCK)
                     WHERE StorerKey = @cStorerKey
                     AND LabelType = 'SHIPPLABEL'
                     AND Key05     = @cShipperKey )
         BEGIN
            EXEC dbo.isp_BT_GenBartenderCommand
                  @cPrinterID     = @cLabelPrinter
                , @c_LabelType    = @cLabelType
                , @c_userid       = @cUserName
                , @c_Parm01       = @cLoadKey
                , @c_Parm02       = @cOrderKey
                , @c_Parm03       = ''--@cShipperKey
                , @c_Parm04       = '0'
                , @c_Parm05       = ''
                , @c_Parm06       = ''
                , @c_Parm07       = ''
                , @c_Parm08       = ''
                , @c_Parm09       = ''
                , @c_Parm10       = ''
                , @c_StorerKey    = @cStorerKey
                , @c_NoCopy       = '1'
                , @b_Debug        = '0'
                , @c_Returnresult = 'N'
                , @n_err          = @nErrNo  OUTPUT
                , @c_errmsg       = @cERRMSG OUTPUT
         END
      END
   END

   GOTO QUIT

RollBackTran:
   ROLLBACK TRAN rdt_867ExtUpdSP02 -- Only rollback change made here

Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN rdt_867ExtUpdSP02
END

GO
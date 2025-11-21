SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************/
/* Store procedure: rdtUALabel                                             */
/*                                                                         */
/* Modifications log:                                                      */
/*                                                                         */
/* Date       Rev  Author   Purposes                                       */
/* 2015-06-03 1.0  ChewKP   SOS#342113 Created                             */
/* 2016-10-07 1.1  ChewKP   WMS-490 Add 1 more options (ChewKP01)          */
/* 2017-01-12 1.2  ChewKP   WMS-924 Add Passcode (ChewKP02)                */
/* 2017-10-20 1.3  ChewKP   WMS-3190 Print Additional Label (ChewKP03)     */
/* 2019-03-13 1.4  James    WMS-8240 Do not print carton label             */
/*                          if carton contain uom 2 (james01)              */
/* 2020-02-24 1.5  Leong    INC1049672 - Revise BT Cmd parameters.         */
/***************************************************************************/

CREATE PROC [RDT].[rdtUALabel] (
   @nMobile    INT,
   @nFunc      INT,
   @nStep      INT,
   @cLangCode  NVARCHAR( 3),
   @cStorerKey NVARCHAR( 15),
   @cOption    NVARCHAR( 1),
   @cParam1    NVARCHAR(20),  -- LoadKey
   @cParam2    NVARCHAR(20),
   @cParam3    NVARCHAR(20),  -- LabelNo
   @cParam4    NVARCHAR(20),
   @cParam5    NVARCHAR(20),
   @nErrNo     INT OUTPUT,
   @cErrMsg    NVARCHAR( 20) OUTPUT
)
AS
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF

   DECLARE @b_Success     INT


   DECLARE @cLabelPrinter NVARCHAR( 10)
   DECLARE @cPaperPrinter NVARCHAR( 10)

   DECLARE @cLabelType    NVARCHAR( 20)
   DECLARE @cUserName     NVARCHAR( 18)

   DECLARE @cLabelNo      NVARCHAR(20)
         , @cPrintCartonLabel NVARCHAR(1)
         , @cOrderCCountry    NVARCHAR(30)
         , @cOrderType        NVARCHAR(10)
         , @cLoadKey      NVARCHAR(10)
         , @cTargetDB     NVARCHAR(20)
         , @cVASType      NVARCHAR(10)
         , @cField01      NVARCHAR(10)
         , @cTemplate     NVARCHAR(50)
         , @cOrderKey     NVARCHAR(10)
         , @cPickSlipNo   NVARCHAR(10)
         , @nCartonNo     INT
         , @cCodeTwo      NVARCHAR(30)
         , @cTemplateCode NVARCHAR(60)
         , @cPasscode     NVARCHAR(20) -- (ChewKP02)
         , @cDataWindow   NVARCHAR( 50) -- (ChewKP03)

   -- cLabelNo mapping
   SET @cLabelNo = @cParam1
   SET @cPasscode = @cParam3 -- (ChewKP02)

   -- Check blank
   IF ISNULL( @cLabelNo, '') = ''
   BEGIN
      SET @nErrNo = 93601
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --Label Req
      GOTO Quit
   END

--   IF NOT EXISTS ( SELECT 1 FROM dbo.Replenishment WITH (NOLOCK)
--                   WHERE RefNo = @cLabelNo
--                   AND StorerKey = @cStorerKey )
--   BEGIN
--      SET @nErrNo = 93602
--      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --InvalidLabelNo
--      GOTO Quit
--   END

   IF NOT EXISTS ( SELECT 1 FROM dbo.PackDetail WITH (NOLOCK)
                   WHERE StorerKey = @cStorerKey
                   AND DropID = @cLabelNo )
   BEGIN
      SET @nErrNo = 93603
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --InvalidLabelNo
      GOTO Quit
   END

   -- Get printer info
   SELECT
      @cUserName = UserName,
      @cLabelPrinter = Printer,
      @cPaperPrinter = Printer_Paper
   FROM rdt.rdtMobRec WITH (NOLOCK)
   WHERE Mobile = @nMobile

   /*-------------------------------------------------------------------------------

                                    Print Label

   -------------------------------------------------------------------------------*/

   -- Check label printer blank
   IF @cLabelPrinter = ''
   BEGIN
      SET @nErrNo = 93604
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LabelPrnterReq
      GOTO Quit
   END

   -- (ChewKP01)
   IF @cOption in ( '1' ,'2' )
   BEGIN
      IF @cOption = '1'
      BEGIN
         IF EXISTS (SELECT 1 FROM dbo.PackDetail WITH (NOLOCK)
                    WHERE StorerKey = @cStorerKey
                    AND DropID = @cLabelNo
                    AND RefNo = '1' )
         BEGIN
            SET @nErrNo = 93608
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --CtnScanned
            GOTO Quit
         END
      END
      --SET @cLabelType = 'SHIPPLABELDTC'

      IF @cOption = '2' -- (ChewKP02)
      BEGIN
         IF EXISTS ( SELECT 1 FROM dbo.Codelkup WITH (NOLOCK)
                     WHERE ListName = '593-UA'
                     AND Code = 'Passcode'
                     AND StorerKey = @cStorerKey )
         BEGIN
            IF NOT EXISTS ( SELECT 1 FROM dbo.Codelkup WITH (NOLOCK)
                            WHERE ListName = '593-UA'
                            AND Code = 'Passcode'
                            and Long = @cPasscode  )
            BEGIN
               SET @nErrNo = 93609
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidPasscode
               GOTO Quit
            END
         END
      END

      SELECT TOP 1 @cPickSlipNo = PickSlipNo
                 , @nCartonNo   = CartonNo
      FROM dbo.PackDetail WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
      AND DropID = @cLabelNo

      SELECT TOP 1 @cOrderKey = OrderKey
      FROM dbo.PackHeader WITH (NOLOCK)
      WHERE PickSlipNo = @cPickSlipNo

      SELECT TOP 1 @cOrderType = Type
            ,@cOrderCCountry = C_Country
            ,@cLoadKey = LoadKey
      FROM dbo.Orders WITH (NOLOCK)
      WHERE OrderKey = @cOrderKey

      IF EXISTS (  SELECT 1
                   FROM dbo.DocInfo WITH (NOLOCK)
                   WHERE StorerKey = @cStorerKey
                   AND TableName = 'ORDERDETAIL'
                   AND Key1 = @cOrderKey
                   AND Rtrim(Substring(Docinfo.Data,31,30)) = 'L01'  )
      BEGIN

         DECLARE CursorLabel CURSOR LOCAL FAST_FORWARD READ_ONLY FOR

         SELECT Rtrim(Substring(Docinfo.Data,31,30))
               ,Rtrim(Substring(Docinfo.Data,61,30))
         FROM dbo.DocInfo WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
         AND TableName = 'ORDERDETAIL'
         AND Key1 = @cOrderKey
         AND Key2 = '00001'
         AND Rtrim(Substring(Docinfo.Data,31,30)) = 'L01'

         OPEN CursorLabel
         FETCH NEXT FROM CursorLabel INTO @cVASType, @cField01

         WHILE @@FETCH_STATUS <> -1
         BEGIN
            SET @cTemplate = ''

            DECLARE CursorCodeLkup CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT Notes, Code2
            FROM dbo.CodeLkup WITH (NOLOCK)
            WHERE ListName = 'UALabel'
            AND Code  = @cField01
            AND Short = @cVASType
            AND StorerKey = @cStorerKey

            OPEN CursorCodeLkup
            FETCH NEXT FROM CursorCodeLkup INTO @cTemplate, @cCodeTwo
            WHILE @@FETCH_STATUS<>-1
            BEGIN

      --         SELECT @cTemplate = ISNULL(RTRIM(Notes),'')
      --         FROM dbo.CodeLkup WITH (NOLOCK)
      --         WHERE ListName = 'UALabel'
      --         AND Code  = @cField01
      --         AND Short = @cVASType
      --         AND StorerKey = @cStorerKey

               SET @cTemplateCode = ''
               SET @cTemplateCode = ISNULL(RTRIM(@cField01),'')  + ISNULL(RTRIM(@cCodeTwo),'')

               IF @cTemplate = ''
               BEGIN
                  SET @nErrNo = 93606
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --TemplateNotFound
                  GOTO Quit
               END

               SET @cLabelType = 'SHIPPLABELUA'
               EXEC dbo.isp_BT_GenBartenderCommand
                   @cPrinterID     = @cLabelPrinter
                 , @c_LabelType    = @cLabelType
                 , @c_userid       = @cUserName
                 , @c_Parm01       = @cPickSlipNo
                 , @c_Parm02       = @nCartonNo
                 , @c_Parm03       = @nCartonNo
                 , @c_Parm04       = @cTemplateCode -- @cField01
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

               IF @nErrNo <> 0
                  GOTO Quit

               FETCH NEXT FROM CursorCodeLkup INTO @cTemplate, @cCodeTwo
            END
            CLOSE CursorCodeLkup
            DEALLOCATE CursorCodeLkup

            FETCH NEXT FROM CursorLabel INTO @cVASType, @cField01

         END
         CLOSE CursorLabel
         DEALLOCATE CursorLabel
      END

      --INSERT INTO TRACEINFO (TRaceName , TimeIN, Col1, Col2, Col3, Col4, Col5 )
      --VALUES ( 'UALABEL', Getdate() ,@cVASType ,'' , @nCartonNo ,@cLabelNo ,@cPickSlipNo  )

      IF EXISTS (  SELECT 1
                   FROM dbo.DocInfo WITH (NOLOCK)
                   WHERE StorerKey = @cStorerKey
                   AND TableName = 'ORDERDETAIL'
                   AND Key1 = @cOrderKey
                   AND Rtrim(Substring(Docinfo.Data,31,30)) = 'L02'  )
      BEGIN
         SELECT @cVASType = Rtrim(Substring(Docinfo.Data,31,30))
         FROM dbo.DocInfo WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
         AND TableName = 'ORDERDETAIL'
         AND Key1 = @cOrderKey
         AND Key2 = '00001'
         AND Rtrim(Substring(Docinfo.Data,31,30)) = 'L02'

         SET @cTemplate = ''
         -- Print only if carton do not contain uom 2
         IF NOT EXISTS (
            SELECT 1 FROM dbo.PickDetail WITH (NOLOCK)
            WHERE StorerKey = @cStorerKey
            AND   DropID = @cLabelNo
            AND   UOM = '2')
         BEGIN

            DECLARE CursorCodeLkup CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT Notes, Code2
            FROM dbo.CodeLkup WITH (NOLOCK)
            WHERE ListName = 'UACCLabel'
            AND Code  = @cVASType
            AND StorerKey = @cStorerKey

            OPEN CursorCodeLkup
            FETCH NEXT FROM CursorCodeLkup INTO @cTemplate, @cCodeTwo
            WHILE @@FETCH_STATUS<>-1
            BEGIN

               SET @cTemplateCode = ''
               SET @cTemplateCode = ISNULL(RTRIM(@cVASType),'')  + ISNULL(RTRIM(@cCodeTwo),'')

               IF @cTemplate = ''
               BEGIN
                  SET @nErrNo = 93607
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --TemplateNotFound
                  GOTO Quit
               END

               SET @cLabelType = 'SHIPPLABELUA'
               EXEC dbo.isp_BT_GenBartenderCommand
                   @cPrinterID     = @cLabelPrinter
                 , @c_LabelType    = @cLabelType
                 , @c_userid       = @cUserName
                 , @c_Parm01       = @cPickSlipNo
                 , @c_Parm02       = @nCartonNo
                 , @c_Parm03       = @nCartonNo
                 , @c_Parm04       = @cTemplateCode
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

               IF @nErrNo <> 0
                  GOTO Quit

               FETCH NEXT FROM CursorCodeLkup INTO @cTemplate, @cCodeTwo
            END
            CLOSE CursorCodeLkup
            DEALLOCATE CursorCodeLkup
         END
      END

      -- Print Carton Label --
      SET @cDataWindow = ''
      SET @cTargetDB   = ''

      SELECT @cDataWindow = DataWindow,
             @cTargetDB = TargetDB
      FROM rdt.rdtReport WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
      AND   ReportType = 'CTNLABEL'

      EXEC RDT.rdt_BuiltPrintJob
          @nMobile,
          @cStorerKey,
          'CTNLABEL',    -- ReportType
          'CTNLABEL',    -- PrintJobName
          @cDataWindow,
          @cLabelPrinter,
          @cTargetDB,
          @cLangCode,
          @nErrNo  OUTPUT,
          @cErrMsg OUTPUT,
          @cLabelNo

      UPDATE dbo.PackDetail WITH (ROWLOCK)
      SET RefNo = '1'
      WHERE StorerKey = @cStorerKey
      AND DropID      = @cLabelNo
      AND PickSlipNo  = @cPickSlipNo

      -- Print Packing List Process --
      IF NOT EXISTS ( SELECT 1 FROM dbo.PackDetail WITH (NOLOCK)
                      WHERE StorerKey = @cStorerKey
                      AND PickSlipNo = @cPickSlipNo
                      AND ISNULL(RTRIM(RefNo),'')  <> '1' )
      BEGIN
         SET @cTemplate = ''
         IF EXISTS ( SELECT 1
                     FROM dbo.DocInfo WITH (NOLOCK)
                     WHERE StorerKey = @cStorerKey
                     AND TableName = 'ORDERDETAIL'
                     AND Key1 = @cOrderKey
                     AND Rtrim(Substring(Docinfo.Data,31,30)) = 'F01'  )
         BEGIN
            SELECT @cVASType = Rtrim(Substring(Docinfo.Data,31,30))
            FROM dbo.DocInfo WITH (NOLOCK)
            WHERE StorerKey = @cStorerKey
            AND TableName = 'ORDERDETAIL'
            AND Key1 = @cOrderKey
            AND Rtrim(Substring(Docinfo.Data,31,30)) = 'F01'

            SELECT @cTemplate = ISNULL(RTRIM(Notes),'')
            FROM dbo.CodeLkup WITH (NOLOCK)
            WHERE ListName = 'UAPACKLIST'
            AND Code  = @cVASType
            AND UDF01 <> '1'
            AND StorerKey = @cStorerKey

            IF ISNULL(RTRIM(@cTemplate),'')  <> ''
            BEGIN
               IF @cPaperPrinter = ''
               BEGIN
                  SET @nErrNo = 93605
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PaperPrnterReq
                  GOTO Quit
               END

               SELECT
                      @cTargetDB = TargetDB
               FROM rdt.rdtReport WITH (NOLOCK)
               WHERE StorerKey = @cStorerKey
               AND   ReportType = 'PACKLIST'

               EXEC RDT.rdt_BuiltPrintJob
               @nMobile,
               @cStorerKey,
               'PACKLIST',              -- ReportType
               'UAPACKLIST',            -- PrintJobName
               @cTemplate,
               @cPaperPrinter,
               @cTargetDB,
               @cLangCode,
               @nErrNo  OUTPUT,
               @cErrMsg OUTPUT,
               @cPickSlipNo
            END
         END
      END
   END

Quit:

GO
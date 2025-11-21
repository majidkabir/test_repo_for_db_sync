SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_840ExtPrint01                                   */
/* Purpose: Print H&M label                                             */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2016-06-27 1.0  James      SOS#368195. Created                       */
/************************************************************************/

CREATE PROC [RDT].[rdt_840ExtPrint01] (
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
   @nErrNo      INT           OUTPUT, 
   @cErrMsg     NVARCHAR( 20) OUTPUT
)
AS

   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF

   DECLARE @nTranCount     INT, 
           @cReportType    NVARCHAR( 10),
           @cPrintJobName  NVARCHAR( 50),
           @cDataWindow    NVARCHAR( 50),
           @cTargetDB      NVARCHAR( 20),
           @cOrderType     NVARCHAR( 10),
           @cPaperPrinter  NVARCHAR( 10),
           @cLabelPrinter  NVARCHAR( 10),
           @nOriginalQty   INT, 
           @nPickQty       INT, 
           @nExpectedQty   INT,
           @nPackedQty     INT, 
           @nCtnCount      INT, 
           @nCtnNo         INT, 
           @b_success      INT, 
           @n_err          INT, 
           @c_errmsg       NVARCHAR( 20)


   DECLARE  @bSuccess      INT,
            @cTrackingNo   NVARCHAR( 20),
            @cCartonNo     NVARCHAR( 5),
            @cFacility     NVARCHAR( 5),
            @cUserName     NVARCHAR( 18),
            @cPrintData    NVARCHAR( MAX)

   IF @nInputKey = 1
   BEGIN
      IF @nStep = 4
      BEGIN
         SET @nCartonNo = 0
         SELECT TOP 1 @nCartonNo = CartonNo,
                      @cTrackingNo = LabelNo
         FROM dbo.PackDetail WITH (NOLOCK)
         WHERE PickSlipNo = @cPickSlipNo
         AND Storerkey = @cStorerkey
         ORDER BY 1 DESC

         -- For 1st carton, need print from RDT.
         -- For 2nd carton onwards will print from webservice
         IF @nCartonNo = 1
         BEGIN
            SELECT @cLabelPrinter = Printer,
                   @cUserName = UserName
            FROM rdt.rdtMobRec WITH (NOLOCK)  
            WHERE Mobile = @nMobile  

            SET @cCartonNo = @nCartonNo

            -- Only customer order need print below label
            IF EXISTS ( SELECT 1 FROM dbo.CODELKUP C WITH (NOLOCK) 
                        JOIN dbo.Orders O WITH (NOLOCK) ON (C.Code = O.Type AND C.StorerKey = O.StorerKey)
                        WHERE C.ListName = 'HMORDTYPE'
                        AND   C.Short = 'S'
                        AND   O.OrderKey = @cOrderkey
                        AND   O.StorerKey = @cStorerKey)
            BEGIN
               EXEC dbo.isp_PrintZplLabel
                   @cStorerKey        = @cStorerKey
                  ,@cLabelNo          = ''
                  ,@cTrackingNo       = @cTrackingNo
                  ,@cPrinter          = @cLabelPrinter
                  ,@nErrNo            = @nErrNo
                  ,@cErrMsg           = @cErrMsg

            /*
               SELECT @cPrintData = PrintData
               FROM dbo.CartonTrack WITH (NOLOCK)
               WHERE TrackingNo = @cTrackingNo
               AND   KeyName = @cStorerKey

               -- Trigger metapack here to print label
               SET @bSuccess = 1

               EXECUTE dbo.isp_PrintToRDTSpooler
                  @c_ReportType     = 'HMZPL', 
                  @c_Storerkey      = @cStorerKey,
                  @b_success        = @bSuccess OUTPUT,
                  @n_err			   = @nErrNo   OUTPUT,
                  @c_errmsg	      = @cErrMsg  OUTPUT,
                  @n_Noofparam      = 2,
                  @c_Param01        = @cPickSlipNo,
                  @c_Param02        = @cCartonNo,
                  @c_Param03        = '',
                  @c_Param04        = '',
                  @c_Param05        = '',
                  @c_Param06        = '',
                  @c_Param07        = '',
                  @c_Param08        = '',
                  @c_Param09        = '',
                  @c_Param10        = '',
                  @n_Noofcopy       = 1,
                  @c_UserName       = @cUserName,
                  @c_Facility       = @cFacility, 
                  @c_PrinterID      = '', 
                  @c_Datawindow     = '', 
                  @c_IsPaperPrinter = 'N', 
                  @c_JobType        = 'DIRECTPRN', 
                  @c_PrintData      = @cPrintData 

                  IF @bSuccess <> 1
                     GOTO Quit
            */
            END
         END
      END   --  @nStep = 4
   END   -- @nInputKey = 1

QUIT:

SET QUOTED_IDENTIFIER OFF

GO
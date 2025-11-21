SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: isp_GetReportType                                         */
/* Copyright      : Maersk                                                    */
/*                                                                            */
/* Date         Rev  Author     Purposes                                      */
/* 2024-02-09   1.0  YeeKung    TPS-821 Created                               */
/* 2024-11-06   1.1  YeeKung    TPS-969 Add Facility (yeekung01)              */
/* 2025-02-14   1.2  yeekung    TPS-995 Change Error Message (yeekung02)      */
/******************************************************************************/

CREATE   PROC [API].[isp_GetReportType] (
   @json       NVARCHAR( MAX),
   @jResult    NVARCHAR( MAX) OUTPUT,
   @b_Success  INT = 1  OUTPUT,
   @n_Err      INT = 0  OUTPUT,
   @c_ErrMsg   NVARCHAR( 255) = ''  OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

  DECLARE
      @nMobile          INT,
      @nStep            INT,
      @cLangCode        NVARCHAR( 3),
      @nInputKey        INT,
      @cScanNoType      NVARCHAR( 30),
      @cStorerKey       NVARCHAR( 15),
	   @cFacility        NVARCHAR( 5),
	   @nFunc            NVARCHAR( 5),
	   @cUserName        NVARCHAR( 128),
	   @cOriUserName     NVARCHAR( 128),
      @cScanNo          NVARCHAR( 50),
      @cDropID          NVARCHAR( 50),
      @cPickSlipNo      NVARCHAR( 30),
      @nCartonNo        INT,
      @cCartonID        NVARCHAR( 20),
      @cType            NVARCHAR( 30),
      @cWorkstation     NVARCHAR( 20),
      @cOrderKeyPrint   NVARCHAR( 20),
      @PrinterType      NVARCHAR( 20)

   --decode json
   SELECT @cStorerKey = StorerKey, @cFacility = Facility,@nFunc = Func,@cUserName = UserName,@cLangCode = LangCode
   ,@cScanNo = ScanNo,@nCartonNo = CartonNo, @cType = ctype,  @cWorkstation = Workstation, @cOrderKeyPrint = OrderKey
   ,@PrinterType = PrinterType
      FROM OPENJSON(@json)
      WITH (
	      StorerKey      NVARCHAR( 30),
	      Facility       NVARCHAR( 30),
         Func           NVARCHAR( 5),
         UserName       NVARCHAR( 128),
         LangCode       NVARCHAR( 3),
         ScanNo         NVARCHAR( 30),
         CartonNo       INT,
         cType          NVARCHAR( 30),
         Workstation    NVARCHAR( 30),
         OrderKey       NVARCHAR( 10),
         PrinterType    NVARCHAR( 10),
         ReportType     NVARCHAR( 20)
      )

   IF @PrinterType = 'Label'
   BEGIN
	   IF NOT EXISTS( SELECT  1 FROM dbo.WMReport WMR WITH (NOLOCK) 
                     JOIN WMReportdetail WMRD (NOLOCK) ON WMR.ReportID = WMRD.ReportID
                     WHERE Storerkey = @cStorerKey 
                        AND ModuleID ='TPPack'
                        AND IsPaperPrinter <> 'Y')  
      BEGIN
         SET @b_Success = 0
         SET @n_Err = 1001201
         SET @c_ErrMsg = API.TouchPadGetMessage( @n_Err, @cLangCode, 'DSP')--'no LabelReport on this storer : isp_GetReportType'
         GOTO EXIT_SP  
      END
      ELSE
      BEGIN
         SET @jResult =(SELECT reporttype
                        FROM dbo.WMReport WMR WITH (NOLOCK) 
                        JOIN WMReportdetail WMRD (NOLOCK) ON WMR.ReportID = WMRD.ReportID
                        WHERE Storerkey = @cStorerKey 
                           AND ModuleID ='TPPack'
                           AND IsPaperPrinter <> 'Y' 
                           AND (WMRD.Facility = '' OR WMRD.Facility = @cFacility) 
                        GROUP BY reporttype
                        FOR JSON AUTO , INCLUDE_NULL_VALUES)
      END
   END

   IF @PrinterType = 'Paper'
   BEGIN
	   IF NOT EXISTS( SELECT  1 FROM dbo.WMReport WMR WITH (NOLOCK) 
                     JOIN WMReportdetail WMRD (NOLOCK)  ON WMR.ReportID = WMRD.ReportID
                     WHERE Storerkey = @cStorerKey 
                        AND ModuleID ='TPPack'
                        AND IsPaperPrinter = 'Y')  
      BEGIN
         SET @b_Success = 0
         SET @n_Err = 1001202
         SET @c_ErrMsg = API.TouchPadGetMessage( @n_Err, @cLangCode, 'DSP')--'no PaperReport on this storer : isp_GetReportType'
         GOTO EXIT_SP    
      END
      ELSE
      BEGIN
         SET @jResult =(SELECT reporttype
                        FROM dbo.WMReport WMR WITH (NOLOCK) 
                        JOIN WMReportdetail WMRD (NOLOCK) ON WMR.ReportID = WMRD.ReportID
                        WHERE Storerkey = @cStorerKey 
                           AND ModuleID ='TPPack'
                           AND IsPaperPrinter = 'Y' 
                           AND (WMRD.Facility = '' OR WMRD.Facility = @cFacility) 
                        GROUP BY reporttype
                        FOR JSON AUTO , INCLUDE_NULL_VALUES)
      END
   END


   SET @b_Success = 1

   --SET @jResult =(
   --SELECT @cDefaultWorkstation AS DefaultWorkstation,workstation
   --FROM Api.AppWorkstation WITH (NOLOCK)
   --FOR JSON AUTO
   --)


   EXIT_SP:
      REVERT
END

GO
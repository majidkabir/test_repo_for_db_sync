SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO



/******************************************************************************/
/* Store procedure: isp_CheckPrinter                                          */
/* Copyright      : LFLogistics                                               */
/*                                                                            */
/* Date         Rev  Author     Purposes                                      */
/* 2020-04-07   1.0  Chermaine  Created                                       */
/* 2021-09-05   1.1  Chermaine  TPS-11 ErrMsg add to rdtmsg (cc01)            */
/* 2025-02-14   1.2  yeekung    TPS-995 Follow Error Message (yeekung01)      */
/******************************************************************************/

CREATE   PROC [API].[isp_CheckPrinter] (
   @json       NVARCHAR( MAX),
   @jResult    NVARCHAR( MAX) OUTPUT,
   @b_Success  INT = 1  OUTPUT,
   @n_Err      INT = 0  OUTPUT,
   @c_ErrMsg   NVARCHAR( 255) = ''  OUTPUT
)
AS

SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF
SET CONCAT_NULL_YIELDS_NULL OFF

DECLARE
   @cLangCode        NVARCHAR( 3),
   @cUserName        NVARCHAR( 128),
   @cStorerKey       NVARCHAR( 15),
   @cFacility        NVARCHAR( 5),
   @nFunc            INT,
   @cWorkstation     NVARCHAR( 30),
   @cReportType      NVARCHAR( 20),
   @cPrinterType     NVARCHAR( 20),
   @cPrinterTypeJson NVARCHAR( 500),
   @curPT            CURSOR

DECLARE @PrinterTypeList TABLE (
   PrinterType   NVARCHAR( 20)
)


--Decode Json Format
SELECT @cStorerKey = StorerKey, @cFacility = Facility,  @nFunc=Func, @cUserName = UserName, @cLangCode = LangCode, @cWorkstation = Workstation, @cPrinterTypeJson = PrinterType
FROM OPENJSON(@json)
WITH (
	   StorerKey   NVARCHAR( 15),
	   Facility    NVARCHAR( 5),
	   Func        INT,
	   UserName    NVARCHAR( 128),
      LangCode    NVARCHAR( 3),
      Workstation NVARCHAR( 30),
      PrinterType NVARCHAR( MAX) as json
)
--SELECT @nFunc AS Func, @cLangCode AS LangCode,@cWorkstation as Workstation

--Data Validate
IF @cWorkstation = ''
BEGIN
   SET @b_Success = 0
   SET @n_Err = 1001001
   SET @c_ErrMsg = API.TouchPadGetMessage( @n_Err, @cLangCode, 'DSP')--'Unable to retrieve Workstation ID. Function : isp_CheckPrinter. Function : isp_CheckPrinter'
   GOTO EXIT_SP
END

IF @cStorerKey = ''
BEGIN
   SET @b_Success = 0
   SET @n_Err = 1001002
   SET @c_ErrMsg = rdt.rdtgetmessage( @n_Err, @cLangCode, 'DSP')--'Unable to retrieve StorerKey. Function : isp_CheckPrinter'
   GOTO EXIT_SP
END

SET @c_ErrMsg = ''
SET @curPT = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT *
   FROM OPENJSON(@cPrinterTypeJson)
   WITH (
         Printer             NVARCHAR( 20)    '$.Printer'
   )

OPEN @curPT
   FETCH NEXT FROM @curPT INTO @cPrinterType
   WHILE @@FETCH_STATUS <> -1
   BEGIN

      IF @cPrinterType = 'Label'
      BEGIN
	      IF EXISTS (SELECT TOP 1 ReportType FROM rdt.rdtReport WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND paperType = @cprinterType)
	      BEGIN
	         SET @b_Success = 0
            SET @n_Err = 1001003
            IF @c_ErrMsg = ''
            BEGIN
            	SET @c_ErrMsg = @n_Err + @cPrinterType+ ' printer'
            END
            ELSE
            BEGIN
            	SET @c_ErrMsg =  @n_Err +  @c_ErrMsg + ' and ' + @cPrinterType+ ' printer'
            END

            --SET @c_ErrMsg = @c_ErrMsg +' not setup in Touch Pack config. Function : isp_CheckPrinter'

            --GOTO EXIT_SP
         END
      END
      ELSE
      BEGIN
	      IF EXISTS (SELECT TOP 1 ReportType FROM rdt.rdtReport WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND (paperType = @cprinterType OR paperType = ''))
	      BEGIN
	         SET @b_Success = 0
            SET @n_Err = 175619
            IF @c_ErrMsg = ''
            BEGIN
            	SET @c_ErrMsg =  @n_Err + @cPrinterType+ ' printer'
            END
            ELSE
            BEGIN
            	SET @c_ErrMsg = @n_Err + @c_ErrMsg + ' and ' + @cPrinterType+ ' printer'
            END
            --SET @c_ErrMsg = @c_ErrMsg +' not setup in Touch Pack config. Function : isp_CheckPrinter'
            --GOTO EXIT_SP
         END
      END

      FETCH NEXT FROM @curPT INTO @cPrinterType
   END

IF @c_ErrMsg = ''
BEGIN
	SET @b_Success = 1
   SET @jResult = '[{Success}]'
END
ELSE
BEGIN
	SET @c_ErrMsg = @c_ErrMsg +' not setup in Touch Pack config. Function : isp_CheckPrinter'
END


EXIT_SP:
   REVERT


SET QUOTED_IDENTIFIER OFF

GO
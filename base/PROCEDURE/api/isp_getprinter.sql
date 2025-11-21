SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO



/******************************************************************************/
/* Store procedure: isp_GetPrinter                                            */
/* Copyright      : LFLogistics                                               */
/*                                                                            */
/* Date         Rev  Author     Purposes                                      */
/* 2020-04-06   1.0  Chermaine  Created                                       */
/* 2021-09-05   1.1  Chermaine  TPS-11 ErrMsg add to rdtmsg (cc01)            */
/* 2022-04-15   1.2  YeeKung    Add LblPrinter/PPr Printer in web (yeekung01) */
/* 2025-02-14   1.3  yeekung    TPS-995 Change Error Message (yeekung02)      */
/******************************************************************************/

CREATE   PROC [API].[isp_GetPrinter] (
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
   @cLangCode           NVARCHAR( 3),
   @cUserName           NVARCHAR( 30),
   @cStorerKey          NVARCHAR( 15),
   @cFacility           NVARCHAR( 5),
   @nFunc               INT,
   @cWorkstation        NVARCHAR( 30),
   @cLabelPrinter       NVARCHAR( 20),
   @cPaperPrinter       NVARCHAR( 20),
   @cLabelPrinterConfig NVARCHAR( 20),
   @cPaperPrinterConfig NVARCHAR( 20)


--Decode Json Format
SELECT @nFunc=Func, @cLangCode = LangCode, @cWorkstation = Workstation,
       @cLabelPrinter = LabelPrinter, @cPaperPrinter = PaperPrinter
FROM OPENJSON(@json)
WITH (
	   Func        INT,
      LangCode    NVARCHAR( 3),
      Workstation NVARCHAR( 30),
      LabelPrinter NVARCHAR( 20),
      PaperPrinter NVARCHAR( 20)
)
--SELECT @nFunc AS Func, @cLangCode AS LangCode,@cWorkstation as Workstation

--convert login
SET @n_Err = 0
EXEC [WM].[lsp_SetUser] @c_UserName = @cUserName OUTPUT, @n_Err = @n_Err OUTPUT, @c_ErrMsg = @c_ErrMsg OUTPUT

EXECUTE AS LOGIN = @cUserName

IF @n_Err <> 0
BEGIN
   --INSERT INTO @errMsg(nErrNo,cErrMsg)
   SET @b_Success = 0
   SET @n_Err = @n_Err
   SET @c_ErrMsg = @c_ErrMsg
   GOTO EXIT_SP
END


----SELECT @cUserName AS username
----select SUSER_SNAME ()

--Data Validate  - ScanNo
IF @cWorkstation = ''
BEGIN
   IF ISNULL(@cLabelPrinter,'')='' AND ISNULL(@cPaperPrinter,'')=''
   BEGIN
      SET @b_Success = 0
      SET @n_Err = 1001151
      SET @c_ErrMsg = API.TouchPadGetMessage( @n_Err, @cLangCode, 'DSP')--'Unable to retrieve Workstation ID. Function : isp_GetPrinter'

      GOTO EXIT_SP
   END
END
ELSE
BEGIN
   SELECT @cLabelPrinterConfig = PrinterID FROM api.AppPrinter WITH (NOLOCK) WHERE Workstation = @cWorkstation AND PrinterType = 'Label'
   SELECT @cPaperPrinterConfig = PrinterID FROM api.AppPrinter WITH (NOLOCK) WHERE Workstation = @cWorkstation AND PrinterType = 'Paper'
END

SET @b_Success = 1
SET @jResult =(
SELECT @cLabelPrinterConfig AS LabelPrinterConfig,@cPaperPrinterConfig AS PaperPrinterConfig,* FROM (SELECT
'[' +STUFF(( SELECT ',' + '"' + printerID  + '"'
FROM rdt.rdtPrinter WITH (NOLOCK) FOR XML PATH('')),1,1,'')+ ']' as LabelPrinter
,
'[' +STUFF(( SELECT ',' + '"' + printerID + '"'
FROM rdt.rdtPrinter WITH (NOLOCK) FOR XML PATH('')),1,1,'')+ ']' as PaperPrinter
)PrinterList
FOR JSON AUTO
)

--SET @jResult =(
--SELECT JSON_QUERY('[' + STUFF(( SELECT ',' + '"' + printerID + '"'
--FROM rdt.rdtPrinter WITH (NOLOCK) FOR XML PATH('')),1,1,'') + ']' ) LabelPrinter
--FOR JSON PATH , WITHOUT_ARRAY_WRAPPER
--)



EXIT_SP:
   REVERT

SET QUOTED_IDENTIFIER OFF

GO
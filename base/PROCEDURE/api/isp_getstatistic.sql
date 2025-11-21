SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: isp_GetStatistic                                          */
/* Copyright      : LFLogistics                                               */
/*                                                                            */
/* Date         Rev  Author     Purposes                                      */
/* 2020-04-20   1.0  Chermaine  Created                                       */
/* 2021-09-05   1.1  Chermaine  TPS-11 ErrMsg add to rdtmsg (cc01)            */
/* 2023-02-10   1.2  yeekung    TPS-663 correct 'Orders' (yeekung01)          */
/* 2025-01-28   1.3  YeeKung    UWP-29489 Change API Username (yeekung02)     */
/******************************************************************************/

CREATE   PROC [API].[isp_GetStatistic] (
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
   @cUserName           NVARCHAR( 128),
   @cStorerKey          NVARCHAR( 15),
   @cFacility           NVARCHAR( 5),
   @nFunc               INT,
   @cWorkstation        NVARCHAR( 30),
   @cLabelPrinterConfig NVARCHAR( 20),
   @cPaperPrinterConfig NVARCHAR( 20)


--Decode Json Format
SELECT @nFunc=Func, @cLangCode = LangCode, @cUserName = UserName
FROM OPENJSON(@json)
WITH (
	   Func        INT,
      LangCode    NVARCHAR( 3),
      UserName    NVARCHAR( 128)
)
--SELECT @nFunc AS Func, @cLangCode AS LangCode,@cWorkstation as Workstation

--convert login
--SET @n_Err = 0
--EXEC [WM].[lsp_SetUser] @c_UserName = @cUserName OUTPUT, @n_Err = @n_Err OUTPUT, @c_ErrMsg = @c_ErrMsg OUTPUT

--EXECUTE AS LOGIN = @cUserName

--IF @n_Err <> 0
--BEGIN
--   --INSERT INTO @errMsg(nErrNo,cErrMsg)
--   SET @b_Success = 0
--   SET @n_Err = @n_Err
--   SET @c_ErrMsg = @c_ErrMsg
--   GOTO EXIT_SP
--END

----SELECT @cUserName AS username
----select SUSER_SNAME ()

--Data Validate  - ScanNo
IF @cUserName = ''
BEGIN
   SET @b_Success = 0
   SET @n_Err = 175624
   SET @c_ErrMsg = rdt.rdtgetmessage( @n_Err, @cLangCode, 'DSP')--'Unable to retrieve username. Function : isp_GetStatistic'

   GOTO EXIT_SP
END

DECLARE
@cCartonPacked NVARCHAR( 5),
@cPickSlipPacked NVARCHAR( 5)

SELECT @cPickSlipPacked = COUNT(DISTINCT pickslipNo) FROM packInfo WITH (NOLOCK) WHERE editWho = @cUserName AND CONVERT(NVARCHAR(10),editDate,121) = CONVERT(nvarchar(10),GETDATE(),121)
SELECT @cCartonPacked = COUNT(cartonNo) FROM packInfo WITH (NOLOCK) WHERE editWho = @cUserName AND CONVERT(NVARCHAR(10),editDate,121) = CONVERT(nvarchar(10),GETDATE(),121)


SET @b_Success = 1
SET @jResult =(
SELECT 'ORDERS PROCESSED' AS ColName1,@cPickSlipPacked AS ColValue1, 'CARTON PACKED' AS ColName2,@cCartonPacked AS ColValue2
,'' AS ColName3, '' AS ColValue3
,'' AS ColName4, '' AS ColValue4
,'' AS ColName5, '' AS ColValue5
FOR JSON PATH
)

EXIT_SP:
   REVERT

SET QUOTED_IDENTIFIER OFF

GO
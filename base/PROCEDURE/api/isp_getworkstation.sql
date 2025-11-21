SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: isp_GetWorkstation                                        */
/* Copyright      : LFLogistics                                               */
/*                                                                            */
/* Date         Rev  Author     Purposes                                      */
/* 2020-05-05   1.0  Chermaine  Created                                       */
/* 2021-09-05   1.1  Chermaine  TPS-11 ErrMsg add to rdtmsg (cc01)            */
/* 2025-02-14   1.2  yeekung    TPS-995 Change Error Message (yeekung01)      */
/* 2025-02-20   1.3  yeekung    UWP-27764 Add New Params (yeekung02)          */
/* 2025-03-06   1.4  yeekung    UWP-31029 Valid the storer and facility       */
/*                              setup or not (yeekung03)                      */
/******************************************************************************/

CREATE   PROC [API].[isp_GetWorkstation] (
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
   @cUserName        NVARCHAR( 30),
   @cStorerKey       NVARCHAR( 15) = '',
   @cFacility        NVARCHAR( 5) = '',
   @nFunc            INT,
   @cDeviceID        NVARCHAR( 50),
   @cDefaultWorkstation     NVARCHAR( 30),
   @cTargetVersion          NVARCHAR( 12),
   @cCurrentVersion         NVARCHAR( 12)


--Decode Json Format
SELECT @nFunc=Func, @cLangCode = LangCode, @cDeviceID = Device, @cStorerKey = Storerkey ,@cFacility  = Facility
FROM OPENJSON(@json)
WITH (
	   Func        INT,
      LangCode    NVARCHAR( 3),
      Device      NVARCHAR( 50),
      Storerkey   NVARCHAR( 15),
      Facility    NVARCHAR(  5)
)
--SELECT @nFunc AS Func, @cLangCode AS LangCode,@cWorkstation as Workstation

----convert login
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

IF @cDeviceID <>''
BEGIN
   IF ISNULL(@cDeviceID,'') <> 'WEB'
   BEGIN
      SELECT @cDefaultWorkstation = workstation, @cTargetVersion = ISNULL(TargetVersion,''), @cCurrentVersion = ISNULL(CurrentVersion,'')FROM API.AppWorkstation WHERE deviceid = @cDeviceID

      IF ISNULL(@cDefaultWorkstation,'') = ''
      BEGIN
         IF NOT EXISTS (SELECT TOP 1 1 FROM Api.AppWorkstation WITH (NOLOCK) WHERE deviceID ='')
         BEGIN
            SET @b_Success = 0
            SET @n_Err = 1001301
            SET @c_ErrMsg =  API.TouchPadGetMessage( @n_Err, @cLangCode, 'DSP')--'No workstation available for device setup. Please ensure workstation has been setup. Funtion : isp_GetWorkstation'
            GOTO EXIT_SP
         END
      END
   END
   ELSE
   BEGIN
      IF NOT EXISTS (SELECT TOP 1 1 FROM Api.AppWorkstation WITH (NOLOCK) WHERE DefaultStorerkey = ISNULL(@cStorerKey,'') AND DefaultFacility =  ISNULL(@cFacility,''))
      BEGIN
         SET @b_Success = 0
         SET @n_Err = 1001303
         SET @c_ErrMsg =  API.TouchPadGetMessage( @n_Err, @cLangCode, 'DSP')--'1001303 Workstation no setup defaultstorer and defaultfacility. Funtion : isp_GetWorkstation'
         GOTO EXIT_SP
      END
   END
END
ELSE
BEGIN
	SET @b_Success = 0
   SET @n_Err = 1001302
   SET @c_ErrMsg =  API.TouchPadGetMessage( @n_Err, @cLangCode, 'DSP')--'Device ID setup not done. Please setup the Device ID. Funtion : isp_GetWorkstation'

   GOTO EXIT_SP
END

SET @b_Success = 1

--SET @jResult =(
--SELECT @cDefaultWorkstation AS DefaultWorkstation,workstation
--FROM Api.AppWorkstation WITH (NOLOCK)
--FOR JSON AUTO
--)

SET @jResult =(
SELECT @cDefaultWorkstation AS DefaultWorkstation,@cCurrentVersion AS CurrentVersion, @cTargetVersion AS TargetVersion,* FROM (SELECT
'[' +STUFF(( SELECT ',' + '"' + workstation  + '"'
FROM Api.AppWorkstation WITH (NOLOCK) WHERE deviceID IN('','WEB') AND DefaultStorerkey = ISNULL(@cStorerKey,'') AND DefaultFacility =  ISNULL(@cFacility,'') FOR XML PATH('')),1,1,'')+ ']' as WorkStationList
)WorkStationList1
FOR JSON AUTO , INCLUDE_NULL_VALUES
)


EXIT_SP:
   REVERT

SET QUOTED_IDENTIFIER OFF

GO
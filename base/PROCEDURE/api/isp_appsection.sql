SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/******************************************************************************/
/* Store procedure: isp_AppSection                                            */
/* Copyright      : LFLogistics                                               */
/*                                                                            */
/* Date         Rev  Author     Purposes                                      */
/* 2020-03-13   1.0  Chermaine  Created                                       */
/* 2021-08-11   1.1  Chermaine  TPS-623 Fix Multiple user line (cc01)         */
/* 2021-09-05   1.2  Chermaine  TPS-11 ErrMsg add to rdtmsg (cc02)            */
/* 2024-02-19   1.3  YeeKung    TPS-839 Add Defaultstorer/facility (yeekung02)*/
/* 2024-03-25   1.4  YeeKung    TPS-899 add max timeout (yeekung01)           */
/* 2024-12-31   1.5  YeeKung    TPS-995 Change error message (yeekung03)      */ 
/* 2025-02-20   1.6  yeekung    UWP-27764 remove checking on web (yeekung04)  */
/******************************************************************************/

--App,DeviceID,UserID,ScanNo
CREATE   PROC [API].[isp_AppSection] (
   @json       NVARCHAR( MAX),
   @jResult    NVARCHAR( MAX) OUTPUT,
   @b_Success  INT = 1  OUTPUT,
   @n_Err      INT = 0  OUTPUT,
   @c_ErrMsg   NVARCHAR( 255) = ''  OUTPUT,
   @n_LogOut   INT = 0  OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE
	   @cStorerKey    NVARCHAR( 30),
	   @cFacility     NVARCHAR( 5),
	   @cLangCode     NVARCHAR( 3),
	   @cAppName      NVARCHAR( 30),
	   @cDeviceID     NVARCHAR( 50),
	   @cUserID       NVARCHAR( 128),
      @cScanNo       NVARCHAR( 30),
      @cType         NVARCHAR( 30),
      @timeOut       INT,
      @dNow          DATETIME,
      @c_UserName    NVARCHAR( 128),
      @cSCEUserName  NVARCHAR( 128),
      @cWorkStation  NVARCHAR( 30)

   SET @dNow = GETDATE()

   DECLARE @errMsg TABLE (
       nErrNo    INT,
       cErrMsg   NVARCHAR( 1024)
   )

   --Decode Json Format
   --'[{"StorerKey":"NIKESG","Facility":"","AppName":"TouchPad","DeviceID":"Device2","UserID":"chermainecheng","ScanNo":"","cType":"Login"}]
   SELECT @cStorerKey = StorerKey, @cFacility = Facility, @cAppName = AppName, @cDeviceID = DeviceID,  @cUserID=UserID, @cScanNo=ScanNo, @cType = cType, @cLangCode = LangCode,@cWorkStation= WorkStation
   FROM OPENJSON(@json)
   WITH (
	      StorerKey   NVARCHAR( 30),
	      Facility    NVARCHAR( 15),
	      AppName     NVARCHAR( 30),
	      DeviceID    NVARCHAR( 50),
	      UserID      NVARCHAR( 128),
         ScanNo      NVARCHAR( 30),
         cType       NVARCHAR( 30),
         LangCode    NVARCHAR( 3),
         WorkStation NVARCHAR( 30)
   )

   SET @cSCEUserName = @cUserID
   --SELECT @cStorerKey, @cFacility, @cAppName, @cDeviceID,  @cUserID, @cScanNo, @cType

   --convert login
   SET @n_Err = 0
   EXEC [WM].[lsp_SetUser] @c_UserName = @cUserID OUTPUT, @n_Err = @n_Err OUTPUT, @c_ErrMsg = @c_ErrMsg OUTPUT

   EXECUTE AS LOGIN = @cUserID

   IF @n_Err <> 0
   BEGIN
      --INSERT INTO @errMsg(nErrNo,cErrMsg)
      SET @b_Success = 0
      SET @n_Err = @n_Err
   --   SET @c_ErrMsg = @c_ErrMsg
      GOTO EXIT_SP
   END



   --SELECT @c_UserName AS c_UserName
   --SELECT @cUserID AS cUserID
   --select SUSER_SNAME () AS sname

   --Data Validate : Check ScanNo blank
   IF  @cAppName = '' OR @cDeviceID = ''  OR @cSCEUserName = ''
   BEGIN
      SET @b_Success = 0
      SET @n_Err = 1000801
      SET @c_ErrMsg = API.TouchPadGetMessage( @n_Err, @cLangCode, 'DSP')--'Insufficient parameter for application process execution. Function : isp_AppSection'
      GOTO EXIT_SP
   END

--get StorerConfig

   EXECUTE dbo.nspGetRight @cFacility
      , @cStorerKey         -- Storer
      , ''                   -- Sku
      , 'TPSectionTime'          -- ConfigKey
      , @b_success   OUTPUT
      , @timeOut     OUTPUT
      , @n_err       OUTPUT
      , @c_errmsg    OUTPUT

   IF @b_success <> 1
   BEGIN
      SET @b_Success = 0
      SET @n_Err = 175602
      SET @c_ErrMsg = API.TouchPadGetMessage( @n_Err, @cLangCode, 'DSP')--'Error in executing nspGetRight. Function : isp_AppSection'
      SET @n_LogOut = 0

      GOTO EXIT_SP
   END
  --SELECT @timeOut

	IF @timeOut = 0  
		SET @timeOut = 99999  

   --type: login
   IF @cType = 'LogIn'
   BEGIN
	   --1a. DeviceID not in db
	   IF NOT EXISTS (SELECT TOP 1 1 FROM API.AppSection WITH (NOLOCK) WHERE deviceID = @cDeviceID)
	   BEGIN
		   --SELECT  '1a'
	      --User lock by others device: user not yet expired
		   IF EXISTS (SELECT TOP 1 1 FROM API.AppSection WITH (NOLOCK) WHERE UserID = @cSCEUserName AND (DATEADD(s,@timeOut,SectionTime) > @dNow OR SectionTime IS NULL))
         BEGIN
      	   --SELECT  '1ab'
      	   SET @b_Success = 0
            SET @n_Err = 175603
            SET @c_ErrMsg = rdt.rdtgetmessage( @n_Err, @cLangCode, 'DSP')--'User login in another device. Please logout from previous device before login in this device. Function : isp_AppSection'
            SET @n_LogOut = 1

            GOTO EXIT_SP
         END
         ELSE
         BEGIN
      	   --SELECT  '1aa'
		      INSERT INTO API.AppSection (APPName,DeviceID,UserID,SectionTime,ScanNo,AddWho,AddDate,EditWho,EditDate)
		      VALUES (@cAppName,@cDeviceID,@cSCEUserName,@dNow,@cScanNo,@cSCEUserName,@dNow,@cSCEUserName,@dNow)
         END

		   GOTO SUCCESS_SP
	   END
	   ELSE
	   --1b. DeviceID in db
	   BEGIN
		   --SELECT  '1b'
		   GOTO DEVICE_SP
	   END

      DEVICE_SP:
      -- 2a. Device expired
      IF EXISTS (SELECT TOP 1 1 FROM API.AppSection WITH (NOLOCK) WHERE deviceID = @cDeviceID AND (DATEADD(s,@timeOut,SectionTime) < @dNow OR SectionTime IS NULL))
      BEGIN
   	   --SELECT  '2a'
   	   GOTO CHECK_USER_SP
      END
      ELSE
      --2b. Device still using
      BEGIN
   	   --SELECT  '2b'
   	   GOTO USER_SP
      END

      SCANNO_SP:
      --3a. No ScanNo - can direct update
	   IF @cScanNo = ''
	   BEGIN
		   --SELECT  '3a'
		   UPDATE API.AppSection WITH (ROWLOCK)
		   SET userID = @cSCEUserName,
			   SectionTime = @dNow,
			   editWho = @cSCEUserName,
			   editDate = @dNow
		   WHERE deviceID = @cDeviceID
            AND userID = @cSCEUserName

		   GOTO SUCCESS_SP
	   END
	   ELSE
	   --3b. got ScanNo
	   BEGIN
		   --SELECT  '3b'
         GOTO SCANNO_LOCK_SP
	   END

      SCANNO_LOCK_SP:
      --4a pickslip locked - not yet expired
      IF EXISTS (SELECT TOP 1 1 FROM API.AppSection WITH (NOLOCK) WHERE ScanNo = @cScanNo AND (DATEADD(s,@timeOut,SectionTime) > @dNow))
      BEGIN
   	   --SELECT  '4a'
   	   GOTO SCANNO_LOCKBYWHO_SP
      END
      ELSE
      --4b pickslip No locked
      BEGIN
   	   --SELECT  '4b'
   	   UPDATE API.AppSection WITH (ROWLOCK)
		   SET SectionTime = @dNow,
			   ScanNo = @cScanNo,
			   EditWho = @cSCEUserName,
			   EditDate = @dNow
		   WHERE deviceID = @cDeviceID
            AND userID = @cSCEUserName
			   


         IF EXISTS (SELECT 1
                    FROM API.AppWorkstation (NOLOCK)
                    WHERE deviceid = @cDeviceID
                     AND (DefaultStorerkey <> @cStorerKey
                     OR DefaultFacility <> @cFacility))
         BEGIN
            UPDATE API.AppWorkstation WITH (ROWLOCK)
		      SET DefaultStorerkey = @cStorerKey,
			      DefaultFacility = @cFacility,
			      EditWho = @cSCEUserName,
			      EditDate = @dNow
		      WHERE deviceID = @cDeviceID
               AND WorkStation = @cWorkStation
         END

		   GOTO SUCCESS_SP
      END

      SCANNO_LOCKBYWHO_SP:
      --5a pickslip locked by user himself
      IF EXISTS (SELECT TOP 1 1 FROM API.AppSection WITH (NOLOCK) WHERE ScanNo = @cScanNo AND UserID = @cSCEUserName)
      BEGIN
   	   --SELECT  '5a'
   	   UPDATE API.AppSection WITH (ROWLOCK)
		   SET SectionTime = @dNow,
			   ScanNo = @cScanNo,
			   EditWho = @cSCEUserName,
			   EditDate = @dNow
		   WHERE deviceID = @cDeviceID
           AND userID = @cSCEUserName

		   GOTO SUCCESS_SP
      END
      ELSE
      --5b. locked by others user
      BEGIN
   	   --SELECT  '5b'
   	   SET @b_Success = 0
         SET @n_Err = 175604
         SET @c_ErrMsg = rdt.rdtgetmessage( @n_Err, @cLangCode, 'DSP')--'The scanned document ID is process by another user. Please use another document ID. Function : isp_AppSection'
         SET @n_LogOut = 0

         GOTO EXIT_SP
      END

      USER_SP:
      --6a device locked: by same user himself
      IF EXISTS (SELECT TOP 1 1 FROM API.AppSection WITH (NOLOCK) WHERE DeviceID = @cDeviceID AND UserID = @cSCEUserName AND (DATEADD(s,@timeOut,SectionTime) > @dNow OR SectionTime IS NULL))
      BEGIN
   	   --SELECT  '6a'
   	   GOTO SCANNO_SP
      END
      ELSE
      --6b device locked: by others user
      BEGIN
   	   --SELECT  '6b'
   	   SET @b_Success = 0
         SET @n_Err = 175605
         SET @c_ErrMsg = rdt.rdtgetmessage( @n_Err, @cLangCode, 'DSP')--'Other user login to this device. Please ensure no other user login in this device before proceed to login. Function : isp_AppSection'
         SET @n_LogOut = 1

         GOTO EXIT_SP
      END

      CHECK_USER_SP:
      --7a. User lock by others device: user not yet expired
      -- IF User no proper logout, username still in section, remove user from expired secion (cc01)
      IF EXISTS (SELECT TOP 1 1 FROM API.AppSection WITH (NOLOCK) WHERE UserID = @cSCEUserName AND (DATEADD(s,@timeOut,SectionTime) < @dNow OR SectionTime IS NULL))
      BEGIN
   	   UPDATE API.AppSection WITH (ROWLOCK)
	      SET userID = '',
		      SectionTime = Null,
		      ScanNo = '',
		      EditWho = SUSER_SNAME (),
		      EditDate = @dNow
	      WHERE UserID = @cSCEUserName
	      AND (DATEADD(s,@timeOut,SectionTime) < @dNow OR SectionTime IS NULL)
      END

      IF EXISTS (SELECT TOP 1 1 FROM API.AppSection WITH (NOLOCK) WHERE UserID = @cSCEUserName AND (DATEADD(s,@timeOut,SectionTime) > @dNow OR SectionTime IS NULL))
      BEGIN
   	   --SELECT  '7a'
   	   SET @b_Success = 0
         SET @n_Err = 175606
         SET @c_ErrMsg = rdt.rdtgetmessage( @n_Err, @cLangCode, 'DSP')--'User found login in another device. Please logout from previous device before proceed to login in this device. Function : isp_AppSection'
         SET @n_LogOut = 1

         GOTO EXIT_SP
      END
      ELSE
      --7b user locked by others device
      BEGIN
   	   --SELECT  '7b'
   	   GOTO SCANNO_SP
      END
    END

   --type: logout
   IF @cType = 'LogOut'
   BEGIN
	   IF EXISTS ( SELECT TOP 1 1 
                  FROM API.AppSection WITH (NOLOCK) 
                  WHERE DeviceID = @cDeviceID 
                  AND userID = @cSCEUserName)
	   UPDATE API.AppSection WITH (ROWLOCK)
	   SET userID = '',
		   SectionTime = Null,
		   ScanNo = '',
		   EditWho = SUSER_SNAME (),
		   EditDate = @dNow
	   WHERE deviceID = @cDeviceID
         AND userID = @cSCEUserName

	   GOTO SUCCESS_SP
   END

   --type: unlock
   IF @cType = 'Unlock'
   BEGIN
	   IF EXISTS (SELECT TOP 1 1 FROM API.AppSection WITH (NOLOCK) 
                  WHERE DeviceID = @cDeviceID 
                     and userID = @cSCEUserName)
      BEGIN
	      UPDATE API.AppSection WITH (ROWLOCK)
	      SET ScanNo = '',
	      EditWho = SUSER_SNAME (),
	      EditDate = @dNow
	      WHERE deviceID = @cDeviceID
	         AND userID = @cSCEUserName

	      GOTO SUCCESS_SP
      END
   END

   SUCCESS_SP:
      SET @b_Success = 1
	   SET @jResult = (SELECT @dNow AS SectionTime, @timeOut AS ConfigInSec FOR JSON PATH)
	   GOTO EXIT_SP


   EXIT_SP:
      REVERT
END

GO
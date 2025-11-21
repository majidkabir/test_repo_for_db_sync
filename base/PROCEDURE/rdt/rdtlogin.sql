SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: rdtLogin                                           */
/* Creation Date:                                                       */
/* Copyright: Maersk                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.3                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author  Ver.  Purposes                                  */
/* 2005-11-25   dhung   1.1   Fix ESC key not working on verify storer  */
/*                            and facility screen                       */
/* 2007-08-10   Vicky   1.2   Add Printer Validation & LangCode         */
/* 2007-12-14   Vicky   1.3   SOS#89137 - Check on MultiLogon setting   */
/*                            Y - allow MultiLogon, N - not allow       */
/* 2009-04-08   Vicky   1.4   Disable MultiLogin (Vicky01)              */
/* 2009-10-05   Vicky   1.5   Retire RDTMobRec with Func = 0 (Vicky02)  */
/* 2010-07-22   Vicky   1.6   Add Paper Printer field (Vicky03)         */
/* 2011-03-31   Ung     1.7   SOS190785 Add rdt user active / inactive  */
/* 2012-03-12   Ung     1.8   SOS235841 Add rdt login record            */
/* 2012-05-22   Ung     1.9   SOS245172 Fix field attr not reset (ung01)*/
/* 19-Nov-2012  James   2.0   Fix nVARCHAR length (james01)             */
/* 2013-03-18   Ung     2.1   SOS271056 Add DeviceID                    */
/* 2014-08-29   ChewKP  2.2   SOS#317796 Add LightMode (ChewKP01)       */
/* 2015-09-17   Ung     2.3   SOS349992 Fix DeviceID field disabled     */
/* 2016-08-15   Ung     2.4   Update rdtMobRec with Editdate            */
/*                            Set focus on login, storer facility screen*/
/* 2018-02-05   James   2.5   WMS3893-Add DefaultDeviceID (james02)     */
/* 2019-04-18   YeeKung 2.6   Fix handheld incorrect logout(yeekung01)  */
/* 2021-01-21   James   2.7   WMS-15781 Add AllowResumeSession (james03)*/
/* 2024-05-24   NLT013  2.8   Add session id to get unique mobile       */
/* 2024-07-26   JACKC   2.9   UWP-19305 Encrypt rdt password            */
/* 2024-08-15   JACKC   3.0   UWP-15736 Penetration Testing Fix         */
/************************************************************************/

CREATE PROC [RDT].[rdtLogin] (
   @nMobile    int,
   @nErrNo     int  OUTPUT,
   @cErrMsg    NVARCHAR(1024) OUTPUT,
   @nFunction  int OUTPUT,
   @cClientIP  NVARCHAR( 15),
   @cSessionID NVARCHAR(60) = ''
)
AS
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF

   DECLARE @nFunc                int,
          @nScn                  int,
          @nStep                 int,
          @cUsrName              NVARCHAR(18),
          @cPassword             NVARCHAR(15),
          @cEncryptPwd           NVARCHAR(32), --（jackc)
          @cStorer               NVARCHAR(15),
          @cFacility             NVARCHAR(5),
          @cLangCode             NVARCHAR(3),
          @iMenu                 int,
          @cMultiLogin           NVARCHAR(1),
          @cUsrPasswd            NVARCHAR(32),
          @cDefaultUOM           NVARCHAR(10),
          @bSuccess              int,
          @cPrinter              NVARCHAR(10), -- Added on 10-Aug-2007
          @cPrinter_Paper        NVARCHAR(10), -- (Vicky03)
          @cDeviceID             NVARCHAR(20),
          @cActive               NVARCHAR(1),
          @cLightMode            NVARCHAR(10), -- (ChewKP01)
          @cAllowResumeSession   NVARCHAR( 1),   -- (james03)
          @nLoginFailCount       INT,
          @dLastLoginDate        DATETIME

   SELECT @nFunc     = Func,
          @nScn      = Scn,
          @nStep     = Step,
          @cUsrName  = I_Field01,
          @cPassword = I_Field02
	FROM   RDT.RDTMOBREC WITH (NOLOCK)  WHERE Mobile = @nMobile

   IF RTRIM(@cUsrName) IS NULL OR RTRIM(@cUsrName) = ''
   BEGIN
      SELECT @nErrNo = -1,
             @cErrMsg = 'Retrieve Mobile Record Failed, Mobile# ' + RTRIM( CAST(@nMobile as NVARCHAR(4)) )-- (james01)
      EXEC rdt.rdtSetFocusField @nMobile, 1
      GOTO RETURN_SP
   END

   --V3.0 JacKc
   SELECT TOP 1 @dLastLoginDate = AddDate 
   FROM rdt.rdtloginlog WITH (NOLOCK) 
   WHERE Remarks = 'LOGIN' 
      AND UserName = @cUsrName 
   ORDER BY AddDate DESC

   SELECT @nLoginFailCount = COUNT(1) 
      FROM RDT.RDTLoginLog WITH (NOLOCK)
      WHERE UserName = @cUsrName 
         AND Remarks = 'InvIDPwd'  
         AND datediff(second,adddate,GETDATE()) < 30
         AND AddDate > ISNULL(@dLastLoginDate, '1900-01-01 00:00:00.000')
      
   IF @nLoginFailCount > 4
   BEGIN
      SELECT @nErrNo = -1,
      @nStep = 0,
      @cErrMsg = rdt.rdtgetmessage(221151,@cLangCode,'DSP')
      EXEC rdt.rdtSetFocusField @nMobile, 1
      GOTO EXIT_PROCESS
   END

   --V3.0 Jackc End

   --V2.9 Jackc
   SET @cEncryptPwd = rdt.rdt_RDTUserEncryption(@cUsrName, @cPassword)
   --V2.9 Jackc End


   SELECT @cStorer     = ISNULL(DefaultStorer, ''),
          @cFacility   = ISNULL(DefaultFacility, ''),
          @cLangCode   = DefaultLangCode, --ISNULL(DefaultLangCode, ''),
          @iMenu       = ISNULL(DefaultMenu, ''),
          @cMultiLogin = ISNULL(MultiLogin, 0),
          @cUsrPasswd  = ISNULL([Password], ''),
          @cDefaultUOM = ISNULL(DefaultUOM, ''),
          @cPrinter    = ISNULL(DefaultPrinter, ''), -- Added on 10-Aug-2007
          @cPrinter_Paper = ISNULL(DefaultPrinter_Paper, ''), -- (Vicky03)
          @cDeviceID   = ISNULL(DefaultDeviceID, ''), -- (james02)
          @cActive     = ISNULL(Active, ''),
          @cLightMode  = ISNULL(DefaultLightColor, '' ), -- (ChewKP01)
          @cAllowResumeSession = AllowResumeSession
   FROM RDT.rdtUser WITH (NOLOCK)
   WHERE Username =  @cUsrname

   IF @@ROWCOUNT = 0 OR (@cUsrPasswd IS NULL) OR (@cUsrPasswd <> @cEncryptPwd)
   BEGIN
      INSERT INTO RDT.rdtLoginLog (UserName, Mobile, ClientIP, Remarks, SessionID)
      VALUES (@cUsrname, @nMobile, @cClientIP, 'InvIDPwd', @cSessionID)

      SELECT @nErrNo = -1,
         @nStep = 0,
         @cErrMsg = rdt.rdtgetmessage(1,@cLangCode,'DSP')
   END
   ELSE
   BEGIN
      UPDATE RDT.RDTMOBREC WITH (ROWLOCK) SET
         EditDate = GETDATE(),
         Lang_Code = CASE WHEN ISNULL(@cLangCode, '') <> '' THEN @cLangCode ELSE 'ENG' END
      WHERE Mobile = @nMobile
   END

   -- SOS190785 Add rdt user active / inactive
   IF @cActive <> '1'
   BEGIN
      SELECT
         @nStep = 0,
         @nErrNo = -1,
         @cErrMsg = rdt.rdtgetmessage(52, @cLangCode, 'DSP') --52^InactiveUser
   END

   -- (james03)
   IF @cAllowResumeSession <> 'Y'
   BEGIN
 	IF EXISTS (SELECT 1 FROM RDT.RDTMOBREC (NOLOCK) WHERE Username = RTRIM(@cUsrName) AND Step > 0)
 	BEGIN
 	   SELECT @nErrNo = -1,
 	            @cErrMsg = rdt.rdtgetmessage(44,@cLangCode,'DSP')
 	   --GOTO RETURN_SP
 	END
   END

   -- (Vicky02) - Start
   IF EXISTS (SELECT 1 FROM RDT.RDTMOBREC (NOLOCK) WHERE Username = RTRIM(@cUsrName) AND Func <= 5 AND Mobile <> @nMobile)
   BEGIN
      DECLARE @nRetireMobile INT
      SELECT TOP 1
         @nRetireMobile = Mobile
      FROM RDT.RDTMOBREC WITH (NOLOCK)
      WHERE Username = RTRIM(@cUsrName)
         AND Func <= 5
         AND Mobile <> @nMobile

      WHILE @nRetireMobile > 0
      BEGIN
         UPDATE RDT.RDTMOBREC WITH (ROWLOCK) SET
            EditDate = GETDATE(),
            Username = 'RETIRED'
         WHERE Mobile = @nRetireMobile
         -- WHERE Username = @cUsrName
         --    AND Func <= 5
         --    AND Mobile <> @nMobile

         SET @nRetireMobile = 0
         SELECT TOP 1
            @nRetireMobile = Mobile
         FROM RDT.RDTMOBREC WITH (NOLOCK)
         WHERE Username = RTRIM(@cUsrName)
            AND Func <= 5
            AND Mobile <> @nMobile
      END
   END

   -- (Vicky02) - End

   -- (Vicky01) - Start
   IF EXISTS (SELECT 1 FROM RDT.RDTMOBREC (NOLOCK) WHERE Username = RTRIM(@cUsrName) AND Func > 0) --(yeekung01)
   BEGIN
		SET @nScn = 5390
		SET @nFunc = 2
		SET @nStep = 1
   END

	-- (Vicky01) - End

   -- Validate SQL login
   EXECUTE RDT.rdtIsSQLLoginSetup @cUsrName, @cLangCode, @bSuccess OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT
   IF @bSuccess = 0 -- Fail
   BEGIN
      SET @nErrNo = -1
      SET @nStep = 0
   END

   --V3.0 Jackc
   EXIT_PROCESS:
   --V3.0 Jackc end

   IF @nErrNo <> -1
   BEGIN
      -- Update user Last Login data and time
      BEGIN TRAN

      Update RDT.rdtUser WITH (ROWLOCK)
       SET LastLogin = GetDate()
      WHERE Username =  @cUsrname

      -- Insert login record
      INSERT INTO RDT.rdtLoginLog (UserName, Mobile, ClientIP, Remarks, SessionID)
      VALUES (@cUsrname, @nMobile, @cClientIP, 'Login', @cSessionID)

      COMMIT TRAN
   END

	IF (@nStep=0) AND (@nScn=0) --(yeekung01)
	BEGIN
		-- Login Successfull update Step
		SET @nStep = 1
		SET @nScn = 1
		SET @nFunc = 1
	END

   BEGIN TRAN

   IF @nErrNo = -1
   BEGIN
      UPDATE RDT.RDTMOBREC WITH (ROWLOCK) SET
         EditDate = GETDATE(),
         ErrMsg = @cErrMsg
      WHERE Mobile = @nMobile
   END
   ELSE
   BEGIN
   	IF @nFunc=1 --(yeekung01)
		BEGIN
			
	      EXEC rdt.rdtSetFocusField @nMobile, 1
	      UPDATE RDT.RDTMOBREC WITH (ROWLOCK) SET
	         EditDate  = GETDATE(),
	         Facility  = @cFacility,
	         StorerKey = @cStorer,
	         ErrMsg    = @cErrMsg,
	         Username  = @cUsrName,
	         Lang_code = @cLangCode,
	         Scn       = @nScn,
	         Step      = @nStep,
				Func      = @nFunc,
	         O_Field01 = @cStorer,
	         O_Field02 = @cFacility,
	         O_Field03 = CASE @cDefaultUOM WHEN '1' THEN 'Pallet'
	                                       WHEN '2' THEN 'Carton'
	                                       WHEN '3' THEN 'Inner Pack'
	                                       WHEN '4' THEN 'Other Unit 1'
	                                       WHEN '5' THEN 'Other Unit 2'
	                                       WHEN '6' THEN 'Each'
	                                       ELSE 'Each'
	                     END,
	         O_Field04 = @cPrinter,
	         O_Field05 = @cPrinter_Paper, -- (Vicky03)
	         O_Field06 = @cDeviceID,
	         V_UOM     = @cDefaultUOM,
	         Printer   = @cPrinter,
	         Printer_Paper = @cPrinter_Paper, -- (Vicky03)
	         DeviceID  = @cDeviceID,
	         LightMode = @cLightMode, -- (ChewKP01)
	         FieldAttr01 = '', --(ung01)
	         FieldAttr02 = '',
	         FieldAttr03 = '',
	         FieldAttr04 = '',
	         FieldAttr05 = '',
	         FieldAttr06 = '',
	         FieldAttr07 = '',
	         FieldAttr08 = '',
	         FieldAttr09 = '',
	         FieldAttr10 = '',
	         FieldAttr11 = '',
	         FieldAttr12 = '',
	         FieldAttr13 = '',
	         FieldAttr14 = '',
	         FieldAttr15 = ''
	      WHERE Mobile = @nMobile
	   END
	   ELSE IF @nFunc =2 --(yeekung01)
		BEGIN
			EXEC rdt.rdtSetFocusField @nMobile, 1
			UPDATE RDT.RDTMOBREC WITH (ROWLOCK) SET
			EditDate  = GETDATE(),
			ErrMsg    = @cErrMsg,
			Username  = @cUsrName,
			Lang_code = @cLangCode,
			Scn       = @nScn,
			Step      = @nStep,
			Func      = @nFunc
			WHERE Mobile = @nMobile
		END
	END
	
   IF @@ERROR <> 0
   BEGIN
      ROLLBACK TRAN
   END
   ELSE
   BEGIN
      COMMIT TRAN
   END

RETURN_SP:

GO
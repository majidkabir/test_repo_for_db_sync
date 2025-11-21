SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_MY_EPOD_Update                                 */
/* Creation Date: 13-Mar-2014                                           */
/* Copyright: LFL                                                       */
/* Written by: Chee Jun Yan                                             */
/*                                                                      */
/* Purpose: Update info from ePOD table to WMS's POD Table for          */
/*          Philippines SOS#303938                                      */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/* 06-Jun-2014  CHEE          - Add EPOD.AddDate & EPOD.Try parameter   */
/*                            - Add StorerConfig - UseEPODSystemDate to */
/*                              use EPOD.AddDate as EPOD Delivery Date  */
/*                            - Send EmailAlert on final try (Chee01)   */
/* 01-Oct-2014  CHEE          - SOS#321425 Update Image File Name to    */
/*                              POD.TrackCol03, create/append CSV file  */
/*                              for DMS (Chee02)                        */
/* 30-Oct-2014  CHEE          - Add buffer to run this script for epod. */
/*                              adddate > 300 secs, to make sure enough */
/*                              time to upload first image, so that     */
/*                              the epod record will be added into DMS  */
/*                              INDEX file (Chee03)                     */
/************************************************************************/

CREATE PROC [dbo].[isp_MY_EPOD_Update] (
  @cStorerKey           NVARCHAR(15),
  @cEPOD_OrderKey       NVARCHAR(50),
  @cEPODStatus          NVARCHAR(10),
  @cEPOD_Date           DATETIME,
  @cEPODNotes           NVARCHAR(1000),
  @cLatitude            NVARCHAR(30),
  @cLongtitude          NVARCHAR(30),
  @cAccountID           NVARCHAR(30),
  @cRejectReasonCode    NVARCHAR(20),
  @nePODKey             BIGINT,
  @dLocationCaptureDate DATETIME,
  @nUID                 INT,
  @cContainImage        NVARCHAR(1),
  @cEmailTitle          NVARCHAR(250)  = '',
  @cEmailRecipients     NVARCHAR(1000) = '',
  @nErrorNo             INT = 1 OUTPUT,
  @cErrorMsg            NVARCHAR(2048) = '' OUTPUT,
  @cEPODAddDate         DATETIME,  -- (Chee01)
  @nEPODTry             INT        -- (Chee01)
) 
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_WARNINGS OFF
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF

   DECLARE
      @nReturnCode      INT,
      @cSubject         NVARCHAR(255),
      @cEmailBodyHeader NVARCHAR(255),
      @cTableHTML       NVARCHAR(MAX),
      @b_debug          INT,
      @b_success        INT,
      @n_StartTCnt      INT

   DECLARE @tError TABLE
      ( ErrorNo INT
      , ErrorMessage NVARCHAR(1000))

   DECLARE
      @cType                   NVARCHAR(2),
      @cFinalizeFlag           NVARCHAR(1),
      @cPODDef07               NVARCHAR(30),
      @cStampNotes             NVARCHAR(4000),
      @cEPODStatusDescr        NVARCHAR(30),
      @cRejectReasonCodeDescr  NVARCHAR(30)

   -- SOS#321425 (Chee02)
   DECLARE
      @cDocType             NCHAR(3),
      @cCountry             NCHAR(2),
      @cStorerCode          NCHAR(3),
      @cImgKey              NCHAR(12),
      @cVersion             NCHAR(2),
      @cImageFileName       NVARCHAR(30),
      @cCSVFileName         NVARCHAR(50),
      @cCSVFilePath         NVARCHAR(50),
      @cCSVFileContent      NVARCHAR(500), 
      @cCSVCommand          NVARCHAR(4000),
      @cGenKeyRef1          NCHAR(30),
      @cGenKeyRef2          NCHAR(30),
      @cGenKeyRef3          NCHAR(30),
      @cGenKeyRef4          NCHAR(30),
      @cGenKeyRef5          NCHAR(30),
      @cWMSStorerKey        NVARCHAR(15),

      @cSourceDBName        NVARCHAR(30),
      @cExecStatements      NVARCHAR(4000),
      @cArguments           NVARCHAR(4000)

   SET @cWMSStorerKey = ''
   SET @cSourceDBName = ''
   SET @cExecStatements = ''
   SET @cArguments = ''
 
   DECLARE @tFiles TABLE (FullPath NVARCHAR(2000))

   SELECT @nErrorNo = 0, @cErrorMsg = '', @b_Success = 1 
   SET @b_debug = 0
   SET @cDocType = 'POD'  -- Hardcode to POD (Chee02)

   SET @n_StartTCnt = @@TRANCOUNT

   SELECT @cSourceDBName = ISNULL(RTRIM(Code), '')
   FROM CODELKUP WITH (NOLOCK)
   WHERE LISTNAME = 'EPODTable'

   IF @cSourceDBName = ''
   BEGIN
      SET @b_success = 0
      SET @nErrorNo = 90001
      SET @cErrorMsg = RTRIM(@cErrorMsg) + ' Invalid SourceDatabaseName# ' + ISNULL(RTRIM(@cSourceDBName), '') + '.'
      INSERT INTO @tError VALUES (@nErrorNo, @cErrorMsg)
      GOTO QUIT
   END

   --Check WMS Storer with EPOD Storer (Alex01)
   IF NOT EXISTS (SELECT  TOP 1 * FROM CODELKUP (NOLOCK) WHERE  Code = @cAccountID AND LISTNAME = 'EPODStorer')
   BEGIN
      SET @b_success = 0
      SET @nErrorNo = 90001
      SET @cErrorMsg = RTRIM(@cErrorMsg) + ' Invalid AccountID# ' + ISNULL(RTRIM(@cAccountID), '') + '.'
      INSERT INTO @tError VALUES (@nErrorNo, @cErrorMsg)
      GOTO QUIT
   END
   ELSE 
   BEGIN
      SELECT @cWMSStorerKey = StorerKey 
      FROM Codelkup WITH (NOLOCK)
      WHERE Code = @cAccountID AND LISTNAME = 'EPODStorer'
   END

   -- Add buffer to retry next time if EPOD.Adddate < 30 secs (Chee03)
   IF DATEDIFF(second, @cEPODAddDate, GETDATE()) < 300
   BEGIN
      SET @b_Success = 0
      SET @nErrorNo = 70010
      SET @cErrorMsg = 'Retry on next schedule because EPOD.AddDate < 300 seconds. (isp_MY_EPOD_Update)'
      GOTO QUIT
   END

   -- Switch EPOD.AddDate as EPODDeliveryDatem (Chee01)
   IF EXISTS (SELECT 1 FROM dbo.StorerConfig WITH (NOLOCK) 
              WHERE ConfigKey = 'UseEPODSystemDate' AND SValue = '1'
              AND StorerKey = @cWMSStorerKey)
   BEGIN
      SET @cEPOD_Date = @cEPODAddDate

      -- Update epod.adddate to epod.deliveryDate 
      --UPDATE ePOD.dbo.EPOD WITH (ROWLOCK)
      --SET DeliveryDate = AddDate
      --WHERE ePODKey = @nePODKey

      SET @cExecStatements = ''
      SET @cArguments = ''
      SET @cExecStatements = N'UPDATE ' + ISNULL(RTRIM(@cSourceDBName), '') + '.dbo.EPOD WITH (ROWLOCK) '
                           + 'SET DeliveryDate = AddDate '
                           + 'WHERE ePODKey = @nePODKey '

      SET @cArguments = N'@nePODKey    BIGINT'

      EXEC sp_ExecuteSql @cExecStatements
                        ,@cArguments
                        ,@nePODKey

   END

   -- Get ImgKey (Chee02)
   SET @cImgKey = @cEPOD_OrderKey

   SET @cType = LEFT(@cEPOD_OrderKey, 2)
   -- Remove Prefix
   IF @cType IN ('MB', 'LP')
      SET @cEPOD_OrderKey = RIGHT(@cEPOD_OrderKey, LEN(@cEPOD_OrderKey) - 2)
   ELSE
      SET @cImgKey = 'SO' + @cImgKey

   SET @cFinalizeFlag = ''
   SELECT TOP 1
      @cFinalizeFlag = P.FinalizeFlag ,
      @cPODDef07     = P.PODDef07
   FROM dbo.POD P WITH (NOLOCK)
   WHERE @cEPOD_OrderKey = CASE @cType
                              WHEN 'MB' THEN MbolKey
                              WHEN 'LP' THEN LoadKey
                           ELSE ExternOrderKey
                           END
   AND   StorerKey = @cWMSStorerKey

   IF @cFinalizeFlag = ''
   BEGIN
      SET @b_Success = 0
      SET @nErrorNo = 70000
      SET @cErrorMsg = 'ePOD [' + CASE WHEN @cType IN ('MB', 'LP') THEN @cType ELSE '' END + @cEPOD_OrderKey + 
                       '] under StorerKey [' + @cAccountID + '] not exists in WMS POD. (isp_MY_EPOD_Update)'
      INSERT INTO @tError VALUES (@nErrorNo, @cErrorMsg)
      GOTO QUIT
   END

   IF @cFinalizeFlag = 'Y'
   BEGIN
      SET @b_Success = 0
      SET @nErrorNo = 70001
      SET @cErrorMsg = 'ePOD [' + CASE WHEN @cType IN ('MB', 'LP') THEN @cType ELSE '' END + @cEPOD_OrderKey +
                       '] under StorerKey [' + @cAccountID + '] already finalized in WMS POD. (isp_MY_EPOD_Update)'
      INSERT INTO @tError VALUES (@nErrorNo, @cErrorMsg)
      GOTO QUIT
   END

   IF ISNULL(@cPODDef07, '') <> ''
   BEGIN
      SET @b_Success = 0
      SET @nErrorNo = 70002
      SET @cErrorMsg = 'ePOD [' + CASE WHEN @cType IN ('MB', 'LP') THEN @cType ELSE '' END + @cEPOD_OrderKey +
                       '] under StorerKey [' + @cAccountID + '] has already existing status in WMS POD. (isp_MY_EPOD_Update)'
      INSERT INTO @tError VALUES (@nErrorNo, @cErrorMsg)
      GOTO QUIT
   END

   IF @b_debug = '1'
      PRINT '@cType: ' + CASE WHEN @cType IN ('MB', 'LP') THEN @cType ELSE '' END + ', @cEPOD_OrderKey: ' + @cEPOD_OrderKey
         
   SET @cStampNotes = ''
   SELECT @cStampNotes = ISNULL(Notes, '') 
   FROM dbo.CODELKUP WITH (NOLOCK)
   WHERE LISTNAME = 'EPODNOTES'
     AND Code = '1'

   -- Get EPOD Status Description
	SELECT @cEPODStatusDescr = @cEPODStatus, @cFinalizeFlag = 'N'
	--SELECT 
 --     @cEPODStatusDescr = @cEPODStatusDescr + ' - ' + Description, 
 --     @cFinalizeFlag = CASE UDF05 WHEN 'Y' THEN 'Y' ELSE 'N' END
	--FROM ePOD.dbo.CODELKUP PODSTATUS WITH (NOLOCK)
	--WHERE LISTNAME = 'PODSTATUS'
	--  AND Code = @cEPODStatus
	--  AND PODSTATUS.StorerKey = CASE WHEN EXISTS(SELECT 1 FROM ePOD.dbo.CODELKUP WITH (NOLOCK)
	--															WHERE ListName=PODSTATUS.Listname
	--															  AND Code=PODSTATUS.Code
	--															  AND StorerKey=@cAccountID) THEN @cWMSStorerKey
	--									 ELSE '' END
   
   SET @cExecStatements = ''
   SET @cArguments = ''
    SET @cExecStatements = N'SELECT @cEPODStatusDescr = @cEPODStatusDescr + '' - '' + Description, '
                        + '@cFinalizeFlag = CASE UDF05 WHEN ''Y'' THEN ''Y'' ELSE ''N'' END '
                        + 'FROM ' + ISNULL(RTRIM(@cSourceDBName), '') + '.dbo.CODELKUP PODSTATUS WITH (NOLOCK) '
                        + 'WHERE LISTNAME = ''PODSTATUS'' '
                        + 'AND Code = @cEPODStatus '
                        + 'AND PODSTATUS.StorerKey = CASE WHEN EXISTS(SELECT 1 FROM ' 
                        + ISNULL(RTRIM(@cSourceDBName), '') + '.dbo.CODELKUP WITH (NOLOCK) '
                        + 'WHERE ListName=PODSTATUS.Listname '
                        + 'AND Code=PODSTATUS.Code '
                        + 'AND StorerKey=@cAccountID) THEN @cWMSStorerKey '
                        + 'ELSE '''' END '

   SET @cArguments = N'@cEPODStatus          NVARCHAR(10), '
                   + '@cAccountID            NVARCHAR(30), '
                   + '@cWMSStorerKey         NVARCHAR(15), '
                   + '@cEPODStatusDescr      NVARCHAR(30) OUTPUT, '
                   + '@cFinalizeFlag         NVARCHAR(1)  OUTPUT '

   EXEC sp_ExecuteSql @cExecStatements
                     ,@cArguments
                     ,@cEPODStatus
                     ,@cAccountID
                     ,@cWMSStorerKey
                     ,@cEPODStatusDescr   OUTPUT
                     ,@cFinalizeFlag      OUTPUT

   -- Get Reject Reason Code Description
	SET @cRejectReasonCodeDescr = @cRejectReasonCode
	--SELECT @cRejectReasonCodeDescr = @cRejectReasonCodeDescr + ' - ' + Description
	--FROM ePOD.dbo.CODELKUP REASONCODE WITH (NOLOCK)
	--WHERE Code = @cRejectReasonCode
	--  AND REASONCODE.LISTNAME = CASE WHEN EXISTS(SELECT 1 FROM ePOD.dbo.CODELKUP WITH (NOLOCK)
	--															WHERE ListName='L2REASON'
	--															  AND Code=REASONCODE.Code) THEN 'L2REASON'
	--											ELSE 'REASONCODE' END
	--AND REASONCODE.StorerKey = CASE WHEN EXISTS(SELECT 1 FROM ePOD.dbo.CODELKUP WITH (NOLOCK)
	--															 WHERE ListName=REASONCODE.LISTNAME
	--																AND Code=REASONCODE.Code
	--																AND StorerKey=@cAccountID) THEN @cWMSStorerKey
	--											 ELSE '' END

   SET @cExecStatements = ''
   SET @cArguments = ''
   SET @cExecStatements = N'SELECT @cRejectReasonCodeDescr = @cRejectReasonCodeDescr + '' - '' + Description '
                       + 'FROM ' + ISNULL(RTRIM(@cSourceDBName), '') + '.dbo.CODELKUP REASONCODE WITH (NOLOCK) '
                       + 'WHERE Code = @cRejectReasonCode '
                       + 'AND REASONCODE.LISTNAME = CASE WHEN EXISTS(SELECT 1 FROM ' + ISNULL(RTRIM(@cSourceDBName), '') 
                                                                     + '.dbo.CODELKUP WITH (NOLOCK) '
                                                                     + 'WHERE ListName=''L2REASON'' '
                                                                     + 'AND Code=REASONCODE.Code) THEN ''L2REASON'' '
                                                                     + 'ELSE ''REASONCODE'' END '
                       + 'AND REASONCODE.StorerKey = CASE WHEN EXISTS(SELECT 1 FROM ' + ISNULL(RTRIM(@cSourceDBName), '') 
                                                                     + '.dbo.CODELKUP WITH (NOLOCK) ' 
                                                                     + 'WHERE ListName=REASONCODE.LISTNAME '
                                                                     + 'AND Code=REASONCODE.Code '
                                                                     + 'AND StorerKey=@cAccountID) THEN @cWMSStorerKey '
                                                                     + 'ELSE '''' END ' 

   SET @cArguments = N'@cRejectReasonCode          NVARCHAR(20), '
                   + '@cAccountID                  NVARCHAR(30), ' 
                   + '@cWMSStorerKey               NVARCHAR(15), '
                   + '@cRejectReasonCodeDescr      NVARCHAR(30) OUTPUT, '
                   + '@cFinalizeFlag               NVARCHAR(1)  OUTPUT '

   EXEC sp_ExecuteSql @cExecStatements
                     ,@cArguments
                     ,@cRejectReasonCode
                     ,@cAccountID
                     ,@cWMSStorerKey
                     ,@cRejectReasonCodeDescr   OUTPUT
                     ,@cFinalizeFlag            OUTPUT

   -- If Contain Image (Chee02)
   IF @cContainImage = '1'
   BEGIN
      -- Get Country Code (Chee02)
      --SELECT @cCountry = Code
      --FROM ePOD.dbo.CODELKUP (NOLOCK)
      --WHERE LISTNAME = 'COUNTRY'

      SET @cExecStatements = ''
      SET @cArguments = ''
      SET @cExecStatements = N'SELECT @cCountry = Code ' 
                           + 'FROM ' + ISNULL(RTRIM(@cSourceDBName), '') + '.dbo.CODELKUP WITH (NOLOCK) '
                           + 'WHERE LISTNAME = ''COUNTRY'' '

      SET @cArguments = N'@cCountry    NCHAR(2) OUTPUT'

      EXEC sp_ExecuteSql @cExecStatements
                        ,@cArguments
                        ,@cCountry OUTPUT

      IF ISNULL(@cCountry, '') = ''
      BEGIN
         SET @b_success = 0
         SET @nErrorNo = 70004
         SET @cErrorMsg = 'Failed to retrieve Country Code. (isp_MY_EPOD_Update)'
         INSERT INTO @tError VALUES (@nErrorNo, @cErrorMsg)
         GOTO QUIT
      END

      -- Get Storer Code (Chee02)
      --SELECT @cStorerCode = Code, @cCSVFilePath = Long
      --FROM ePOD.dbo.CODELKUP (NOLOCK)
      --WHERE LISTNAME = 'DMSSTORER'
--  AND StorerKey = @cStorerKey

      SET @cExecStatements = ''
      SET @cArguments = ''
      SET @cExecStatements = N'SELECT @cStorerCode = Code, @cCSVFilePath = Long ' 
                           + 'FROM ' + ISNULL(RTRIM(@cSourceDBName), '') + '.dbo.CODELKUP WITH (NOLOCK) '
                           + 'WHERE LISTNAME = ''DMSSTORER'' '
                           + 'AND StorerKey = @cStorerKey'

      SET @cArguments = N'@cStorerKey     NVARCHAR(15), '
                      + '@cCSVFilePath    NVARCHAR(50) OUTPUT, '
                      + '@cStorerCode     NCHAR(3) OUTPUT'

      EXEC sp_ExecuteSql @cExecStatements
                        ,@cArguments
                        ,@cStorerKey
                        ,@cCSVFilePath OUTPUT
                        ,@cStorerCode OUTPUT

      IF ISNULL(@cStorerCode, '') = ''
      BEGIN
         SET @b_success = 0
         SET @nErrorNo = 70005
         SET @cErrorMsg = 'Failed to retrieve Storer Code. (isp_MY_EPOD_Update)'
         INSERT INTO @tError VALUES (@nErrorNo, @cErrorMsg)
         GOTO QUIT
      END

      IF ISNULL(@cCSVFilePath, '') = ''
      BEGIN
         SET @b_success = 0
         SET @nErrorNo = 70006
         SET @cErrorMsg = 'Failed to retrieve CSV File Path. (isp_MY_EPOD_Update)'
         INSERT INTO @tError VALUES (@nErrorNo, @cErrorMsg)
         GOTO QUIT
      END

      -- Get Version (Chee02)
      --SELECT @cVersion = RIGHT('00' + CAST(COUNT(1) AS NVARCHAR), 2)
      --FROM ePOD.dbo.EPOD (NOLOCK)
      --WHERE OrderKey = CASE WHEN @cType IN ('MB', 'LP') THEN @cImgKey
      --                      ELSE @cEPOD_OrderKey
      --                  END

      SET @cExecStatements = ''
      SET @cArguments = ''
      SET @cExecStatements = N'SELECT @cVersion = RIGHT(''00'' + CAST(COUNT(1) AS NVARCHAR), 2) ' 
                           + 'FROM ' + ISNULL(RTRIM(@cSourceDBName), '') + '.dbo.EPOD (NOLOCK) '
                           + 'WHERE OrderKey = CASE WHEN @cType IN (''MB'', ''LP'') THEN @cImgKey '
                           + '                 ELSE @cEPOD_OrderKey '
                           + '                 END'

      SET @cArguments = N'@cType             NVARCHAR(2), '
                      + '@cImgKey            NCHAR(12), '
                      + '@cEPOD_OrderKey     NVARCHAR(50), '
                      + '@cVersion           NCHAR(2) OUTPUT'

      EXEC sp_ExecuteSql @cExecStatements
                        ,@cArguments
                        ,@cType
                        ,@cImgKey
                        ,@cEPOD_OrderKey
                        ,@cVersion OUTPUT

      -- Build Image File Name (Chee02)
      IF ISNULL(@cImageFileName, '') = ''
         SET @cImageFileName = @cDocType + '-' + @cCountry + @cStorerCode + @cImgKey + @cVersion

      IF ISNULL(@cImageFileName, '') = ''
      BEGIN
         SET @b_success = 0
         SET @nErrorNo = 70007
         SET @cErrorMsg = 'Failed to retrieve Image File Name. (isp_MY_EPOD_Update)'
         INSERT INTO @tError VALUES (@nErrorNo, @cErrorMsg)
         GOTO QUIT
      END
   END -- IF @cContainImage = '1'

   BEGIN TRAN

   IF @cEPODStatus = '1'
   BEGIN
      UPDATE dbo.POD WITH (ROWLOCK)
      SET    Status = '7'
            ,ActualDeliveryDate = @cEPOD_Date
            ,Notes = @cEPODNotes
            ,Notes2 = @cStampNotes
            ,Latitude = @cLatitude
            ,Longtitude = @cLongtitude
            ,FinalizeFlag = @cFinalizeFlag
            ,TrackCol05 = CAST(@nePODKey AS NVARCHAR)
            ,TrackDate05 = @dLocationCaptureDate
            ,PODDef07  = @cEPODStatusDescr
            ,TrackCol03 = CASE WHEN @cContainImage = '1' THEN @cImageFileName ELSE TrackCol03 END -- (Chee02)
      WHERE @cEPOD_OrderKey = CASE @cType
                              WHEN 'MB' THEN MbolKey
                              WHEN 'LP' THEN LoadKey 
                              ELSE ExternOrderKey 
                         END
      AND   StorerKey = @cWMSStorerKey
      AND   FinalizeFlag = 'N'
   END -- IF @cEPODStatus = '1'
   ELSE IF @cEPODStatus = '2'
   BEGIN
      UPDATE dbo.POD WITH (ROWLOCK)
      SET    Status = '4'
            ,ActualDeliveryDate = @cEPOD_Date
            ,Notes = @cEPODNotes
            ,Notes2 = @cStampNotes
            ,Latitude = @cLatitude
            ,Longtitude = @cLongtitude
            ,FinalizeFlag = @cFinalizeFlag
            ,TrackCol05 = CAST(@nePODKey AS NVARCHAR)
            ,TrackDate05 = @dLocationCaptureDate
            ,PODDef02  = @cRejectReasonCode
            ,PODDef03  = @cRejectReasonCodeDescr
            ,PODDef07  = @cEPODStatusDescr
            ,TrackCol03 = CASE WHEN @cContainImage = '1' THEN @cImageFileName ELSE TrackCol03 END -- (Chee02)
      WHERE @cEPOD_OrderKey = CASE @cType
                              WHEN 'MB' THEN MbolKey
                              WHEN 'LP' THEN LoadKey
                              ELSE ExternOrderKey
                           END
      AND   StorerKey = @cWMSStorerKey
      AND   FinalizeFlag = 'N'
   END -- IF @cEPODStatus = '2'
   ELSE IF @cEPODStatus = '3'
   BEGIN
      UPDATE dbo.POD WITH (ROWLOCK)
      SET    Status = '2'
            ,ActualDeliveryDate = @cEPOD_Date
            ,Notes = @cEPODNotes
            ,Notes2 = @cStampNotes
            ,Latitude = @cLatitude
            ,Longtitude = @cLongtitude
            ,FinalizeFlag = @cFinalizeFlag
            ,TrackCol05 = CAST(@nePODKey AS NVARCHAR)
            ,TrackDate05 = @dLocationCaptureDate
            ,RejectReasonCode = @cRejectReasonCode
            ,FullRejectDate = @cEPOD_Date
            ,PODDef04  = @cRejectReasonCodeDescr
            ,PODDef07  = @cEPODStatusDescr
            ,TrackCol03 = CASE WHEN @cContainImage = '1' THEN @cImageFileName ELSE TrackCol03 END -- (Chee02)
      WHERE @cEPOD_OrderKey = CASE @cType
                              WHEN 'MB' THEN MbolKey
                              WHEN 'LP' THEN LoadKey
                              ELSE ExternOrderKey
                           END
      AND   StorerKey = @cWMSStorerKey
      AND   FinalizeFlag = 'N'
   END -- IF @cEPODStatus = '3'
   ELSE IF @cEPODStatus = '4'
   BEGIN
      UPDATE dbo.POD WITH (ROWLOCK)
      SET    Status = '3'
            ,ActualDeliveryDate = @cEPOD_Date
            ,Notes = @cEPODNotes
            ,Notes2 = @cStampNotes
            ,Latitude = @cLatitude
            ,Longtitude = @cLongtitude
            ,FinalizeFlag = @cFinalizeFlag
            ,TrackCol05 = CAST(@nePODKey AS NVARCHAR)
            ,TrackDate05 = @dLocationCaptureDate
            ,RejectReasonCode = @cRejectReasonCode
            ,PartialRejectDate = @cEPOD_Date
            ,PODDef04  = @cRejectReasonCodeDescr
            ,PODDef07  = @cEPODStatusDescr
            ,TrackCol03 = CASE WHEN @cContainImage = '1' THEN @cImageFileName ELSE TrackCol03 END -- (Chee02)
      WHERE @cEPOD_OrderKey = CASE @cType
                              WHEN 'MB' THEN MbolKey
                              WHEN 'LP' THEN LoadKey
                              ELSE ExternOrderKey
                           END
      AND   StorerKey = @cWMSStorerKey
      AND   FinalizeFlag = 'N'
   END -- IF @cEPODStatus = '4'
   ELSE
   BEGIN
      UPDATE dbo.POD WITH (ROWLOCK)
      SET    Status = '7'
            ,ActualDeliveryDate = @cEPOD_Date
            ,Notes = @cEPODNotes
            ,Notes2 = @cStampNotes
            ,Latitude = @cLatitude
            ,Longtitude = @cLongtitude
            ,FinalizeFlag = @cFinalizeFlag
            ,TrackCol05 = CAST(@nePODKey AS NVARCHAR)
            ,TrackDate05 = @dLocationCaptureDate
            ,PODDef07  = @cEPODStatusDescr
            ,TrackCol03 = CASE WHEN @cContainImage = '1' THEN @cImageFileName ELSE TrackCol03 END -- (Chee02)
      WHERE @cEPOD_OrderKey = CASE @cType
                              WHEN 'MB' THEN MbolKey
                              WHEN 'LP' THEN LoadKey
                              ELSE ExternOrderKey
                           END
      AND   StorerKey = @cWMSStorerKey
      AND   FinalizeFlag = 'N'
   END

   IF @@ERROR <> 0
   BEGIN
      SET @b_Success = 0
      SET @nErrorNo = 70003
      SET @cErrorMsg = 'Update POD Failed. (isp_MY_EPOD_Update)'
      INSERT INTO @tError VALUES (@nErrorNo, @cErrorMsg)
      GOTO Quit
   END
   COMMIT TRAN

   -- If Contain Image (Chee02)
   IF @cContainImage = '1'
   BEGIN
      -- Create/Append CSV file (Chee02)
      IF RIGHT(@cCSVFilePath,1) <> '\'
         SET @cCSVFilePath = @cCSVFilePath + '\'

      -- Get File Content
      SELECT @cCSVFileContent = 
         '"WMSPOD01",' +                                                                -- Mapping ID (default)
         '"' + RTRIM(ISNULL(@cCountry, '')) + '",' +                                    -- Country
         '"' + RTRIM(ISNULL(O.StorerKey, '')) + '",' +                                  -- Client
         '"' + RTRIM(ISNULL(P.TrackCol03, '')) + '",' +                                -- Filename
         '"' + RTRIM(ISNULL(@cDocType, '')) + '",' +                                    -- Document Type
         '"' + RTRIM(ISNULL(O.ExternOrderKey, '')) + '",' +                             -- Client Reference No
         '"' + RTRIM(ISNULL(O.BuyerPO, '')) + '",' +                                    -- PO Number
         '"' + RTRIM(ISNULL(O.ConsigneeKey, '')) + '",' +                               -- Sold To
         '"' + RTRIM(ISNULL(O.C_Company, '')) + '",' +                                  -- Sold To Name
         '"' + RTRIM(ISNULL(O.C_City, '')) + '",' +                                     -- Sold To City
         '"' + RTRIM(ISNULL(O.InvoiceNo, '')) + '",' +                                  -- Invoice No
         '"' + RTRIM(ISNULL(CONVERT(NVARCHAR, P.PODDate01, 105), '')) + '",' +          -- Invoice Date
         '"' + RTRIM(ISNULL(CONVERT(NVARCHAR, P.ActualDeliveryDate, 105), '')) + '",' + -- Actual Delivery Date
         '"' + RTRIM(ISNULL(CONVERT(NVARCHAR, P.PODReceivedDate, 105), '')) + '",' +    -- Document Capture Date
         '"",' +                                                                        -- Tracking No
         CAST(@nePODKey AS NVARCHAR)                                                    -- Temporarily Add ePODKey at the end, will be removed before sending to DMS 
      FROM dbo.POD P (NOLOCK)
      LEFT JOIN dbo.Orders O (NOLOCK) ON O.OrderKey = P.OrderKey
      WHERE @cEPOD_OrderKey = CASE @cType
                              WHEN 'MB' THEN P.MbolKey
                              WHEN 'LP' THEN P.LoadKey
                              ELSE P.ExternOrderKey
                           END
      AND   P.StorerKey = @cWMSStorerKey
      AND   P.FinalizeFlag = @cFinalizeFlag

      -- Check if file Exists
      SET @cCSVCommand = 'DIR "' + @cCSVFilePath + @cCountry + '_WMS_DispatchOrder_*.csv"'
      INSERT INTO @tFiles
      EXECUTE xp_cmdshell @cCSVCommand

      SELECT @cCSVFileName = SUBSTRING(FullPath, CHARINDEX(@cCountry, FullPath), LEN(FullPath) -1)
      FROM @tFiles
      WHERE FullPath LIKE '%' + @cCountry + '_WMS_DispatchOrder_%.csv'

      IF ISNULL(@cCSVFileName, '') = ''
      BEGIN
         SET @cCSVFileName = @cCountry + '_WMS_DispatchOrder_' +  REPLACE(REPLACE(REPLACE(CONVERT(NVARCHAR, GETDATE(), 120), '-', ''), ':', ''), ' ', '') + '.csv'
         -- Add Header Text
         SET @cCSVCommand = 'ECHO Mapping ID,Country,Client,Filename,Document Type,Client Reference No,PO Number,Sold To,Sold To Name,' + 
                            'Sold To City,Invoice No,Invoice Date,Actual Delivery Date,Document Capture Date,Tracking No,Record Status>>"' + 
                            @cCSVFilePath + @cCSVFileName + '"'
         EXEC @nReturnCode = xp_cmdshell @cCSVCommand 
         IF @nReturnCode <> 0
         BEGIN
            SET @b_success = 0  
            SET @nErrorNo = 70008
            SET @cErrorMsg = 'Failed to create CSV file. (isp_MY_EPOD_Update)'
            INSERT INTO @tError VALUES (@nErrorNo, @cErrorMsg)
            GOTO QUIT
         END
      END

      -- Write file content to CSV file
      SET @nReturnCode = 0
      SET @cCSVCommand = 'ECHO '+ @cCSVFileContent + '>>"' + @cCSVFilePath + @cCSVFileName + '"'
      EXEC @nReturnCode = xp_cmdshell @cCSVCommand
      IF @nReturnCode <> 0
      BEGIN
         SET @b_success = 0  
         SET @nErrorNo = 70009
         SET @cErrorMsg = 'Failed to create CSV file. (isp_MY_EPOD_Update)'
         INSERT INTO @tError VALUES (@nErrorNo, @cErrorMsg)
         GOTO QUIT
      END
   END -- IF @cContainImage = '1'

QUIT:
 
   -- Update ErrMsg
   IF @nErrorNo <> 0 AND ISNULL(RTRIM(@cEmailRecipients),'') <> ''
   BEGIN
      -- Send EmailAlert on final try (Chee01)
      IF @nEPODTry = 3
      BEGIN
         SET @cSubject = @cEmailTitle + ' (' + @cEPOD_OrderKey + ')'
         SET @cEmailBodyHeader = @cStorerCode + ' MY EPOD Update Error '
         SET @cTableHTML =
             N'<H1>' + @cEmailBodyHeader + '</H1>' +
             N'<table border="1">' +
             N'<tr><th>Error No</th><th>Error Message</th>' +
             CAST ( ( SELECT td = ErrorNo, ''
                            ,td = ErrorMessage, ''
                      FROM @tError
               FOR XML PATH('tr'), TYPE
             ) AS NVARCHAR(MAX) ) +
             N'</table>' ;

         EXEC @nReturnCode = msdb.dbo.sp_send_dbmail @recipients=@cEmailRecipients
                                          ,  @subject=@cSubject
                                          ,  @body=@cTableHTML
                                          ,  @body_format='HTML';
      END -- IF @nEPODTry = 3
   END

   WHILE @@TRANCOUNT < @n_StartTCnt
      BEGIN TRAN

   IF @b_Success = 0  -- Error Occured - Process And Return
   BEGIN  
      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt
      BEGIN  
         ROLLBACK TRAN  
      END  
      ELSE  
      BEGIN  
         WHILE @@TRANCOUNT > @n_StartTCnt  
         BEGIN  
            COMMIT TRAN  
         END  
      END
   END 
   ELSE
   BEGIN
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
   END
END -- Procedure

GO
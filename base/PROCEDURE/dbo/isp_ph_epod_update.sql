SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_PH_EPOD_Update                                 */
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
/* 13-Nov-2015  Alex          - Enhancement - Setup storerkey in        */
/*                              Codelkup by EPODStorer ListName         */
/* 16-Mar-2021  Alex01        - Dynamic SQL for cross db execution      */
/************************************************************************/

CREATE PROC [dbo].[isp_PH_EPOD_Update] (
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
      @cWMSStorerKey        NVARCHAR(15)

   --Alex01 Begin
   DECLARE
      @cSQLQuery            NVARCHAR(MAX) = '',
      @cSQLArgs             NVARCHAR(2000) = '',
      @cDBName              NVARCHAR(30) = REPLACE(DB_NAME(), 'WMS', 'EPOD')
   --Alex01 End

   SET @cWMSStorerKey = ''

 
   DECLARE @tFiles TABLE (FullPath NVARCHAR(2000))

   SELECT @nErrorNo = 0, @cErrorMsg = '', @b_Success = 1 
   SET @b_debug = 0
   SET @cDocType = 'POD'  -- Hardcode to POD (Chee02)

   SET @n_StartTCnt = @@TRANCOUNT

   --Check WMS Storer with EPOD Storer (Alex01)
   IF NOT EXISTS (SELECT  TOP 1 * FROM CODELKUP (NOLOCK) WHERE  Code = @cAccountID AND LISTNAME = 'EPODStorer')
   BEGIN
      SET @b_success = 0
      SET @nErrorNo = 71000
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
      SET @cErrorMsg = 'Retry on next schedule because EPOD.AddDate < 300 seconds. (isp_PH_EPOD_Update)'
      GOTO QUIT
   END

   -- Switch EPOD.AddDate as EPODDeliveryDatem (Chee01)
   IF EXISTS (SELECT 1 FROM dbo.StorerConfig WITH (NOLOCK) 
              WHERE ConfigKey = 'UseEPODSystemDate' AND SValue = '1'
              AND StorerKey = @cWMSStorerKey)
   BEGIN
      SET @cEPOD_Date = @cEPODAddDate

      --Alex01 Begin
      -- Update epod.adddate to epod.deliveryDate 
      --UPDATE PHePOD.dbo.EPOD WITH (ROWLOCK)
      --SET DeliveryDate = AddDate
      --WHERE ePODKey = @nePODKey

      SET @cSQLQuery = 'UPDATE ' + @cDBName + '.dbo.EPOD WITH (ROWLOCK) ' + CHAR(13) +
                     + 'SET DeliveryDate = AddDate ' + CHAR(13) +
                     + 'WHERE ePODKey = @nePODKey '
      SET @cSQLArgs = '@nePODKey BIGINT'

      EXEC sys.sp_executesql @cSQLQuery, @cSQLArgs, @nePODKey
      --Alex01 End
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
                       '] under StorerKey [' + @cAccountID + '] not exists in WMS POD. (isp_PH_EPOD_Update)'
      INSERT INTO @tError VALUES (@nErrorNo, @cErrorMsg)
      GOTO QUIT
   END

   IF @cFinalizeFlag = 'Y'
   BEGIN
      SET @b_Success = 0
      SET @nErrorNo = 70001
      SET @cErrorMsg = 'ePOD [' + CASE WHEN @cType IN ('MB', 'LP') THEN @cType ELSE '' END + @cEPOD_OrderKey +
                       '] under StorerKey [' + @cAccountID + '] already finalized in WMS POD. (isp_PH_EPOD_Update)'
      INSERT INTO @tError VALUES (@nErrorNo, @cErrorMsg)
      GOTO QUIT
   END

   IF ISNULL(@cPODDef07, '') <> ''
   BEGIN
      SET @b_Success = 0
      SET @nErrorNo = 70002
      SET @cErrorMsg = 'ePOD [' + CASE WHEN @cType IN ('MB', 'LP') THEN @cType ELSE '' END + @cEPOD_OrderKey +
                       '] under StorerKey [' + @cAccountID + '] has already existing status in WMS POD. (isp_PH_EPOD_Update)'
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
   --Alex01 Begin
	--SELECT 
 --     @cEPODStatusDescr = @cEPODStatusDescr + ' - ' + Description, 
 --     @cFinalizeFlag = CASE UDF05 WHEN 'Y' THEN 'Y' ELSE 'N' END
	--FROM PHePOD.dbo.CODELKUP PODSTATUS WITH (NOLOCK)
	--WHERE LISTNAME = 'PODSTATUS'
 --     AND Code = @cEPODStatus
 --     AND PODSTATUS.StorerKey = CASE WHEN EXISTS(SELECT 1 FROM PHePOD.dbo.CODELKUP WITH (NOLOCK)
 --        WHERE ListName=PODSTATUS.Listname
 --        AND Code=PODSTATUS.Code
 --        AND StorerKey=@cAccountID) THEN @cWMSStorerKey
 --        ELSE '' END

   SET @cSQLQuery = ' SELECT ' + CHAR(13) +
                  + '    @cEPODStatusDescr = @cEPODStatusDescr + '' - '' + Description, ' + CHAR(13) +
                  + '    @cFinalizeFlag = CASE UDF05 WHEN ''Y'' THEN ''Y'' ELSE ''N'' END ' + CHAR(13) +
	               + ' FROM ' + @cDBName + '.dbo.CODELKUP PODSTATUS WITH (NOLOCK) '
	               + ' WHERE LISTNAME = ''PODSTATUS'' ' + CHAR(13) +
                  + '    AND Code = @cEPODStatus ' + CHAR(13) +
                  + '    AND PODSTATUS.StorerKey = CASE WHEN EXISTS(SELECT 1 FROM ' + @cDBName + '.dbo.CODELKUP WITH (NOLOCK) ' + CHAR(13) +
                  + '       WHERE ListName=PODSTATUS.Listname ' + CHAR(13) +
                  + '       AND Code=PODSTATUS.Code ' + CHAR(13) +
                  + '       AND StorerKey=@cAccountID) THEN @cWMSStorerKey ' + CHAR(13) +
                  + '       ELSE '''' END '

   SET @cSQLArgs = '@cEPODStatus NVARCHAR(10), @cAccountID NVARCHAR(30), @cWMSStorerKey NVARCHAR(15), '
                 + '@cEPODStatusDescr NVARCHAR(30) OUTPUT, @cFinalizeFlag NVARCHAR(1) OUTPUT'
   
   EXEC sys.sp_executesql @cSQLQuery, @cSQLArgs, @cEPODStatus, @cAccountID, @cWMSStorerKey, @cEPODStatusDescr OUTPUT, @cFinalizeFlag OUTPUT

   -- Get Reject Reason Code Description
	SET @cRejectReasonCodeDescr = @cRejectReasonCode
   --SELECT 
   --   @cRejectReasonCodeDescr = @cRejectReasonCodeDescr + ' - ' + Description
   --FROM PHePOD.dbo.CODELKUP REASONCODE WITH (NOLOCK)
   --WHERE Code = @cRejectReasonCode
   --AND REASONCODE.LISTNAME = CASE WHEN EXISTS(SELECT 1 FROM PHePOD.dbo.CODELKUP WITH (NOLOCK)
   --   WHERE ListName='L2REASON'
   --   AND Code=REASONCODE.Code) THEN 'L2REASON'
   --   ELSE 'REASONCODE' END
   --AND REASONCODE.StorerKey = CASE WHEN EXISTS(SELECT 1 FROM PHePOD.dbo.CODELKUP WITH (NOLOCK)
   --   WHERE ListName=REASONCODE.LISTNAME
   --   AND Code=REASONCODE.Code
   --   AND StorerKey=@cAccountID) THEN @cWMSStorerKey
   --   ELSE '' END

     SET @cSQLQuery = ' SELECT ' + CHAR(13) +
                    + '    @cRejectReasonCodeDescr = @cRejectReasonCodeDescr + '' - '' + Description ' + CHAR(13) +
                    + ' FROM ' + @cDBName + '.dbo.CODELKUP REASONCODE WITH (NOLOCK) ' + CHAR(13) +
                    + ' WHERE Code = @cRejectReasonCode ' + CHAR(13) +
                    + ' AND REASONCODE.LISTNAME = CASE WHEN EXISTS(SELECT 1 FROM ' + @cDBName + '.dbo.CODELKUP WITH (NOLOCK) ' + CHAR(13) +
                    + '    WHERE ListName=''L2REASON'' ' + CHAR(13) +
                    + '    AND Code=REASONCODE.Code) THEN ''L2REASON'' ' + CHAR(13) +
                    + '    ELSE ''REASONCODE'' END ' + CHAR(13) +
                    + ' AND REASONCODE.StorerKey = CASE WHEN EXISTS(SELECT 1 FROM ' + @cDBName + '.dbo.CODELKUP WITH (NOLOCK) ' + CHAR(13) +
                    + '    WHERE ListName=REASONCODE.LISTNAME ' + CHAR(13) +
                    + '    AND Code=REASONCODE.Code ' + CHAR(13) +
                    + '    AND StorerKey=@cAccountID) THEN @cWMSStorerKey ' + CHAR(13) +
                    + '    ELSE '''' END '

   SET @cSQLArgs = '@cRejectReasonCode NVARCHAR(20), @cAccountID NVARCHAR(30), @cWMSStorerKey NVARCHAR(15), '
                 + '@cRejectReasonCodeDescr NVARCHAR(30) OUTPUT'
   
   EXEC sys.sp_executesql @cSQLQuery, @cSQLArgs, @cRejectReasonCode, @cAccountID, @cWMSStorerKey, @cRejectReasonCodeDescr OUTPUT

   -- If Contain Image (Chee02)
   IF @cContainImage = '1'
   BEGIN
      -- Get Country Code (Chee02)
      --SELECT @cCountry = Code
      --FROM PHePOD.dbo.CODELKUP (NOLOCK)
      --WHERE LISTNAME = 'COUNTRY'

      SET @cSQLQuery = ' SELECT ' + CHAR(13) +
                     + ' SELECT @cCountry = Code ' + CHAR(13) +
                     + ' FROM ' + @cDBName + '.dbo.CODELKUP (NOLOCK) ' + CHAR(13) +
                     + ' WHERE LISTNAME = ''COUNTRY'' '

      SET @cSQLArgs = '@cCountry NCHAR(2) OUTPUT'
      
      EXEC sys.sp_executesql @cSQLQuery, @cSQLArgs, @cCountry OUTPUT


      IF ISNULL(@cCountry, '') = ''
      BEGIN
         SET @b_success = 0
         SET @nErrorNo = 70004
         SET @cErrorMsg = 'Failed to retrieve Country Code. (isp_PH_EPOD_Update)'
         INSERT INTO @tError VALUES (@nErrorNo, @cErrorMsg)
         GOTO QUIT
      END

      -- Get Storer Code (Chee02)
      --SELECT @cStorerCode = Code, @cCSVFilePath = Long
      --FROM PHePOD.dbo.CODELKUP (NOLOCK)
      --WHERE LISTNAME = 'DMSSTORER'
      --  AND StorerKey = @cStorerKey
      SET @cSQLQuery = ' SELECT @cStorerCode = Code, @cCSVFilePath = Long ' + CHAR(13) +
                     + ' FROM ' + @cDBName + '.dbo.CODELKUP (NOLOCK) ' + CHAR(13) +
                     + ' WHERE LISTNAME = ''DMSSTORER'' '
                     + ' AND StorerKey = @cStorerKey '

      SET @cSQLArgs = '@cStorerKey NVARCHAR(15), @cStorerCode NCHAR(3) OUTPUT'
      
      EXEC sys.sp_executesql @cSQLQuery, @cSQLArgs, @cStorerKey, @cStorerCode OUTPUT

      IF ISNULL(@cStorerCode, '') = ''
      BEGIN
         SET @b_success = 0
         SET @nErrorNo = 70005
         SET @cErrorMsg = 'Failed to retrieve Storer Code. (isp_PH_EPOD_Update)'
         INSERT INTO @tError VALUES (@nErrorNo, @cErrorMsg)
         GOTO QUIT
      END

      IF ISNULL(@cCSVFilePath, '') = ''
      BEGIN
         SET @b_success = 0
         SET @nErrorNo = 70006
         SET @cErrorMsg = 'Failed to retrieve CSV File Path. (isp_PH_EPOD_Update)'
         INSERT INTO @tError VALUES (@nErrorNo, @cErrorMsg)
         GOTO QUIT
      END

      -- Get Version (Chee02)
      --SELECT @cVersion = RIGHT('00' + CAST(COUNT(1) AS NVARCHAR), 2)
      --FROM PHePOD.dbo.EPOD (NOLOCK)
      --WHERE OrderKey = CASE WHEN @cType IN ('MB', 'LP') THEN @cImgKey
      --                      ELSE @cEPOD_OrderKey
      --                  END
      
      SET @cSQLQuery = ' SELECT @cVersion = RIGHT(''00'' + CAST(COUNT(1) AS NVARCHAR), 2) ' + CHAR(13) +
                     + ' FROM ' + @cDBName + '.dbo.EPOD (NOLOCK) ' + CHAR(13) +
                     + ' WHERE OrderKey = CASE WHEN @cType IN (''MB'', ''LP'') THEN @cImgKey '
                     + ' ELSE @cEPOD_OrderKey END '

      SET @cSQLArgs = '@cType NVARCHAR(2), @cImgKey NCHAR(12), @cEPOD_OrderKey NVARCHAR(50), @cVersion NCHAR(2) OUTPUT'
      
      EXEC sys.sp_executesql @cSQLQuery, @cSQLArgs, @cType, @cImgKey, @cEPOD_OrderKey, @cVersion OUTPUT

      -- Build Image File Name (Chee02)
      IF ISNULL(@cImageFileName, '') = ''
         SET @cImageFileName = @cDocType + '-' + @cCountry + @cStorerCode + @cImgKey + @cVersion

      IF ISNULL(@cImageFileName, '') = ''
      BEGIN
         SET @b_success = 0
 SET @nErrorNo = 70007
         SET @cErrorMsg = 'Failed to retrieve Image File Name. (isp_PH_EPOD_Update)'
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
      SET @cErrorMsg = 'Update POD Failed. (isp_PH_EPOD_Update)'
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
            SET @cErrorMsg = 'Failed to create CSV file. (isp_PH_EPOD_Update)'
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
         SET @cErrorMsg = 'Failed to create CSV file. (isp_PH_EPOD_Update)'
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
         SET @cEmailBodyHeader = @cStorerCode + ' PH EPOD Update Error '
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
SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO



/******************************************************************************/
/* Store procedure: rdt_TrackNoPalletInquiry_GetList                          */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Date       Rev  Author   Purposes                                          */
/* 2018-03-20 1.0  Ung      WMS-4225 Created                                  */
/* 2018-10-01 1.1  Ung      WMS-4225 Fix multi page issue                     */
/* 2019-07-11 1.2  James    WMS-9636 Add pallet line replace @cReason(james01)*/
/* 2022-10-17 1.3  Ung      WMS-20952 Add PalletDetailTrackingNo              */
/******************************************************************************/

CREATE   PROC [RDT].[rdt_TrackNoPalletInquiry_GetList] (
   @nMobile        INT,
   @nFunc          INT,
   @cLangCode      NVARCHAR( 3),
   @nStep          INT,
   @nInputKey      INT,
   @cFacility      NVARCHAR( 5),
   @cStorerKey     NVARCHAR( 15),
   @cType          NVARCHAR( 10),
   @cPalletKey     NVARCHAR( 20),
   @cMBOLKey       NVARCHAR( 10),
   @cTrackNo       NVARCHAR( 20),
   @cTotalCarton   NVARCHAR( 20) = NULL OUTPUT,
   @cInvalidCarton NVARCHAR( 20) = NULL OUTPUT,
   @cOutField01    NVARCHAR( 20) = ''   OUTPUT,
   @cOutField02    NVARCHAR( 20) = ''   OUTPUT,
   @cOutField03    NVARCHAR( 20) = ''   OUTPUT,
   @cOutField04    NVARCHAR( 20) = ''   OUTPUT,
   @cOutField05    NVARCHAR( 20) = ''   OUTPUT,
   @cOutField06    NVARCHAR( 20) = ''   OUTPUT,
   @cOutField07    NVARCHAR( 20) = ''   OUTPUT,
   @cOutField08    NVARCHAR( 20) = ''   OUTPUT,
   @cOutField09    NVARCHAR( 20) = ''   OUTPUT,
   @cOutField10    NVARCHAR( 20) = ''   OUTPUT,
   @cCurrentPage   NVARCHAR( 2)  = ''   OUTPUT,
   @cTotalPage     NVARCHAR( 2)  = ''   OUTPUT,
   @nErrNo         INT           = 0    OUTPUT,
   @cErrMsg        NVARCHAR( 20) = ''   OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nRowRef           INT
   DECLARE @nCount            INT
   DECLARE @nTotalRecord      INT
   DECLARE @nRecordOnPage     INT
   DECLARE @nCurrentPage      INT
   DECLARE @nTopRecordOnPage  INT
   DECLARE @cReason           NVARCHAR( 20)
   DECLARE @cOrderKey         NVARCHAR( 10)
   DECLARE @cOutField         NVARCHAR( 20)
   DECLARE @cPalletLineNumber NVARCHAR( 5)
   DECLARE @cLineNumberToDisplay NVARCHAR( 20)
   DECLARE @cPalletDetailTrackingNo NVARCHAR( 1)
   
   SET @cPalletDetailTrackingNo = rdt.rdtGetConfig( @nFunc, 'PalletDetailTrackingNo', @cStorerKey)
   
   /***********************************************************************************************
                                             Get statistics
   ***********************************************************************************************/
   -- Total carton
   IF @cTotalCarton IS NOT NULL
      SELECT @cTotalCarton = COUNT(1)
      FROM PalletDetail PD WITH (NOLOCK)
      WHERE PalletKey = @cPalletKey

   -- Invalid carton
   IF @cInvalidCarton IS NOT NULL
   BEGIN
      IF @cPalletDetailTrackingNo = '1'
         SELECT @cInvalidCarton = COUNT(1)
         FROM PalletDetail PD WITH (NOLOCK)
            LEFT JOIN CartonTrack CT WITH (NOLOCK) ON (PD.TrackingNo = CT.TrackingNo)
            LEFT JOIN Orders O WITH (NOLOCK) ON (CT.LabelNo = O.OrderKey)
            LEFT JOIN CodeLKUP CL WITH (NOLOCK) ON (CL.ListName = 'SOSTSBLOCK' AND CL.Code = O.SOStatus AND CL.StorerKey = @cStorerKey AND CL.Code2 = @nFunc) -- TrackNoToPallet
         WHERE PalletKey = @cPalletKey
            AND (O.OrderKey IS NULL -- Order had changed the tracking no
            OR CL.Code IS NOT NULL) -- Order status is blocked
      ELSE
         SELECT @cInvalidCarton = COUNT(1)
         FROM PalletDetail PD WITH (NOLOCK)
            LEFT JOIN CartonTrack CT WITH (NOLOCK) ON (PD.CaseID = CT.TrackingNo)
            LEFT JOIN Orders O WITH (NOLOCK) ON (CT.LabelNo = O.OrderKey)
            LEFT JOIN CodeLKUP CL WITH (NOLOCK) ON (CL.ListName = 'SOSTSBLOCK' AND CL.Code = O.SOStatus AND CL.StorerKey = @cStorerKey AND CL.Code2 = @nFunc) -- TrackNoToPallet
         WHERE PalletKey = @cPalletKey
            AND (O.OrderKey IS NULL -- Order had changed the tracking no
            OR CL.Code IS NOT NULL) -- Order status is blocked
   END

   /***********************************************************************************************
                                             List invalid cartons
   ***********************************************************************************************/
   IF @cType <> 'LIST'
      GOTO Quit

   DECLARE @tTrackNo TABLE
   (
      RowRef            INT IDENTITY( 1, 1),
      TrackNo           NVARCHAR( 20) NOT NULL,
      OrderKey          NVARCHAR( 10) NULL,
      PalletLineNumber  NVARCHAR( 5) NOT NULL
   )

   SET @cOutField01 = ''
   SET @cOutField02 = ''
   SET @cOutField03 = ''
   SET @cOutField04 = ''
   SET @cOutField05 = ''
   SET @cOutField06 = ''
   SET @cOutField07 = ''
   SET @cOutField08 = ''
   SET @cOutField09 = ''
   SET @cOutField10 = ''

   SET @nRecordOnPage = 5
   SET @nCurrentPage = CAST( @cCurrentPage AS INT)

   -- Populate list
   IF @cPalletDetailTrackingNo = '1'
      INSERT INTO @tTrackNo (TrackNo, OrderKey, PalletLineNumber)
      SELECT PD.TrackingNo, PD.UserDefine01, PD.PalletLineNumber
      FROM PalletDetail PD WITH (NOLOCK)
         LEFT JOIN CartonTrack CT WITH (NOLOCK) ON (PD.TrackingNo = CT.TrackingNo)
         LEFT JOIN Orders O WITH (NOLOCK) ON (CT.LabelNo = O.OrderKey)
         LEFT JOIN CodeLKUP CL WITH (NOLOCK) ON (CL.ListName = 'SOSTSBLOCK' AND CL.Code = O.SOStatus AND CL.StorerKey = @cStorerKey AND CL.Code2 = @nFunc) -- TrackNoToPallet
      WHERE PalletKey = @cPalletKey
         AND (O.OrderKey IS NULL -- Order had changed the tracking no
         OR CL.Code IS NOT NULL) -- Order status is blocked
      ORDER BY PD.AddDate DESC
   ELSE
      INSERT INTO @tTrackNo (TrackNo, OrderKey, PalletLineNumber)
      SELECT PD.CaseID, PD.UserDefine01, PD.PalletLineNumber
      FROM PalletDetail PD WITH (NOLOCK)
         LEFT JOIN CartonTrack CT WITH (NOLOCK) ON (PD.CaseID = CT.TrackingNo)
         LEFT JOIN Orders O WITH (NOLOCK) ON (CT.LabelNo = O.OrderKey)
         LEFT JOIN CodeLKUP CL WITH (NOLOCK) ON (CL.ListName = 'SOSTSBLOCK' AND CL.Code = O.SOStatus AND CL.StorerKey = @cStorerKey AND CL.Code2 = @nFunc) -- TrackNoToPallet
      WHERE PalletKey = @cPalletKey
         AND (O.OrderKey IS NULL -- Order had changed the tracking no
         OR CL.Code IS NOT NULL) -- Order status is blocked
      ORDER BY PD.AddDate DESC

   -- Get current page top record
   SET @nTotalRecord = @@ROWCOUNT
   SET @nTopRecordOnPage = ((@nCurrentPage-1) * @nRecordOnPage) + 1

   -- Current page no record (record deleted), get previous page
   WHILE @nTopRecordOnPage > @nTotalRecord
   BEGIN
      SET @nCurrentPage = @nCurrentPage - 1
      SET @nTopRecordOnPage = ((@nCurrentPage-1) * @nRecordOnPage) + 1
   END

   DECLARE @curTrackNo CURSOR
   SET @curTrackNo = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT TOP (@nRecordOnPage)
         RowRef, TrackNo, OrderKey, PalletLineNumber
      FROM @tTrackNo
      WHERE RowRef >= @nTopRecordOnPage
      ORDER BY RowRef
   OPEN @curTrackNo
   FETCH NEXT FROM @curTrackNo INTO @nRowRef, @cTrackNo, @cOrderKey, @cPalletLineNumber

   SET @nCount = 1
   WHILE @nCount <= @nRecordOnPage
   BEGIN
      -- Lottable available to show on this position
      IF @@FETCH_STATUS = 0
      BEGIN
         IF @nRowRef <= 9
            -- Format track no
            SET @cOutField = CAST( @nRowRef AS NVARCHAR(1)) + '. ' + RIGHT( @cTrackNo, 17)
         ELSE  -- 10, 11, 12, ...
            -- Format track no
            SET @cOutField = CAST( @nRowRef AS NVARCHAR(2)) + '.' + RIGHT( @cTrackNo, 17)

         SET @cLineNumberToDisplay = SPACE( 3) + @cPalletLineNumber
      END
      ELSE
         -- No record for this position
         SELECT @cOutField = '', @cLineNumberToDisplay = ''

      -- Output to screen
      IF @nCount = 1 SELECT @cOutField01 = @cOutField, @cOutField02 = @cLineNumberToDisplay ELSE
      IF @nCount = 2 SELECT @cOutField03 = @cOutField, @cOutField04 = @cLineNumberToDisplay ELSE
      IF @nCount = 3 SELECT @cOutField05 = @cOutField, @cOutField06 = @cLineNumberToDisplay ELSE
      IF @nCount = 4 SELECT @cOutField07 = @cOutField, @cOutField08 = @cLineNumberToDisplay ELSE
      IF @nCount = 5 SELECT @cOutField09 = @cOutField, @cOutField10 = @cLineNumberToDisplay

      SET @nCount = @nCount + 1
      FETCH NEXT FROM @curTrackNo INTO @nRowRef, @cTrackNo, @cOrderKey, @cPalletLineNumber
   END

   -- Output stat
   SET @cTotalCarton = @nTotalRecord
   SET @cCurrentPage = CAST( @nCurrentPage AS NVARCHAR( 2))
   SET @cTotalPage = CAST( CEILING( @nTotalRecord * 1.0 / @nRecordOnPage) AS NVARCHAR(2))

Quit:

END

GO
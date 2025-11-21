SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/****************************************************************************/
/* Store procedure: rdt_1653ExtScn01                                        */
/* Copyright      :  Maersk                                                 */
/*                                                                          */
/* Purpose:       FCR-539                                                   */
/*                                                                          */
/* Date       Rev    Author   Purposes                                      */
/* 2024-07-08 1.0    CYU027   CREATE                                        */
/* 2024-10-08 1.1    NLT013   FCR-950 Enhancement                           */
/* 2024-10-18 1.2    JCH507   FCR-950 Verify palletkey not exists when      */
/*                            New Pallet                                    */
/* 2024-10-24 1.3.0  NLT013   FCR-1084, add additional validation  for      */
/*                            location and pallet id                        */
/* 2024-10-25 1.3.1  JCH507   FCR-1084, add status when check label exists  */
/*                            in pallet id                                  */
/* 2024-10-25 1.4.0  Dennis   FCR-1316 Last Carton                          */
/* 2024-12-19 1.4.1  NLT013   FCR-1316 Valid location is needed for new ID  */
/* 2025-02-06 1.4.2  CYU027   UWP-30023 Hotfix add trim avoid spaces        */
/* 2025-01-10 1.4.3  Dennis   FCR-1316 Performance Issue                    */
/* 2025-02-20 1.5.0  NLT013   UWP-30312 Performance Tune                    */
/****************************************************************************/

CREATE   PROC [rdt].[rdt_1653ExtScn01] (
   @nMobile          INT,           
   @nFunc            INT,           
   @cLangCode        NVARCHAR( 3),  
   @nStep            INT,           
   @nScn             INT,           
   @nInputKey        INT,           
   @cFacility        NVARCHAR( 5),  
   @cStorerKey       NVARCHAR( 15), 
   @tExtScnData      VariableTable READONLY,
   @cInField01       NVARCHAR( 60) OUTPUT,  @cOutField01 NVARCHAR( 60) OUTPUT,  @cFieldAttr01 NVARCHAR( 1) OUTPUT,  @cLottable01 NVARCHAR( 18) OUTPUT,  
   @cInField02       NVARCHAR( 60) OUTPUT,  @cOutField02 NVARCHAR( 60) OUTPUT,  @cFieldAttr02 NVARCHAR( 1) OUTPUT,  @cLottable02 NVARCHAR( 18) OUTPUT,  
   @cInField03       NVARCHAR( 60) OUTPUT,  @cOutField03 NVARCHAR( 60) OUTPUT,  @cFieldAttr03 NVARCHAR( 1) OUTPUT,  @cLottable03 NVARCHAR( 18) OUTPUT,  
   @cInField04       NVARCHAR( 60) OUTPUT,  @cOutField04 NVARCHAR( 60) OUTPUT,  @cFieldAttr04 NVARCHAR( 1) OUTPUT,  @dLottable04 DATETIME      OUTPUT,  
   @cInField05       NVARCHAR( 60) OUTPUT,  @cOutField05 NVARCHAR( 60) OUTPUT,  @cFieldAttr05 NVARCHAR( 1) OUTPUT,  @dLottable05 DATETIME      OUTPUT,  
   @cInField06       NVARCHAR( 60) OUTPUT,  @cOutField06 NVARCHAR( 60) OUTPUT,  @cFieldAttr06 NVARCHAR( 1) OUTPUT,  @cLottable06 NVARCHAR( 30) OUTPUT, 
   @cInField07       NVARCHAR( 60) OUTPUT,  @cOutField07 NVARCHAR( 60) OUTPUT,  @cFieldAttr07 NVARCHAR( 1) OUTPUT,  @cLottable07 NVARCHAR( 30) OUTPUT, 
   @cInField08       NVARCHAR( 60) OUTPUT,  @cOutField08 NVARCHAR( 60) OUTPUT,  @cFieldAttr08 NVARCHAR( 1) OUTPUT,  @cLottable08 NVARCHAR( 30) OUTPUT, 
   @cInField09       NVARCHAR( 60) OUTPUT,  @cOutField09 NVARCHAR( 60) OUTPUT,  @cFieldAttr09 NVARCHAR( 1) OUTPUT,  @cLottable09 NVARCHAR( 30) OUTPUT, 
   @cInField10       NVARCHAR( 60) OUTPUT,  @cOutField10 NVARCHAR( 60) OUTPUT,  @cFieldAttr10 NVARCHAR( 1) OUTPUT,  @cLottable10 NVARCHAR( 30) OUTPUT, 
   @cInField11       NVARCHAR( 60) OUTPUT,  @cOutField11 NVARCHAR( 60) OUTPUT,  @cFieldAttr11 NVARCHAR( 1) OUTPUT,  @cLottable11 NVARCHAR( 30) OUTPUT,
   @cInField12       NVARCHAR( 60) OUTPUT,  @cOutField12 NVARCHAR( 60) OUTPUT,  @cFieldAttr12 NVARCHAR( 1) OUTPUT,  @cLottable12 NVARCHAR( 30) OUTPUT,
   @cInField13       NVARCHAR( 60) OUTPUT,  @cOutField13 NVARCHAR( 60) OUTPUT,  @cFieldAttr13 NVARCHAR( 1) OUTPUT,  @dLottable13 DATETIME      OUTPUT,
   @cInField14       NVARCHAR( 60) OUTPUT,  @cOutField14 NVARCHAR( 60) OUTPUT,  @cFieldAttr14 NVARCHAR( 1) OUTPUT,  @dLottable14 DATETIME      OUTPUT,
   @cInField15       NVARCHAR( 60) OUTPUT,  @cOutField15 NVARCHAR( 60) OUTPUT,  @cFieldAttr15 NVARCHAR( 1) OUTPUT,  @dLottable15 DATETIME      OUTPUT,
   @nAction          INT, --0 Jump Screen, 1 Validation(pass through all input fields), 2 Update, 3 Prepare output fields .....
   @nAfterScn        INT OUTPUT, @nAfterStep    INT OUTPUT, 
   @nErrNo           INT            OUTPUT, 
   @cErrMsg          NVARCHAR( 20)  OUTPUT,
   @cUDF01  NVARCHAR( 250) OUTPUT, @cUDF02 NVARCHAR( 250) OUTPUT, @cUDF03 NVARCHAR( 250) OUTPUT,
   @cUDF04  NVARCHAR( 250) OUTPUT, @cUDF05 NVARCHAR( 250) OUTPUT, @cUDF06 NVARCHAR( 250) OUTPUT,
   @cUDF07  NVARCHAR( 250) OUTPUT, @cUDF08 NVARCHAR( 250) OUTPUT, @cUDF09 NVARCHAR( 250) OUTPUT,
   @cUDF10  NVARCHAR( 250) OUTPUT, @cUDF11 NVARCHAR( 250) OUTPUT, @cUDF12 NVARCHAR( 250) OUTPUT,
   @cUDF13  NVARCHAR( 250) OUTPUT, @cUDF14 NVARCHAR( 250) OUTPUT, @cUDF15 NVARCHAR( 250) OUTPUT,
   @cUDF16  NVARCHAR( 250) OUTPUT, @cUDF17 NVARCHAR( 250) OUTPUT, @cUDF18 NVARCHAR( 250) OUTPUT,
   @cUDF19  NVARCHAR( 250) OUTPUT, @cUDF20 NVARCHAR( 250) OUTPUT, @cUDF21 NVARCHAR( 250) OUTPUT,
   @cUDF22  NVARCHAR( 250) OUTPUT, @cUDF23 NVARCHAR( 250) OUTPUT, @cUDF24 NVARCHAR( 250) OUTPUT,
   @cUDF25  NVARCHAR( 250) OUTPUT, @cUDF26 NVARCHAR( 250) OUTPUT, @cUDF27 NVARCHAR( 250) OUTPUT,
   @cUDF28  NVARCHAR( 250) OUTPUT, @cUDF29 NVARCHAR( 250) OUTPUT, @cUDF30 NVARCHAR( 250) OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE
      @nTranCount             INT,
      @cSuggPalletKey         NVARCHAR( 20),
      @cPalletKey             NVARCHAR( 20),
      @cTrackNo               NVARCHAR( 40),
      @cOrderKey              NVARCHAR( 10),
      @cMBOLKey               NVARCHAR( 10),
      @cLane                  NVARCHAR( 30),
      @cLabelNo               NVARCHAR( 20),
      @cSuggestLoc            NVARCHAR( 1),
      @cOverrideLoc           NVARCHAR( 1),
      @cOption                NVARCHAR( 1),
      @tCreateMBOLVar         VARIABLETABLE,
      @nRowCount              INT,
      @cNewPalletKeyPrefix    NVARCHAR(30),
      @nCurrentScn            INT,
      @cCaseID                NVARCHAR(20),
      @cWaveType              NVARCHAR(18),
      @cCODELKUPUdf01         NVARCHAR(60)='',
      @cCODELKUPUdf02         NVARCHAR(60)='',
      @cCODELKUPUdf03         NVARCHAR(60)='',
      @cCODELKUPUdf04         NVARCHAR(60)='',
      @cCODELKUPUdf05         NVARCHAR(60)='',
      @cSQLString             NVARCHAR(MAX),
      @cSQLParam              NVARCHAR(MAX)
   -- Screen constant  
   DECLARE  
      @nStep_TrackNo          INT,  @nScn_TrackNo           INT,  
      @nStep_ScanPalletID     INT,  @nScn_ScanPalletID      INT,  
      @nStep_ShowPalletID     INT,  @nScn_ShowPalletID      INT,  
      @nStep_ClosePallet      INT,  @nScn_ClosePallet       INT,  
      @nStep_ScanDiffPallet   INT,  @nScn_ScanDiffPallet    INT,  
      @nStep_PalletDimension  INT,  @nScn_PalletDimension   INT,  
      @nStep_ConfirmNewLane   INT,  @nScn_ConfirmNewLane    INT  
   
   SELECT  
      @nStep_TrackNo          = 1,   @nScn_TrackNo          = 5800,  
      @nStep_ScanPalletID     = 2,   @nScn_ScanPalletID     = 5801,  
      @nStep_ShowPalletID     = 3,   @nScn_ShowPalletID     = 5802,  
      @nStep_ClosePallet      = 4,   @nScn_ClosePallet      = 5803,  
      @nStep_ScanDiffPallet   = 5,   @nScn_ScanDiffPallet   = 5804,  
      @nStep_PalletDimension  = 6,   @nScn_PalletDimension  = 5805,  
      @nStep_ConfirmNewLane   = 7,   @nScn_ConfirmNewLane   = 5806  

   SELECT
      @cLabelNo               = V_String1,
      @cMBOLKey               = V_String3,
      @cSuggestLoc            = V_String29,
      @cOverrideLoc           = V_String30,
      @cTrackNo               = V_String41,
      @cOrderKey              = V_OrderKey,
      @cLane                  = V_String42,
      @nCurrentScn            = Scn
   FROM rdt.RDTMOBREC (NOLOCK)
   WHERE Mobile = @nMobile

   SELECT @cPalletKey = Value FROM @tExtScnData WHERE Variable = '@cPalletKey'
   SELECT @cLane = Value FROM @tExtScnData WHERE Variable = '@cLane'

   IF @nFunc = 1653
   BEGIN
      IF @nStep = 1
      BEGIN
         SET @cOption = @cInField02
         IF ISNULL(@cOption,'') <> '1' AND @nInputKey = 1
         BEGIN
            SET @cFieldAttr05 = ''

            SELECT @cLabelNo = Value FROM @tExtScnData WHERE Variable = '@cLabelNo'

            IF ISNULL( @cLabelNo, '' ) <> ''
            AND EXISTS (SELECT 1 FROM dbo.PalletDetail WITH(NOLOCK) WHERE CaseID IS NOT NULL AND CaseID = @cLabelNo AND StorerKey = @cStorerKey AND Status <> '9' ) --V1.3.1
            BEGIN
               SET @cOutField01 = '' 
               SET @cOutField02 = @cPalletKey
               SET @nAfterStep = 99
               SET @nAfterScn = 6447
               GOTO Quit
            END
            SET @cOutField14 = ''
            SELECT TOP 1 @cWaveType = W.WaveType
            FROM dbo.PackDetail PD WITH (NOLOCK)  
            JOIN dbo.PackHeader PH WITH (NOLOCK) ON ( PD.PickSlipNo = PH.PickSlipNo)  
            JOIN dbo.ORDERS     O  WITH (NOLOCK) ON ( PH.OrderKey = O.OrderKey)
            JOIN dbo.Wave       W  WITH (NOLOCK) ON ( W.WaveKey = O.UserDefine09)
            WHERE PD.StorerKey = @cStorerKey
               AND   PD.LabelNo = @cLabelNo
            ORDER BY 1

            IF TRIM(@cWaveType) NOT IN('', '0')
               SELECT TOP 1
                  @cCODELKUPUdf01 = SUBSTRING(TRIM(UDF01), CHARINDEX('.',TRIM(UDF01)) + 1, LEN(TRIM(UDF01))),
                  @cCODELKUPUdf02 = SUBSTRING(TRIM(UDF02), CHARINDEX('.',TRIM(UDF02)) + 1, LEN(TRIM(UDF02))),
                  @cCODELKUPUdf03 = SUBSTRING(TRIM(UDF03), CHARINDEX('.',TRIM(UDF03)) + 1, LEN(TRIM(UDF03))),
                  @cCODELKUPUdf04 = SUBSTRING(TRIM(UDF04), CHARINDEX('.',TRIM(UDF04)) + 1, LEN(TRIM(UDF04))),
                  @cCODELKUPUdf05 = SUBSTRING(TRIM(UDF05), CHARINDEX('.',TRIM(UDF05)) + 1, LEN(TRIM(UDF05)))
               FROM dbo.CODELKUP WITH(NOLOCK)
               WHERE LISTNAME = 'WAVETYPE'
                  AND StorerKey = @cStorerKey 
                  AND Code = @cWaveType
            ELSE
               SET @cCODELKUPUdf01 = 'MBOLKey'

            SET @cCODELKUPUdf01 = ISNULL(@cCODELKUPUdf01, '')
            SET @cCODELKUPUdf02 = ISNULL(@cCODELKUPUdf02, '')
            SET @cCODELKUPUdf03 = ISNULL(@cCODELKUPUdf03, '')
            SET @cCODELKUPUdf04 = ISNULL(@cCODELKUPUdf04, '')
            SET @cCODELKUPUdf05 = ISNULL(@cCODELKUPUdf05, '')

            SET @cTrackNo = @cOutField01
            --FCR-539 Pallet Found, loc uneditable
            IF @cPalletKey <> 'NEW PALLET' AND ISNULL(@cPalletKey,'') <> ''
            BEGIN
               SET @cFieldAttr05 = 'O'
               BEGIN TRY
                  SET @cSQLString =
                  'WITH FilteredPalletDetail AS (
                     SELECT
                        UserDefine01,
                        UserDefine02,
                        UserDefine03,
                        UserDefine04,
                        UserDefine05,
                        CaseID
                     FROM
                        dbo.PalletDetail PD2 WITH (NOLOCK)
                     WHERE
                        PD2.palletkey = @cPalletKey
                        AND PD2.StorerKey = @cStorerKey
                  )
                  SELECT distinct
                     @cCaseID = PD.caseid
                  FROM dbo.PickDetail PD WITH (NOLOCK)
                  INNER JOIN dbo.Orders O WITH (NOLOCK) ON PD.orderkey = O.orderkey AND PD.StorerKey = O.StorerKey
                  INNER JOIN dbo.PackInfo PI WITH(NOLOCK) ON PI.RefNo IS NOT NULL AND PD.CaseID = PI.RefNo AND PI.CartonStatus = ''PACKED''
                  WHERE
                     PD.StorerKey = @cStorerKey
                     AND PD.Status = ''5''
                     AND NOT EXISTS ( SELECT 1 FROM FilteredPalletDetail FPD WHERE FPD.CaseID = PD.CaseID AND EXISTS ( SELECT 1 FROM FilteredPalletDetail FPD2 WHERE FPD2.UserDefine01 = FPD.UserDefine01))'
                     +IIF(@cCODELKUPUdf01 <> '',   ' AND EXISTS(SELECT 1 FROM FilteredPalletDetail FPD WHERE ISNULL(FPD.UserDefine01,'''') = O.' + @cCODELKUPUdf01 + ') ', '')
                     +IIF(@cCODELKUPUdf02 <> '',   ' AND EXISTS(SELECT 1 FROM FilteredPalletDetail FPD WHERE ISNULL(FPD.UserDefine02,'''') = O.' + @cCODELKUPUdf02 + ') ', '')
                     +IIF(@cCODELKUPUdf03 <> '',   ' AND EXISTS(SELECT 1 FROM FilteredPalletDetail FPD WHERE ISNULL(FPD.UserDefine03,'''') = O.' + @cCODELKUPUdf03 + ') ', '')
                     +IIF(@cCODELKUPUdf04 <> '',   ' AND EXISTS(SELECT 1 FROM FilteredPalletDetail FPD WHERE ISNULL(FPD.UserDefine04,'''') = O.' + @cCODELKUPUdf04 + ') ', '')
                     +IIF(@cCODELKUPUdf05 <> '',   ' AND EXISTS(SELECT 1 FROM FilteredPalletDetail FPD WHERE ISNULL(FPD.UserDefine05,'''') = O.' + @cCODELKUPUdf05 + ') ', '')

                  SET @cSQLParam =  '@cStorerKey NVARCHAR( 15), @cPalletKey NVARCHAR(20), @cCaseID NVARCHAR(20) OUTPUT'
                  EXEC sp_executesql @cSQLString, @cSQLParam, 
                     @cStorerKey = @cStorerKey, @cPalletKey = @cPalletKey, @cCaseID = @cCaseID OUTPUT
                  SET @nRowCount = @@ROWCOUNT
                  IF @nRowCount = 1 AND @cCaseID = @cTrackNo
                     SET @cOutField14 = 'LAST CARTON'
                  
                  SELECT @nRowCount = COUNT(DISTINCT CaseID) FROM dbo.PalletDetail WITH(NOLOCK) WHERE PalletKey = @cPalletKey AND CaseID IS NOT NULL AND CaseID <> '' AND StorerKey = @cStorerKey
               END TRY
               BEGIN CATCH
                  SET @nErrNo = 219109
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Execute SQL Statement Fail
                  
                  -- Prep next screen var  
                  SET @cOutField01 = '' -- Track No  
                  SET @cOutField02 = '' -- Option  
               
                  SET @nAfterScn = @nScn_TrackNo  
                  SET @nAfterStep = @nStep_TrackNo  
                  GOTO Quit
               END CATCH
            END
            ELSE
            --FCR-539 Pallet not Found, loc found, uneditable
            BEGIN
               --Do not suggest LOC
               IF @cSuggestLoc <> '1'
                  SET @cLane = ''
               --Do not override LOC
               IF @cOverrideLoc = '0' AND @cLane <> ''
                  SET @cFieldAttr05 = 'O'
               BEGIN TRY
                  SET @cSQLString =
                     'WITH FilteredOrders AS (
                        SELECT '
                        +IIF(@cCODELKUPUdf01 <> '',   'O2.'+@cCODELKUPUdf01+', ','')
                        +IIF(@cCODELKUPUdf02 <> '',   'O2.'+@cCODELKUPUdf02+', ','')
                        +IIF(@cCODELKUPUdf03 <> '',   'O2.'+@cCODELKUPUdf03+', ','')
                        +IIF(@cCODELKUPUdf04 <> '',   'O2.'+@cCODELKUPUdf04+', ','')
                        +IIF(@cCODELKUPUdf05 <> '',   'O2.'+@cCODELKUPUdf05+', ','')
                     +' O2.ORDERKEY
                        FROM dbo.Orders O2 WITH (NOLOCK)
                        INNER JOIN dbo.PickDetail PD2 WITH (NOLOCK) ON PD2.ORDERKEY = O2.ORDERKEY AND O2.StorerKey = PD2.StorerKey
                        WHERE
                           PD2.CaseID = @cTrackNo
                           AND O2.StorerKey = @cStorerKey
                     ),
                     FilteredPalletDetail AS (
                        SELECT
                           PD2.CaseID,
                           PD2.UserDefine01
                        FROM dbo.PalletDetail PD2 WITH (NOLOCK)
                        WHERE
                           EXISTS (
                                 SELECT 1
                                 FROM dbo.Orders O2 WITH (NOLOCK)
                                 INNER JOIN dbo.PickDetail PD3 WITH (NOLOCK) ON PD3.ORDERKEY = O2.ORDERKEY AND O2.StorerKey = PD3.StorerKey
                                 WHERE
                                    PD3.CaseID = @cTrackNo
                                    AND O2.MBOLKey = PD2.UserDefine01
                                    AND O2.StorerKey = @cStorerKey
                           )
                           AND PD2.StorerKey = @cStorerKey
                     )
                     SELECT DISTINCT
                        @cCaseID = PD.caseid
                     FROM dbo.PickDetail PD WITH (NOLOCK)
                     INNER JOIN dbo.Orders O WITH (NOLOCK) ON PD.orderkey = O.orderkey AND PD.StorerKey = O.StorerKey
                     INNER JOIN dbo.PackInfo PI WITH(NOLOCK) ON PI.RefNo IS NOT NULL AND PD.CaseID = PI.RefNo AND PI.CartonStatus = ''PACKED''
                     WHERE
                        PD.StorerKey = @cStorerKey
                        AND PD.Status = ''5''
                        AND NOT EXISTS ( SELECT 1 FROM FilteredPalletDetail FPD WHERE FPD.CaseID = PD.CaseID ) '
                        +IIF(@cCODELKUPUdf01 <> '',   ' AND EXISTS ( SELECT 1 FROM FilteredOrders FO WHERE (FO.' + @cCODELKUPUdf01 + ' IS NULL AND O.' + @cCODELKUPUdf01 + ' IS NULL) OR (FO.'+ @cCODELKUPUdf01 + ' IS NOT NULL AND O.' + @cCODELKUPUdf01 + ' IS NOT NULL AND FO.'+ @cCODELKUPUdf01 + ' = O.' + @cCODELKUPUdf01 + '))', '')
                        +IIF(@cCODELKUPUdf02 <> '',   ' AND EXISTS ( SELECT 1 FROM FilteredOrders FO WHERE (FO.' + @cCODELKUPUdf02 + ' IS NULL AND O.' + @cCODELKUPUdf02 + ' IS NULL) OR (FO.'+ @cCODELKUPUdf02 + ' IS NOT NULL AND O.' + @cCODELKUPUdf02 + ' IS NOT NULL AND FO.'+ @cCODELKUPUdf02 + ' = O.' + @cCODELKUPUdf02 + '))', '')
                        +IIF(@cCODELKUPUdf03 <> '',   ' AND EXISTS ( SELECT 1 FROM FilteredOrders FO WHERE (FO.' + @cCODELKUPUdf03 + ' IS NULL AND O.' + @cCODELKUPUdf03 + ' IS NULL) OR (FO.'+ @cCODELKUPUdf03 + ' IS NOT NULL AND O.' + @cCODELKUPUdf03 + ' IS NOT NULL AND FO.'+ @cCODELKUPUdf03 + ' = O.' + @cCODELKUPUdf03 + '))', '')
                        +IIF(@cCODELKUPUdf04 <> '',   ' AND EXISTS ( SELECT 1 FROM FilteredOrders FO WHERE (FO.' + @cCODELKUPUdf04 + ' IS NULL AND O.' + @cCODELKUPUdf04 + ' IS NULL) OR (FO.'+ @cCODELKUPUdf04 + ' IS NOT NULL AND O.' + @cCODELKUPUdf04 + ' IS NOT NULL AND FO.'+ @cCODELKUPUdf04 + ' = O.' + @cCODELKUPUdf04 + '))', '')
                        +IIF(@cCODELKUPUdf05 <> '',   ' AND EXISTS ( SELECT 1 FROM FilteredOrders FO WHERE (FO.' + @cCODELKUPUdf05 + ' IS NULL AND O.' + @cCODELKUPUdf05 + ' IS NULL) OR (FO.'+ @cCODELKUPUdf05 + ' IS NOT NULL AND O.' + @cCODELKUPUdf05 + ' IS NOT NULL AND FO.'+ @cCODELKUPUdf05 + ' = O.' + @cCODELKUPUdf05 + '))', '')

                  SET @cSQLParam =  '@cStorerKey NVARCHAR( 15), @cTrackNo NVARCHAR(40), @cCaseID NVARCHAR(20) OUTPUT'
                  EXEC sp_executesql @cSQLString, @cSQLParam, 
                     @cStorerKey = @cStorerKey, @cTrackNo = @cTrackNo, @cCaseID = @cCaseID OUTPUT
                  SET @nRowCount = @@ROWCOUNT
                  IF @nRowCount = 1 AND @cCaseID = @cTrackNo
                     SET @cOutField14 = 'LAST CARTON'
                  SET @nRowCount = 0
               END TRY
               BEGIN CATCH
                  SET @nErrNo = 219109
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Execute SQL Statement Fail
                  -- Prep next screen var  
                  SET @cOutField01 = '' -- Track No  
                  SET @cOutField02 = '' -- Option  
               
                  SET @nAfterScn = @nScn_TrackNo  
                  SET @nAfterStep = @nStep_TrackNo  
                  GOTO Quit
               END CATCH
            END

            SET @cInField05 = @cLane
            SET @cOutField05 = @cLane
            SET @nAfterStep = 99
            SET @nAfterScn = 5807

            SET @cOutField15 = 'Carton Count: ' + CAST(@nRowCount AS NVARCHAR(5))
            GOTO Quit
         END
      END


      IF @nStep = 99
      BEGIN
         IF @nCurrentScn = 5807
         BEGIN
            IF @nInputKey = 1 -- Yes or Send
            BEGIN
               /********************************************************************************
                  Scn = 5807. SCAN TO LOC/LANE
                     TRACK NO          (field01)
                     ORDERKEY          (field02)
                     SCAN TO PALLET:   (field04, input)
                     SCAN PALLET:      (field03)
                     LOC/LANE:         (field05, input)
               ********************************************************************************/
               -- Initialize value
               SET @cSuggPalletKey = @cOutField03
               SET @cPalletKey = trim(@cInField04)

               IF ISNULL(@cOverrideLoc,'0') <> '1' AND @cLane <> @cInField05 AND ISNULL(@cLane,'') <> ''
               BEGIN
                  SET @nErrNo = 219151
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --cannot override location
                  GOTO Step_ShowPalletID_Fail
               END

               IF ISNULL( @cPalletKey, '') = ''
               BEGIN
                  SET @nErrNo = 219152
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need Pallet ID
                  GOTO Step_ShowPalletID_Fail
               END

               -- Check barcode format
               IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'PalletKey', @cPalletKey) = 0
               BEGIN
                  SET @nErrNo = 219153
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Format
                  GOTO Step_ShowPalletID_Fail
               END


               IF @cSuggPalletKey <> @cPalletKey AND @cSuggPalletKey <> 'NEW PALLET'
               BEGIN
                  SET @nErrNo = 219154
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Pallet Not Match
                  GOTO Step_ShowPalletID_Fail
               END

               IF @cSuggPalletKey = 'NEW PALLET'
               BEGIN
                  SELECT @cNewPalletKeyPrefix = Code
                  FROM dbo.CODELKUP WITH(NOLOCK)
                  WHERE LISTNAME = 'USIDOutPre'
                     AND StorerKey = @cStorerKey

                  SELECT @nRowCount = @@ROWCOUNT

                  IF @nRowCount = 0
                  BEGIN
                     SET @nErrNo = 219161
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NoUSIDOutPre
                     GOTO Step_ShowPalletID_Fail
                  END

                  IF LEFT(@cPalletKey, LEN(@cNewPalletKeyPrefix)) <> @cNewPalletKeyPrefix
                  BEGIN
                     SET @nErrNo = 219162
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidPrefix
                     GOTO Step_ShowPalletID_Fail
                  END

                  IF EXISTS (SELECT 1 FROM dbo.PALLET WITH(NOLOCK) WHERE StorerKey = @cStorerKey AND PalletKey = @cPalletKey)
                  BEGIN
                     SET @nErrNo = 219166
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PalletExists
                     GOTO Step_ShowPalletID_Fail
                  END

                  IF ISNULL(@cInField05,'') = ''
                  BEGIN
                     SET @nErrNo = 219156
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Location is required
                     GOTO Step_ShowPalletID_Fail
                  END

                  IF NOT EXISTS ( SELECT 1
                                 FROM dbo.LOC WITH (NOLOCK)
                                 WHERE LOC = @cInField05
                                 AND Facility = @cFacility)
                  BEGIN
                     SET @nErrNo = 219155
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LOC NOT FOUND
                     GOTO Step_ShowPalletID_Fail
                  END

                  SELECT @nRowCount = COUNT(1)
                  FROM dbo.CODELKUP WITH(NOLOCK)
                  WHERE LISTNAME = 'LVSPLTLOC'
                     AND StorerKey = @cStorerKey

                  IF @nRowCount = 0
                  BEGIN
                     SET @nErrNo = 219163
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NoLocPre
                     GOTO Step_ShowPalletID_Fail
                  END

                  IF NOT EXISTS ( SELECT 1
                                 FROM dbo.CODELKUP WITH (NOLOCK)
                                 WHERE StorerKey = @cStorerKey
                                    AND ListName = 'LVSPLTLOC'
                                    AND Code = LEFT(@cInField05, LEN(Code)) )
                  BEGIN
                     SET @nErrNo = 219164
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidLoc
                     GOTO Step_ShowPalletID_Fail
                  END
               END

               IF EXISTS(SELECT 1
                        FROM dbo.PALLETDETAIL PD WITH(NOLOCK)
                        INNER JOIN dbo.PALLET PA WITH(NOLOCK)
                           ON PD.StorerKey = PA.StorerKey
                           AND PD.PalletKey = PA.PalletKey
                        WHERE PD.StorerKey = @cStorerKey
                           AND PD.Loc = @cInField05
                           AND PD.PalletKey <> @cPalletKey
                           AND PA.Status < '9') --JCH507
               BEGIN
                  SET @nErrNo = 219165
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --219165 Existing Pallet is Closed
                  GOTO Step_ShowPalletID_Fail
               END

               SET @nTranCount = @@TRANCOUNT
               BEGIN TRAN  -- Begin our own transaction
               SAVE TRAN rdt_CreateMbol -- For rollback or commit only our own transaction

               SET @nErrNo = 0
               EXEC [RDT].[rdt_TrackNo_SortToPallet_CreateMbol]
                  @nMobile       = @nMobile,
                  @nFunc         = @nFunc,
                  @cLangCode     = @cLangCode,
                  @nStep         = @nStep,
                  @nInputKey     = @nInputKey,
                  @cFacility     = @cFacility,
                  @cStorerKey    = @cStorerKey,
                  @cTrackNo      = @cTrackNo,
                  @cOrderKey     = @cOrderKey,
                  @cPalletKey    = @cPalletKey,
                  @cMBOLKey      = @cMBOLKey,
                  @cLane         = @cInField05,
                  @cLabelNo      = @cLabelNo,
                  @tCreateMBOLVar= @tCreateMBOLVar,
                  @nErrNo        = @nErrNo      OUTPUT,
                  @cErrMsg       = @cErrMsg     OUTPUT

               IF @nErrNo <> 0
                  ROLLBACK TRAN rdt_CreateMbol
               ElSE
                  COMMIT TRAN rdt_CreateMbol
               WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
                  COMMIT TRAN

               IF @nErrNo <> 0
                  GOTO Quit

               -- Prep next screen var
               SET @cOutField01 = '' -- Track No
               SET @cOutField02 = '' -- Option
               SET @cOutField15 = ''

               EXEC rdt.rdtSetFocusField @nMobile, 1

               SET @nAfterScn = 5800
               SET @nAfterStep = 1


               GOTO Quit

            END

            IF @nInputKey = 0 -- Esc or No
            BEGIN
               -- Initialize value
               SET @cTrackNo = ''
               SET @cOrderKey = ''

               -- Prep next screen var
               SET @cOutField01 = '' -- Track No
               SET @cOutField02 = ''
               SET @cOutField15 = ''

               SET @nAfterScn = 5800
               SET @nAfterStep = 1
            END
         END
         /********************************************************************************
         Scn = 6447. SConfirm to remove carton?
         /*       Carton already      */
         /*       Scanned to pallet.  */
         /*       Confirm to remove   */
         /*       carton from pallet? */
         /*                           */
         /*       1 - Yes             */
         /*       2 - No              */
         /*       Field01 (Input)     */
         ********************************************************************************/
         ELSE IF @nCurrentScn = 6447
         BEGIN
            IF @nInputKey = 1 -- Enter
            BEGIN
               SET @cOption = @cInField01
               IF @cOption NOT IN ('1', '2')
               BEGIN
                  SET @nErrNo = 219159
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidOption
                  GOTO Quit
               END
               --Yes, move the carton from the pallet
               IF @cOption = '1'
               BEGIN
                  SET @nTranCount = @@TRANCOUNT  

                  SELECT @cLabelNo = Value FROM @tExtScnData WHERE Variable = '@cLabelNo'

                  SELECT TOP 1 @cPalletKey = PalletKey 
                  FROM dbo.PalletDetail WITH(NOLOCK)
                  WHERE CaseID IS NOT NULL
                     AND CaseID = @cLabelNo
                     AND StorerKey = @cStorerKey

                  IF @nTranCount = 0
                  BEGIN
                     BEGIN TRANSACTION
                  END
                  ELSE
                  BEGIN
                     SAVE TRANSACTION TR_1653_6447
                  END

                  BEGIN TRY
                     --Remove PalletDetails
                     DELETE FROM dbo.PalletDetail
                     WHERE PalletKey = @cPalletKey
                     AND CaseID IS NOT NULL
                     AND CaseID = @cLabelNo
                     AND StorerKey = @cStorerKey

                     SELECT @nRowCount = COUNT(1) 
                     FROM dbo.PalletDetail WITH(NOLOCK)
                     WHERE PalletKey = @cPalletKey
                     AND StorerKey = @cStorerKey

                     --If no detail, need remove the Pallet Header
                     IF @nRowCount = 0
                     BEGIN
                        DELETE FROM dbo.Pallet
                        WHERE PalletKey = @cPalletKey
                     END
                  END TRY
                  BEGIN CATCH
                     IF @nTranCount > 0
                     BEGIN
                        IF XACT_STATE() <> -1  
                        BEGIN
                           ROLLBACK TRANSACTION TR_1653_6447
                        END
                     END
                     ELSE
                     BEGIN
                        ROLLBACK TRANSACTION
                     END

                     SET @nErrNo = 219160
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --RemoveCTNFail
                     GOTO Quit
                  END CATCH

                  WHILE @@TRANCOUNT > @nTranCount
                     COMMIT TRANSACTION

                  GOTO BACK_FIRST_SCREEN
               END
               --No, return to first screen
               ELSE IF @cOption = '2'
               BEGIN
                  GOTO BACK_FIRST_SCREEN
               END
            END
            --return to first screen
            ELSE IF @nInputKey = 0 -- ESC
            BEGIN
               GOTO BACK_FIRST_SCREEN
            END

            BACK_FIRST_SCREEN:
            BEGIN
               -- Initialize value
               SET @cTrackNo = ''
               SET @cOrderKey = ''

               -- Prep next screen var
               SET @cOutField01 = '' -- Track No
               SET @cOutField02 = ''
               SET @cOutField15 = ''

               SET @nAfterScn = 5800
               SET @nAfterStep = 1
               GOTO Quit
            END
         END
      END

      Step_ShowPalletID_Fail:
      BEGIN
         SET @cPalletKey = ''
         SET @cOutField04 = ''
      END
   END
Quit:
END

GO
SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************************/
/* Stored Proc : isp_VNAActionConfirm_Wrapper                                          */
/* Creation Date:                                                                      */
/* Copyright: Maersk WMS                                                               */
/* Written by:  NLT013                                                                 */
/*                                                                                     */
/* Purpose: It called by IML to adjust inventory                                       */
/*          1. TaskType:  VNAIN, VNAOUT                                                */
/*          2. TaskCode:  FPK, RPF                                                     */
/* Remarks: FPK: Full Pallet Pick    RPF: Replenishment                                */
/*                                                                                     */
/*  Scenarios:                                                                         */
/*     a) TaskCode:VNAIN    Call rdt_TM_PutawayFrom_Confirm                            */
/*     b) TaskCode:VNAOUT  TaskCode:FPK  Call rdt_TM_PalletPick_Confirm                */
/*     c) TaskCode:VNAOUT  TaskCode:RPF  Call ConirmPA                                 */
/*                                                                                     */
/* Usage:                                                                              */
/*                                                                                     */
/* Local Variables:                                                                    */
/*                                                                                     */
/* Called By: DIML                                                                     */
/*                                                                                     */
/* PVCS Version:                                                                       */
/*                                                                                     */
/* Version: Maersk WMS V2                                                              */
/*                                                                                     */
/* Data Modifications:                                                                 */
/*                                                                                     */
/* Updates:                                                                            */
/* Date         Author        Purposes                                                 */
/* 2002-03-07   NLT013        VNA confirm                                              */
/***************************************************************************************/

CREATE PROC dbo.isp_VNAActionConfirm_Wrapper(
   @cTaskDetailKey                  NVARCHAR(10),
   @nErrNo                          INT               OUTPUT,
   @cErrMsg                         NVARCHAR( 255)    OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON 
   SET ANSI_NULLS OFF 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
      
   DECLARE
      @cSQL                         NVARCHAR(1000),
      @cSQLParam                    NVARCHAR(1000),
      @nRowCount                    INT,

      @cTaskType                    NVARCHAR(10),
      @cTaskCode                      NVARCHAR(255),

      @nMobile                      INT,
      @nFunc                        INT,
      @cLangCode                    NVARCHAR( 3) = 'ENG',
      @cUserName                    NVARCHAR( 18),
      @cFacility                    NVARCHAR( 5),
      @cStorerKey                   NVARCHAR( 15),
      @cDeviceID                    NVARCHAR( 20),

      @nDeviceIDLen                 INT          = 10,
      @cFromLoc                     NVARCHAR( 10),
      @cToLoc                       NVARCHAR( 10),
      @cLogicalToLoc                NVARCHAR( 10),
      @cID                          NVARCHAR( 18),
      @cStatus                      NVARCHAR( 10),

      @cDropID                      NVARCHAR( 20),
      @nQTY                         INT,
      @cFinalLOC                    NVARCHAR( 10),
      @cReasonKey                   NVARCHAR( 10),
      @cListKey                     NVARCHAR( 10),

      @cSPName                      VARCHAR( 30),

      @cDebug                       NVARCHAR( 1)

      --Status = F   Fail   
      --Error msg -> StatusMsg

   SELECT 
      @cTaskType        = td.TaskType,
      @cTaskCode        = ISNULL(td.Message03, ''),
      @cFacility        = ISNULL(loc.Facility, ''),
      @cFromLoc         = ISNULL(td.FromLoc, ''),
      @cToLoc           = ISNULL(ToLoc, ''),
      @cLogicalToLoc    = ISNULL(LogicalToLoc, ''),
      @cID              = ISNULL(ToID, ''),
      @nQTY             = Qty,
      @cDeviceID        = ISNULL(UserKey, '-1'),
      @cStatus          = td.Status,
      @cStorerKey       = td.StorerKey
   FROM dbo.TaskDetail td WITH(NOLOCK)
   INNER JOIN dbo.Loc loc WITH(NOLOCK)
      ON td.FromLoc = loc.Loc
   INNER JOIN dbo.Loc loc1 WITH(NOLOCK)
      ON td.ToLoc = loc1.Loc
      AND loc.Facility = loc1.Facility
   WHERE td.TaskDetailKey = @cTaskDetailKey

   SELECT @nRowCount = @@ROWCOUNT

   IF @nRowCount = 0
   BEGIN
      SET @nErrNo = 212508
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid Task detail key
      GOTO Quit
   END

   IF @cStatus = '9'
   BEGIN
      SET @nErrNo = 212511
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Task closed
      GOTO Quit
   END
   
   IF LEN(@cDeviceID) > @nDeviceIDLen
   BEGIN
      SET @nErrNo = 212501
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid Device ID
      GOTO Quit
   END
   
   SELECT @nRowCount = COUNT(1)
   FROM dbo.DeviceProfile dp WITH(NOLOCK)
   INNER JOIN dbo.LOC loc WITH(NOLOCK)
      ON dp.DeviceID = Loc.Loc
   WHERE dp.DeviceID = @cDeviceID
      AND dp.DeviceType = 'VNATruck'

   IF @nRowCount = 0 OR @cDeviceID IS NULL OR TRIM(@cDeviceID) = ''
   BEGIN
      SET @nErrNo = 212501
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid Device ID
      GOTO Quit
   END

   SELECT @cSPName = ISNULL(Long, '')
   FROM dbo.CODELKUP WITH(NOLOCK)
   WHERE LISTNAME = 'VNACONFIRM'
      AND CODE =  @cTaskType
      AND code2 = @cTaskCode
      AND StorerKey = @cStorerKey

   IF @cSPName IS NULL OR TRIM(@cSPName) = ''
   BEGIN
      SET @nErrNo = 212512
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- VNA Confirm SP Not Setup
      GOTO Quit
   END

   
   IF @cSPName <> ''
   BEGIN
      IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cSPName AND type = 'P')
      BEGIN
         SET @cSQL = 'EXEC dbo.' + RTRIM( @cSPName) +
            ' @cTaskDetailKey, ' +
            ' @nErrNo OUTPUT, @cErrMsg OUTPUT '

         SET @cSQLParam =
            ' @cTaskDetailKey NVARCHAR( 10), ' + 
            ' @nErrNo         INT            OUTPUT, ' + 
            ' @cErrMsg        NVARCHAR( 255) OUTPUT '
            
         BEGIN TRY
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @cTaskDetailKey, 
               @nErrNo OUTPUT, @cErrMsg OUTPUT 
         END TRY
         BEGIN CATCH
            SET @nErrNo = 212507
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --VNA Confrim Fail
            GOTO Quit
         END CATCH

         GOTO Quit
      END
      ELSE 
      BEGIN
         SET @nErrNo = 212513
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- VNA Confirm SP Not Exists
         GOTO Quit
      END 
   END

   Quit:
      IF @nErrNo <> 0
      BEGIN
         UPDATE dbo.TaskDetail WITH(ROWLOCK) SET
            Status = 'F',
            StatusMsg = @cErrMsg,
            EndTime = GETDATE(),
            EditDate = GETDATE(),
            EditWho  = SYSTEM_USER,
            Trafficcop = NULL
         WHERE TaskDetailKey = @cTaskDetailKey

         --Log the error
      END;
      RETURN
END



GO
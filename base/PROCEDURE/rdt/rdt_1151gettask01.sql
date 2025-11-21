SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_1151GetTask01                                   */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Get next task for VAP Uncasing.                             */
/*          Support 1 job multi workorderkey                            */
/*                                                                      */
/* Called from: rdtfnc_VAP_Uncasing                                     */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 02-Mar-2016 1.0  James       SOS363309 Created                       */
/************************************************************************/

CREATE PROC [RDT].[rdt_1151GetTask01] (
   @nMobile               INT, 
   @nFunc                 INT, 
   @cLangCode             NVARCHAR( 3), 
   @nStep                 INT, 
   @nInputKey             INT, 
   @cStorerkey            NVARCHAR( 15), 
   @cID                   NVARCHAR( 18), 
   @cLOT                  NVARCHAR( 10), 
   @cWorkStation          NVARCHAR( 10)  OUTPUT, 
   @cWorkOrderKey         NVARCHAR( 10)  OUTPUT, 
   @cJobKey               NVARCHAR( 10)  OUTPUT, 
   @cTaskDetailKey        NVARCHAR( 10)  OUTPUT, 
   @cWorkOrderName        NVARCHAR( 100) OUTPUT, 
   @cWorkRoutingDescr     NVARCHAR( 160) OUTPUT, 
   @nWorkQtyRemain        INT            OUTPUT, 
   @cTDStatus             NVARCHAR( 10)  OUTPUT, 
   @cWkOrdReqOutputsKey   NVARCHAR( 10)  OUTPUT, 
   @cOrderKey             NVARCHAR( 10)  OUTPUT, 
   @cOrderLineNumber      NVARCHAR( 5)   OUTPUT, 
   @cUserKey              NVARCHAR( 18)  OUTPUT, 
   @cJobLineNo            NVARCHAR( 5)   OUTPUT, 
   @nRecCount             INT            OUTPUT, 
   @cSKU                  NVARCHAR( 20)  OUTPUT, 
   @nErrNo                INT            OUTPUT, 
   @cErrMsg               NVARCHAR( 20)  OUTPUT  
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cFacility   NVARCHAR( 5), 
           @cUserName   NVARCHAR( 18), 
           @cNewLot     NVARCHAR( 10), 
           @cNewSKU     NVARCHAR( 20) 

   IF ISNULL( @cJobKey, '') = ''
   BEGIN
      SET @nRecCount = 0
      GOTO Quit
   END

   SELECT @cFacility = Facility, 
          @cUserName = UserName 
   FROM RDT.RDTMOBREC WITH (NOLOCK) 
   WHERE Mobile = @nMobile

   SET @nRecCount = 0

   IF @nInputKey = '1'
   BEGIN
      IF @nStep IN (1, 2)
      BEGIN
         IF ISNULL( @cTaskDetailKey, '') = ''
         BEGIN
            SELECT TOP 1 
                  @cJobKey            = WJ.JobKey
                , @cWorkOrderName     = WJ.WorkOrderName
                , @cWorkOrderKey      = WJ.WorkOrderKey
                , @cWorkStation       = WorkStation
                , @cWorkRoutingDescr  = WR.Descr
                , @cTDStatus          = CL.Description
                , @cTaskDetailKey     = TD.TaskDetailKey
                , @cWkOrdReqOutputsKey = WRO.WkOrdReqOutputsKey
                , @cOrderKey          = TD.OrderKey
                , @cOrderLineNumber   = TD.OrderLineNumber
                , @cUserKey           = TD.UserKey
                , @cJobLineNo         = Right(RTRIM(TD.SourceKey),5)   
	         FROM dbo.TaskDetail TD WITH (NOLOCK) 
	         INNER JOIN dbo.CodeLKup CL WITH (NOLOCK) ON CL.Code = TD.Status
	         INNER JOIN dbo.WorkOrderJOB WJ WITH (NOLOCK) ON LEFT(RTRIM(TD.SOURCEKEY),10) = WJ.JobKey
	         INNER JOIN dbo.WorkOrderJobDetail WJD WITH (NOLOCK) ON WJD.JobKey = WJ.JobKey 
	         INNER JOIN dbo.WorkOrderRouting WR WITH (NOLOCK) ON WJ.WorkOrderName = WR.WorkOrderName
	         INNER JOIN dbo.WorkOrderRequestOutputs WRO WITH (NOLOCK) ON WRO.WorkOrderKey = WJ.WorkOrderKey
	         WHERE  TD.TaskType  = 'FG'
	         AND    TD.Status    IN ('0','3')
	         AND    WJ.Facility  = @cFacility
	         AND    CL.ListName  = 'TMSTATUS'  
  	         AND    WJ.JobKey    = @cJobKey
 	         AND    WJ.WorkOrderKey = CASE WHEN ISNULL( @cWorkOrderKey, '') = '' THEN WJ.WorkOrderKey ELSE @cWorkOrderKey END
  	         AND    WJ.WorkStation  = @cWorkStation
  	         Order By CASE WHEN TD.UserKey = @cUserName THEN 0 ELSE 1 END
	                , TD.Priority   
	                , TD.TaskDetailKey
	                , WRO.WkOrdReqOutputsKey

            SET @nRecCount = @@ROWCOUNT
         END
         ELSE
         BEGIN
            SELECT TOP 1 
                    @cJobKey            = WJ.JobKey
                  , @cWorkOrderName     = WJ.WorkOrderName
                  , @cWorkOrderKey      = WJ.WorkOrderKey
                  , @cWorkStation       = WorkStation
                  , @cWorkRoutingDescr  = WR.Descr
                  , @cTDStatus          = CL.Description
                  , @cTaskDetailKey     = TD.TaskDetailKey
                  , @cWkOrdReqOutputsKey = WRO.WkOrdReqOutputsKey
   	      FROM dbo.TaskDetail TD WITH (NOLOCK) 
   	      INNER JOIN dbo.CodeLKup CL WITH (NOLOCK) ON CL.Code = TD.Status
   	      INNER JOIN dbo.WorkOrderJOB WJ WITH (NOLOCK) ON LEFT(TD.SOURCEKEY,10) = WJ.JobKey
   	      INNER JOIN dbo.WorkOrderJobDetail WJD WITH (NOLOCK) ON WJD.JobKey = WJ.JobKey 
   	      INNER JOIN dbo.WorkOrderRouting WR WITH (NOLOCK) ON WJ.WorkOrderName = WR.WorkOrderName
   	      INNER JOIN dbo.WorkOrderRequestOutputs WRO WITH (NOLOCK) ON WRO.WorkOrderKey = WJ.WorkOrderKey
   	      WHERE  TD.TaskType  = 'FG'
            AND    TD.Status    IN ('0','3')
            AND    WJ.Facility  = @cFacility
            AND    CL.ListName  = 'TMSTATUS'  
            AND    TD.TaskDetailKey > @cTaskDetailKey
            AND    WJ.JobKey    = @cJobKey
            AND    WJ.WorkOrderKey = CASE WHEN ISNULL( @cWorkOrderKey, '') = '' THEN WJ.WorkOrderKey ELSE @cWorkOrderKey END
            AND    WJ.WorkStation  = @cWorkStation
   	      Order By TD.Priority   
   	               , TD.TaskDetailKey
   	               , WRO.WkOrdReqOutputsKey

            SET @nRecCount = @@ROWCOUNT
         END

         IF @nRecCount = 0
         BEGIN
            SELECT TOP 1 
                  @cJobKey            = WJ.JobKey
                  , @cWorkOrderName     = WJ.WorkOrderName
                  , @cWorkOrderKey      = WJ.WorkOrderKey
                  , @cWorkStation       = WorkStation
                  , @cWorkRoutingDescr  = WR.Descr
                  , @cTDStatus          = CL.Description
                  , @cTaskDetailKey     = TD.TaskDetailKey
                  , @cWkOrdReqOutputsKey = WRO.WkOrdReqOutputsKey
   	      FROM dbo.TaskDetail TD WITH (NOLOCK) 
   	      INNER JOIN dbo.CodeLKup CL WITH (NOLOCK) ON CL.Code = TD.Status
   	      INNER JOIN dbo.WorkOrderJOB WJ WITH (NOLOCK) ON LEFT(TD.SOURCEKEY,10) = WJ.JobKey
   	      INNER JOIN dbo.WorkOrderJobDetail WJD WITH (NOLOCK) ON WJD.JobKey = WJ.JobKey 
   	      INNER JOIN dbo.WorkOrderRouting WR WITH (NOLOCK) ON WJ.WorkOrderName = WR.WorkOrderName
   	      INNER JOIN dbo.WorkOrderRequestOutputs WRO WITH (NOLOCK) ON WRO.WorkOrderKey = WJ.WorkOrderKey
   	      WHERE  TD.TaskType  = 'FG'
	         AND    TD.Status    IN ('0','3')
	         AND    WJ.Facility  = @cFacility
	         AND    CL.ListName  = 'TMSTATUS'  
	         AND    TD.TaskDetailKey > @cTaskDetailKey
	         AND    WJ.JobKey    = @cJobKey
            AND    WJ.WorkOrderKey = CASE WHEN ISNULL( @cWorkOrderKey, '') = '' THEN WJ.WorkOrderKey ELSE @cWorkOrderKey END
   	      AND    WJ.WorkStation  = @cWorkStation
   	      Order By TD.Priority   
   	               , TD.TaskDetailKey
   	               , WRO.WkOrdReqOutputsKey

            SET @nRecCount = @@ROWCOUNT
         END

	      SELECT @cSKU = SKU,
                @nWorkQtyRemain = Qty - QtyCompleted
		   FROM dbo.WorkOrderRequestOutputs WITH (NOLOCK) 
   	   WHERE WorkOrderKey = @cWorkOrderKey
      END

      IF @nStep IN (3, 6)
      BEGIN
         IF ISNULL( @cLOT, '') = ''
         BEGIN
            SELECT TOP 1 @cNewSKU = SKU, 
                         @cNewLot = LOT
            FROM dbo.LotxLocxID LLI WITH (NOLOCK) 
            JOIN dbo.LOC LOC WITH (NOLOCK) ON ( LLI.LOC = LOC.LOC)
            WHERE StorerKey = @cStorerKey
            AND   ID = @cID
            AND   ( Qty - QtyPicked) > 0
            AND   Facility = @cFacility
            AND   EXISTS ( SELECT 1 FROM dbo.WorkOrderRequestInputs WRI WITH (NOLOCK) 
                           JOIN dbo.WorkOrderJob WOJ WITH (NOLOCK) ON ( WRI.WorkOrderKey = WOJ.WorkOrderKey)
                           WHERE WRI.SKU = LLI.SKU
                           AND   WOJ.JobKey = @cJobKey)
            GROUP BY SKU, LOT
            ORDER BY SKU, LOT
         END
         ELSE
         BEGIN
            SELECT TOP 1 @cNewSKU = SKU, 
                         @cNewLot = LOT
            FROM dbo.LotxLocxID LLI WITH (NOLOCK) 
            JOIN dbo.LOC LOC WITH (NOLOCK) ON LLI.LOC = LOC.LOC
            WHERE StorerKey = @cStorerKey
            AND   ID = @cID
            AND   ( Qty - QtyPicked) > 0
            AND   Facility = @cFacility
            AND   SKU = @cSKU
            AND   LOT > @cLOT
            AND   EXISTS ( SELECT 1 FROM dbo.WorkOrderRequestInputs WRI WITH (NOLOCK) 
                           JOIN dbo.WorkOrderJob WOJ WITH (NOLOCK) ON ( WRI.WorkOrderKey = WOJ.WorkOrderKey)
                           WHERE WRI.SKU = LLI.SKU
                           AND   WOJ.JobKey = @cJobKey)
            GROUP BY SKU, LOT
            ORDER BY SKU, LOT            

            IF ISNULL( @cNewLot, '') = ''
               SELECT TOP 1 @cNewSKU = SKU, 
                            @cNewLot = LOT
               FROM dbo.LotxLocxID LLI WITH (NOLOCK) 
               JOIN dbo.LOC LOC WITH (NOLOCK) ON LLI.LOC = LOC.LOC
               WHERE StorerKey = @cStorerKey
               AND   ID = @cID
               AND   ( Qty - QtyPicked) > 0
               AND   Facility = @cFacility
               AND   SKU > @cSKU
               AND   EXISTS ( SELECT 1 FROM dbo.WorkOrderRequestInputs WRI WITH (NOLOCK) 
                              JOIN dbo.WorkOrderJob WOJ WITH (NOLOCK) ON ( WRI.WorkOrderKey = WOJ.WorkOrderKey)
                              WHERE WRI.SKU = LLI.SKU
                              AND   WOJ.JobKey = @cJobKey)
               GROUP BY SKU, LOT
               ORDER BY SKU, LOT
         END

         IF ISNULL( @cNewLot, '') <> ''
         BEGIN
            SET @cLot = @cNewLot
            SET @cSKU = @cNewSKU
            SELECT @nRecCount = COUNT( DISTINCT LOT)
            FROM dbo.LotxLocxID LLI WITH (NOLOCK) 
            JOIN dbo.LOC LOC WITH (NOLOCK) ON LLI.LOC = LOC.LOC
            WHERE StorerKey = @cStorerKey
            AND   ID = @cID
            AND   ( Qty - QtyPicked) > 0
            AND   Facility = @cFacility
            AND   EXISTS ( SELECT 1 FROM dbo.WorkOrderRequestInputs WRI WITH (NOLOCK) 
                           JOIN dbo.WorkOrderJob WOJ WITH (NOLOCK) ON ( WRI.WorkOrderKey = WOJ.WorkOrderKey)
                           WHERE WRI.SKU = LLI.SKU
                           AND   WOJ.JobKey = @cJobKey)
         END
         ELSE
            SET @cSKU = ''
      END
   END

   IF @nInputKey = '0'
   BEGIN
      SELECT TOP 1 
            @cJobKey            = WJ.JobKey
          , @cWorkOrderName     = WJ.WorkOrderName
          , @cWorkOrderKey      = WJ.WorkOrderKey
          , @cWorkStation       = WorkStation
          , @cWorkRoutingDescr  = WR.Descr
          , @nWorkQtyRemain     = (WRO.Qty - WRO.QtyCompleted)
          , @cTDStatus          = CL.Description
          , @cTaskDetailKey     = TD.TaskDetailKey
          , @cWkOrdReqOutputsKey = WRO.WkOrdReqOutputsKey
	   FROM dbo.TaskDetail TD WITH (NOLOCK) 
	   INNER JOIN dbo.CodeLKup CL WITH (NOLOCK) ON CL.Code = TD.Status
	   INNER JOIN dbo.WorkOrderJOB WJ WITH (NOLOCK) ON LEFT(TD.SOURCEKEY,10) = WJ.JobKey
	   INNER JOIN dbo.WorkOrderJobDetail WJD WITH (NOLOCK) ON WJD.JobKey = WJ.JobKey 
	   INNER JOIN dbo.WorkOrderRouting WR WITH (NOLOCK) ON WJ.WorkOrderName = WR.WorkOrderName
	   INNER JOIN dbo.WorkOrderRequestOutputs WRO WITH (NOLOCK) ON WRO.WorkOrderKey = WJ.WorkOrderKey
	   WHERE  TD.TaskType  = 'FG'
      AND    TD.Status    IN ('0','3')
      AND    WJ.Facility  = @cFacility
      AND    CL.ListName  = 'TMSTATUS'  
      AND    WJ.JobKey    = @cJobKey
      AND    WJ.WorkOrderKey = CASE WHEN ISNULL( @cWorkOrderKey, '') = '' THEN WJ.WorkOrderKey ELSE @cWorkOrderKey END
      AND    WJ.WorkStation  = @cWorkStation
	   Order By TD.Priority   
	          , TD.TaskDetailKey
	          , WRO.WkOrdReqOutputsKey

      SET @nRecCount = @@ROWCOUNT
   END
   
Quit:

END

GO
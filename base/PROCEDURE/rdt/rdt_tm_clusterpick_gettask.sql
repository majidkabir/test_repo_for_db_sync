SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_TM_ClusterPick_GetTask                          */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: TM Cluster Pick Get Task SP                                 */
/*                                                                      */
/* Called from: rdtfnc_TM_ClusterPick                                   */
/*                                                                      */
/* Date         Rev  Author   Purposes                                  */
/* 2020-03-17   1.0  James    WMS-12055 Created                         */
/************************************************************************/

CREATE PROC [RDT].[rdt_TM_ClusterPick_GetTask] (
   @nMobile        INT,
   @nFunc          INT,
   @cLangCode      NVARCHAR( 3),
   @nStep          INT,
   @nInputKey      INT,
   @cFacility      NVARCHAR( 5),
   @cStorerKey     NVARCHAR( 15),
   @cGroupKey      NVARCHAR( 10),
   @cCartId        NVARCHAR( 10),
   @cType          NVARCHAR( 10),
   @cTaskDetailKey NVARCHAR( 10) OUTPUT,
   @cFromLoc       NVARCHAR( 10) OUTPUT,
   @cCartonId      NVARCHAR( 20) OUTPUT,
   @cSKU           NVARCHAR( 20) OUTPUT,
   @nQty           INT           OUTPUT,
   @tGetTask       VariableTable READONLY, 
   @nErrNo         INT           OUTPUT,
   @cErrMsg        NVARCHAR( 20) OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nRowCount            INT
   DECLARE @cPickConfirmStatus   NVARCHAR( 1)
   DECLARE @cLogicalLocation     NVARCHAR( 18)
   DECLARE @cNewTaskDetailKey    NVARCHAR( 10)
   
   -- Remember current taskdetailkey
   -- Need to retrieve the taskdetailkey again because
   -- the taskdetailkey seq might be different from caseid seq
   -- so when get new case id need retrieve new taskdetailkey
   -- taskdetailkey 0007422288 caseid 00000156747420020314
   -- taskdetailkey 0007422287 caseid 00000156747420020321

   -- Get storer config  
   SET @cPickConfirmStatus = rdt.RDTGetConfig( @nFunc, 'PickConfirmStatus', @cStorerKey)  
   IF @cPickConfirmStatus = '0'  
      SET @cPickConfirmStatus = '5'  

   -- Get logical LOC  
   SET @cLogicalLocation = ''  
   SELECT @cLogicalLocation = LogicalLocation 
   FROM dbo.LOC WITH (NOLOCK) 
   WHERE LOC = @cFromLoc  
   AND   Facility = @cFacility
   
   SET @cNewTaskDetailKey = ''

   IF @cType = 'NEXTLOC'
   BEGIN
      SELECT TOP 1 
         @cFromLoc = FromLoc, 
         @cSKU = TD.Sku, 
         @nQty = TD.Qty,
         @cCartonId = TD.Caseid,
         @cNewTaskDetailKey = TD.TaskDetailKey
      FROM dbo.TaskDetail TD WITH (NOLOCK)
      JOIN dbo.LOC LOC WITH (NOLOCK) ON ( TD.FromLoc = LOC.Loc)
      JOIN dbo.PICKDETAIL PD WITH (NOLOCK) ON ( TD.FromLoc = PD.Loc AND TD.Sku = PD.Sku AND TD.Caseid = PD.CaseID)
      WHERE TD.Groupkey = @cGroupKey
      AND   TD.[Status] = '3'
      AND   LOC.Facility = @cFacility
      AND   PD.Status < @cPickConfirmStatus
      AND   PD.Status <> '4'
      AND (LOC.LogicalLocation > @cLogicalLocation  
      OR  (LOC.LogicalLocation = @cLogicalLocation AND LOC.LOC > @cFromLoc))  
      ORDER BY LOC.LogicalLocation, LOC.Loc, TD.Caseid, TD.Sku
      
      SET @nRowCount = @@ROWCOUNT
   END

   IF @cType = 'NEXTCARTON'
   BEGIN
      SELECT TOP 1 
         @cSKU = TD.Sku, 
         @nQty = TD.Qty,
         @cCartonId = TD.Caseid,
         @cNewTaskDetailKey = TD.TaskDetailKey
      FROM dbo.TaskDetail TD WITH (NOLOCK)
      JOIN dbo.LOC LOC WITH (NOLOCK) ON ( TD.FromLoc = LOC.Loc)
      JOIN dbo.PICKDETAIL PD WITH (NOLOCK) ON ( TD.FromLoc = PD.Loc AND TD.Sku = PD.Sku AND TD.Caseid = PD.CaseID)
      WHERE TD.Groupkey = @cGroupKey
      AND   TD.[Status] = '3'
      AND   TD.FromLoc = @cFromLoc
      AND   TD.Caseid > @cCartonId
      AND   LOC.Facility = @cFacility
      AND   PD.Status < @cPickConfirmStatus
      AND   PD.Status <> '4'
      ORDER BY TD.Caseid, TD.Sku

      SET @nRowCount = @@ROWCOUNT
   END

   IF @cType = 'NEXTSKU'
   BEGIN
      SELECT TOP 1 
         @cSKU = TD.Sku, 
         @nQty = TD.Qty,
         @cNewTaskDetailKey = TD.TaskDetailKey
      FROM dbo.TaskDetail TD WITH (NOLOCK)
      JOIN dbo.LOC LOC WITH (NOLOCK) ON ( TD.FromLoc = LOC.Loc)
      JOIN dbo.PICKDETAIL PD WITH (NOLOCK) ON ( TD.FromLoc = PD.Loc AND TD.Sku = PD.Sku AND TD.Caseid = PD.CaseID)
      WHERE TD.Groupkey = @cGroupKey
      AND   TD.[Status] = '3'
      AND   TD.FromLoc = @cFromLoc
      AND   TD.Caseid = @cCartonId
      AND   TD.Sku > @cSKU
      AND   LOC.Facility = @cFacility
      AND   PD.Status < @cPickConfirmStatus
      AND   PD.Status <> '4'
      ORDER BY TD.Sku

      SET @nRowCount = @@ROWCOUNT
   END
     
   IF @nRowCount = 0
   BEGIN
      SET @nErrNo = 148951
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No Task
      GOTO Quit
   END

   IF ISNULL( @cNewTaskDetailKey, '') <> '' 
      SET @cTaskDetailKey = @cNewTaskDetailKey

   Quit:
END

GO
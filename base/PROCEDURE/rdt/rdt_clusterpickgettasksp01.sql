SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/************************************************************************/  
/* Store procedure: rdt_ClusterPickGetTaskSP01                          */  
/* Copyright      : Maersk                                              */  
/* Customer       : Granite Levis                                       */  
/*                                                                      */  
/* Purpose: TM Cluster Pick Get Task SP                                 */  
/*                                                                      */  
/* Called from: rdtfnc_TM_Assist_ClusterPick                            */  
/*                                                                      */  
/* Date         Rev    Author   Purposes                                */  
/* 2025-01-06   1.0.0  NLT013   FCR-1755 Add customize SP               */  
/************************************************************************/  
  
CREATE   PROC [RDT].[rdt_ClusterPickGetTaskSP01] (  
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
   @cToteID        NVARCHAR( 20) OUTPUT,  
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

   DECLARE 
      @cPickZone                 NVARCHAR( 10),
      @cUserName                 NVARCHAR( 18),
      @cMethod                   NVARCHAR( 5)
  
   -- Get storer config    
   SET @cPickConfirmStatus = rdt.RDTGetConfig( @nFunc, 'PickConfirmStatus', @cStorerKey)    
   IF @cPickConfirmStatus = '0'    
      SET @cPickConfirmStatus = '5'    

   SELECT 
      @cUserName                    = UserName,
      @cPickZone                    = V_String24
   FROM RDT.RDTMOBREC WITH (NOLOCK)
   WHERE Mobile = @nMobile
  
   -- Get logical LOC    
   SET @cLogicalLocation = ''    
   SELECT @cLogicalLocation = LogicalLocation   
   FROM dbo.LOC WITH (NOLOCK)   
   WHERE LOC = @cFromLoc    
   AND   Facility = @cFacility  
     
   SET @cNewTaskDetailKey = ''  

      --NICK
   DECLARE @NICKMSG NVARCHAR(200)
   SET @NICKMSG = CONCAT_WS(',', 'rdt_ClusterPickGetTaskSP01', @cPickZone,  @cPickConfirmStatus )
   INSERT INTO DocInfo (Tablename, Storerkey, key1, key2, key3, lineSeq, Data)
	VALUES ('NICKLOG', '', '', '', '', 0, @NICKMSG)


   IF @cPickZone = 'PICK'
   BEGIN
      IF @cType = 'NEXTLOC'  
      BEGIN  
         SELECT TOP 1   
            @cFromLoc = FromLoc,   
            @cSKU = TD.Sku,   
            @nQty = TD.Qty,  
            @cCartonId = TD.Caseid,  
            @cToteID = TD.DropID,  
            @cNewTaskDetailKey = TD.TaskDetailKey  
         FROM dbo.TaskDetail TD WITH (NOLOCK)  
         JOIN dbo.LOC LOC WITH (NOLOCK) ON ( TD.FromLoc = LOC.Loc)  
         JOIN dbo.PICKDETAIL PD WITH (NOLOCK) ON ( TD.FromLoc = PD.Loc AND TD.Sku = PD.Sku AND TD.Caseid = PD.CaseID)  
         WHERE TD.Groupkey = @cGroupKey  
         AND   TD.[Status] = '3'  
         AND   LOC.Facility = @cFacility  
         AND   TD.DropID <> ''  
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
            @cToteID = TD.DropID,  
            @cNewTaskDetailKey = TD.TaskDetailKey  
         FROM dbo.TaskDetail TD WITH (NOLOCK)  
         JOIN dbo.LOC LOC WITH (NOLOCK) ON ( TD.FromLoc = LOC.Loc)  
         JOIN dbo.PICKDETAIL PD WITH (NOLOCK) ON ( TD.FromLoc = PD.Loc AND TD.Sku = PD.Sku AND TD.Caseid = PD.CaseID)  
         WHERE TD.Groupkey = @cGroupKey  
         AND   TD.[Status] = '3'  
         AND   TD.FromLoc = @cFromLoc  
         AND   TD.Caseid > @cCartonId  
         AND   TD.DropID <> ''  
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
         AND   TD.DropID <> ''  
         AND   LOC.Facility = @cFacility  
         AND   PD.Status < @cPickConfirmStatus  
         AND   PD.Status <> '4'  
         ORDER BY TD.Sku  
   
         SET @nRowCount = @@ROWCOUNT  
      END  
         
      IF @nRowCount = 0  
      BEGIN  
         SET @nErrNo = 231651  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No Task  
         GOTO Quit  
      END  
   END
   ELSE 
   BEGIN
      IF @cType = 'NEXTLOC'  
      BEGIN  
         SELECT TOP 1   
            @cFromLoc = FromLoc,   
            @cSKU = TD.Sku,   
            @nQty = TD.Qty,  
            @cCartonId = TD.Caseid,  
            @cToteID = TD.DropID,  
            @cNewTaskDetailKey = TD.TaskDetailKey  
         FROM dbo.TaskDetail TD WITH (NOLOCK)  
         JOIN dbo.LOC LOC WITH (NOLOCK) ON ( TD.FromLoc = LOC.Loc)  
         JOIN dbo.PICKDETAIL PD WITH (NOLOCK) ON ( TD.FromLoc = PD.Loc AND TD.Sku = PD.Sku AND TD.TaskDetailKey = PD.TaskDetailKey)  
         WHERE TD.Groupkey = @cGroupKey  
         AND   TD.[Status] = '3'  
         AND   LOC.Facility = @cFacility  
         AND   TD.DropID <> ''  
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
            @cToteID = TD.DropID,  
            @cNewTaskDetailKey = TD.TaskDetailKey  
         FROM dbo.TaskDetail TD WITH (NOLOCK)  
         JOIN dbo.LOC LOC WITH (NOLOCK) ON ( TD.FromLoc = LOC.Loc)  
         JOIN dbo.PICKDETAIL PD WITH (NOLOCK) ON ( TD.FromLoc = PD.Loc AND TD.Sku = PD.Sku AND TD.TaskDetailKey = PD.TaskDetailKey)  
         WHERE TD.Groupkey = @cGroupKey  
         AND   TD.[Status] = '3'  
         AND   TD.FromLoc = @cFromLoc  
         AND   TD.Caseid > @cCartonId  
         AND   TD.DropID <> ''  
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
         JOIN dbo.PICKDETAIL PD WITH (NOLOCK) ON ( TD.FromLoc = PD.Loc AND TD.Sku = PD.Sku AND TD.TaskDetailKey = PD.TaskDetailKey)  
         WHERE TD.Groupkey = @cGroupKey  
         AND   TD.[Status] = '3'  
         AND   TD.FromLoc = @cFromLoc  
         AND   TD.Caseid = @cCartonId  
         AND   TD.Sku > @cSKU  
         AND   TD.DropID <> ''  
         AND   LOC.Facility = @cFacility  
         AND   PD.Status < @cPickConfirmStatus  
         AND   PD.Status <> '4'  
         ORDER BY TD.Sku  
   
         SET @nRowCount = @@ROWCOUNT  
      END  
         
      IF @nRowCount = 0  
      BEGIN  
         SET @nErrNo = 231652
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No Task  
         GOTO Quit  
      END  
   END
  
   IF ISNULL( @cNewTaskDetailKey, '') <> ''   
      SET @cTaskDetailKey = @cNewTaskDetailKey  
  
   Quit:  
END  

GO
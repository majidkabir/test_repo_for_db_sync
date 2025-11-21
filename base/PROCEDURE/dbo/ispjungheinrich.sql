SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/******************************************************************************/  
/* Store procedure: ispJungheinrich                                           */  
/* Purpose: Send command to Jungheinrich direct equipment to location         */  
/*                                                                            */  
/* Modifications log:                                                         */  
/*                                                                            */  
/* Date         Author    Ver.  Purposes                                      */  
/* 2013-02-21   Ung       1.0   SOS256104 Created                             */  
/* 2014-05-24   Chee      1.1   Add DeviceType filter (Chee01)                */  
/* 2014-05-08   Ung       1.2   SOS309193 Add MVF for TBL XDock               */  
/*                              SOS309834 Add NMF for TBL XDock               */  
/* 2015-01-02   Ung       1.3   SOS328774 Add piece receiving                 */  
/* 2015-03-02   Ung       1.4   SOS331668 Add Print packing list screen       */  
/* 2015-04-23   Ung       1.5   SOS340175 Add MVF                             */  
/* 2015-06-12   Ung       1.6   SOS343961 RPF route UOM base on wave type     */  
/* 2018-12-19   Ung       1.7   Performance tuning                            */  
/* 2019-11-29   YeeKung   1.8   WMS11247 RPF_Task_Enhancement (yeekung01)     */  
/******************************************************************************/  
  
CREATE   PROCEDURE [dbo].[ispJungheinrich]  
    @nMobile         INT  
   ,@nFunc           INT  
   ,@cLangCode       NVARCHAR( 3)  
   ,@nStep           INT  
   ,@cTaskdetailKey  NVARCHAR( 10)  
   ,@nErrNo          INT       OUTPUT  
   ,@cErrMsg         NVARCHAR( 20) OUTPUT  
   ,@cParam01        NVARCHAR( 30) = ''  
   ,@cParam02        NVARCHAR( 30) = ''  
   ,@cParam03        NVARCHAR( 30) = ''  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE @b_Success   INT  
   DECLARE @n_err       INT  
   DECLARE @c_errmsg    NVARCHAR( 250)  
  
   DECLARE @cStorerKey   NVARCHAR( 15)  
   DECLARE @cSKU         NVARCHAR( 20)  
   DECLARE @cPutawayZone NVARCHAR( 15)  
   DECLARE @cUCC         NVARCHAR( 20)  
   DECLARE @cLOC         NVARCHAR( 10)  
   DECLARE @cToLOC       NVARCHAR(10)  
   DECLARE @cToID        NVARCHAR( 18)  
   DECLARE @cPickMethod  NVARCHAR( 10)  
   DECLARE @cLocationCategory NVARCHAR( 10)  
  
   DECLARE @cVNACommand  NVARCHAR( 5)  
   DECLARE @cVNALOC      NVARCHAR( 10)  
   DECLARE @cVNAReply    NVARCHAR( 255)  
   DECLARE @cVNACommand1 NVARCHAR( 5)  
   DECLARE @cVNALOC1     NVARCHAR( 10)  
   DECLARE @cVNAReply1   NVARCHAR( 255)  
  
   DECLARE @cWCSToLOC    NVARCHAR( 20)  
   DECLARE @cSortLane    NVARCHAR(10)  
   DECLARE @curUCC       CURSOR  
  
   SET @cVNACommand = ''  
   SET @cVNAReply = ''  
   SET @cVNALOC = ''  
   SET @cVNACommand1 = ''  
   SET @cVNAReply1 = ''  
   SET @cVNALOC1 = ''  
  
   -- TM Putaway From  
   IF @nFunc = 1797  
   BEGIN  
      IF @nStep = 0 -- Init  
      BEGIN  
         -- Get task info  
         SET @cLOC = ''  
         SELECT  
            @cLOC = FromLOC,  
            @cStorerKey = StorerKey  
         FROM dbo.TaskDetail WITH (NOLOCK)  
            JOIN dbo.LOC WITH (NOLOCK) ON (TaskDetail.FromLOC = LOC.LOC)  
         WHERE TaskdetailKey = @cTaskdetailKey  
            AND LOC.LocationCategory IN ('PND', 'PND_IN')  
  
         -- Build VNA command  
         IF @cLOC <> ''  
         BEGIN  
            SET @cVNACommand = 'RTGET'  
            SET @cVNALOC = @cLOC  
            SET @cVNAReply = @cLOC  
         END  
      END  
  
      IF @nStep = 1 -- From LOC  
      BEGIN  
         -- Get task info  
         SELECT @cStorerKey = StorerKey FROM dbo.TaskDetail WITH (NOLOCK) WHERE TaskdetailKey = @cTaskdetailKey  
  
         -- Build VNA command  
         SET @cVNACommand = 'RTSTP'  
         SET @cVNALOC = ''  
         SET @cVNAReply = ''  
      END  
  
      IF @nStep = 2 -- FromID  
      BEGIN  
         -- Get task info  
         SET @cLOC = ''  
         SELECT  
            @cLOC = ToLOC,  
            @cStorerKey = StorerKey  
         FROM dbo.TaskDetail WITH (NOLOCK)  
            JOIN dbo.LOC WITH (NOLOCK) ON (TaskDetail.ToLOC = LOC.LOC)  
         WHERE TaskdetailKey = @cTaskdetailKey  
            AND LOC.LocationCategory = 'VNA'  
  
         -- Build VNA command  
         IF @cLOC <> ''  
         BEGIN  
            SET @cVNACommand = 'RTPUT'  
            SET @cVNALOC = @cLOC  
            SET @cVNAReply = @cLOC  
         END  
      END  
  
      IF @nStep = 3 -- ToLOC  
      BEGIN  
         -- Build VNA command  
         SET @cVNACommand = 'RTSTP'  
         SET @cVNALOC = ''  
         SET @cVNAReply = ''  
  
         -- Get task info  
         SET @cToLOC = ''  
         SELECT  
            @cToLOC = ToLOC,  
            @cToID = ToID,  
            @cStorerKey = StorerKey  
         FROM dbo.TaskDetail WITH (NOLOCK)  
         WHERE TaskdetailKey = @cTaskdetailKey  
  
         -- Loop UCC on ID  
         IF @cToLOC = 'IND1001'  
         BEGIN  
            SET @cUCC = ''  
            SET @curUCC = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR  
               SELECT DISTINCT UCCNo  
               FROM dbo.UCC WITH (NOLOCK)  
               WHERE StorerKey = @cStorerKey  
                  AND ID = @cToID  
                  AND LOC = 'IND1001'  
                  AND Status = '1' -- Received  
            OPEN @curUCC  
            FETCH NEXT FROM @curUCC INTO @cUCC  
            WHILE @@FETCH_STATUS = 0  
            BEGIN  
               -- Get SKU  
               SELECT TOP 1 @cSKU = SKU  
               FROM dbo.UCC WITH (NOLOCK)  
               WHERE StorerKey = @cStorerKey  
                  AND UCCNo = @cUCC  
  
               -- Get putawayZone  
               SELECT @cPutawayZone = PutawayZone FROM dbo.SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU = @cSKU  
  
               -- Get induct point on destination  
               SET @cWCSToLOC = ''  
               SELECT @cWCSToLOC = UDF01  
               FROM dbo.CodeLkup WITH (NOLOCK)  
               WHERE ListName = 'PTZONE'  
                  AND Short = @cPutawayZone  
  
               -- Build WCS command  
               IF @cWCSToLOC <> ''  
               BEGIN  
                  EXECUTE dbo.isp_WS_WCS_VF_ContainerCommand  
                      @cLPNNo         = @cUCC  
                     ,@cContainerType = 'Replenishment'  
                     ,@cToLoc         = @cWCSToLOC  
                     ,@bSuccess       = @b_Success  OUTPUT  
                     ,@nErr           = @nErrNo     OUTPUT  
                     ,@cErrMsg        = @cErrMsg    OUTPUT  
                     ,@nFunc          = @nFunc  
                  IF @nErrNo <> 0  
                     GOTO Fail  
               END  
  
               IF @cPutawayZone <> ''  
               BEGIN  
                  EXECUTE dbo.isp_WS_WCS_VF_PrintingInfor  
                      @cLPNNo       = @cUCC  
                     ,@cPrintString = @cPutawayZone  
                     ,@bSuccess     = @b_Success  OUTPUT  
                     ,@nErr         = @nErrNo     OUTPUT  
                     ,@cErrMsg      = @cErrMsg    OUTPUT  
                  SET @nErrNo = 0  
                  SET @cErrMsg = ''  
               END  
  
               FETCH NEXT FROM @curUCC INTO @cUCC  
            END  
         END  
      END  
   END  
  
   -- TM Putaway To  
   IF @nFunc = 1796  
   BEGIN  
      IF @nStep = 0 -- Init  
      BEGIN  
         -- Get task info  
         SET @cLOC = ''  
         SELECT  
            @cLOC = FromLOC,  
            @cStorerKey = StorerKey  
         FROM dbo.TaskDetail WITH (NOLOCK)  
            JOIN dbo.LOC WITH (NOLOCK) ON (TaskDetail.FromLOC = LOC.LOC)  
         WHERE TaskdetailKey = @cTaskdetailKey  
            AND LOC.LocationCategory IN ('PND', 'PND_IN')  
  
         -- Build VNA command  
         IF @cLOC <> ''  
         BEGIN  
            SET @cVNACommand = 'RTGET'  
            SET @cVNALOC = @cLOC  
            SET @cVNAReply = @cLOC  
         END  
      END  
  
      IF @nStep = 1 -- From ID  
      BEGIN  
         -- Get task info  
         SELECT @cStorerKey = StorerKey FROM dbo.TaskDetail WITH (NOLOCK) WHERE TaskdetailKey = @cTaskdetailKey  
  
         -- Build VNA command  
         SET @cVNACommand = 'RTSTP'  
         SET @cVNALOC = ''  
         SET @cVNAReply = ''  
      END  
  
      IF @nStep = 3 -- UCC  
      BEGIN  
         -- Get task info  
         SET @cLOC = ''  
         SELECT  
            @cLOC = ToLOC,  
            @cStorerKey = StorerKey  
         FROM dbo.TaskDetail WITH (NOLOCK)  
            JOIN dbo.LOC WITH (NOLOCK) ON (TaskDetail.ToLOC = LOC.LOC)  
         WHERE TaskdetailKey = @cTaskdetailKey  
            AND LOC.LocationCategory = 'VNA'  
  
         -- Build VNA command  
         IF @cLOC <> ''  
         BEGIN  
            SET @cVNACommand = 'GOLOC'  
            SET @cVNALOC = @cLOC  
            SET @cVNAReply = '' -- GOLOC command does not have keyboard message return  
         END  
      END  
  
      IF @nStep = 4 -- To LOC  
      BEGIN  
         -- Get task info  
         SELECT @cStorerKey = StorerKey FROM dbo.TaskDetail WITH (NOLOCK) WHERE TaskdetailKey = @cTaskdetailKey  
  
         -- Build VNA command  
         SET @cVNACommand = 'RTSTP'  
         SET @cVNALOC = ''  
         SET @cVNAReply = ''  
      END  
   END  
  
   -- TM Replen From  
   IF @nFunc = 1764  
   BEGIN  
      IF @nStep = 0 -- Initial  
      BEGIN  
         -- Get task info  
         SET @cLOC = ''  
         SELECT  
            @cLOC = FromLOC,  
            @cStorerKey = StorerKey,  
            @cPickMethod = TaskDetail.PickMethod  
         FROM dbo.TaskDetail WITH (NOLOCK)  
            JOIN dbo.LOC WITH (NOLOCK) ON (TaskDetail.FromLOC = LOC.LOC)  
         WHERE TaskdetailKey = @cTaskdetailKey  
            AND LOC.LocationCategory IN ('VNA', 'PND', 'PND_IN', 'PND_OUT')  
  
         -- Build VNA command  
         IF @cLOC <> '' AND @cPickMethod = 'FP'  
         BEGIN  
            SET @cVNACommand = 'RTGET'  
            SET @cVNALOC = @cLOC  
            SET @cVNAReply = @cLOC  
         END  
      END  
  
      IF @nStep = 1 -- DropID  
      BEGIN  
         -- Get task info  
         SET @cLOC = ''  
         SELECT  
            @cLOC = FromLOC,  
            @cStorerKey = StorerKey,  
            @cPickMethod = TaskDetail.PickMethod  
         FROM dbo.TaskDetail WITH (NOLOCK)  
            JOIN dbo.LOC WITH (NOLOCK) ON (TaskDetail.ToLOC = LOC.LOC)  
         WHERE TaskdetailKey = @cTaskdetailKey  
            AND LOC.LocationCategory IN ('VNA', 'PND', 'PND_IN', 'PND_OUT')  
  
         -- Build VNA command  
         IF @cLOC <> '' AND @cPickMethod = 'PP'  
         BEGIN  
            SET @cVNACommand = 'GOLOC'  
            SET @cVNALOC = @cLOC  
            SET @cVNAReply = '' -- GOLOC command does not have keyboard message return  
         END  
      END  
  
      IF @nStep = 2 -- From LOC  
      BEGIN  
         -- Get task info  
         SELECT @cStorerKey = StorerKey FROM dbo.TaskDetail WITH (NOLOCK) WHERE TaskdetailKey = @cTaskdetailKey  
  
         -- Build VNA command  
         SET @cVNACommand = 'RTSTP'  
         SET @cVNALOC = ''  
         SET @cVNAReply = ''  
      END  
  
      IF @nStep = 3 -- FromID  
      BEGIN  
         DECLARE @cWaveKey NVARCHAR( 10)  
  
         -- Get task info  
         SET @cLOC = ''  
         SELECT  
            @cLOC = ToLOC,  
            @cWaveKey = WaveKey,  
            @cStorerKey = StorerKey  
         FROM dbo.TaskDetail WITH (NOLOCK)  
         WHERE TaskdetailKey = @cTaskdetailKey  
  
         -- WCS induction  
         IF @cLOC = 'IND1001'  
         BEGIN  
            DECLARE @cWaveType   NVARCHAR( 1)  
            DECLARE @cOrderGroup NVARCHAR( 20)  
            DECLARE @cUOM        NVARCHAR(10)  
            DECLARE @cListKey    NVARCHAR(10)  
            DECLARE @cPDTaskDetailKey NVARCHAR(10)  
     
            -- Get wave info  
            SELECT @cWaveType = LEFT( LTRIM( UserDefine01), 1) FROM Wave WITH (NOLOCK) WHERE WaveKey = @cWaveKey  
            IF @cWaveType = ''  
            BEGIN  
               -- Get order info  
               SELECT TOP 1   
                  @cOrderGroup = O.OrderGroup  
               FROM dbo.Orders O WITH (NOLOCK)  
                  JOIN dbo.WaveDetail WD WITH (NOLOCK) ON (O.OrderKey = WD.OrderKey)  
               WHERE WD.WaveKey = @cWaveKey  
               ORDER BY O.OrderKey  
                 
               SELECT @cWaveType = Short FROM CodeLKUP WITH (NOLOCK) WHERE ListName = 'ORDERGROUP' AND Code = @cOrderGroup  
            END  
  
            -- Get ListKey  
            SET @cListKey = ''  
            SELECT @cListKey = ListKey FROM dbo.TaskDetail WITH (NOLOCK) WHERE TaskDetailKey = @cTaskDetailKey  
  
            -- Loop UCC on original task  
            -- Note: any UCC go into IND1001 will route to its SKU.PutawayZone destination induct point, regardless of going to which final ToLOC  
            IF @cListKey = ''  
               SET @curUCC = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR  
                  SELECT DISTINCT PD.DropID  
                  FROM dbo.TaskDetail TD WITH (NOLOCK)  
                     JOIN dbo.PickDetail PD WITH (NOLOCK) ON (TD.TaskDetailKey = PD.TaskDetailKey)  
                  WHERE TD.TaskDetailKey = @cTaskDetailKey  
            ELSE  
               SET @curUCC = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR  
                  SELECT DISTINCT PD.DropID  
                  FROM dbo.TaskDetail TD WITH (NOLOCK)  
                     JOIN dbo.PickDetail PD WITH (NOLOCK) ON (TD.TaskDetailKey = PD.TaskDetailKey)  
                  WHERE TD.ListKey = @cListKey  
                     AND TD.TransitCount = 0  
  
            SET @cUCC = ''  
            OPEN @curUCC  
            FETCH NEXT FROM @curUCC INTO @cUCC  
            WHILE @@FETCH_STATUS = 0  
            BEGIN  
               -- Get SKU  
               SELECT TOP 1 @cSKU = SKU  
               FROM dbo.UCC WITH (NOLOCK)  
               WHERE StorerKey = @cStorerKey  
                  AND UCCNo = @cUCC  
  
               -- Get UCC assigned PickDetail info  
               SET @cUOM = ''  
               SELECT TOP 1  
                  @cUOM = UOM,  
                  @cPDTaskDetailKey = TaskDetailKey  
               FROM dbo.PickDetail WITH (NOLOCK)  
               WHERE StorerKey = @cStorerKey  
                  AND DropID = @cUCC  
  
               -- Get FinalLOC  
               SET @cToLOC = ''  
               SELECT @cToLOC = CASE WHEN FinalLOC <> '' THEN FinalLOC ELSE ToLOC END  
               FROM dbo.TaskDetail WITH (NOLOCK)  
               WHERE TaskDetailKey = @cPDTaskDetailKey  
  
               /*  
                  UOM 2 = full case  
                  UOM 6 = conso case  
                  UOM 7 = loose case  
  
                  WaveType = N-Normal  
                     UOM 2     Go to full case label station  
                     UOM 6,7   Go to DPP zone induct out  
                  WaveType = L-Launch  
                     UOM 2     Go to full case label station  
                     UOM 6     Go to light zone (no WCS message)  
                     UOM 7     Go to DPP zone induct out  
          WaveType = R-Leisure  
                     UOM 2,6,7 Go to DPP zone induct out  
                  WaveType = E-Ecom  
                     UOM 6,7 Go To DPP Area  
               */  
                 
               -- Route full case to label station  
               IF (@cWaveType = 'N' AND @cUOM = '2') OR  
                  (@cWaveType = 'L' AND @cUOM = '2')  
               BEGIN  
                  -- Build WCS command  
                  EXECUTE dbo.isp_WS_WCS_VF_ContainerCommand  
                      @cLPNNo         = @cUCC  
                     ,@cContainerType = 'FullCase'  
                     ,@cToLoc         = 'FCLabelStation'  
                     ,@bSuccess       = @b_Success  OUTPUT  
                     ,@nErr           = @nErrNo     OUTPUT  
                     ,@cErrMsg        = @cErrMsg    OUTPUT  
                     ,@nFunc          = @nFunc  
                  IF @nErrNo <> 0  
                     GOTO Fail  
               END  
  
               -- Route conso case to DP, loose case to DPP  
               IF (@cWaveType = 'N' AND @cUOM IN ('6', '7')) OR  
                  (@cWaveType = 'L' AND @cUOM IN ('7')) OR  
                  (@cWaveType = 'R') OR  
                  (@cWaveType = 'E' AND @cUOM IN ('6', '7')) -- (yeekung01)  
               BEGIN  
                  -- Get putawayZone  
                  SELECT @cPutawayZone = PutawayZone FROM dbo.SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU = @cSKU  
  
                  -- Get induct point on destination  
                  SET @cWCSToLOC = ''  
                  SELECT @cWCSToLOC = UDF01  
                  FROM dbo.CodeLkup WITH (NOLOCK)  
                  WHERE ListName = 'PTZONE'  
                     AND Short = @cPutawayZone  
  
                  -- Build WCS command  
                  IF @cWCSToLOC <> ''  
                  BEGIN  
                     EXECUTE dbo.isp_WS_WCS_VF_ContainerCommand  
                         @cLPNNo         = @cUCC  
                        ,@cContainerType = 'Replenishment'  
                        ,@cToLoc         = @cWCSToLOC  
                        ,@bSuccess       = @b_Success  OUTPUT  
                        ,@nErr           = @nErrNo     OUTPUT  
                        ,@cErrMsg        = @cErrMsg    OUTPUT  
                        ,@nFunc          = @nFunc  
                     IF @nErrNo <> 0  
                        GOTO Fail  
                  END  
  
                  -- Build WCS command  
                  IF @cToLOC <> ''  
                  BEGIN  
                     EXECUTE dbo.isp_WS_WCS_VF_PrintingInfor  
                         @cLPNNo       = @cUCC  
                        ,@cPrintString = @cToLOC  
                        ,@bSuccess     = @b_Success  OUTPUT  
                        ,@nErr         = @nErrNo     OUTPUT  
                        ,@cErrMsg      = @cErrMsg    OUTPUT  
                     SET @nErrNo = 0  
                     SET @cErrMsg = ''  
                  END  
               END  
  
               FETCH NEXT FROM @curUCC INTO @cUCC  
            END  
         END  
      END  
  
      IF @nStep = 6 -- ToLOC  
      BEGIN  
         -- Get task info  
         SET @cLOC = ''  
         SELECT  
            @cLOC = ToLOC,  
            @cToID = ToID,  
            @cStorerKey = StorerKey,  
            @cLocationCategory = LOC.LocationCategory  
         FROM dbo.TaskDetail WITH (NOLOCK)  
            JOIN dbo.LOC WITH (NOLOCK) ON (TaskDetail.ToLOC = LOC.LOC)  
         WHERE TaskdetailKey = @cTaskdetailKey  
  
         -- Build TCP command  
         IF @cLocationCategory IN ('VNA', 'PND', 'PND_IN', 'PND_OUT')  
         BEGIN  
            SET @cVNACommand = 'PUTPL'  
            SET @cVNALOC = @cLOC  
            SET @cVNAReply = '' -- PUTPL command does not have keyboard message return  
         END  
      END  
   END  
  
   -- Dynamic pick and pack  
   IF @nFunc = 950  
   BEGIN  
      IF @nStep = 6 -- LabelNo  
      BEGIN  
         -- Build TCP command  
         IF @cParam01 <> ''  
         BEGIN  
            IF NOT EXISTS( SELECT 1  
               FROM SKU WITH (NOLOCK)  
               WHERE StorerKey = @cParam02  
                  AND SKU = @cParam03  
                  AND CONVERT( NVARCHAR( 10), SKU.Notes1) = 'ODDSIZE')  
            BEGIN  
               EXECUTE dbo.isp_WS_WCS_VF_ContainerCommand  
                   @cLPNNo         = @cParam01  
                  ,@cContainerType = 'Pick'  
                  ,@cToLoc         = 'CPRegular'  
                  ,@bSuccess       = @b_Success  OUTPUT  
                  ,@nErr           = @nErrNo     OUTPUT  
                  ,@cErrMsg        = @cErrMsg    OUTPUT  
                  ,@nFunc          = @nFunc  
               IF @nErrNo <> 0  
                  GOTO Fail  
            END  
         END  
      END  
   END  
  
   -- Dynamic UCC pick and pack  
   IF @nFunc = 949  
   BEGIN  
      IF @nStep = 3 -- UCC  
      BEGIN  
         -- Build TCP command  
         IF @cParam01 <> ''  
         BEGIN  
            -- SKU Conveyable  
            IF NOT EXISTS( SELECT TOP 1 1  
               FROM PackDetail PD WITH (NOLOCK)  
                  JOIN SKU WITH (NOLOCK) ON (PD.StorerKey = SKU.StorerKey AND PD.SKU = SKU.SKU)  
               WHERE PD.LabelNo = @cParam01  
                  AND CONVERT( NVARCHAR( 10), SKU.Notes1) = 'ODDSIZE')  
            BEGIN  
               EXECUTE dbo.isp_WS_WCS_VF_ContainerCommand  
                   @cLPNNo         = @cParam01  
                  ,@cContainerType = 'FullCase'  
                  ,@cToLoc         = 'FCLabelStation'  
                  ,@bSuccess       = @b_Success  OUTPUT  
                  ,@nErr           = @nErrNo     OUTPUT  
                  ,@cErrMsg        = @cErrMsg    OUTPUT  
                  ,@nFunc          = @nFunc  
               IF @nErrNo <> 0  
                  GOTO Fail  
            END  
         END  
      END  
   END  
  
   -- Post pick audit  
   IF @nFunc IN (850, 855) -- All/DropID  
   BEGIN  
      -- Get sort lane  
      SELECT @cSortLane = O.Door FROM dbo.Orders O WITH (NOLOCK) WHERE OrderKey = @cParam02  
  
      IF @nStep = 2 OR -- PPA Stat   
         @nStep = 5    -- Print packing list  
      BEGIN  
         -- Build TCP command  
         IF @cParam01 <> '' AND @cSortLane <> ''  
         BEGIN  
            -- SKU Conveyable  
            IF NOT EXISTS( SELECT TOP 1 1  
               FROM PackDetail PD WITH (NOLOCK)  
                  JOIN SKU WITH (NOLOCK) ON (PD.StorerKey = SKU.StorerKey AND PD.SKU = SKU.SKU)  
               WHERE PD.LabelNo = @cParam01  
                  AND CONVERT( NVARCHAR( 10), SKU.Notes1) = 'ODDSIZE')  
            BEGIN  
               EXECUTE dbo.isp_WS_WCS_VF_ContainerCommand  
                   @cLPNNo         = @cParam01  
                  ,@cContainerType = ''  
                  ,@cToLoc         = @cSortLane  
                  ,@bSuccess       = @b_Success  OUTPUT  
                  ,@nErr           = @nErrNo     OUTPUT  
                  ,@cErrMsg        = @cErrMsg    OUTPUT  
                  ,@nFunc          = @nFunc  
               IF @nErrNo <> 0  
                  GOTO Fail  
            END  
         END  
      END  
  
      IF @nStep = 4 -- Discrepancy  
      BEGIN  
         -- Build TCP command  
         IF @cParam01 <> '' AND @cSortLane <> ''  
         BEGIN  
            IF @cParam03 = 'QC'  
            BEGIN  
               EXECUTE dbo.isp_WS_WCS_VF_ContainerCommand  
                   @cLPNNo         = @cParam01  
                  ,@cContainerType = ''  
                  ,@cToLoc         = 'CPTrouble'  
                  ,@bSuccess       = @b_Success  OUTPUT  
                  ,@nErr         = @nErrNo     OUTPUT  
                  ,@cErrMsg        = @cErrMsg    OUTPUT  
                  ,@nFunc          = @nFunc  
               IF @nErrNo <> 0  
                  GOTO Fail  
            END  
         END  
      END  
   END  
  
   -- UCC Post pick audit  
   IF @nFunc = 580  
   BEGIN  
      -- Get sort lane  
      SELECT @cSortLane = O.Door FROM dbo.Orders O WITH (NOLOCK) WHERE OrderKey = @cParam02  
  
      IF @nStep = 1 -- UCC  
      BEGIN  
         -- Build TCP command  
         IF @cParam01 <> '' AND @cSortLane <> ''  
         BEGIN  
            -- SKU Conveyable  
            IF NOT EXISTS( SELECT TOP 1 1  
               FROM PackDetail PD WITH (NOLOCK)  
                  JOIN SKU WITH (NOLOCK) ON (PD.StorerKey = SKU.StorerKey AND PD.SKU = SKU.SKU)  
               WHERE PD.LabelNo = @cParam01  
                  AND CONVERT( NVARCHAR( 10), SKU.Notes1) = 'ODDSIZE')  
            BEGIN  
               EXECUTE dbo.isp_WS_WCS_VF_ContainerCommand  
                   @cLPNNo         = @cParam01  
                  ,@cContainerType = ''  
                  ,@cToLoc         = @cSortLane  
                  ,@bSuccess       = @b_Success  OUTPUT  
                  ,@nErr           = @nErrNo     OUTPUT  
                  ,@cErrMsg  = @cErrMsg    OUTPUT  
                  ,@nFunc          = @nFunc  
               IF @nErrNo <> 0  
                  GOTO Fail  
            END  
         END  
      END  
   END  
  
   -- Move to ID  
   IF @nFunc = 534  
   BEGIN  
      IF @nStep = 5 -- ToLOC  
      BEGIN  
         -- Get putawayZone  
         SELECT @cPutawayZone = PutawayZone FROM dbo.SKU WITH (NOLOCK) WHERE StorerKey = @cParam02 AND SKU = @cParam03  
  
         -- Get induct point on destination  
         SET @cWCSToLOC = ''  
         SELECT @cWCSToLOC = UDF01  
         FROM dbo.CodeLkup WITH (NOLOCK)  
         WHERE ListName = 'PTZONE'  
            AND Short = @cPutawayZone  
  
         -- Build TCP command  
         IF @cParam01 <> '' AND @cWCSToLOC <> ''  
         BEGIN  
            -- SKU Conveyable  
            IF NOT EXISTS( SELECT TOP 1 1  
               FROM LOTxLOCxID LLI WITH (NOLOCK)  
                  JOIN SKU WITH (NOLOCK) ON (LLI.StorerKey = SKU.StorerKey AND LLI.SKU = SKU.SKU)  
               WHERE LLI.ID = @cParam01  
                  AND CONVERT( NVARCHAR( 10), SKU.Notes1) = 'ODDSIZE')  
            BEGIN  
               EXECUTE dbo.isp_WS_WCS_VF_ContainerCommand  
                   @cLPNNo         = @cParam01  
                  ,@cContainerType = 'Replenishment'  
                  ,@cToLoc         = @cWCSToLOC  
                  ,@bSuccess       = @b_Success  OUTPUT  
                  ,@nErr           = @nErrNo     OUTPUT  
                  ,@cErrMsg        = @cErrMsg    OUTPUT  
                  ,@nFunc          = @nFunc  
               IF @nErrNo <> 0  
                  GOTO Fail  
  
               IF @cPutawayZone <> ''  
               BEGIN  
                  EXECUTE dbo.isp_WS_WCS_VF_PrintingInfor  
                      @cLPNNo       = @cParam01  
                     ,@cPrintString = @cPutawayZone  
                     ,@bSuccess     = @b_Success  OUTPUT  
                     ,@nErr         = @nErrNo     OUTPUT  
                     ,@cErrMsg      = @cErrMsg    OUTPUT  
                  SET @nErrNo = 0  
                  SET @cErrMsg = ''  
               END  
            END  
         END  
      END  
   END  
  
   -- TM Non-inventory move  
   IF @nFunc = 1759  
   BEGIN  
      IF @nStep = 0 -- Init  
      BEGIN  
         -- Get task info  
         SET @cLOC = ''  
         SELECT  
            @cLOC = FromLOC,  
            @cStorerKey = StorerKey  
         FROM dbo.TaskDetail WITH (NOLOCK)  
            JOIN dbo.LOC WITH (NOLOCK) ON (TaskDetail.FromLOC = LOC.LOC)  
         WHERE TaskdetailKey = @cTaskdetailKey  
            AND LOC.LocationCategory IN ('PND', 'PND_IN', 'PACK&HOLD')  
  
         -- Build VNA command  
         IF @cLOC <> ''  
         BEGIN  
            SET @cVNACommand = 'RTGET'  
            SET @cVNALOC = @cLOC  
            SET @cVNAReply = @cLOC  
         END  
      END  
  
      IF @nStep = 5 -- ID  
      BEGIN  
         -- Get task info  
         SELECT @cStorerKey = StorerKey FROM dbo.TaskDetail WITH (NOLOCK) WHERE TaskdetailKey = @cTaskdetailKey  
  
         -- Build VNA command  
         SET @cVNACommand = 'RTSTP'  
         SET @cVNALOC = ''  
         SET @cVNAReply = ''  
  
         -- Get ToLOC info  
         IF @cParam01 <> ''  
         BEGIN  
            IF EXISTS( SELECT 1  
               FROM dbo.LOC WITH (NOLOCK)  
               WHERE LOC = @cParam01  
                  AND LocationCategory IN ('PND', 'PND_OUT', 'PACK&HOLD'))  
            BEGIN  
               -- Build VNA command  
               SET @cVNACommand1 = 'RTPUT'  
               SET @cVNALOC1 = @cParam01  
               SET @cVNAReply1 = @cParam01  
            END  
         END  
      END  
  
      IF @nStep = 2 -- To LOC  
      BEGIN  
         -- Get task info  
         SELECT @cStorerKey = StorerKey FROM dbo.TaskDetail WITH (NOLOCK) WHERE TaskdetailKey = @cTaskdetailKey  
  
         -- Build VNA command  
         SET @cVNACommand = 'RTSTP'  
         SET @cVNALOC = ''  
         SET @cVNAReply = ''  
      END  
  
      IF @nStep = 4 -- Successful message  
      BEGIN  
         -- Get task info  
         SET @cLOC = ''  
         SELECT  
            @cLOC = FromLOC,  
            @cStorerKey = StorerKey  
         FROM dbo.TaskDetail WITH (NOLOCK)  
            JOIN dbo.LOC WITH (NOLOCK) ON (TaskDetail.FromLOC = LOC.LOC)  
         WHERE TaskdetailKey = @cParam01 -- NextTaskDetailKey  
            AND LOC.LocationCategory IN ('PND', 'PND_IN', 'PACK&HOLD')  
  
         -- Build VNA command  
         IF @cLOC <> ''  
         BEGIN  
            SET @cVNACommand = 'RTGET'  
            SET @cVNALOC = @cLOC  
            SET @cVNAReply = @cLOC  
         END  
      END  
   END  
  
   -- TM move  
   IF @nFunc = 1748  
   BEGIN  
      IF @nStep = 0 -- Initial  
      BEGIN  
         -- Get task info  
         SET @cLOC = ''  
         SELECT  
            @cLOC = FromLOC,  
            @cStorerKey = StorerKey,  
            @cPickMethod = TaskDetail.PickMethod  
         FROM dbo.TaskDetail WITH (NOLOCK)  
            JOIN dbo.LOC WITH (NOLOCK) ON (TaskDetail.FromLOC = LOC.LOC)  
         WHERE TaskdetailKey = @cTaskdetailKey  
            AND LOC.LocationCategory IN ('VNA', 'PND', 'PND_IN', 'PND_OUT')  
  
         -- Build VNA command  
         IF @cLOC <> '' AND @cPickMethod = 'FP'  
         BEGIN  
            SET @cVNACommand = 'RTGET'  
            SET @cVNALOC = @cLOC  
            SET @cVNAReply = @cLOC  
         END  
      END  
  
      IF @nStep = 1 -- DropID  
      BEGIN  
         -- Get task info  
         SET @cLOC = ''  
         SELECT  
            @cLOC = FromLOC,  
            @cStorerKey = StorerKey,  
            @cPickMethod = TaskDetail.PickMethod  
         FROM dbo.TaskDetail WITH (NOLOCK)  
            JOIN dbo.LOC WITH (NOLOCK) ON (TaskDetail.ToLOC = LOC.LOC)  
         WHERE TaskdetailKey = @cTaskdetailKey  
            AND LOC.LocationCategory IN ('VNA', 'PND', 'PND_IN', 'PND_OUT')  
  
         -- Build VNA command  
         IF @cLOC <> '' AND @cPickMethod = 'PP'  
         BEGIN  
            SET @cVNACommand = 'GOLOC'  
            SET @cVNALOC = @cLOC  
            SET @cVNAReply = '' -- GOLOC command does not have keyboard message return  
         END  
      END  
  
      IF @nStep = 2 -- From LOC  
      BEGIN  
         -- Get task info  
         SELECT @cStorerKey = StorerKey FROM dbo.TaskDetail WITH (NOLOCK) WHERE TaskdetailKey = @cTaskdetailKey  
  
         -- Build VNA command  
         SET @cVNACommand = 'RTSTP'  
         SET @cVNALOC = ''  
         SET @cVNAReply = ''  
      END  
  
      IF @nStep = 3 -- From ID  
      BEGIN  
         -- Get task info  
         SET @cLOC = ''  
         SET @cToLOC = ''  
         SELECT  
            @cLOC = FromLOC,  
            @cToLOC = ToLOC,  
            @cToID = ToID,  
            @cStorerKey = StorerKey  
         FROM dbo.TaskDetail WITH (NOLOCK)  
         WHERE TaskdetailKey = @cTaskdetailKey  
  
         -- Loop UCC on ID  
         IF @cToLOC = 'IND1001'  
         BEGIN  
            SET @cUCC = ''  
            SET @curUCC = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR  
               SELECT DISTINCT UCCNo  
               FROM dbo.UCC WITH (NOLOCK)  
               WHERE StorerKey = @cStorerKey  
                  AND ID = @cToID  
                  AND LOC = @cLOC  
                  AND Status = '1' -- Received  
            OPEN @curUCC  
            FETCH NEXT FROM @curUCC INTO @cUCC  
            WHILE @@FETCH_STATUS = 0  
            BEGIN  
               EXECUTE dbo.isp_WS_WCS_VF_ContainerCommand  
                   @cLPNNo         = @cUCC  
                  ,@cContainerType = 'FullCase'  
                  ,@cToLoc         = 'FCLabelStation'  
                  ,@bSuccess       = @b_Success  OUTPUT  
                  ,@nErr           = @nErrNo     OUTPUT  
                  ,@cErrMsg        = @cErrMsg    OUTPUT  
                  ,@nFunc          = @nFunc  
               IF @nErrNo <> 0  
                  GOTO Fail  
  
               FETCH NEXT FROM @curUCC INTO @cUCC  
            END  
         END  
      END  
  
      IF @nStep = 6 -- ToLOC  
      BEGIN  
         -- Get task info  
         SET @cLOC = ''  
         SELECT  
            @cLOC = ToLOC,  
            @cToID = ToID,  
            @cStorerKey = StorerKey,  
            @cLocationCategory = LOC.LocationCategory  
         FROM dbo.TaskDetail WITH (NOLOCK)  
            JOIN dbo.LOC WITH (NOLOCK) ON (TaskDetail.ToLOC = LOC.LOC)  
         WHERE TaskdetailKey = @cTaskdetailKey  
  
         -- Build TCP command  
         IF @cLocationCategory IN ('VNA', 'PND', 'PND_IN', 'PND_OUT')  
         BEGIN  
            SET @cVNACommand = 'PUTPL'  
            SET @cVNALOC = @cLOC  
            SET @cVNAReply = '' -- PUTPL command does not have keyboard message return  
         END  
      END  
   END  
  
   -- TM NMF  
   IF @nFunc = 1746  
   BEGIN  
      IF @nStep = 0 -- Init  
      BEGIN  
         -- Get task info  
         SET @cLOC = ''  
         SELECT  
            @cLOC = FromLOC,  
            @cStorerKey = StorerKey  
         FROM dbo.TaskDetail WITH (NOLOCK)  
            JOIN dbo.LOC WITH (NOLOCK) ON (TaskDetail.FromLOC = LOC.LOC)  
         WHERE TaskdetailKey = @cTaskdetailKey  
            AND LOC.LocationCategory IN ('PND', 'PND_IN', 'PACK&HOLD')  
  
         -- Build VNA command  
         IF @cLOC <> ''  
         BEGIN  
            SET @cVNACommand = 'RTGET'  
            SET @cVNALOC = @cLOC  
            SET @cVNAReply = @cLOC  
         END  
      END  
  
      IF @nStep = 2 -- ID  
      BEGIN  
         -- Get task info  
         SELECT @cStorerKey = StorerKey FROM dbo.TaskDetail WITH (NOLOCK) WHERE TaskdetailKey = @cTaskdetailKey  
  
         -- Build VNA command  
         SET @cVNACommand = 'RTSTP'  
         SET @cVNALOC = ''  
         SET @cVNAReply = ''  
  
         -- Get ToLOC info  
         IF @cParam01 <> ''  
         BEGIN  
            IF EXISTS( SELECT 1  
               FROM dbo.LOC WITH (NOLOCK)  
               WHERE LOC = @cParam01  
                  AND LocationCategory IN ('PND', 'PND_OUT', 'PACK&HOLD'))  
            BEGIN  
               -- Build VNA command  
               SET @cVNACommand1 = 'RTPUT'  
               SET @cVNALOC1 = @cParam01  
               SET @cVNAReply1 = @cParam01  
            END  
         END  
      END  
  
      IF @nStep = 3 -- To LOC  
      BEGIN  
         -- Get task info  
         SELECT @cStorerKey = StorerKey FROM dbo.TaskDetail WITH (NOLOCK) WHERE TaskdetailKey = @cTaskdetailKey  
  
         -- Build VNA command  
         SET @cVNACommand = 'RTSTP'  
         SET @cVNALOC = ''  
         SET @cVNAReply = ''  
      END  
  
      IF @nStep = 4 -- Successful message  
      BEGIN  
         -- Get task info  
         SET @cLOC = ''  
         SELECT  
            @cLOC = FromLOC,  
            @cStorerKey = StorerKey  
         FROM dbo.TaskDetail WITH (NOLOCK)  
            JOIN dbo.LOC WITH (NOLOCK) ON (TaskDetail.FromLOC = LOC.LOC)  
         WHERE TaskdetailKey = @cParam01 -- NextTaskDetailKey  
            AND LOC.LocationCategory IN ('PND', 'PND_IN', 'PACK&HOLD')  
  
         -- Build VNA command  
         IF @cLOC <> ''  
         BEGIN  
            SET @cVNACommand = 'RTGET'  
            SET @cVNALOC = @cLOC  
            SET @cVNAReply = @cLOC  
         END  
      END  
   END  
  
   -- Piece receiving  
   IF @nFunc = 1580  
   BEGIN  
      -- SKU Conveyable  
      IF NOT EXISTS( SELECT TOP 1 1  
         FROM ReceiptDetail RD WITH (NOLOCK)  
            JOIN SKU WITH (NOLOCK) ON (RD.StorerKey = SKU.StorerKey AND RD.SKU = SKU.SKU)  
         WHERE RD.ReceiptKey = @cParam01  
            AND RD.ToID = @cParam02  
            AND RD.BeforeReceivedQTY > 0  
            AND CONVERT( NVARCHAR( 10), SKU.Notes1) = 'ODDSIZE')  
      BEGIN  
         -- Get SKU  
         SELECT TOP 1   
            @cStorerKey = StorerKey,   
            @cSKU = SKU  
         FROM dbo.ReceiptDetail WITH (NOLOCK)  
         WHERE ReceiptKey = @cParam01  
            AND ToID = @cParam02  
            AND BeforeReceivedQTY > 0  
  
         -- Get putawayZone  
         SELECT @cPutawayZone = PutawayZone FROM dbo.SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU = @cSKU  
  
         -- Get induct point on destination  
         SET @cWCSToLOC = ''  
         SELECT @cWCSToLOC = UDF01  
         FROM dbo.CodeLkup WITH (NOLOCK)  
         WHERE ListName = 'RTZONE'  
            -- AND Short = @cPutawayZone  
           
         -- Build WCS command  
         IF @cWCSToLOC <> ''  
         BEGIN  
            EXECUTE dbo.isp_WS_WCS_VF_ContainerCommand  
                @cLPNNo         = @cParam02  
               ,@cContainerType = 'Replenishment'  
               ,@cToLoc         = @cWCSToLOC  
               ,@bSuccess       = @b_Success  OUTPUT   
               ,@nErr           = @nErrNo     OUTPUT  
               ,@cErrMsg        = @cErrMsg    OUTPUT  
               ,@nFunc          = @nFunc  
            IF @nErrNo <> 0  
               GOTO Fail  
         END  
           
         IF @cPutawayZone <> ''  
         BEGIN  
            EXECUTE dbo.isp_WS_WCS_VF_PrintingInfor  
                @cLPNNo       = @cParam02  
               ,@cPrintString = @cPutawayZone  
               ,@bSuccess     = @b_Success  OUTPUT  
               ,@nErr         = @nErrNo     OUTPUT  
               ,@cErrMsg      = @cErrMsg    OUTPUT  
            SET @nErrNo = 0  
            SET @cErrMsg = ''  
         END  
      END  
   END  
  
   -- VNA command  
   IF @cVNACommand <> ''  
   BEGIN  
      -- Get device IP and port  
      DECLARE @cRemoteEndPoint NVARCHAR( 100)  
      SET @cRemoteEndPoint = ''  
      SELECT @cRemoteEndPoint = RTRIM( IPAddress) + CASE WHEN PortNo <> '' THEN ':' + RTRIM( PortNo) END  
      FROM rdt.rdtMobRec MB WITH (NOLOCK)  
         JOIN dbo.DeviceProfile DP WITH (NOLOCK) ON (MB.DeviceID = DP.DeviceID)  
      WHERE MB.Mobile = @nMobile  
         AND DP.DeviceType = 'VNATruck'  -- (Chee01)  
      IF @cRemoteEndPoint = ''  
         RETURN  
  
      -- Send VNA message  
      EXECUTE dbo.Isp_TCP_Junghienrich_wrapper_OUT  
            @c_RemoteEndPoint = @cRemoteEndPoint  
          , @c_TruckAction    = @cVNACommand  
          , @c_Location       = @cVNALOC  
          , @c_ReplyMessage   = @cVNAReply  
          , @c_StorerKey      = @cStorerKey  
          , @b_Debug          = 0  
          , @b_Success        = @b_Success  OUTPUT  
          , @n_Err            = @nErrNo     OUTPUT  
          , @c_ErrMsg         = @cErrMsg    OUTPUT  
  
      -- Send VNA message  
      IF @cVNACommand1 <> ''  
         EXECUTE dbo.Isp_TCP_Junghienrich_wrapper_OUT  
               @c_RemoteEndPoint = @cRemoteEndPoint  
             , @c_TruckAction    = @cVNACommand1  
             , @c_Location       = @cVNALOC1  
             , @c_ReplyMessage   = @cVNAReply1  
             , @c_StorerKey      = @cStorerKey  
             , @b_Debug          = 0  
             , @b_Success        = @b_Success  OUTPUT  
             , @n_Err            = @nErrNo     OUTPUT  
             , @c_ErrMsg         = @cErrMsg    OUTPUT  
  
      SET @nErrNo = 0  
      SET @cErrMsg = ''  
   END  
  
Fail:  
  
END  

GO
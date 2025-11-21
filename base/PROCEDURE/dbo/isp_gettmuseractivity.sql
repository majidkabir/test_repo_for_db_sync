SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/      
/* Stored Procedure: isp_GetTMUserActivity                              */      
/* Creation Date: 28-Jun-2010                                           */      
/* Copyright: IDS                                                       */      
/* Written by:                                                          */      
/*                                                                      */      
/* PVCS Version: 1.0                                                    */      
/*                                                                      */      
/* Version: 5.5                                                         */      
/*                                                                      */      
/* Data Modifications:                                                  */      
/*                                                                      */      
/* Updates:                                                             */      
/* Date        Author  Ver   Purposes                                   */      
/* 28-Jun-2010 Shong   1.0   For IDSUK Diana Project                    */      
/* 22-Sep-2010 Shong   1.1   Filter by User Permission & rdtMobRec      */     
/* 15-Oct-2010 NJOW01  1.2   192714-Only show active user in a area,    */        
/*                           putaway task filtered by toloc             */  
/* 21-Oct-2010 TLTING  1.3   Performance Tune (tlting01)                */  
/* 11-Oct-2011 NJOW02  1.4  226882 - Include Cycle Count tasks (CC)     */
/* 21-Nov-2011 ChewKP  1.5    Bug Fixes (ChewKP01)                      */ 
/************************************************************************/     
CREATE PROC [dbo].[isp_GetTMUserActivity]           
   @c_Facility NVARCHAR(5),           
   @c_Section  NVARCHAR(10),          
   @c_AreaKey  NVARCHAR(10),          
   @c_Zone     NVARCHAR(10),          
   @c_LoadKey  NVARCHAR(10),
   @c_TaskTypeParam NVARCHAR(10)='ALL' --NJOW02
AS          
SET NOCOUNT ON           
      -- tlting01  
CREATE TABLE #TMAct      (       
            RowRef    INT Identity(1,1) Primary Key,  
            Area      NVARCHAR(10)          
           ,UserKey   NVARCHAR(18)      
           ,Equipment NVARCHAR(60)          
           ,FromLoc   NVARCHAR(10)      
           ,ToLoc     NVARCHAR(10)      
           ,TaskDetailKey NVARCHAR(10)      
           ,TM_Type   NVARCHAR(30)      
           ,UOMQty    INT          
           ,UOM       NVARCHAR(10)          
           ,Qty       INT      
           ,LastDate  DATETIME      
           ,StorerKey NVARCHAR(15)      
           ,ID        NVARCHAR(18)      
        )          
             
DECLARE @c_FromAlsie   NVARCHAR(10)          
       ,@c_FromType    NVARCHAR(10)          
       ,@c_FromArea    NVARCHAR(10)          
       ,@c_ToAlsie     NVARCHAR(10)          
       ,@c_ToType      NVARCHAR(10)          
       ,@c_ToArea      NVARCHAR(10)          
       ,@c_TaskType    NVARCHAR(10)          
       ,@c_FromLoc     NVARCHAR(10)          
       ,@c_FromID      NVARCHAR(18)          
       ,@c_FromLot     NVARCHAR(10)          
       ,@n_TMQty       INT          
       ,@c_PickMethod  NVARCHAR(10)      
       ,@c_UserKey     NVARCHAR(18)        
       ,@c_ToLoc       NVARCHAR(10)      
       ,@c_StorerKey   NVARCHAR(10)      
       ,@c_UOM         NVARCHAR(10)      
       ,@n_UOMQty      INT      
       ,@c_TaskDetailKey NVARCHAR(10)      
       ,@d_LastDate      DATETIME      
       ,@c_ID            NVARCHAR(18)       
       ,@c_EquipmentDesc NVARCHAR(60)       
       ,@c_TaskDesc      NVARCHAR(30)      
             
          
DECLARE C_TM_Activity  CURSOR LOCAL FAST_FORWARD READ_ONLY           
FOR          
    SELECT DISTINCT td.UserKey           
    FROM   TaskDetail td WITH (NOLOCK)          
           LEFT JOIN LOC fl WITH (NOLOCK)          
                ON  fl.Loc = td.FromLoc          
           LEFT JOIN PutawayZone fpz WITH (NOLOCK)          
                ON  fpz.PutawayZone = fl.PutawayZone          
           LEFT JOIN AreaDetail fad WITH (NOLOCK)          
                ON  fad.PutawayZone = fpz.PutawayZone          
           LEFT JOIN LOC tl WITH (NOLOCK)   
                ON  tl.Loc = td.ToLoc    
           LEFT JOIN PutawayZone tpz WITH (NOLOCK)    
                ON  tpz.PutawayZone = tl.PutawayZone    
           LEFT JOIN AreaDetail tad WITH (NOLOCK)    
                ON  tad.PutawayZone = tpz.PutawayZone                            
    WHERE ((FL.Facility = CASE           
                              WHEN @c_Facility='ALL' THEN FL.Facility          
                              ELSE @c_Facility          
                         END AND          
           FL.SectionKey = CASE           
                                WHEN @c_Section='ALL' THEN FL.SectionKey          
                 ELSE @c_Section          
                           END AND          
           fad.AreaKey = CASE           
                              WHEN @c_AreaKey='ALL' THEN fad.AreaKey          
                              ELSE @c_AreaKey          
                         END AND                     
           fl.PutawayZone = CASE           
                                 WHEN @c_Zone='ALL' THEN FL.PutawayZone          
                                 ELSE @c_Zone          
                            END AND td.tasktype<>'PA' ) OR    
           (TL.Facility = CASE     
                              WHEN @c_Facility='ALL' THEN TL.Facility    
                              ELSE @c_Facility    
                         END AND    
           TL.SectionKey = CASE     
                                WHEN @c_Section='ALL' THEN TL.SectionKey    
                                ELSE @c_Section    
                           END AND    
           Tad.AreaKey = CASE     
                              WHEN @c_AreaKey='ALL' THEN Tad.AreaKey    
                              ELSE @c_AreaKey    
                         END AND    
           TL.PutawayZone = CASE     
                                 WHEN @c_Zone='ALL' THEN TL.PutawayZone    
                                 ELSE @c_Zone    
                            END AND td.tasktype='PA')) AND          
           td.UserKey <> '' AND td.UserKey IS NOT NULL AND     
           td.[Status] NOT IN ('X','S','R') AND     
           DateDiff(hour, td.[EditDate], GETDATE()) < 12                                              
           AND td.TaskType = CASE         
                              WHEN @c_TaskTypeParam='ALL' THEN td.TaskType        
                              ELSE @c_TaskTypeParam        
                             END --NJOW02                                                  
           AND td.Loadkey = CASE         
                              WHEN @c_Loadkey='ALL' THEN td.Loadkey        
                              ELSE @c_Loadkey        
                            END                  

OPEN C_TM_Activity      
      
FETCH NEXT FROM C_TM_Activity INTO @c_UserKey       
      
WHILE @@FETCH_STATUS <> -1      
BEGIN      
   
   
   
   SELECT TOP 1       
          @c_TaskType = td.TaskType,       
          @c_FromLoc  = td.FromLoc,       
          @c_ToLoc    = td.ToLoc,       
          @c_TaskDetailKey = td.TaskDetailKey,       
          @n_UOMQty        = td.UOMQty,      
          @n_TMQty         = td.Qty,       
          @d_LastDate      = td.EditDate,       
          @c_UOM           = td.UOM,       
          @c_StorerKey     = td.Storerkey,       
          @c_ID            = td.FromID,      
          @c_FromArea = CASE WHEN td.tasktype = 'PA' THEN  
                 tad.AreaKey       
               ELSE  
                 fad.AreaKey END                 
   FROM   TaskDetail td WITH (NOLOCK)          
   LEFT JOIN LOC fl WITH (NOLOCK) ON  fl.Loc = td.FromLoc          
   LEFT JOIN AreaDetail fad WITH (NOLOCK) ON  fad.PutawayZone = fl.PutawayZone          
   LEFT JOIN LOC tl WITH (NOLOCK) ON  tl.Loc = td.ToLoc          
   LEFT JOIN AreaDetail tad WITH (NOLOCK) ON  tad.PutawayZone = tl.PutawayZone          
   JOIN TaskManagerUserDetail TMU WITH (NOLOCK) ON (TMU.UserKey = td.UserKey     
                           AND ((TMU.AreaKey = fad.AreaKey AND TD.tasktype <> 'PA') OR   -- (ChewKP01)
                                (TMU.AreaKey = tad.AreaKey AND TD.tasktype = 'PA'))      -- (ChewKP01) 
                           AND TMU.Permission = '1')   
   JOIN RDT.RdtMobRec RMR WITH (NOLOCK) ON RMR.UserName = td.UserKey     
                          AND DateDiff(hour, RMR.[EditDate], GETDATE()) < 12     
                          AND RMR.V_String5 = td.TaskDetailKey --NJOW01  
    WHERE ((FL.Facility = CASE           
                              WHEN @c_Facility='ALL' THEN FL.Facility          
                              ELSE @c_Facility          
                         END AND          
           FL.SectionKey = CASE           
                                WHEN @c_Section='ALL' THEN FL.SectionKey          
                 ELSE @c_Section          
                           END AND          
           fad.AreaKey = CASE           
                              WHEN @c_AreaKey='ALL' THEN fad.AreaKey          
                              ELSE @c_AreaKey          
                         END AND                     
           fl.PutawayZone = CASE           
                                 WHEN @c_Zone='ALL' THEN FL.PutawayZone          
                                 ELSE @c_Zone          
                            END AND td.tasktype<>'PA') OR     
           (TL.Facility = CASE     
                              WHEN @c_Facility='ALL' THEN TL.Facility    
                              ELSE @c_Facility    
                         END AND    
           TL.SectionKey = CASE     
                                WHEN @c_Section='ALL' THEN TL.SectionKey    
                                ELSE @c_Section    
                           END AND    
           Tad.AreaKey = CASE     
                              WHEN @c_AreaKey='ALL' THEN Tad.AreaKey    
                              ELSE @c_AreaKey    
                         END AND    
           TL.PutawayZone = CASE     
                                 WHEN @c_Zone='ALL' THEN TL.PutawayZone    
                                 ELSE @c_Zone    
                            END AND td.tasktype='PA')) AND                                      
           td.UserKey = @c_UserKey AND     
           td.[Status] NOT IN ('X','S','R') AND     
           DateDiff(hour, td.[EditDate], GETDATE()) < 12     
           AND td.TaskType = CASE         
                              WHEN @c_TaskTypeParam='ALL' THEN td.TaskType        
                              ELSE @c_TaskTypeParam        
                             END --NJOW02                                                  
           AND td.Loadkey = CASE         
                              WHEN @c_Loadkey='ALL' THEN td.Loadkey        
                              ELSE @c_Loadkey        
                            END                  
           ORDER BY td.EditDate DESC 
             
   IF @@ROWCOUNT = 0      
      GOTO SKIP_NEXT      
         
   SELECT @c_EquipmentDesc = DESCR       
   FROM   EquipmentProfile e WITH (NOLOCK)       
   JOIN   TaskManagerUser t WITH (NOLOCK) ON t.EquipmentProfileKey = e.EquipmentProfileKey      
   WHERE  t.UserKey = @c_UserKey      
       
   SET @c_TaskDesc = ''         
   SELECT @c_TaskDesc = DESCRIPTION      
   FROM   CODELKUP c WITH (NOLOCK)      
   WHERE  c.LISTNAME = 'TASKTYPE'       
   AND    c.Code = @c_TaskType     
         
   INSERT INTO #TMAct (      
            Area                
           ,UserKey         
           ,Equipment           
           ,FromLoc         
           ,ToLoc           
           ,TaskDetailKey       
           ,TM_Type         
           ,UOMQty              
           ,UOM                 
           ,Qty             
           ,LastDate        
           ,StorerKey       
           ,ID)       
   VALUES (          
            @c_FromArea                 
           ,@c_UserKey         
           ,@c_EquipmentDesc            
           ,@c_FromLoc          
           ,@c_ToLoc           
           ,@c_TaskDetailKey       
           ,@c_TaskDesc         
           ,@n_UOMQty              
           ,@c_UOM                 
           ,@n_TMQty             
           ,@d_LastDate         
           ,@c_StorerKey       
    ,@c_ID )      
      
   SKIP_NEXT:                        
   FETCH NEXT FROM C_TM_Activity INTO @c_UserKey      
END      
CLOSE C_TM_Activity      
DEALLOCATE C_TM_Activity      
      
SELECT Area     
     ,UserKey   
     ,Equipment   
     ,FromLoc   
     ,ToLoc   
     ,TaskDetailKey   
     ,TM_Type   
     ,UOMQty   
     ,UOM   
     ,Qty   
     ,LastDate   
     ,StorerKey   
     ,ID  
FROM #TMAct

GO
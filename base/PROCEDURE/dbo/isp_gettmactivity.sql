SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/            
/* Stored Procedure: isp_GetTMActivity                                  */            
/* Creation Date:                                                       */            
/* Copyright: IDS                                                       */            
/* Written by:                                                          */            
/*                                                                      */            
/* Purpose:                                                             */            
/*                                                                      */            
/* Called By:                                                           */            
/*                                                                      */            
/* PVCS Version: 1.2                                                    */            
/*                                                                      */            
/* Version: 5.4                                                         */            
/*                                                                      */            
/* Data Modifications:                                                  */            
/*                                                                      */            
/* Updates:                                                             */            
/* Date         Author   Ver  Purposes                                  */            
/* 04-Feb-2010  Shong    1.0  Show Area which have no Task (Shong01)    */      
/* 27-May-2010  NJOW01   1.1  158736 - Add OPK task type in bar chart   */      
/*                            AND filter the NMV W/Q status tasks(fix)  */      
/* 18-Oct-2010  NJOW02   1.2  192714 - Area (sum) filter by facility    */    
/*                            and section                               */     
/* 21-Oct-2010  TLTING   1.3  Performance Tune                          */  
/* 02-Mar-2011  NJOW02   1.4  206962 - Include split tasks (SPK)        */
/* 11-Oct-2011  NJOW03   1.5  226882 - Include Cycle Count tasks (CC)   */
/************************************************************************/  
            
CREATE PROC [dbo].[isp_GetTMActivity]         
   @c_Facility NVARCHAR(5),         
   @c_Section  NVARCHAR(10),        
   @c_AreaKey  NVARCHAR(10),        
   @c_Zone     NVARCHAR(10),        
   @c_LoadKey  NVARCHAR(10),         
   @c_GenType  NVARCHAR(10)='TM',        
   @n_MaxTask  INT=0,
   @c_TaskTypeParam NVARCHAR(10)='ALL' --NJOW03
AS        
 SET NOCOUNT ON          
 SET QUOTED_IDENTIFIER OFF          
 SET ANSI_NULLS OFF          
 SET CONCAT_NULL_YIELDS_NULL OFF       
BEGIN  
CREATE TABLE #TMAct           -- tlting01  
(   
         RowRef      INT IDENTITY (1, 1) PRIMARY KEY,  
            Area     NVARCHAR(10) NULL        
           ,Aisle    NVARCHAR(10) NULL       
           ,TM_Type  NVARCHAR(10) NULL       
           ,PickType NVARCHAR(5)  NULL      
           ,Qty      INT NULL     
           ,TaskType NVARCHAR(10) NULL --NJOW01                                         
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
        
DECLARE C_TM_Activity  CURSOR LOCAL FAST_FORWARD READ_ONLY         
FOR        
    SELECT FL.LocAisle AS FromAlsie        
          ,FL.LocationCategory AS FromType        
          ,MIN(FAD.AreaKey) AS FromArea          
          ,ISNULL(TL.LocAisle,'') AS ToAlsie          
          ,ISNULL(TL.LocationCategory,'OTHER') AS ToType          
          ,MIN(TAD.AreaKey) AS ToArea          
          ,TD.TaskType        
          ,TD.FromID        
          ,TD.FromLoc        
          ,TD.Lot        
          ,TD.PickMethod        
         ,TD.Qty        
    FROM   TaskDetail td WITH (NOLOCK)        
           LEFT OUTER JOIN LOC fl WITH (NOLOCK)          
                ON  fl.Loc = td.FromLoc        
           LEFT OUTER JOIN PutawayZone fpz WITH (NOLOCK)          
                ON  fpz.PutawayZone = fl.PutawayZone        
           LEFT OUTER JOIN AreaDetail fad WITH (NOLOCK)          
                ON  fad.PutawayZone = fpz.PutawayZone        
    LEFT OUTER JOIN LOC tl WITH (NOLOCK)          
                ON  tl.Loc = td.ToLoc        
           LEFT OUTER JOIN PutawayZone tpz WITH (NOLOCK)          
                ON  tpz.PutawayZone = tl.PutawayZone        
           LEFT OUTER JOIN AreaDetail tad WITH (NOLOCK)          
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
                            END ) OR        
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
                            END )) AND         
           td.Loadkey = CASE         
                              WHEN @c_Loadkey='ALL' THEN td.Loadkey        
                              ELSE @c_Loadkey        
                         END AND                 
           td.Status NOT IN ('9' ,'S' ,'R', 'X')          
           AND NOT (td.TaskType = 'NMV' AND td.Status IN('W','Q')) 
           AND td.TaskType = CASE         
                              WHEN @c_TaskTypeParam='ALL' THEN td.TaskType        
                              ELSE @c_TaskTypeParam        
                             END --NJOW03                                                  
    GROUP BY td.TaskDetailKey, FL.LocAisle          
          ,FL.LocationCategory          
          ,ISNULL(TL.LocAisle,'')          
          ,ISNULL(TL.LocationCategory,'OTHER')             
          ,TD.TaskType          
          ,TD.FromID          
          ,TD.FromLoc          
          ,TD.Lot          
          ,TD.PickMethod          
          ,TD.Qty      
        
OPEN C_TM_Activity         
        
FETCH NEXT FROM C_TM_Activity          
INTO @c_FromAlsie, @c_FromType, @c_FromArea, @c_ToAlsie, @c_ToType, @c_ToArea, @c_TaskType,         
     @c_FromID, @c_FromLoc, @c_FromLot, @c_PickMethod, @n_TMQty                                                                                                                                                                                                
                                              
WHILE @@FETCH_STATUS<>-1        
BEGIN        
    IF @c_TaskType='PA'        
        SET @c_PickMethod = 'FP'        
            
--    SELECT @c_FromArea '@c_FromArea'        
--          ,@c_ToArea '@c_ToArea'        
--          ,@c_FromType '@c_FromType'        
--     ,@c_FromAlsie '@c_FromAlsie'        
--          ,@c_ToAlsie '@c_ToAlsie'         
        

    IF @c_TaskType = 'CC'  --NJOW03      
    BEGIN      
        INSERT INTO #TMAct        
          (        
            Area, Aisle, TM_Type, PickType, Qty, TaskType        
          )        
        VALUES        
          (        
            @c_FromArea, @c_FromAlsie, 'IN', @c_PickMethod, 1, @c_TaskType       
          )                    
    END      
    ELSE
    IF @c_TaskType = 'OPK'  --NJOW01      
    BEGIN      
        INSERT INTO #TMAct        
          (        
            Area, Aisle, TM_Type, PickType, Qty, TaskType        
          )        
        VALUES        
          (        
            @c_FromArea, @c_FromAlsie, 'IN', @c_PickMethod, 1, @c_TaskType       
          )              
      
        IF @c_ToType LIKE 'PnD%'        
        BEGIN        
            INSERT INTO #TMAct        
              (        
                Area, Aisle, TM_Type, PickType, Qty, TaskType        
              )        
            VALUES        
              (        
                @c_ToArea, @c_ToAlsie, 'OUT', @c_PickMethod, 1, @c_TaskType        
              )        
        END                  
    END      
    ELSE            
    IF @c_FromArea<>@c_ToArea        
    BEGIN        
        INSERT INTO #TMAct        
          (        
            Area, Aisle, TM_Type, PickType, Qty, TaskType        
          )        
        VALUES        
          (        
            @c_FromArea, @c_FromAlsie, 'OUT', @c_PickMethod, 1, @c_TaskType       
          )        
                
        INSERT INTO #TMAct        
          (        
            Area, Aisle, TM_Type, PickType, Qty, TaskType        
          )        
        VALUES        
          (        
            @c_ToArea, @c_ToAlsie, 'IN', @c_PickMethod, 1, @c_TaskType        
          )        
    END        
    ELSE         
    IF @c_FromArea=@c_ToArea        
    BEGIN        
        IF @c_FromType LIKE 'PnD%'        
        BEGIN        
            INSERT INTO #TMAct        
              (        
                Area, Aisle, TM_Type, PickType, Qty, TaskType        
              )        
            VALUES        
              (        
                @c_FromArea, @c_FromAlsie, 'IN', @c_PickMethod, 1, @c_TaskType        
              )        
        END        
        ELSE        
        BEGIN        
            INSERT INTO #TMAct        
              (        
                Area, Aisle, TM_Type, PickType, Qty, TaskType        
              )        
            VALUES        
              (        
                @c_FromArea, @c_FromAlsie, 'IN', @c_PickMethod, 1, @c_TaskType        
              )        
        END        
                
        IF @c_ToType LIKE 'PnD%'        
        BEGIN        
            INSERT INTO #TMAct        
              (        
                Area, Aisle, TM_Type, PickType, Qty, TaskType        
              )        
            VALUES        
              (        
                @c_ToArea, @c_ToAlsie, 'OUT', @c_PickMethod, 1, @c_TaskType        
              )        
        END        
        ELSE        
        BEGIN        
            INSERT INTO #TMAct        
              (        
                Area, Aisle, TM_Type, PickType, Qty, TaskType        
              )        
            VALUES        
              (        
                @c_ToArea, @c_ToAlsie, 'IN', @c_PickMethod, 1, @c_TaskType        
              )        
        END        
    END        
            
    FETCH NEXT FROM C_TM_Activity         
    INTO @c_FromAlsie, @c_FromType, @c_FromArea, @c_ToAlsie, @c_ToType, @c_ToArea,         
    @c_TaskType, @c_FromID, @c_FromLoc, @c_FromLot, @c_PickMethod, @n_TMQty        
END         
CLOSE C_TM_Activity        
DEALLOCATE C_TM_Activity          
        
        
IF @c_GenType='BAR'        
BEGIN        
    DECLARE @n_OUT_FP_Perctg  INT        
           ,@n_OUT_PP_Perctg  INT        
           ,@n_IN_FP_Perctg   INT        
           ,@n_IN_PP_Perctg   INT      
           ,@n_IN_OPK_Perctg  INT --NJOW01      
           ,@n_OUT_OPK_Perctg INT --NJOW01                                    
           ,@n_IN_SPK_Perctg  INT --NJOW02      
           ,@n_OUT_SPK_Perctg INT --NJOW02                                    
           ,@n_IN_CC_Perctg  INT --NJOW03      
           ,@n_OUT_CC_Perctg INT --NJOW03                                    
           ,@n_Series         INT        
           ,@n_Tot_IN         INT        
           ,@n_Tot_OUT                
            INT        
           ,@c_IN_BAR         NVARCHAR(5)        
           ,@c_OUT_BAR        NVARCHAR(5)        
      
    CREATE TABLE #BarResult    
            (   RowRef  INT IDENTITY(1,1) Primary Key,     
                Area NVARCHAR(10)  NULL      
               ,Serial INT NULL       
               ,IN_BAR NVARCHAR(10) NULL       
               ,OUT_BAR   NVARCHAR(10)   NULL     
               ,Tot_IN INT    NULL    
               ,Tot_OUT INT   NULL     
            )        
            
            
    -- @n_MaxTask /                   
    SELECT @n_OUT_FP_Perctg = FLOOR(        
               (        
                   SUM(        
                       CASE         
                            WHEN TM_Type='OUT' AND        
                       PickType='FP' AND TaskType NOT IN('SPK','CC') THEN Qty ELSE 0 END --NJOW02 & 03      
                   )*1.000        
               )        
           )        
          ,@n_OUT_PP_Perctg = FLOOR(        
               (        
                   SUM(        
                     CASE         
                            WHEN TM_Type='OUT' AND        
                       PickType<>'FP' AND TaskType NOT IN('OPK','SPK','CC') THEN Qty ELSE 0 END  --NJOW01 & 02 & 03
                   )*1.000        
               )        
           )                   
          ,@n_IN_FP_Perctg = FLOOR(        
               (        
                   SUM(        
                       CASE         
                            WHEN TM_Type='IN' AND        
                       PickType='FP' AND TaskType NOT IN('SPK','CC') THEN Qty ELSE 0 END --NJOW02 & 03        
                   )*1.000        
               )        
           )        
          ,@n_IN_PP_Perctg = FLOOR(        
               (        
                   SUM(        
                       CASE         
                            WHEN TM_Type='IN' AND        
          PickType<>'FP' AND TaskType NOT IN('OPK','SPK','CC') THEN Qty ELSE 0 END   --NJOW01 & 02 & 03      
                   )*1.000        
               )        
           )        
           --NJOW01                 
          ,@n_OUT_OPK_Perctg = FLOOR(        
               (        
                   SUM(        
                       CASE         
                            WHEN TM_Type='OUT' AND        
                       PickType='PP' AND TaskType = 'OPK' THEN Qty ELSE 0 END        
                   )*1.000        
               )        
           )                   
           --NJOW01                 
          ,@n_IN_OPK_Perctg = FLOOR(        
               (        
                   SUM(        
                       CASE         
                            WHEN TM_Type='IN' AND        
                       PickType='PP' AND TaskType = 'OPK' THEN Qty ELSE 0 END        
                   )*1.000        
               )        
           )        
           --NJOW02                 
          ,@n_OUT_SPK_Perctg = FLOOR(        
               (        
                   SUM(        
                       CASE         
                            WHEN TM_Type='OUT' AND        
                            TaskType = 'SPK' THEN Qty ELSE 0 END        
                   )*1.000        
               )        
           )                   
           --NJOW02                 
          ,@n_IN_SPK_Perctg = FLOOR(        
               (        
                   SUM(        
                       CASE         
                            WHEN TM_Type='IN' AND        
                            TaskType = 'SPK' THEN Qty ELSE 0 END        
                   )*1.000        
               )        
           )        
           --NJOW03
          ,@n_OUT_CC_Perctg = FLOOR(        
               (        
                   SUM(        
                       CASE         
                            WHEN TM_Type='OUT' AND        
                            TaskType = 'CC' THEN Qty ELSE 0 END        
                   )*1.000        
               )        
           )                   
           --NJOW03                 
          ,@n_IN_CC_Perctg = FLOOR(        
               (        
                   SUM(        
                       CASE         
                            WHEN TM_Type='IN' AND        
                            TaskType = 'CC' THEN Qty ELSE 0 END        
                   )*1.000        
               )        
           )                                          
    FROM   #TMAct         
    WHERE  Area = CASE         
                    WHEN @c_AreaKey='ALL' THEN Area        
                    ELSE @c_AreaKey        
                 END         
            
    --SELECT @n_OUT_FP_Perctg '@n_OUT_FP_Perctg', @n_OUT_PP_Perctg '@n_OUT_PP_Perctg',        
    --  @n_IN_FP_Perctg '@n_IN_FP_Perctg', @n_IN_PP_Perctg '@n_IN_PP_Perctg'        
            
    --SET @n_Tot_IN = @n_IN_FP_Perctg+@n_IN_PP_Perctg+@n_IN_OPK_Perctg+@n_IN_SPK_Perctg --NJOW01 & 02     
    --SET @n_Tot_Out = @n_OUT_FP_Perctg+@n_OUT_PP_Perctg+@n_OUT_OPK_Perctg+@n_OUT_SPK_Perctg --NJOW01 & 02        
    SET @n_Tot_IN = @n_IN_FP_Perctg+@n_IN_PP_Perctg+@n_IN_OPK_Perctg+@n_IN_SPK_Perctg + @n_IN_CC_Perctg --NJOW01 & 02 & 03     
    SET @n_Tot_Out = @n_OUT_FP_Perctg+@n_OUT_PP_Perctg+@n_OUT_OPK_Perctg+@n_OUT_SPK_Perctg + @n_OUT_CC_Perctg  --NJOW01 & 02 & 03        
            
    SET @n_OUT_FP_Perctg = CEILING((@n_OUT_FP_Perctg/(@n_MaxTask*1.000))*100)         
    SET @n_OUT_PP_Perctg = CEILING((@n_OUT_PP_Perctg/(@n_MaxTask*1.000))*100)        
    SET @n_IN_FP_Perctg = CEILING((@n_IN_FP_Perctg/(@n_MaxTask*1.000))*100)        
    SET @n_IN_PP_Perctg = CEILING((@n_IN_PP_Perctg/(@n_MaxTask*1.000))*100)        
          
    --NJOW01 Start      
    SET @n_OUT_OPK_Perctg = CEILING((@n_OUT_OPK_Perctg/(@n_MaxTask*1.000))*100)        
    SET @n_IN_OPK_Perctg = CEILING((@n_IN_OPK_Perctg/(@n_MaxTask*1.000))*100)        
    IF @n_OUT_OPK_Perctg>=2        
        SET @n_OUT_OPK_Perctg = @n_OUT_OPK_Perctg/2        
    IF @n_IN_OPK_Perctg>=2        
        SET @n_IN_OPK_Perctg = @n_IN_OPK_Perctg/2      
    --NJOW01 End      

    --NJOW02 Start      
    SET @n_OUT_SPK_Perctg = CEILING((@n_OUT_SPK_Perctg/(@n_MaxTask*1.000))*100)        
    SET @n_IN_SPK_Perctg = CEILING((@n_IN_SPK_Perctg/(@n_MaxTask*1.000))*100)        
    IF @n_OUT_SPK_Perctg>=2        
        SET @n_OUT_SPK_Perctg = @n_OUT_SPK_Perctg/2        
    IF @n_IN_SPK_Perctg>=2        
        SET @n_IN_SPK_Perctg = @n_IN_SPK_Perctg/2      
    --NJOW02 End      

    --NJOW03 Start      
    SET @n_OUT_CC_Perctg = CEILING((@n_OUT_CC_Perctg/(@n_MaxTask*1.000))*100)        
    SET @n_IN_CC_Perctg = CEILING((@n_IN_CC_Perctg/(@n_MaxTask*1.000))*100)        
    IF @n_OUT_CC_Perctg>=2        
        SET @n_OUT_CC_Perctg = @n_OUT_CC_Perctg/2        
    IF @n_IN_CC_Perctg>=2        
        SET @n_IN_CC_Perctg = @n_IN_CC_Perctg/2      
    --NJOW03 End      
     
    IF @n_OUT_FP_Perctg>=2        
        SET @n_OUT_FP_Perctg = @n_OUT_FP_Perctg/2        
            
    IF @n_OUT_PP_Perctg>=2        
        SET @n_OUT_PP_Perctg = @n_OUT_PP_Perctg/2        
            
    IF @n_IN_FP_Perctg>=2        
        SET @n_IN_FP_Perctg = @n_IN_FP_Perctg/2        
            
    IF @n_IN_PP_Perctg>=2        
        SET @n_IN_PP_Perctg = @n_IN_PP_Perctg/2        
            
    --SELECT @n_OUT_FP_Perctg '@n_OUT_FP_Perctg', @n_OUT_PP_Perctg '@n_OUT_PP_Perctg',        
    --   @n_IN_FP_Perctg '@n_IN_FP_Perctg', @n_IN_PP_Perctg '@n_IN_PP_Perctg'        
            
    SET @n_Series = 1        
    WHILE @n_Series<=50        
    BEGIN        
        SET @c_OUT_BAR = ''        
        SET @c_IN_BAR = ''        
                
        IF @n_Series<=@n_OUT_FP_Perctg        
            SET @c_OUT_BAR = 'FP'        
        ELSE         
        IF @n_Series<=@n_OUT_FP_Perctg+@n_OUT_PP_Perctg        
            SET @c_OUT_BAR = 'PP'       
        ELSE      
        IF @n_Series<=@n_OUT_FP_Perctg+@n_OUT_PP_Perctg+@n_OUT_OPK_Perctg  --NJOW01      
            SET @c_OUT_BAR = 'PPOPK'  
        ELSE    
        IF @n_Series<=@n_OUT_FP_Perctg+@n_OUT_PP_Perctg+@n_OUT_OPK_Perctg+@n_OUT_SPK_Perctg  --NJOW02      
            SET @c_OUT_BAR = 'SPK'      
        ELSE
        IF @n_Series<=@n_OUT_FP_Perctg+@n_OUT_PP_Perctg+@n_OUT_OPK_Perctg+@n_OUT_SPK_Perctg+@n_OUT_CC_Perctg  --NJOW03     
            SET @c_OUT_BAR = 'CC'      
                
        IF @n_Series<=@n_IN_FP_Perctg        
            SET @c_IN_BAR = 'FP'        
        ELSE         
        IF @n_Series<=@n_IN_FP_Perctg+@n_IN_PP_Perctg        
            SET @c_IN_BAR = 'PP'      
        ELSE        
        IF @n_Series<=@n_IN_FP_Perctg+@n_IN_PP_Perctg+@n_IN_OPK_Perctg  --NJOW01      
            SET @c_IN_BAR = 'PPOPK'        
        ELSE        
        IF @n_Series<=@n_IN_FP_Perctg+@n_IN_PP_Perctg+@n_IN_OPK_Perctg+@n_IN_SPK_Perctg  --NJOW02      
            SET @c_IN_BAR = 'SPK'    
        ELSE    
        IF @n_Series<=@n_IN_FP_Perctg+@n_IN_PP_Perctg+@n_IN_OPK_Perctg+@n_IN_SPK_Perctg+@n_IN_CC_Perctg  --NJOW03      
            SET @c_IN_BAR = 'CC'        
                
        INSERT INTO #BarResult        
          (        
            Area, Serial, IN_BAR, OUT_BAR, Tot_IN, Tot_OUT        
          )        
        VALUES        
          (        
            @c_AreaKey, @n_Series, @c_IN_BAR, @c_OUT_BAR, @n_Tot_IN, @n_Tot_OUT        
          )        
                
        SET @n_Series = @n_Series+1        
    END         
    SELECT Area      
         ,Serial        
         ,IN_BAR        
         ,OUT_BAR        
         ,Tot_IN     
         ,Tot_OUT           
    FROM   #BarResult         
    WHERE  Area = CASE         
                    WHEN @c_AreaKey='ALL' THEN Area        
                    ELSE @c_AreaKey        
                 END    
    DROP TABLE #BarResult       
END        
ELSE         
IF @c_GenType='SUM'        
BEGIN        
    /*SELECT Area        
          ,SUM(CASE WHEN TM_Type='IN' THEN Qty ELSE 0 END) AS [IN]        
          ,SUM(CASE WHEN TM_Type='OUT' THEN Qty ELSE 0 END) AS [OUT]        
    FROM   #TMAct          
    WHERE  Area = CASE         
                        WHEN @c_AreaKey='ALL' THEN Area        
                        ELSE @c_AreaKey        
                     END         
    GROUP BY Area */    
    CREATE TABLE #TMP_AREA  
    (  RowRef      INT IDENTITY (1, 1) PRIMARY KEY,  
       Area     NVARCHAR(10)         )      
    --NJOW02   
    INSERT INTO #TMP_AREA (   Area )         
    SELECT DISTINCT TMA.Area        
    FROM   #TMAct TMA    
    JOIN  AreaDetail ad (NOLOCK) ON (TMA.Area = ad.Areakey)    
    JOIN  Loc (NOLOCK) ON (ad.Putawayzone = Loc.Putawayzone)    
    WHERE  TMA.Area = CASE         
                        WHEN @c_AreaKey='ALL' THEN TMA.Area        
                        ELSE @c_AreaKey        
                      END AND    
           Loc.Facility = CASE         
                              WHEN @c_Facility='ALL' THEN Loc.Facility        
                              ELSE @c_Facility        
                          END AND    
           Loc.SectionKey = CASE         
                                WHEN @c_Section='ALL' THEN Loc.SectionKey        
                                ELSE @c_Section        
                           END                                
        
    SELECT TMA.Area        
          ,SUM(CASE WHEN TMA.TM_Type='IN' THEN TMA.Qty ELSE 0 END) AS [IN]        
          ,SUM(CASE WHEN TMA.TM_Type='OUT' THEN TMA.Qty ELSE 0 END) AS [OUT]        
    FROM   #TMAct TMA    
    JOIN #TMP_AREA ON (TMA.Area = #TMP_AREA.Area)    
    GROUP BY TMA.Area    
    UNION ALL -- (Shong01)      
    SELECT DISTINCT fad.AreaKey, 0, 0        
    FROM   LOC fl WITH (NOLOCK)      
           JOIN PutawayZone fpz WITH (NOLOCK)        
                ON  fpz.PutawayZone = fl.PutawayZone        
           JOIN AreaDetail fad WITH (NOLOCK)        
                ON  fad.PutawayZone = fpz.PutawayZone       
    WHERE (FL.Facility = CASE         
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
                         END AND             fl.PutawayZone = CASE         
                                 WHEN @c_Zone='ALL' THEN FL.PutawayZone        
                                 ELSE @c_Zone        
                            END ) AND      
            NOT EXISTS(SELECT 1 FROM #TMAct TMA WHERE TMA.Area = fad.AreaKey)           
    ORDER BY 1    
      
   DROP TABLE #TMP_AREA  
      
END        
ELSE         
IF @c_GenType='TM'        
BEGIN        
    SELECT Area        
          ,Aisle        
          ,SUM(CASE WHEN TM_Type='IN' THEN Qty ELSE 0 END) AS [IN]        
          ,SUM(CASE WHEN TM_Type='OUT' THEN Qty ELSE 0 END) AS [OUT]        
    FROM   #TMAct         
    WHERE  Area = CASE         
                        WHEN @c_AreaKey='ALL' THEN Area        
                        ELSE @c_AreaKey        
                     END         
    GROUP BY        
           Area        
          ,Aisle         
                   
                   
           --SELECT * FROM #TMAct WHERE aisle = 'DH'        
END     
  
DROP TABLE #TMAct  
  
END 


GO
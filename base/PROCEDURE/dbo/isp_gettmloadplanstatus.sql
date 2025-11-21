SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/          
/* Stored Procedure: isp_GetTMLoadplanStatus                            */          
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
/* 12-Mar-2010  Shong    1.1  Only show Loadpla's DropID in Staging    */
/* 06-MAY-2010  SHONG    1.2  Only show Loadplan already released but   */
/*                            not completed (staged)                    */     
/* 07-May-2010  Vicky    1.3  Those released but not Pick in progress   */
/*                            should be shown (Vicky01)                 */  
/* 21-Feb-2012  Shong    1.4  Performance Tuning                        */
/************************************************************************/          
CREATE PROC [dbo].[isp_GetTMLoadplanStatus]       
   @c_Facility NVARCHAR(5),       
   @c_Section  NVARCHAR(10),      
   @c_AreaKey  NVARCHAR(10)      
AS      
SET NOCOUNT ON         
         
DECLARE @c_FromAlsie   NVARCHAR(10)      
       ,@c_FromType    NVARCHAR(10)      
       ,@c_FromArea    NVARCHAR(10)      
       ,@c_ToAlsie     NVARCHAR(10)      
       ,@n_Staged      INT      
       ,@n_Released    INT      
       ,@n_Pending     INT 
       ,@n_CtnInStage  INT
       ,@n_PickedCtns  INT
       ,@c_LoadKey     NVARCHAR(10)
       ,@c_StorerKey   NVARCHAR(15)     
      
    SELECT @n_Pending = COUNT(DISTINCT L.LoadKey)      
    FROM   PickDetail p WITH (NOLOCK)      
           JOIN LOC WITH (NOLOCK)      
                ON  LOC.Loc = p.Loc      
           JOIN PutawayZone fpz WITH (NOLOCK)      
                ON  fpz.PutawayZone = LOC.PutawayZone      
           JOIN AreaDetail fad WITH (NOLOCK)      
                ON  fad.PutawayZone = fpz.PutawayZone      
           JOIN LoadplanDetail lpd WITH (NOLOCK)      
                ON  lpd.OrderKey = p.OrderKey                      
           JOIN Loadplan l WITH (NOLOCK)      
                ON  l.Loadkey = lpd.Loadkey      
    WHERE  LOC.Facility = CASE       
                              WHEN @c_Facility='ALL' THEN LOC.Facility      
                              ELSE @c_Facility      
                         END AND      
           LOC.SectionKey = CASE       
                                WHEN @c_Section='ALL' THEN LOC.SectionKey      
                                ELSE @c_Section      
                           END AND      
           fad.AreaKey = CASE       
                              WHEN @c_AreaKey='ALL' THEN fad.AreaKey      
                              ELSE @c_AreaKey      
                         END AND      
           l.Status IN ('1','2') AND     
           l.PROCESSFLAG NOT IN ('Y')      

    -- Added by SHONG on 06-May-2010
    -- Only show Loadplan already released but not completed (staged)   
    SET @n_Released = 0          
    DECLARE CUR_Load CURSOR LOCAL FAST_FORWARD READ_ONLY 
    FOR SELECT DISTINCT L.LoadKey, P.StorerKey       
    FROM   PickDetail p WITH (NOLOCK)      
           JOIN LOC WITH (NOLOCK)      
                ON  LOC.Loc = p.Loc      
           JOIN PutawayZone fpz WITH (NOLOCK)      
                ON  fpz.PutawayZone = LOC.PutawayZone      
           JOIN AreaDetail fad WITH (NOLOCK)      
                ON  fad.PutawayZone = fpz.PutawayZone      
           JOIN LoadplanDetail lpd WITH (NOLOCK)      
                ON  lpd.OrderKey = p.OrderKey                      
           JOIN Loadplan l WITH (NOLOCK) ON  l.Loadkey = lpd.Loadkey 
    WHERE  LOC.Facility = CASE       
                              WHEN @c_Facility='ALL' THEN LOC.Facility      
                              ELSE @c_Facility      
            END AND      
           LOC.SectionKey = CASE       
                                WHEN @c_Section='ALL' THEN LOC.SectionKey      
        ELSE @c_Section      
                           END AND      
           fad.AreaKey = CASE       
                              WHEN @c_AreaKey='ALL' THEN fad.AreaKey      
                              ELSE @c_AreaKey      
                         END AND      
           l.PROCESSFLAG IN ('Y') AND       
           l.Status < '9'       
                  
    OPEN CUR_LOAD

    FETCH NEXT FROM CUR_LOAD INTO @c_LoadKey, @c_StorerKey 
    WHILE @@FETCH_STATUS <> -1
    BEGIN
       SET @n_CtnInStage=0
       SELECT @n_CtnInStage = COUNT(DISTINCT dd.ChildId)     
       FROM Dropid d WITH (NOLOCK)     
       JOIN DropidDetail dd WITH (NOLOCK) ON dd.Dropid = d.Dropid     
       JOIN LOC l WITH (NOLOCK) ON l.LOC = d.Droploc AND l.LocationCategory = 'STAGING'     
       WHERE d.Loadkey = @c_LoadKey  

       SET @n_PickedCtns=0
       SELECT @n_PickedCtns = ISNULL( COUNT(Distinct p.LabelNo), 0 )   
       FROM DROPID D WITH (NOLOCK)  
       INNER JOIN PACKDETAIL P WITH (NOLOCK) ON P.StorerKey = @c_StorerKey AND P.RefNo = d.DropID     
       WHERE D.LabelPrinted = 'Y'   
       AND   D.LoadKey = @c_LoadKey   

       IF (@n_CtnInStage <> @n_PickedCtns) OR (@n_CtnInStage+ @n_PickedCtns = 0) -- (Vicky01)
       BEGIN
          SET @n_Released = @n_Released + 1 
       END 
       FETCH NEXT FROM CUR_LOAD INTO @c_LoadKey, @c_StorerKey 
    END
    CLOSE CUR_LOAD
    DEALLOCATE CUR_LOAD 

    SELECT @n_Staged = COUNT(DISTINCT LP.LoadKey)      
    FROM   Loadplan lp WITH (NOLOCK)      
           JOIN DropID DI WITH (NOLOCK)      
                ON  DI.Loadkey = lp.Loadkey          
           JOIN LOC WITH (NOLOCK)      
                ON  LOC.Loc = DI.DropLoc      
           JOIN PutawayZone fpz WITH (NOLOCK)      
                ON  fpz.PutawayZone = LOC.PutawayZone      
           JOIN AreaDetail fad WITH (NOLOCK)      
                ON  fad.PutawayZone = fpz.PutawayZone      
    WHERE  LOC.Facility = CASE       
                              WHEN @c_Facility='ALL' THEN LOC.Facility      
                              ELSE @c_Facility      
                         END AND      
           LOC.SectionKey = CASE       
                                WHEN @c_Section='ALL' THEN LOC.SectionKey      
                                ELSE @c_Section      
                           END AND      
           fad.AreaKey = CASE       
                              WHEN @c_AreaKey='ALL' THEN fad.AreaKey      
                              ELSE @c_AreaKey      
                         END AND      
           lp.PROCESSFLAG = 'Y' AND       
           lp.Status < '9' AND   
           DI.LoadKey = lp.LoadKey AND  
           LOC.LocationCategory = 'STAGING'       
                 
                 
   SELECT @n_Pending 'Pending', @n_Released 'Released', @n_Staged 'Staged'

GO
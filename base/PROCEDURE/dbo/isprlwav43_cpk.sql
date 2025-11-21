SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Stored Proc: ispRLWAV43_CPK                                          */  
/* Creation Date: 2021-07-21                                            */  
/* Copyright: LF Logistics                                              */  
/* Written by: Wan                                                      */  
/*                                                                      */  
/* Purpose: WMS-17299 - RG - Adidas Release Wave                        */  
/*        :                                                             */  
/* Called By:                                                           */  
/*          :                                                           */  
/* PVCS Version: 1.3                                                    */  
/*                                                                      */  
/* Version: 7.0                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date        Author   Ver   Purposes                                  */  
/* 2021-07-21  Wan      1.0   Created.                                  */  
/* 2021-09-28  Wan      1.0   DevOps Combine Script.                    */  
/* 2021-09-28  Wan01    1.1   Check Build CPK Case Qty against Pick Qty */ 
/* 2022-02-09  Wan02    1.2   CR 3.0 Link Deviceprofile by storerkey    */  
/*                            Fixed. For allocated stock from DPBULK,use*/ 
/*                            DBBULK's PickZone to find PackStation     */
/*                            regardless if there is Home Loc setup.    */
/* 2022-10-06  Wan03    1.3   WMS-20898 - THA-adidas-Assign Wave priority*/
/*                            to Taskdetail (RPF, RPT,CPK,ASTCPK)       */  
/************************************************************************/  
CREATE PROC [dbo].[ispRLWAV43_CPK]  
   @c_Wavekey     NVARCHAR(10)      
,  @b_Success     INT            = 1   OUTPUT  
,  @n_Err         INT            = 0   OUTPUT  
,  @c_ErrMsg      NVARCHAR(255)  = ''  OUTPUT  
,  @n_debug       INT            = 0   
AS  
BEGIN  
   SET NOCOUNT ON  
   SET ANSI_NULLS OFF  
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE    
           @n_StartTCnt          INT         = 0  
         , @n_Continue           INT         = 1  
  
         , @n_Batch              INT         = 0  
         , @n_TaskDetailKey      INT         = 0   
         --, @c_PickSlipNo         NVARCHAR(10)= ''  
         --, @c_CaseID             NVARCHAR(20)= ''  
         , @c_TaskDetailKey      NVARCHAR(10)= ''   
         , @c_TaskStatus         NVARCHAR(10)= '0'  
         
         , @c_CaseID             NVARCHAR(20) = ''    --(Wan01)
         
         , @c_Facility           NVARCHAR(5)  = ''    --(Wan03)         
         , @c_Storerkey          NVARCHAR(15) = ''    --(Wan03)
         , @c_Priority_Wave      NVARCHAR(10) = '9'   --(Wan03)
         , @c_Release_Opt5       NVARCHAR(1000)= ''   --(Wan03)
         , @c_TaskByWavePriority NVARCHAR(10) = 'N'   --(Wan03)
     
   DECLARE @t_ORDERS             TABLE  
         (  Wavekey              NVARCHAR(10) NOT NULL   DEFAULT('')   
         ,  Loadkey              NVARCHAR(10) NOT NULL   DEFAULT('')   
         ,  Orderkey             NVARCHAR(10) NOT NULL   DEFAULT('')    PRIMARY KEY  
         ,  Facility             NVARCHAR(5)  NOT NULL   DEFAULT('')  
         ,  Storerkey            NVARCHAR(15) NOT NULL   DEFAULT('')  
         ,  DocType              NVARCHAR(10) NOT NULL   DEFAULT('')   
         ,  Ecom_Single_Flag     NVARCHAR(10) NOT NULL   DEFAULT('')  
         )  
           
   SET @n_StartTCnt = @@TRANCOUNT  
   SET @n_Continue = 1  
   SET @n_err      = 0  
   SET @c_errmsg   = ''  
    
   IF OBJECT_ID('tempdb..#CPK_WIP','U') IS NOT NULL  
   BEGIN  
      DROP TABLE #CPK_WIP 
   END  
   
   CREATE TABLE #CPK_WIP    
   (  RowID             INT          IDENTITY(1,1)     PRIMARY KEY  
   ,  Orderkey          NVARCHAR(10) DEFAULT('')  
   ,  Pickdetailkey     NVARCHAR(10) DEFAULT('')     
   ,  Storerkey         NVARCHAR(15) DEFAULT('')  
   ,  Sku               NVARCHAR(20) DEFAULT('')  
   ,  UOM               NVARCHAR(10) DEFAULT('')  
   ,  UOMQty            INT          DEFAULT(0)  
   ,  Qty               INT          DEFAULT(0)  
   ,  Lot               NVARCHAR(10) DEFAULT('')  
   ,  Loc               NVARCHAR(10) DEFAULT('')            
   ,  CaseID            NVARCHAR(20) DEFAULT('')  
   ,  DropID            NVARCHAR(20) DEFAULT('')        
   ,  PickLoc           NVARCHAR(10) DEFAULT('')         --RPF toLoc (DP/DPP/PackStation/SortStationGroup) or Pickdetail.Loc  
   ,  PickLogicalloc    NVARCHAR(10) DEFAULT('')  
   ,  PickZone          NVARCHAR(10) DEFAULT('')  
   ,  PickAreakey       NVARCHAR(10) DEFAULT('')  
   ,  PackZone          NVARCHAR(10) DEFAULT('')         --Ecom PackZone, Single = PackStation, Multi = SortStation Group   
   --,  PackStation       INT          DEFAULT(0)  
   ,  SkuGroup          NVARCHAR(30) DEFAULT('')           
   ,  Style             NVARCHAR(10) DEFAULT('')          
   ,  Color             NVARCHAR(10) DEFAULT('')        
   ,  Size              NVARCHAR(10) DEFAULT('')   
   ,  PickMethod        NVARCHAR(10) DEFAULT('')   
   ,  Score             NVARCHAR(10) DEFAULT('')   
   )  
     
   IF OBJECT_ID('tempdb..#CPK','U') IS NOT NULL    
   BEGIN  
      DROP TABLE #CPK
   END
   
   CREATE TABLE #CPK      
      (  RowID             INT          IDENTITY(1,1)     PRIMARY KEY    
      ,  TaskDetailKey     NVARCHAR(10) DEFAULT('')     
      ,  Wavekey           NVARCHAR(10) DEFAULT('')     
      ,  Orderkey          NVARCHAR(10) DEFAULT('')    
      ,  Storerkey         NVARCHAR(15) DEFAULT('')    
      ,  Sku               NVARCHAR(20) DEFAULT('')    
      ,  UOM               NVARCHAR(10) DEFAULT('')    
      ,  Qty               INT          DEFAULT(0)    
      ,  CaseID            NVARCHAR(20) DEFAULT('')    
      ,  Lot               NVARCHAR(10) DEFAULT('')    
      ,  FromLoc           NVARCHAR(10) DEFAULT('')    
      ,  Logicallocation   NVARCHAR(10) DEFAULT('')    
      ,  ToLoc             NVARCHAR(10) DEFAULT('')    
      ,  ToLogicallocation NVARCHAR(10) DEFAULT('')     
      ,  PickZone          NVARCHAR(10) DEFAULT('')    
      ,  AreaKey           NVARCHAR(10) DEFAULT('')    
      ,  PickMethod        NVARCHAR(10) DEFAULT('')   
      ,  Score             NVARCHAR(10) DEFAULT('')   
      ,  RowRef            INT           DEFAULT(0)    
  
      )    
   
   INSERT INTO @t_ORDERS  
        ( Wavekey, Loadkey, Orderkey, Facility, Storerkey, DocType, Ecom_Single_Flag )  
   SELECT WD.Wavekey, OH.Loadkey, OH.Orderkey, OH.Facility, OH.Storerkey, OH.DocType, OH.ECOM_SINGLE_Flag  
   FROM WAVEDETAIL WD WITH (NOLOCK)  
   JOIN ORDERS OH WITH (NOLOCK) ON WD.Orderkey = OH.Orderkey  
   WHERE WD.Wavekey = @c_Wavekey 
   
   --(Wan03) - START
   SELECT TOP 1                              
            @c_Facility  = tor.Facility   
         ,  @c_Storerkey = tor.Storerkey
   FROM @t_ORDERS AS tor 
   
   SELECT @c_Release_Opt5 = ISNULL(fgr.Option5,'')
   FROM dbo.fnc_GetRight2( @c_Facility, @c_Storerkey, '', 'ReleaseWave_SP') AS fgr
   
   SET @c_TaskByWavePriority = 'N'
   SELECT @c_TaskByWavePriority = dbo.fnc_GetParamValueFromString('@c_TaskByWavePriority', @c_Release_Opt5, @c_TaskByWavePriority) 
   
   IF @c_TaskByWavePriority = 'Y'
   BEGIN
      SELECT @c_Priority_Wave = IIF(w.UserDefine09 <> '' AND w.UserDefine09 IS NOT NULL, w.UserDefine09, @c_Priority_Wave)
      FROM dbo.WAVE AS w (NOLOCK) 
      WHERE w.WaveKey = @c_Wavekey
   END
   --(Wan03) - END
   
   INSERT INTO #CPK_WIP    
      (  Orderkey            
      ,  Pickdetailkey       
      ,  Storerkey           
      ,  Sku                 
      ,  UOM                 
      ,  UOMQty              
      ,  Qty                 
      ,  Lot                 
      ,  Loc  
      ,  CaseID   
      ,  DropID  
      ,  PickLoc  
      ,  SkuGroup            
      ,  Style               
      ,  Color               
      ,  Size  
      ,  PickMethod  
      )          
   SELECT  
         p.Orderkey            
      ,  p.Pickdetailkey       
      ,  p.Storerkey           
      ,  p.Sku                 
      ,  p2.PackUOM3                 
      ,  p.UOMQty              
      ,  p.Qty                 
      ,  p.Lot  
      ,  p.Loc    
      ,  p.CaseID       
      ,  p.DropID                   
      ,  PickLoc    = CASE WHEN td2.TaskDetailKey IS NULL AND p.UOM IN ('2','6')  
                           THEN p.Loc   
                           WHEN td2.TaskDetailKey IS NULL AND p.UOM IN ('7') AND l.LocationType IN ( 'DPBULK' )           
                           THEN p.Loc     
                           WHEN td2.TaskDetailKey IS NULL AND p.UOM IN ('7') AND l.LocationType NOT IN ( 'DPBULK' )   -- When release, Stock sill in BULK  
                           THEN sul.Loc                                                          
                           ELSE td2.LogicalToLoc   
                           END   
      ,  s2.SkuGroup            
      ,  s2.Style               
      ,  s2.Color               
      ,  s2.Size   
      ,  PickMethod = CASE WHEN tor.DocType = 'N' THEN 'B2B'  
                           WHEN tor.DocType = 'E' AND tor.ECOM_Single_Flag = 'M' THEN 'B2C-Multis'  
                           WHEN tor.DocType = 'E' AND tor.ECOM_Single_Flag = 'S' THEN 'B2C-Single'   
                           END            
   FROM @t_ORDERS AS tor    
   JOIN dbo.PICKDETAIL AS p WITH (NOLOCK) ON p.Orderkey = tor.Orderkey    
   JOIN dbo.SKU AS s2 WITH (NOLOCK) ON s2.StorerKey = p.Storerkey AND s2.Sku = p.Sku  
   JOIN dbo.PACK AS p2 WITH (NOLOCK) ON p2.PackKey = s2.PackKey  
   JOIN dbo.LOC AS l WITH (NOLOCK) ON p.Loc = l.Loc  
   LEFT OUTER JOIN dbo.TaskDetail AS td2 WITH (NOLOCK) ON  td2.TaskDetailKey = p.TaskDetailKey  
                                                       AND td2.Caseid = p.DropID   
                                                       AND td2.TaskType = 'RPF'  
   LEFT OUTER JOIN dbo.SKUxLOC AS sul WITH (NOLOCK) ON sul.StorerKey = p.Storerkey AND sul.Sku = p.Sku   
                                                    AND sul.LocationType = 'PICK'    
   WHERE p.UOM IN ('2','6','7')   
   AND   p.Qty > 0   
   AND   p.[Status] < '5'   
   AND   p.CaseID <> p.DropID  
   ORDER BY tor.DocType  
         ,  tor.ECOM_Single_Flag  
         ,  s2.Style               
         ,  s2.Color               
         ,  s2.Size   
  
   UPDATE cw  
      SET cw.PickLogicalloc = l.LogicalLocation  
         ,cw.PickZone     = CASE WHEN l.LocationType = 'DPBULK' THEN l.PickZone ELSE l2.PickZone END                                         --(Wan02)
         ,cw.PickAreakey  = ISNULL(ad.Areakey,'')  
 --        ,cw.PackZone     = ISNULL(c.Short,'')  
 --        ,cw.PackStation  = CASE WHEN c.Short = cw.PickLoc THEN 1 ELSE 0 END                                                               --(Wan02)
   FROM @t_ORDERS AS tor          
   JOIN #CPK_WIP AS cw ON cw.Orderkey = tor.Orderkey  
   JOIN dbo.LOC AS l WITH (NOLOCK) ON cw.PickLoc = l.Loc  
   LEFT OUTER JOIN dbo.SKUxLOC AS sul WITH (NOLOCK) ON sul.StorerKey = cw.Storerkey AND sul.Sku = cw.Sku AND sul.LocationType = 'PICK'       --(Wan02)  
   LEFT OUTER JOIN dbo.LOC AS l2 WITH (NOLOCK) ON sul.Loc = l2.Loc AND l2.LocationType = 'DYNPPICK'                                          --(Wan02)
   LEFT OUTER JOIN dbo.AreaDetail AS ad WITH (NOLOCK) ON ad.PutawayZone = l.PickZone  
   --LEFT OUTER JOIN dbo.CODELKUP AS c WITH (NOLOCK) ON  c.LISTNAME  = 'ADPickZone'                                                          --(Wan02)
   --                                                AND c.Code      = l2.PickZone  
   --                                                AND c.Storerkey = cw.Storerkey  
   --                                                AND c.code2     = tor.DocType  
                                                   
   --(Wan02) - START
   UPDATE cw  
      SET cw.PackZone = ISNULL(c.Short,'')  
   FROM @t_ORDERS AS tor          
   JOIN #CPK_WIP AS cw ON cw.Orderkey = tor.Orderkey  
   LEFT OUTER JOIN dbo.CODELKUP AS c WITH (NOLOCK) ON  c.LISTNAME  = 'ADPickZone'  
                                                   AND c.Code      = cw.PickZone  
                                                   AND c.Storerkey = cw.Storerkey  
                                                   AND c.code2     = tor.DocType 
   --(Wan02) - END                                                
  
   UPDATE cw  
      SET cw.PackZone = l.PickZone   
  --      , cw.PackStation  = CASE WHEN cw.PickLoc = l.pickzone THEN 1 ELSE 0 END  
   FROM #CPK_WIP AS cw  
   JOIN dbo.PackTask AS pt WITH (NOLOCK) ON pt.Orderkey = cw.Orderkey AND pt.OrderMode LIKE 'M%'  
   JOIN dbo.DeviceProfile AS dp WITH (NOLOCK) ON  dp.DevicePosition = pt.DevicePosition 
                                              AND dp.Storerkey = cw.Storerkey                --Wan02
   JOIN dbo.LOC AS l WITH (NOLOCK) ON l.Loc = dp.Loc  
      
   IF EXISTS ( SELECT 1    
               FROM #CPK_WIP AS cw  
               WHERE cw.PickAreakey = ''  
                  )  
   BEGIN  
      SET @n_continue = 3      
      SET @n_Err = 66010    
      SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': AreaKey Not Found. Please make sure all pickzone loc has setup areakey. (ispRLWAV43_CPK)'     
      GOTO QUIT_SP   
   END    
  
   ;WITH CTN ( CaseID, PickLogicalLoc_Min ) AS  
   (  SELECT cw.CaseID, MIN(cw.PickLogicalloc)  
      FROM #CPK_WIP AS cw  
      GROUP BY cw.CaseID  
   )  
   UPDATE cw  
      SET cw.Score = PickLogicalLoc_Min  
   FROM #CPK_WIP AS cw  
   JOIN CTN AS C ON C.CaseID = cw.CaseID  
  
   INSERT INTO #CPK  
      (  
         Wavekey             
      ,  Orderkey            
      ,  Storerkey           
      ,  Sku                 
      ,  UOM                 
      ,  Qty                 
      ,  CaseID              
      ,  Lot                 
      ,  FromLoc             
      ,  Logicallocation     
      ,  ToLoc               
      ,  ToLogicallocation   
      ,  PickZone            
      ,  AreaKey             
      ,  PickMethod     
      ,  Score          
      ,  RowRef   
      )             
   SELECT   
         Wavekey= @c_Wavekey             
      ,  Orderkey = CASE WHEN cw.PickMethod = 'B2B' THEN cw.Orderkey ELSE '' END           
      ,  cw.Storerkey           
      ,  cw.Sku                 
      ,  cw.UOM                 
      ,  SUM(cw.Qty)   
      ,  cw.CaseID              
      ,  cw.Lot                 
      ,  cw.PickLoc             
      ,  cw.PickLogicalloc    
      ,  cw.PackZone              
      ,  cw.PackZone    
      ,  cw.PickZone            
      ,  cw.PickAreaKey             
      ,  cw.PickMethod   
      ,  cw.Score        
      ,  RowRef = MIN(cw.RowID)   
   FROM #CPK_WIP AS cw  
   JOIN dbo.LOC AS l WITH (NOLOCK) ON cw.PickLoc = l.Loc  
   WHERE l.LocationType IN ('DYNPPICK', 'DYNPICKP','DPBULK')  
   GROUP BY  
         CASE WHEN cw.PickMethod = 'B2B' THEN cw.Orderkey ELSE '' END              
      ,  cw.Storerkey           
      ,  cw.Sku                 
      ,  cw.UOM                 
      ,  cw.CaseID              
      ,  cw.Lot                 
      ,  cw.PickLoc             
      ,  cw.PickLogicalloc    
      ,  cw.PackZone              
      ,  cw.PickZone            
      ,  cw.PickAreaKey             
      ,  cw.PickMethod   
      ,  cw.Score    
   ORDER BY cw.PickMethod  
         ,  cw.PickZone   
         ,  cw.PickLogicalloc   
         
         
   --(Wan01) - START 
   SET @c_CaseID = ''
   ;WITH td AS
   (  SELECT cw.CaseID, Qty = SUM(cw.Qty)
      FROM #CPK_WIP AS cw 
      GROUP BY cw.CaseID
   )
   , pd AS
    ( SELECT p.CaseID, Qty = SUM(p.Qty)
      FROM WAVEDETAIL AS w WITH (NOLOCK) 
      JOIN PICKDETAIL AS p WITH (NOLOCK) ON p.OrderKey = w.OrderKey
      WHERE w.WaveKey = @c_Wavekey
      AND p.[Status] < '5'
      GROUP BY p.CaseID
   )
  
   SELECT TOP 1 @c_CaseID = RTRIM(pd.CaseID)
   FROM td 
   JOIN pd ON pd.CaseID = td.CaseID
   WHERE td.Qty <> pd.Qty
  
   IF @c_CaseID <> ''
   BEGIN  
      SET @n_continue = 3      
      SET @n_Err = 66015    
      SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Taskdetail Case Qty <> PickDetail Case Qty. CaseID: ' + @c_CaseID 
                   + '. Please make sure No Home Loc Changing during release Wave. (ispRLWAV43_CPK)'     
      GOTO QUIT_SP   
   END 
   --(Wan01) - END
  
   SET @n_Batch = 0  
   SELECT TOP 1 @n_Batch = c.RowID  
   FROM #CPK AS c   
   ORDER BY c.RowID DESC  
  
   SET @c_TaskDetailKey = ''    
   SET @b_success = 1      
   EXECUTE nspg_getkey      
           @KeyName   = 'TaskDetailKey'      
         , @fieldlength = 10         
         , @KeyString = @c_TaskDetailKey     OUTPUT      
         , @b_success   = @b_success         OUTPUT      
         , @n_err       = @n_err             OUTPUT      
         , @c_errmsg    = @c_errmsg          OUTPUT    
         , @n_Batch     = @n_Batch    
                     
   IF NOT @b_success = 1      
   BEGIN      
      SET @n_continue = 3    
      SET @n_Err = 66020    
      SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Get Batch TaskDetaikkey Fail. (ispRLWAV43_CPK)'     
      GOTO QUIT_SP      
   END      
    
   SET @n_TaskDetailkey = CONVERT(INT,@c_TaskDetailKey) - 1    
        
   ;WITH TASK ( RowID, Taskdetailkey ) AS   
   (  
      SELECT c.RowID    
           , Taskdetailkey = RIGHT('0000000000' + CONVERT( NVARCHAR(10), ROW_NUMBER() OVER (ORDER BY c.RowID) + @n_TaskDetailkey),10)    
      FROM #CPK AS c  
   )  
   UPDATE c     
      SET c.TaskDetailKey = t.Taskdetailkey    
   FROM #CPK AS c    
   JOIN TASK AS t ON t.RowID = c.RowID   
     
   SET @c_TaskStatus = '0'  
   IF EXISTS ( SELECT 1    
               FROM #CPK_WIP AS cw  
               JOIN dbo.LOC AS l ON l.Loc = cw.PickLoc  
               WHERE l.LocationType IN ('DYNPICKP', 'DYNPPICK', 'DPBULK')  
               AND cw.DropID <> ''   
            )    
   BEGIN     
      SET @c_TaskStatus = 'H'     
   END    
        
   INSERT INTO TASKDETAIL    
      (  TaskDetailKey    
      ,  TaskType    
      ,  Storerkey    
      ,  Sku    
      ,  Lot    
      ,  UOM    
      ,  UOMQty    
      ,  Qty    
      ,  FromLoc    
      ,  LogicalFromLoc    
      ,  FromID    
      ,  ToLoc    
      ,  LogicalToLoc    
      ,  ToID    
      ,  CaseID    
      ,  PickMethod    
      ,  [Status]    
      ,  [Priority]    
      ,  AreaKey    
      ,  SourceType    
      ,  Sourcekey     
      ,  Wavekey    
      ,  Orderkey    
      ,  Message01    
      )    
   SELECT c.TaskDetailkey    
         ,TaskType = CASE WHEN c.PickMethod = 'B2B' THEN 'CPK' ELSE 'ASTCPK' END --CR 2.2   
         ,c.Storerkey    
         ,c.Sku    
         ,c.Lot    
         ,c.UOM    
         ,c.Qty    
         ,c.Qty    
         ,c.FromLoc    
         ,c.Logicallocation    
         ,FromID = ''    
         ,c.ToLoc    
         ,c.ToLogicallocation    
         ,ToID = ''    
         ,c.CaseID    
         ,c.PickMethod    
         ,[Status] = @c_TaskStatus    
         ,[Priority] = @c_Priority_Wave               --(Wan03)   
         ,c.Areakey    
         ,SourceType = 'ispRLWAV43_CPK'    
         ,Sourcekey  = c.Wavekey    
         ,c.Wavekey    
         ,c.Orderkey    
         ,c.Score    
   FROM #CPK AS c   
   ORDER BY c.RowID    
  
   SET @n_err = @@ERROR      
   IF @n_err <> 0      
   BEGIN    
      SET @n_continue = 3      
      SET @n_Err = 66030    
      SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert Taskdetail Failed. (ispRLWAV43_CPK)'     
      GOTO QUIT_SP    
   END    
  
   ;WITH UPD_PD ( TaskDetailkey, PickDetailKey ) AS  
   (  
      SELECT   
         c.TaskDetailkey  
      ,  cw.PickDetailKey  
      FROM #CPK AS c  
      JOIN #CPK_WIP AS cw ON cw.CaseID = c.CaseID  
                         AND cw.Lot    = c.Lot  
                         AND cw.PickLoc= c.FromLoc  
      WHERE cw.DropID = ''                            --Only Pick From Home Loc does not have RPF and to stamp taskdetailkey  
   )  
   UPDATE p WITH (ROWLOCK)  
      SET p.TaskDetailKey = up.TaskDetailkey  
         ,p.TrafficCop = NULL  
         ,p.EditWho = SUSER_SNAME()  
         ,p.EditDate= GETDATE()  
   FROM UPD_PD AS up        
   JOIN dbo.PICKDETAIL AS p ON p.PickDetailKey = up.PickDetailKey  
   WHERE (p.TaskDetailKey = '' OR p.TaskDetailKey IS NULL)  
     
   SET @n_err = @@ERROR      
   IF @n_err <> 0      
   BEGIN    
      SET @n_continue = 3      
      SET @n_Err = 66040    
      SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update PICKDETAIL Failed. (ispRLWAV43_CPK)'     
      GOTO QUIT_SP    
   END    
    
QUIT_SP:  
   IF @n_Continue=3  -- Error Occured - Process And Return  
   BEGIN  
      SET @b_Success = 0  
      IF  @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt  
      BEGIN  
         ROLLBACK TRAN  
      END  
      ELSE  
      BEGIN  
         WHILE @@TRANCOUNT > @n_StartTCnt  
         BEGIN  
            COMMIT TRAN  
         END  
      END  
  
      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'ispRLWAV43_CPK'  
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012  
   END  
   ELSE  
   BEGIN  
      SET @b_Success = 1  
      WHILE @@TRANCOUNT > @n_StartTCnt  
      BEGIN  
         COMMIT TRAN  
      END  
   END  
END -- procedure  

GO
SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Stored Proc: ispRLWAV43_RPF                                          */  
/* Creation Date: 2021-07-19                                            */  
/* Copyright: LF Logistics                                              */  
/* Written by: WLChooi                                                  */  
/*                                                                      */  
/* Purpose: WMS-17299 - RG - Adidas Release Wave                        */  
/*        :                                                             */  
/* Called By:                                                           */  
/*          :                                                           */  
/* PVCS Version: 1.4                                                    */  
/*                                                                      */  
/* Version: 7.0                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date        Author   Ver   Purposes                                  */  
/* 2021-07-19  WLChooi  1.0   Created - DevOps Combine Script           */
/* 2021-11-08  Wan01    1.1   CR 2.8 Skip Gen Normal Repl Task          */
/* 2021-11-30  Wan02    1.2   WMS-17299 - CR 2.82.Normal repl Task      */
/*                            System Qty must be 0                      */
/* 2022-01-05  Wan03    1.2   WMS-17299 - CR 2.9. Revise Priority Values*/
/*                            for TM RPF Task. Additional validation to */
/*                            prompt HomeLoc Assignment                 */
/* 2022-04-26  Wan04    1.3   WMS-19522 - RG - Adidas SEA - Release Wave*/
/*                            on DP Loc Sequence                        */
/* 2022-07-27  CheeMun  1.3   JSM-68356 - Bug Fix&Skip UOM 2 DP checking*/ 
/* 2022-10-06  Wan05    1.4   WMS-20898 - THA-adidas-Assign Wave priority*/
/*                            to Taskdetail (RPF, RPT,CPK,ASTCPK)       */  
/* 2022-10-10  LZG      1.5   JSM-101260 - Fixed infinite looping       */
/*                            when no DP Loc is found (ZG01)            */
/* 2023-03-22  Calvin   1.6   JSM-137787 [VN ADIDAS] Update UCC Status to*/
/*                            3 for RPF Tasks without Pickdetail (CLVN01)*/
/************************************************************************/  
CREATE   PROC [dbo].[ispRLWAV43_RPF]  
        @c_wavekey      NVARCHAR(10)    
       ,@b_Success      INT            OUTPUT    
       ,@n_err          INT            OUTPUT    
       ,@c_errmsg       NVARCHAR(250)  OUTPUT    
       ,@b_debug        INT = 0          
AS  
BEGIN  
   SET NOCOUNT ON  
   SET ANSI_NULLS OFF  
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE    
           @n_StartTCnt       INT  
         , @n_Continue        INT   
  
         , @c_DispatchPiecePickMethod NVARCHAR(10)  
  
         , @c_Loadkey         NVARCHAR(10)  
         , @c_Orderkey        NVARCHAR(10)  
         , @c_Facility        NVARCHAR(5)  
         , @c_Storerkey       NVARCHAR(15)  
         , @c_Sku             NVARCHAR(20)  
         , @c_UOM             NVARCHAR(10)  
         , @c_Lot             NVARCHAR(10)   
         , @c_fromLoc         NVARCHAR(10)   
         , @c_ID              NVARCHAR(18)   
         , @n_UCCQty          INT  
         , @n_Qty             INT  
         , @c_PickMethod      NVARCHAR(2)   
         , @c_FromLocType     NVARCHAR(10)   
         , @c_ToLocType       NVARCHAR(10)   
         , @c_FromPAZone      NVARCHAR(10)  
     
         , @c_TaskDetailKey   NVARCHAR(10)  
         , @c_TaskType        NVARCHAR(10)  
         , @c_LogicalFromLoc  NVARCHAR(10)   
         , @c_LogicalToLoc    NVARCHAR(10)   
         , @c_ToLoc           NVARCHAR(10)     
         , @c_SourceType      NVARCHAR(30)  
         , @c_DropID          NVARCHAR(20)  
  
         , @c_PickDetailKey   NVARCHAR(10)  
         , @c_PickSlipNo      NVARCHAR(10)  
         , @c_Consigneekey    NVARCHAR(15)  
         , @c_Route           NVARCHAR(10)  
  
         , @n_RowRef             INT  
         , @c_LocationHandling   NVARCHAR(10)
         , @c_LocationType       NVARCHAR(10)
         , @c_LocationCategory   NVARCHAR(10)
  
         , @n_UCCWODPLoc         INT                         
         , @c_DPPPKZone          NVARCHAR(10)                
         , @c_UOM_Prev           NVARCHAR(10)                
  
         , @n_NoOfUCC_Replen     INT                         
         , @n_NoOfUCCToDP        INT                         
         , @n_TotalEmptyLoc      INT                         
         , @c_Lottable01         NVARCHAR(18)               
  
         , @CUR_UPDPM            CURSOR                      
           
         , @c_PreCTNLevel        CHAR(1)                     
         , @c_PackOrderkey       NVARCHAR(10)                
         , @c_Zone               NVARCHAR(10)                
  
         , @c_ExternOrderkey     NVARCHAR(50)                
  
         , @c_MinPalletCarton    NVARCHAR(30)                
         , @n_TotatCartonInID    INT                         
         , @n_MinPalletCarton    INT = 0                         
         , @n_NoOfUCCSku         INT                         
         , @n_UCCWOBULKDPLoc     INT = 0     
           
         , @n_CaseCnt            FLOAT = 0.00     
         , @c_Wavekey_PD         NVARCHAR(10) = ''
                                                  
         , @c_logicalloc         NVARCHAR(10) = ''
         , @c_logicallocStart    NVARCHAR(10) = ''
                                                  
         , @n_LocQty             INT          = 0  
         , @b_UpdMultiWave       BIT          = 0  
         , @b_DirectGenPickSlip  INT          = 0    
         , @c_TransitLoc         NVARCHAR(10)
         , @c_FinalLoc           NVARCHAR(10)
         , @c_FinalID            NVARCHAR(18)
         , @c_DocType            NVARCHAR(10) 
         , @c_AssignDPLoc        NVARCHAR(1)
         , @c_AreaKey            NVARCHAR(10) = ''
         , @c_Pickzones          NVARCHAR(4000)
         , @n_CountPickzone      INT
         , @c_ECSingleFlag       NVARCHAR(10) = ''
         , @n_CountOrderkey      INT
         , @c_ExistingTDKey      NVARCHAR(10) = ''
         
         , @c_Release_Opt5       NVARCHAR(4000) = ''           --Wan01
         , @c_SkipNormalReplTask NVARCHAR(1) = 'N'             --Wan01
         , @c_TaskPriorityDPP    NVARCHAR(10)= '5'             --Wan03
         , @c_TaskPriority       NVARCHAR(10)= '5'             --Wan03  
  
         , @c_Priority_Wave      NVARCHAR(10) = '5'            --(Wan04)         
         , @c_TaskByWavePriority NVARCHAR(10) = 'N'            --(Wan04)
         
   SET @n_StartTCnt = @@TRANCOUNT  
   SET @n_Continue = 1  
   SET @n_err      = 0  
   SET @c_errmsg   = ''   
  
   /*Remark:
   1.  PICKDETAIL.UOM = '2', DROPID = UCCNo, PickMethod = 'C' indicates 1 full UCCNo allocate for 1 orderkey          -------------> PackStation
   2.  PICKDETAIL.UOM = '6', DROPID = UCCNo, , PickMethod = 'C' indicates 1 full UCCNo allocate for multiple orderkey -------------> SortStation / DP Loc 
   3.  PICKDETAIL.UOM = '7', DROPID = UCCNo, PickMethod = 'C' indicates 1 UCCNo allocate for orderkey with residual qty in Home Location (Partial UCC)  ------------>
   4.  PICKDETAIL.UOM = '7', DROPID = '', PickMethod = putawayzone. UOM3PickMethod indicates allocate from home location ---------->
   */
   SET @c_Facility = ''  
   SELECT TOP 1 @c_Facility = OH.Facility  
               ,@c_Storerkey= OH.Storerkey           
   FROM WAVEDETAIL WD WITH (NOLOCK)  
   JOIN ORDERS OH WITH (NOLOCK) ON WD.Orderkey = OH.Orderkey  
   WHERE WD.Wavekey= @c_Wavekey  
   
   --(Wan01) - START
   SELECT @c_Release_Opt5 = ISNULL(fgr.Option5,'')
   FROM dbo.fnc_GetRight2( @c_Facility, @c_Storerkey, '', 'ReleaseWave_SP') AS fgr
   --(Wan01) - END
   
   --(Wan04) - START
   SET @c_TaskByWavePriority = 'N'
   SELECT @c_TaskByWavePriority = dbo.fnc_GetParamValueFromString('@c_TaskByWavePriority', @c_Release_Opt5, @c_TaskByWavePriority) 

   IF @c_TaskByWavePriority = 'Y'
   BEGIN
      SELECT @c_Priority_Wave = w.UserDefine09
      FROM dbo.WAVE AS w (NOLOCK) 
      WHERE w.WaveKey = @c_Wavekey
   END
   --(Wan04) - END
   
   DECLARE @t_UPDPICK TABLE  
   (  RowRef            INT   IDENTITY(1,1) PRIMARY KEY  
   ,  PickDetailKey     NVARCHAR(10)   NOT NULL DEFAULT ('')  
   ,  Loadkey           NVARCHAR(10)   NOT NULL DEFAULT ('')  
   ,  Orderkey          NVARCHAR(10)   NOT NULL DEFAULT ('')  
   ,  Consigneekey      NVARCHAR(15)   NOT NULL DEFAULT ('')  
   ,  [Route]           NVARCHAR(10)   NOT NULL DEFAULT ('')  
   ,  ExternOrderkey    NVARCHAR(50)   NOT NULL DEFAULT ('')  
   ,  Wavekey           NVARCHAR(10)   NOT NULL DEFAULT ('')    
   ,  Qty               INT            NOT NULL DEFAULT(0)                             
   )  
  
   DECLARE @t_DPRange TABLE  
   (  PickZone          NVARCHAR(10)   NOT NULL DEFAULT('') PRIMARY KEY  
   ,  LogicalLocStart   NVARCHAR(10)   NOT NULL DEFAULT('')  
   )  
  
   IF OBJECT_ID('tempdb..#TMP_LOC_DP','u') IS NOT NULL  
   BEGIN  
      DROP TABLE #TMP_LOC_DP;  
   END  
  
   CREATE TABLE #TMP_LOC_DP  
   (  
      Facility          NVARCHAR(5)    NOT NULL DEFAULT('')     
   ,  Loc               NVARCHAR(10)   NOT NULL Primary Key  
   ,  LocationType      NVARCHAR(10)   NOT NULL DEFAULT('')   
   ,  LocationHandling  NVARCHAR(10)   NOT NULL DEFAULT('')        
   ,  LocationCategory  NVARCHAR(10)   NOT NULL DEFAULT('')   
   ,  LogicalLocation   NVARCHAR(10)   NOT NULL DEFAULT('')               
   ,  PickZone          NVARCHAR(10)   NOT NULL DEFAULT('')  
   ,  MaxPallet         INT            NOT NULL DEFAULT(0)    
   )       
     
   IF OBJECT_ID('tempdb..#TMP_LOC_DPP','u') IS NOT NULL  
   BEGIN  
      DROP TABLE #TMP_LOC_DPP;  
   END  
  
   CREATE TABLE #TMP_LOC_DPP  
   (  
      Facility          NVARCHAR(5)    NOT NULL DEFAULT('')     
   ,  Loc               NVARCHAR(10)   NOT NULL Primary Key  
   ,  LocationType      NVARCHAR(10)   NOT NULL DEFAULT('')   
   ,  LocationHandling  NVARCHAR(10)   NOT NULL DEFAULT('')        
   ,  LocationCategory  NVARCHAR(10)   NOT NULL DEFAULT('')   
   ,  LogicalLocation   NVARCHAR(10)   NOT NULL DEFAULT('')               
   ,  PickZone          NVARCHAR(10)   NOT NULL DEFAULT('')  
   ,  MaxPallet         INT            NOT NULL DEFAULT(0)    
   )                 

   CREATE TABLE #TMP_PICK  
   (  RowRef            INT            NOT NULL IDENTITY(1,1)  PRIMARY KEY  
   ,  Facility          NVARCHAR(5)    NULL  
   ,  Storerkey         NVARCHAR(15)   NULL  
   ,  Sku               NVARCHAR(20)   NULL  
   ,  UOM               NVARCHAR(10)   NULL  
   ,  Lot               NVARCHAR(10)   NULL  
   ,  Loc               NVARCHAR(10)   NULL  
   ,  ID                NVARCHAR(18)   NULL  
   ,  DropID            NVARCHAR(20)   NULL  
   ,  UCCQty            INT            NULL  DEFAULT (0)  
   ,  Qty               INT            NULL  DEFAULT (0)  
   ,  PickMethod        NVARCHAR(10)   NULL  
   ,  LogicalFromLoc    NVARCHAR(10)   NULL  
   ,  FromLocType       NVARCHAR(10)   NULL  
   ,  FromPAZone        NVARCHAR(10)   NULL  
   ,  LocationHandling  NVARCHAR(10)   NULL      
   ,  LocationType      NVARCHAR(10)   NULL     
   ,  LocationCategory  NVARCHAR(10)   NULL  
   ,  ToLoc             NVARCHAR(10)   NULL  DEFAULT ('')  
   ,  Style             NVARCHAR(20)   NULL                         
   ,  Color             NVARCHAR(10)   NULL                         
   ,  Size              NVARCHAR(10)   NULL                         
   ,  Lottable01        NVARCHAR(18)   NULL   
   ,  TaskDetailKey     NVARCHAR(10)   NULL                
   ,  DocType           NVARCHAR(10)   NULL 
   ,  ECSingleFlag      NVARCHAR(10)   NULL
   ,  ExistingTDKey     NVARCHAR(10)   NULL 
   )  
  
   ------------------------------------------------------------------------------------  
   -- Getting PIckDetail for Release  
   ------------------------------------------------------------------------------------  
   INSERT INTO #TMP_PICK  
      (  Facility  
      ,  Storerkey  
      ,  Sku  
      ,  UOM  
      ,  Lot  
      ,  Loc  
      ,  ID  
      ,  DropID  
      ,  UCCQty  
      ,  Qty   
      ,  PickMethod    
      ,  LogicalFromLoc    
      ,  FromLocType   
      ,  FromPAZone    
      ,  LocationHandling    
      ,  LocationType        
      ,  LocationCategory  
      ,  Style               
      ,  Color              
      ,  Size    
      ,  Lottable01  
      ,  TaskDetailKey   
      ,  DocType  
      ,  ECSingleFlag
      ,  ExistingTDKey
      )  
   SELECT LOC.Facility  
         ,PD.Storerkey  
         ,PD.Sku  
         ,PD.UOM  
         ,PD.Lot  
         ,PD.Loc  
         ,PD.ID  
         ,PD.DropID  
         ,UCCQty = ISNULL(UCC.Qty,0)  
         ,SUM(PD.Qty)    
         ,PickMethod  = CASE WHEN MIN(PD.PickMethod) = 'P' THEN 'FP'   
                             ELSE 'PP' END  
         ,LogicalFromLoc   = ISNULL(RTRIM(LOC.LogicalLocation),'')  
         ,FromLocType = CASE WHEN LOC.LocationType     <> 'DYNPPICK'   
                              AND LOC.LocationCategory <> 'SHELVING'   
                              AND SxL.LocationType NOT IN ('PICK','CASE')   
                              THEN 'BULK'   
                              ELSE 'DPP' END  
         ,FromPAZone       = ISNULL(RTRIM(LOC.PutawayZone),'')  
         ,LocationHandling = ISNULL(RTRIM(LOC.LocationHandling),'')  
         ,LocationType     = ISNULL(RTRIM(LOC.LocationType),'')  
         ,LocationCategory = ISNULL(RTRIM(LOC.LocationCategory),'')  
         ,Style = CASE WHEN PD.UOM = '6' AND PD.DropID <> ''                                      
                  THEN ISNULL(RTRIM(SKU.Style),'')                              
                  ELSE '' END                                                               
         ,Color = CASE WHEN PD.UOM = '6' AND PD.DropID <> ''                                     
                  THEN ISNULL(RTRIM(SKU.Color),'')                              
                  ELSE '' END                                                   
         ,Size  = CASE WHEN PD.UOM = '6' AND PD.DropID <> ''                                    
                  THEN ISNULL(RTRIM(SKU.Size),'')                               
                  ELSE '' END                                                   
         ,Lottable01 = ISNULL(RTRIM(LA.Lottable01),'')    
         ,TaskDetailKey = ISNULL(RTRIM(TD.TaskDetailkey),'')  
         ,OH.DocType
         ,CASE WHEN PD.UOM IN ('2', '6') THEN OH.ECOM_SINGLE_Flag ELSE '' END AS ECSingleFlag
         ,ExistingTDKey = ISNULL(RTRIM(TD1.TaskDetailkey),'') 
   FROM   WAVEDETAIL WD    WITH (NOLOCK)   
   JOIN   PICKDETAIL PD    WITH (NOLOCK) ON (WD.Orderkey = PD.Orderkey) 
   JOIN   ORDERS     OH    WITH (NOLOCK) ON OH.OrderKey = WD.OrderKey   
   JOIN   LOTATTRIBUTE LA  WITH (NOLOCK) ON (PD.Lot = LA.Lot)                   
   JOIN   LOC        LOC   WITH (NOLOCK) ON (PD.Loc = LOC.Loc)  
   JOIN   SKUxLOC    SxL   WITH (NOLOCK) ON (PD.Storerkey = SxL.Storerkey)  
                                         AND(PD.Sku = SxL.Sku)   
                                         AND(PD.Loc = SxL.Loc)  
   JOIN   SKU        SKU   WITH (NOLOCK) ON (PD.Storerkey = SKU.Storerkey)      
                                         AND(PD.Sku = SKU.Sku)                                         
   LEFT JOIN UCC     UCC   WITH (NOLOCK) ON (PD.DropID = UCC.UCCNo)  
                                         AND(UCC.Storerkey = OH.Storerkey)          
                                         AND(UCC.UCCNo <> '')
                                         AND(UCC.[Status] = '3')    
                                         AND(UCC.LOT = PD.LOT AND UCC.LOC = PD.LOC AND UCC.ID = PD.ID)               
   LEFT JOIN TASKDETAIL TD WITH (NOLOCK) ON (PD.TaskDetailkey = TD.TaskdetailKey)  
                                         AND(TD.Taskdetailkey <> '')               
                                         AND(TD.[Status] <> 'X')   
   LEFT JOIN TASKDETAIL TD1 WITH (NOLOCK) ON (PD.DropID = TD1.Caseid)  
                                          AND(TD1.Taskdetailkey <> '')               
                                          AND(TD1.[Status] <> 'X')
                                          AND(TD1.Storerkey = PD.Storerkey)
                                          AND(TD1.SKU = PD.SKU)
   WHERE  WD.Wavekey = @c_Wavekey                                      
   GROUP BY LOC.Facility  
         ,  PD.Storerkey  
         ,  PD.Sku  
         ,  PD.UOM  
         ,  PD.Lot  
         ,  PD.Loc  
         ,  PD.ID  
         ,  PD.DropID  
         ,  ISNULL(UCC.Qty,0)  
         ,  ISNULL(RTRIM(LOC.LogicalLocation),'')  
         ,  CASE WHEN LOC.LocationType <> 'DYNPPICK'   
                  AND LOC.LocationCategory <> 'SHELVING'   
                  AND SxL.LocationType NOT IN ('PICK','CASE')   
                  THEN 'BULK'   
                  ELSE 'DPP' END  
         ,  ISNULL(RTRIM(LOC.PutawayZone),'')  
         ,  ISNULL(RTRIM(LOC.LocationHandling),'')  
         ,  ISNULL(RTRIM(LOC.LocationType),'')  
         ,  ISNULL(RTRIM(LOC.LocationCategory),'')  
         ,  CASE WHEN PD.UOM = '6' AND PD.DropID <> ''                                          
                 THEN ISNULL(RTRIM(SKU.Style),'')                               
                 ELSE '' END                                                    
         ,  CASE WHEN PD.UOM = '6' AND PD.DropID <> ''                                           
                 THEN ISNULL(RTRIM(SKU.Color),'')                               
                 ELSE '' END                                                    
         ,  CASE WHEN PD.UOM = '6' AND PD.DropID <> ''                                           
                 THEN ISNULL(RTRIM(SKU.Size),'')                                
                 ELSE '' END                                                    
         ,  ISNULL(RTRIM(LA.Lottable01),'')   
         ,  ISNULL(RTRIM(TD.TaskDetailkey),'')
         ,  OH.DocType
         ,  CASE WHEN PD.UOM IN ('2', '6') THEN OH.ECOM_SINGLE_Flag ELSE '' END            
         ,  ISNULL(RTRIM(TD1.TaskDetailkey),'')                         
   ORDER BY PD.UOM  
         ,  LocationType
         ,  CASE WHEN PD.UOM = '6' AND PD.DropID <> '' THEN '' ELSE PD.Loc END                      
         ,  PD.Storerkey  
         ,  PD.Sku  
         ,  Style                                                               
         ,  Color                                                               
         ,  Size                                                                
         ,  Lottable01      
           
   --IF NOT EXISTS ( SELECT 1 FROM #TMP_PICK TP WITH (NOLOCK)   
   --              )  
   --BEGIN  
   --   SET @n_Continue = 3  
   --   SET @n_Err = 81033  
   --   SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': No Allocated Pick record found to release.  (ispRLWAV43_RPF)'  
   --   GOTO QUIT_SP  
   --END        

   IF EXISTS ( SELECT 1  
               FROM #TMP_PICK TP  
               JOIN LOC L (NOLOCK) ON TP.Loc = L.Loc  
               LEFT JOIN AREADETAIL AD WITH (NOLOCK) ON L.PickZone = AD.PutawayZone  
               WHERE AD.Areakey IS NULL  
               )  
   BEGIN  
      SET @n_continue = 3    
      SET @n_Err = 81216  
      SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Missing Loc areakey. (ispRLWAV43_RPF)'   
      GOTO QUIT_SP  
   END  

   ------------------------------------------------------------------------------------  
   -- Pre-requisite for DP Loc Assignment
   ------------------------------------------------------------------------------------  
   IF EXISTS ( SELECT 1 FROM #TMP_PICK TP WITH (NOLOCK)   
               WHERE UOM IN ('2','6')
             )  
   BEGIN  
      INSERT INTO #TMP_LOC_DP  
         (  
         Facility  
      ,  Loc     
      ,  LocationType  
      ,  LocationHandling             
      ,  LocationCategory   
      ,  LogicalLocation                     
      ,  PickZone  
      ,  MaxPallet  
      )   
      SELECT  
         Facility  
      ,  Loc     
      ,  LocationType  
      ,  LocationHandling             
      ,  LocationCategory   
      ,  LogicalLocation                    
      ,  PickZone  
      ,  MaxPallet  
      FROM LOC WITH (NOLOCK)  
      WHERE Facility = @c_Facility  
      AND LocationType = 'DYNPICKP'  
   END  
  
   IF EXISTS (  SELECT 1 FROM #TMP_PICK TP WITH (NOLOCK)   
               WHERE UOM IN ('2', '6', '7') AND FromLocType <> 'DPP'  
            )  
   BEGIN  
       INSERT INTO #TMP_LOC_DPP  
      (  
         Facility  
      ,  Loc     
      ,  LocationType  
      ,  LocationHandling             
      ,  LocationCategory   
      ,  LogicalLocation                     
      ,  PickZone  
      ,  MaxPallet  
      )   
      SELECT  
         Facility  
      ,  Loc     
      ,  LocationType  
      ,  LocationHandling             
      ,  LocationCategory   
      ,  LogicalLocation                    
      ,  PickZone  
      ,  MaxPallet  
      FROM LOC WITH (NOLOCK)  
      WHERE Facility = @c_Facility  
      AND LocationType = 'DYNPPICK'  
   END  

   SET @n_NoOfUCCToDP = 0  
   --JSM-68356 (START) 
   SELECT @n_NoOfUCCToDP = COUNT(DISTINCT PCK.NoOfUCCToDP)   
   FROM (
      SELECT NoOfUCCToDP = TP.DropID   
      FROM #TMP_PICK TP WITH (NOLOCK)     
      WHERE TP.UOM  = '6'  
      --AND   TP.ECSingleFlag = 'M'  
      AND Doctype = 'N'
      AND   TP.DropID <> '' 
      GROUP BY TP.DropID
      UNION
      SELECT TP.DropID      
      FROM #TMP_PICK TP WITH (NOLOCK)      
      JOIN dbo.PICKDETAIL p WITH (NOLOCK) ON p.Storerkey = TP.Storerkey AND p.DropID = TP.DropID      
      JOIN dbo.WAVEDETAIL AS w WITH (NOLOCK) ON p.Orderkey = w.OrderKey      
      JOIN dbo.PackTask AS PT WITH (NOLOCK) ON w.orderkey = PT.orderkey      
      JOIN DeviceProfile DP (NOLOCK) ON DP.DevicePosition = PT.DevicePosition      
      JOIN LOC L (NOLOCK) ON L.LOC = DP.Loc      
      WHERE TP.UOM = '6'      
      AND TP.ECSingleFlag = 'M'      
      AND TP.DropID <> ''      
      AND p.[Status] < '5'      
      AND w.WaveKey = @c_Wavekey  
      GROUP BY TP.DropID
      HAVING COUNT(DISTINCT l.PickZone) > 1
   ) PCK
   --JSM-68356 (END)    
   
   SET @n_TotalEmptyLoc = 0      
   SELECT @n_TotalEmptyLoc = ISNULL(SUM(DP.EmptyLoc),0)      
   FROM (      
      SELECT EmptyLoc = (1 * Loc.MaxPallet)      
      FROM #TMP_LOC_DP LOC WITH (NOLOCK)        
      LEFT JOIN  LOTxLOCxID LLI WITH (NOLOCK)  ON (LLI.Loc = LOC.Loc AND  LLI.Storerkey = @c_Storerkey  )                                         
      WHERE   LOC.Facility = @c_Facility         
      GROUP BY LOC.Facility, LOC.Loc, Loc.MaxPallet       
      HAVING CASE WHEN ISNULL(SUM((LLI.Qty - LLi.QtyPicked) + LLI.PendingMoveIN),0) = 0 THEN 0      
                              ELSE COUNT(1)      
                              END  = 0                   
      
      ) DP                    
  
   IF @n_NoOfUCCToDP > @n_TotalEmptyLoc  
   BEGIN  
      SET @n_Continue = 3  
      SET @n_Err = 81035  
      SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Not enough DP Location. '  
                     +'No of UCC:' + CONVERT(NVARCHAR(5),@n_NoOfUCCToDP - @n_TotalEmptyLoc) + ' still need(s) DP Loc (ispRLWAV43_RPF)'  
      GOTO QUIT_SP  
   END    
    
   --(Wan03) -- START
   SET @c_TaskPriorityDPP = '5'
   SELECT @c_TaskPriorityDPP = dbo.fnc_GetParamValueFromString('@c_DPPTaskPriority', @c_Release_Opt5, @c_TaskPriorityDPP) 
   --(Wan03) -- END 
   ------------------------------------------------------------------------------------  
   -- Calculate To Loc  
   ------------------------------------------------------------------------------------  
   DECLARE CUR_PD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
   SELECT RowRef  
       ,  Facility  
       ,  Storerkey  
       ,  Sku  
       ,  UOM  
       ,  Lot  
       ,  Loc  
       ,  ID  
       ,  DropID  
       ,  UCCQty  
       ,  Qty   
       ,  PickMethod   
       ,  FromPAZone   
       ,  LogicalFromLoc                                                        
       ,  FromLocType                                                           
       ,  Lottable01    
       ,  TaskDetailkey                              
       ,  DocType   
       ,  ECSingleFlag  
       ,  ExistingTDKey                
   FROM #TMP_PICK                                                              
   ORDER BY RowRef  
     
   OPEN CUR_PD  
     
   FETCH NEXT FROM CUR_PD INTO  @n_RowRef  
                              , @c_Facility  
                              , @c_Storerkey  
                              , @c_Sku  
                              , @c_UOM  
                              , @c_Lot  
                              , @c_FromLoc  
                              , @c_ID  
                              , @c_DropID  
                              , @n_UCCQty  
                              , @n_Qty  
                              , @c_PickMethod  
                              , @c_FromPAZone  
                              , @c_LogicalFromLoc                               
                              , @c_FromLocType                                  
                              , @c_Lottable01   
                              , @c_TaskDetailkey     
                              , @c_DocType    
                              , @c_ECSingleFlag      
                              , @c_ExistingTDKey          
  
   WHILE @@FETCH_STATUS <> -1  
   BEGIN  
  
      SET @c_ToLoc = ''  
      SET @c_ToLocType = ''  
      SET @b_UpdMultiWave = 0
      SET @b_DirectGenPickSlip = 0    

      --If FromLocType is DPP, skip
      IF @c_FromLocType = 'DPP'  
      BEGIN  
         GOTO NEXT_LOOP
      END  

      IF @c_UOM IN ('2', '6', '7') AND @c_DropID <> ''
      BEGIN
         --Full UCC allocated for B2C Singles or allocated for single B2B order 
         --PICKDETAIL.UOM = '2', DROPID = UCCNo, PickMethod = 'C' indicates 1 full UCCNo allocate for 1 orderkey -------------> PackStation
         --PICKDETAIL.UOM = '6', DROPID = UCCNo, PickMethod = 'C' indicates 1 full UCCNo allocate for multiple orderkey
         --Or cater for B2C - 1 UCC 1 Order (eg. Golf Kit)
         --Multi & Single order may allocate UOM = '2' 
         SET @c_LocationHandling  = '3'
  
         IF @c_UOM IN ('2', '6') AND @c_DropID <> ''
         BEGIN  
            SELECT @n_CountOrderkey = COUNT(DISTINCT PD.Orderkey)
            FROM PICKDETAIL PD (NOLOCK)
            JOIN WAVEDETAIL WD (NOLOCK) ON WD.OrderKey = PD.OrderKey
            WHERE WD.WaveKey = @c_wavekey
            AND PD.DropID = @c_DropID   --UCC
            AND PD.StorerKey = @c_Storerkey

            --If Full UCC allocated for B2C Singles or allocated for single B2B order in wave, direct replenish to Pack Station
            --IF ((@c_DocType = 'E' AND @c_ECSingleFlag = 'S') OR @c_DocType = 'N') AND (@n_UCCQty = @n_Qty)
            IF (@c_DocType = 'E' AND @c_ECSingleFlag = 'S' AND @n_UCCQty = @n_Qty) OR (@c_DocType = 'N' AND @c_UOM = '2')  
            BEGIN
               SET @c_DPPPKZone = ''  
               SELECT TOP 1 @c_DPPPKZone = LOC.PickZone  
               FROM SKUxLOC WITH (NOLOCK)  
               JOIN LOC     WITH (NOLOCK) ON (SKUxLOC.Loc = LOC.Loc)  
               WHERE SKUxLOC.Storerkey= @c_Storerkey  
               AND   SKUxLOC.Sku      = @c_Sku  
               AND   SKUxLOC.LocationType = 'PICK'    --Home Location  
               AND   LOC.Facility     = @c_Facility  
               ORDER BY LOC.LogicalLocation  
                     ,  LOC.Loc  
               
               SELECT @c_ToLoc = ISNULL(RTRIM(Short),'')  
               FROM CODELKUP WITH (NOLOCK)    
               WHERE ListName = 'ADPICKZONE'  
               AND   Code = @c_DPPPKZone                                              
               AND   Code2= @c_DocType                                
               AND   Storerkey = @c_Storerkey  
               
               SET @c_ToLocType = 'PS'  -- Pack Station  
               
               GOTO ADD_TASK  
            END
            --If Full UCC allocated for B2C Multis with allocated orders assigned to single sort station, direct replenish to Sort Station
            --For UCC allocated for B2C Multis with allocated orders assigned to multiple sort station group ID or allocated for multiple B2B orders per wave, direct replenish to Dynamic Pick (DP) Location
            ELSE IF (@c_DocType = 'E' AND @c_ECSingleFlag = 'M') OR (@c_DocType = 'N' AND @n_CountOrderkey > 1 AND @c_UOM = '6')
            BEGIN
               SELECT @c_Pickzones = STUFF((SELECT DISTINCT ',' + L.PickZone
               FROM PICKDETAIL PD (NOLOCK)
               JOIN WAVEDETAIL WD (NOLOCK) ON WD.OrderKey = PD.OrderKey
               JOIN PACKTASK PT (NOLOCK) ON PT.Orderkey = WD.OrderKey
               JOIN DeviceProfile DP (NOLOCK) ON DP.DevicePosition = PT.DevicePosition
               JOIN LOC L (NOLOCK) ON L.LOC = DP.Loc
               WHERE WD.WaveKey = @c_wavekey
               AND PD.UOM IN ('2', '6')
               AND PD.DropID = @c_DropID   --UCC
               AND DP.StorerKey = @c_Storerkey
               AND L.LocationCategory = 'PTL'  
               AND L.LocationType= 'OTHER'          
               AND L.LocationFlag = 'HOLD' 
               ORDER BY 1 FOR XML PATH('')),1,1,'' )
               
               SELECT @n_CountPickzone = COUNT(DISTINCT [Value]) FROM STRING_SPLIT(@c_Pickzones, ',')
               
               --If Full UCC allocated for B2C Multis with allocated orders assigned to single sort station, direct replenish to Sort Station   ---> @c_CountPickzone = 1
               IF (@n_CountPickzone = 1 AND @c_DocType = 'E')
               BEGIN
                  SET @c_ToLocType = 'ST'  -- Sort Station
                  SET @c_ToLoc = @c_Pickzones
                  GOTO ADD_TASK  
               END
               ELSE   --For UCC allocated for B2C Multis with allocated orders assigned to multiple sort station group ID or allocated for multiple B2B orders per wave, direct replenish to Dynamic Pick (DP) Location
               BEGIN
                  FIND_DP:  
                  SET @c_LocationCategory = 'SHELVING'  
                  SET @n_NoOfUCCSku      = 0  
                  SET @n_TotatCartoninID = 0  

                  --SELECT @n_TotatCartoninID = COUNT(DISTINCT PD.DropID)  
                  --      ,@n_NoOfUCCSku = COUNT(DISTINCT UCC.Sku)  
                  --FROM WAVEDETAIL   WD  WITH (NOLOCK)  
                  --JOIN PICKDETAIL   PD  WITH (NOLOCK) ON (WD.Orderkey = PD.Orderkey)  
                  --JOIN UCC          UCC WITH (NOLOCK) ON (PD.DropID = UCC.UCCNo)  
                  --                          AND(UCC.Status > '1' AND UCC.Status < '6')  
                  --WHERE WD.Wavekey  = @c_Wavekey  
                  --AND   PD.UOM      = '6'  
                  --AND   PD.DropID   <>''  
                  --AND   PD.Status   < '5'  
                  --AND   PD.ID       = @c_ID  
                  --AND   PD.Storerkey= @c_Storerkey  
                  --AND   PD.Sku      = @c_Sku  
               
                  --IF @n_NoOfUCCSku = 1
                  --BEGIN  
                  --   SET @c_LocationCategory = 'BULK'  
                  --END  
               
                  IF @c_LocationCategory = 'SHELVING'  
                  BEGIN  
                     SELECT TOP 1 @c_ToLoc = ISNULL(RTRIM(TD.ToLoc),'')          
                     FROM #TMP_LOC_DP  LOC WITH (NOLOCK)                         
                     JOIN TASKDETAIL   TD  WITH (NOLOCK) ON (LOC.Loc = TD.ToLoc) 
                     JOIN LOTATTRIBUTE LA  WITH (NOLOCK) ON (TD.Lot = LA.Lot)  
                     WHERE LOC.LocationType = 'DYNPICKP'  
                     AND   LOC.LocationHandling = @c_LocationHandling    
                     AND   LOC.LocationCategory = @c_LocationCategory                                
                     AND   LOC.Facility = @c_Facility  
                     AND   TD.TaskType IN ('RPF','RP1','RPT')  
                     AND   TD.UOM       IN ('2', '6') 
                     AND   TD.CaseID    <>''  
                     AND   TD.Status    < '9'  
                     AND   TD.SourceType like 'ispRLWAV43_RPF-%'  
                     AND   TD.Wavekey  = @c_Wavekey  
                     AND   TD.Storerkey= @c_Storerkey  
                     AND EXISTS (SELECT 1     
                                 FROM SKUxLOC SL WITH (NOLOCK)    
                                 JOIN LOC L WITH (NOLOCK) ON SL.loc = L.Loc      
                                 WHERE SL.Storerkey =  @c_Storerkey    
                                 AND   SL.Sku =  @c_Sku       
                                 AND   SL.locationType = 'PICK'      
                                 AND   L.LocationType = 'DYNPPICK'      
                                 AND   L.PickZone = LOC.PickZone    
                                 AND   L.LocationHandling = @c_LocationHandling  
                                 )                   
                     GROUP BY TD.Storerkey                                 
                           ,  TD.ToLoc  
                           ,  ISNULL(LOC.MaxPallet,0)  
                     HAVING ISNULL(LOC.MaxPallet,0) > ISNULL(COUNT( DISTINCT TD.CaseID),0)  
                  END  
                  ELSE  
                  BEGIN  
                     SELECT TOP 1 @c_ToLoc = ISNULL(RTRIM(TD.ToLoc),'')  
                     FROM #TMP_LOC_DP  LOC WITH (NOLOCK)
                     JOIN TASKDETAIL   TD  WITH (NOLOCK) ON (LOC.Loc = TD.ToLoc)  
                     JOIN LOTATTRIBUTE LA  WITH (NOLOCK) ON (TD.Lot = LA.Lot)  
                     WHERE LOC.LocationType = 'DYNPICKP'  
                     AND   LOC.LocationHandling = @c_LocationHandling    
                     AND   LOC.LocationCategory = @c_LocationCategory                                                
                     AND   LOC.Facility = @c_Facility  
                     AND   TD.TaskType IN ('RPF','RP1','RPT')  
                     AND   TD.UOM       IN ('2', '6')  
                     AND   TD.CaseID    <>''  
                     AND   TD.Status    < '9'  
                     AND   TD.FromID    = @c_ID  
                     AND   TD.SourceType LIKE 'ispRLWAV43_RPF-%'  
                     AND   TD.Wavekey  = @c_Wavekey  
                     AND   TD.Storerkey= @c_Storerkey  
                  END  
               
                  IF @c_ToLoc = ''  
                  BEGIN   
                     GET_EMPTY_DP:  
               
                     SET @c_DPPPKZone = ''  

                     DECLARE CUR_DPP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
                     SELECT DPPPKZone = LOC.PickZone  
                     FROM SKUxLOC WITH (NOLOCK)  
                     JOIN #TMP_LOC_DPP  LOC WITH (NOLOCK) ON (SKUxLOC.Loc = LOC.Loc)
                     WHERE SKUxLOC.Storerkey= @c_Storerkey  
                     AND   SKUxLOC.Sku      = @c_Sku  
                     AND   SKUxLOC.LocationType = 'PICK'                              
                     AND   LOC.LocationType = 'DYNPPICK'  
                     AND   LOC.Facility     = @c_Facility  
                     AND   LOC.LocationHandling = @c_LocationHandling
                     GROUP BY LOC.PickZone                                           
                           ,  LOC.LocationHandling                                    
                           ,  LOC.LogicalLocation                                    
                           ,  LOC.Loc                                                
                     ORDER BY LOC.LocationHandling DESC                              
                           ,  LOC.LogicalLocation  
                           ,  LOC.Loc  
               
                     OPEN CUR_DPP  
               
                     FETCH NEXT FROM CUR_DPP INTO @c_DPPPKZone  
                     WHILE @@FETCH_STATUS <> -1 AND @c_ToLoc = ''  
                     BEGIN 
                        --(Wan04) - START
                        IF EXISTS ( SELECT 1        
                                    FROM CODELKUP CL WITH (NOLOCK)           
                                    WHERE CL.ListName = 'ADPHLDPLoc'          
                                    AND   CL.Code = @c_DPPPKZone          
                                    AND   CL.Storerkey = @c_Storerkey
                                    AND   CL.Short = 'N'
                                  )    
                        BEGIN
                           SET @c_ToLoc = ''
                           SET @c_Logicalloc = ''
                           SELECT TOP 1   @c_ToLoc = LOC.Loc  
                                       ,  @c_Logicalloc = LOC.LogicalLocation                                                
                           FROM  #TMP_LOC_DP  LOC WITH (NOLOCK)  
                           LEFT JOIN  LOTxLOCxID LLI WITH (NOLOCK) ON (LLI.Loc = LOC.Loc AND  LLI.Storerkey = @c_Storerkey)                        
                           WHERE LOC.LocationType = 'DYNPICKP'  
                           AND   LOC.LocationHandling = @c_LocationHandling                    
                           AND   LOC.LocationCategory = @c_LocationCategory
                           AND   LOC.Facility = @c_Facility   
                           AND   LOC.PickZone = @c_DPPPKZone  
                           GROUP BY LOC.LogicalLocation, LOC.Loc 
                           HAVING ISNULL(SUM((LLI.Qty - LLi.QtyPicked) + LLI.PendingMoveIN),0) = 0                          
                           ORDER BY LOC.LogicalLocation  
                                   ,LOC.Loc  
                                   
                           -- ZG01 (START)
                           IF @c_ToLoc <> ''  
                              BREAK 
                              
                           GOTO NEXT_DPPPKZone
                           -- ZG01 (END)
                        END 
                        --(Wan04) - END
                        
                        -- Find Last Logical location in DP that has stock  
                        IF NOT EXISTS (SELECT 1 FROM @t_DPRange WHERE PickZone = @c_DPPPKZone)  
                        BEGIN  
                           SET @c_logicalloc = ''           
                           SELECT TOP 1 @c_logicalloc = ISNULL(UDF01,'')          
                           FROM CODELKUP CL WITH (NOLOCK)           
                           WHERE CL.ListName = 'ADPHLDPLoc'          
                           AND   CL.Code = @c_DPPPKZone          
                           AND   CL.Storerkey = @c_Storerkey          
                
                           IF @c_logicalloc = ''          
                           BEGIN          
                              SET @c_logicalloc = ''          
                              SELECT DISTINCT TOP 1 @c_logicalloc = LOC.LogicalLocation          
                              FROM  #TMP_LOC_DP LOC WITH (NOLOCK)          
                              JOIN  LOTxLOCxID LLI WITH (NOLOCK)  ON (LLI.Loc = LOC.Loc AND  LLI.Storerkey = @c_Storerkey)                               
                              WHERE LOC.LocationType = 'DYNPICKP'          
                              AND   LOC.LocationHandling = @c_LocationHandling                            
                              AND   LOC.LocationCategory = @c_LocationCategory                             
                              AND   LOC.Facility = @c_Facility           
                              AND   LOC.PickZone = @c_DPPPKZone          
                              AND   (LLI.Qty - LLi.QtyPicked) + LLI.PendingMoveIN > 0          
                              ORDER BY LOC.LogicalLocation DESC          
                           END              
               
                           INSERT INTO @t_DPRange (PickZone, LogicalLocStart)  
                           VALUES (@c_DPPPKZone, @c_logicalloc)  
                        END  
                          
                        GET_PICKZONE_DP:                                                                                  
                        SET @n_LocQty = 0                                                                                 
                        SET @c_Logicalloc = ''                                                           
                        SET @c_LogicalLocStart = ''                                                                       
                        SELECT TOP 1   @c_ToLoc = LOC.Loc  
                                    ,  @c_Logicalloc = LOC.LogicalLocation                                                
                                    ,  @c_LogicalLocStart = LR.LogicalLocStart                                            
                                    ,  @n_LocQty = ISNULL(SUM((LLI.Qty - LLi.QtyPicked) + LLI.PendingMoveIN),0) 
                        FROM  #TMP_LOC_DP  LOC WITH (NOLOCK)  
                        JOIN  @t_DPRange   LR  ON (LOC.PickZone = LR.PickZone)                                                
                        LEFT JOIN  LOTxLOCxID LLI WITH (NOLOCK) ON (LLI.Loc = LOC.Loc AND  LLI.Storerkey = @c_Storerkey)                        
                        WHERE LOC.LocationType = 'DYNPICKP'  
                        AND   LOC.LocationHandling = @c_LocationHandling                    
                        AND   LOC.LocationCategory = @c_LocationCategory
                        AND   LOC.Facility = @c_Facility   
                        AND   LOC.PickZone = @c_DPPPKZone  
                        AND LOC.LogicalLocation > LR.LogicalLocStart   
                        GROUP BY LOC.LogicalLocation, LOC.Loc, LR.LogicalLocStart                              
                        ORDER BY LOC.LogicalLocation  
                                ,LOC.Loc  
               
                        IF @c_Toloc = '' AND @c_LogicalLocStart = ''  
                        BEGIN  
                           SELECT @c_LogicalLocStart =  LogicalLocStart   
                           FROM @t_DPRange WHERE PickZone = @c_DPPPKZone  
                        END  
               
                        IF @c_Toloc = '' AND @c_LogicalLocStart = ''  
                        BEGIN  
                           GOTO NEXT_DPPPKZone  
                        END   
               
                        IF @c_Toloc = '' AND @c_LogicalLocStart <> ''  -- Last Loc, Search empty from begining  
                        BEGIN  
                           UPDATE @t_DPRange SET LogicalLocStart = '' WHERE PickZone = @c_DPPPKZone  
                           GOTO GET_PICKZONE_DP  
                        END  
               
                        IF @n_LocQty = 0   
                        BEGIN   
                           UPDATE @t_DPRange SET LogicalLocStart = @c_logicalloc WHERE PickZone = @c_DPPPKZone  
                        END  
                        ELSE  
                        BEGIN   
                           SET @c_Toloc = ''  
                        END  
               
                        NEXT_DPPPKZone:
                        FETCH NEXT FROM CUR_DPP INTO @c_DPPPKZone  
                     END  
                     CLOSE  CUR_DPP  
                     DEALLOCATE CUR_DPP  
                  END   
               
                  IF @c_ToLoc = ''  
                  BEGIN   
                     SET @n_Continue = 3  
                     SET @n_Err = 81036  
                     SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Unable To Find DP Loc (ispRLWAV43_RPF) ' 
                     GOTO QUIT_SP  
                  END  
               
                  SET @c_ToLocType = 'DP'     
                  GOTO ADD_TASK
               END   
            END   --@c_ECSingleFlag = 'M' 
         END   --IF @c_UOM IN ('2', '6') AND @c_DropID <> ''
         ELSE IF (@c_DocType = 'N' AND @c_UOM = '7') OR (@c_DocType = 'E')
         BEGIN
         --For UCC allocated for replenishment to Home Location, direct replenish to Home Location -----> DPP LOC
         --DocType = 'N' AND UOM = '7' --> DPP (Home Loc)
         FIND_DPP:
            IF @c_TaskDetailKey <> ''  
            BEGIN  
               GOTO NEXT_LOOP  
            END  

            IF @c_ExistingTDKey <> ''  
            BEGIN  
               GOTO NEXT_LOOP  
            END  
         
            SET @c_ToLocType = 'DPP'  
         
            -- Find Sku in DPP Loc  
            IF @c_ToLoc = ''  
            BEGIN
               SELECT TOP 1 @c_ToLoc = LOC.Loc  
               FROM SKUxLOC SxL  WITH (NOLOCK)  
               JOIN #TMP_LOC_DPP LOC WITH (NOLOCK) ON (SxL.Loc = LOC.Loc)
               LEFT JOIN  LOTxLOCxID LLI WITH (NOLOCK)  ON  (LLI.Loc = LOC.Loc)   
                                                        AND (LLI.Storerkey = @c_Storerkey)  
                                                        AND (LLI.Sku = @c_Sku)   
               WHERE SxL.Storerkey= @c_Storerkey  
               AND   SxL.Sku = @c_Sku    
               AND   SxL.LocationType = 'PICK'                                     
               AND   LOC.Facility = @c_Facility  
               AND   LOC.LocationCategory = 'SHELVING'  
               AND   LOC.LocationType = 'DYNPPICK'  
               AND   LOC.LocationHandling = @c_LocationHandling    
               ORDER BY LOC.LogicalLocation  
                     ,  LOC.Loc  
            END
         END  
      END   --IF @c_UOM IN ('2', '6', '7') AND @c_DropID <> ''
      ADD_TASK:  
         IF @c_ToLoc = '' AND @c_DocType = 'E'  
         BEGIN  
            SET @n_Continue = 3  
            SET @n_Err = 81040  
            SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)  
                         +': ' + CASE WHEN @c_UOM IN ('2','6') THEN 'Pack Station/Sort Station for DropID# ' + @c_DropID ELSE 'DPP Location for Sku: ' + @c_Sku END  
                         + ' Not found. (ispRLWAV43_RPF)'  
            GOTO QUIT_SP  
         END  
         ELSE IF @c_ToLoc = '' AND @c_DocType = 'N'  
         BEGIN  
            SET @n_Continue = 3  
            SET @n_Err = 81040  
            SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)  
                         +': ' + CASE WHEN @c_UOM IN ('2') THEN 'Pack Station for DropID# ' + @c_DropID 
                                      WHEN @c_UOM IN ('6') THEN 'DP Loc for DropID# ' + @c_DropID 
                                      ELSE 'DPP Location for Sku: ' + @c_Sku END  
                         + ' Not found. (ispRLWAV43_RPF)'  
            GOTO QUIT_SP  
         END  
    
         IF @c_ToLoc <> ''          
         BEGIN  
            UPDATE #TMP_PICK  
            SET ToLoc = @c_ToLoc  
            WHERE RowRef = @n_RowRef  
  
            SET @n_err = @@ERROR    
            IF @n_err <> 0    
            BEGIN  
               SET @n_continue = 3    
               SET @n_Err = 81050   
               SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update #TMP_PICK Failed. (ispRLWAV43_RPF)'   
               GOTO QUIT_SP  
            END                     
            ------------------------------------------------------------------------------------  
            -- Create TaskDetail (START)  
            ------------------------------------------------------------------------------------  
            SET @c_TaskDetailkey = ''  
            SET @c_TaskType = 'RPF'  
  
            SET @b_success = 1    
            EXECUTE nspg_getkey    
                  'TaskDetailKey'   
                  , 10    
                  , @c_taskdetailkey OUTPUT    
                  , @b_success   OUTPUT    
                  , @n_err       OUTPUT    
                  , @c_errmsg    OUTPUT  
                   
            IF NOT @b_success = 1    
            BEGIN    
               SET @n_Continue = 3  
               GOTO QUIT_SP    
            END    
   
            SET @c_SourceType = 'ispRLWAV43_RPF-' + TRIM(@c_DocType)  

            IF ISNULL(@c_DocType,'') = ''
               SET @c_SourceType = 'ispRLWAV43_RPF'

            SET @c_LogicalToLoc = @c_ToLoc  
            SET @c_TransitLoc = ''  
            SET @c_FinalLoc = ''  
            SET @c_FinalID = '' 
            SET @c_TaskPriority = '5'              --(Wan03) 

            --To PackStation
            IF @c_ToLocType IN ( 'PS', 'ST' ) AND @c_TaskType = 'RPF'  
            BEGIN          
               SET @c_TransitLoc = @c_Toloc  
               SET @c_FinalLoc = @c_Toloc
            END
            ELSE IF @c_ToLocType IN ('DP','DPP') AND @c_TaskType = 'RPF'  
            BEGIN  
               SELECT @c_TransitLoc = PICKZONE.InLoc  
               FROM LOC (NOLOCK)  
               JOIN PICKZONE (NOLOCK) ON LOC.Pickzone = PICKZONE.Pickzone  
               WHERE LOC.Loc = @c_Toloc  
                 
               IF @c_TransitLoc IS NULL  
                  SET @c_TransitLoc = ''  
                 
               SET @c_FinalLoc = @c_LogicalToLoc  
               SET @c_FinalID = @c_ID   
               
               --(Wan03) - START
               IF @c_UOM = '7' 
               BEGIN
                  SET @c_TaskPriority = @c_TaskPriorityDPP
               END 
               --(Wan03) - END                                           
            END   
            
            IF @c_TaskByWavePriority = 'Y'               --(Wan04) - START
            BEGIN
               SET @c_TaskPriority = IIF(@c_Priority_Wave <> '' AND @c_Priority_Wave IS NOT NULL
                                       , @c_Priority_Wave
                                       , @c_TaskPriority)
            END                                          --(Wan04) - END
            
            SELECT @c_AreaKey = ISNULL(AD.AreaKey,'')
            FROM LOC L (NOLOCK)
            JOIN AREADETAIL AD WITH (NOLOCK) ON L.PickZone = AD.PutawayZone  
            WHERE L.LOC = @c_FromLoc   
              
            INSERT TASKDETAIL    
               (    
                  TaskDetailKey    
               ,  TaskType    
               ,  Storerkey    
               ,  Sku    
               ,  UOM    
               ,  UOMQty    
               ,  Qty    
               ,  SystemQty  
               ,  Lot    
               ,  FromLoc    
               ,  FromID    
               ,  ToLoc    
               ,  ToID    
               ,  SourceType    
               ,  SourceKey    
               ,  Priority    
               ,  SourcePriority    
               ,  Status    
               ,  LogicalFromLoc    
               ,  LogicalToLoc    
               ,  PickMethod  
               ,  Wavekey  
               ,  Message02   
               ,  Areakey  
               ,  Message03  
               ,  Caseid  
               ,  Loadkey  
               ,  PendingMoveIn                                                       
               ,  TransitLoc                        
               ,  FinalLoc 
               ,  FinalID  
               ,  QtyReplen           
               )    
               VALUES    
               (    
                  @c_taskdetailkey    
               ,  @c_TaskType --Tasktype    
               ,  @c_Storerkey    
               ,  @c_Sku    
               ,  @c_UOM         -- UOM,    
               ,  CASE WHEN @c_UOM = '7' AND @c_DropID = '' THEN @n_Qty ELSE @n_UCCQty END      -- UOMQty,    
               ,  CASE WHEN @c_UOM = '7' AND @c_DropID = '' THEN @n_Qty ELSE @n_UCCQty END      --Qty  
               ,  @n_Qty         --systemqty  
               ,  @c_Lot     
               ,  @c_Fromloc     
               ,  @c_ID          -- from id    
               ,  @c_Toloc   
               ,  @c_ID          -- to id    
               ,  @c_SourceType  --Sourcetype    
               ,  @c_Wavekey     --Sourcekey    
               ,  @c_TaskPriority-- Priority                --Wan03   
               ,  '9'            -- Sourcepriority    
               ,  '0'            -- Status    
               ,  @c_LogicalFromLoc --Logical from loc    
               ,  @c_LogicalToLoc   --Logical to loc    
               ,  @c_PickMethod  
               ,  @c_Wavekey  
               ,  @c_ToLocType  
               ,  @c_AreaKey 
               ,  ''  
               ,  @c_DropID  
               ,  ''  
               ,  CASE WHEN (@c_DocType = 'E' AND @c_ECSingleFlag = 'S' AND @n_UCCQty = @n_Qty) OR (@c_DocType = 'N' AND @c_UOM = '2') THEN 0 ELSE @n_UCCQty END        
               ,  @c_TransitLoc  
               ,  @c_FinalLoc 
               ,  @c_FinalID
               ,  0   --CASE WHEN @c_DropID <> '' THEN @n_UCCQty - @n_Qty ELSE 0 END
               )  
      
            SET @n_err = @@ERROR    
            IF @n_err <> 0    
            BEGIN  
               SET @n_continue = 3    
               SET @n_Err = 81070   
               SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert Taskdetail Failed. (ispRLWAV43_RPF)'   
               GOTO QUIT_SP  
            END     
         END  
         ------------------------------------------------------------------------------------  
         -- Create TaskDetail (END)  
         ------------------------------------------------------------------------------------  

         IF @c_DropID <> ''  
         BEGIN  
            ; WITH  UPD (PickDetailkey, DropID) AS  
            ( SELECT PickdetailKey, DropID FROM dbo.PICKDETAIL AS p WITH (NOLOCK) WHERE p.DropID = @c_DropID )  
           
            UPDATE p  
               SET p.TaskDetailKey = @c_TaskDetailKey  
                  ,p.EditWho = SUSER_SNAME()  
                  ,p.EditDate= GETDATE()  
                  ,p.TrafficCop = NULL  
            FROM dbo.PICKDETAIL AS p   
            JOIN UPD ON UPD.PickDetailkey = p.PickDetailKey  
              
            SET @n_err = @@ERROR        
            IF @n_err <> 0        
            BEGIN      
               SET @n_continue = 3        
               SET @n_Err = 81071       
               SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': UPDATE Pickdetail Failed. (ispRLWAV43_RPF)'       
               GOTO QUIT_SP      
            END   
         END  

NEXT_LOOP:
      SET @c_UOM_Prev = @c_UOM  
  
      FETCH NEXT FROM CUR_PD INTO  @n_RowRef  
                                 , @c_Facility  
                                 , @c_Storerkey  
                                 , @c_Sku  
                                 , @c_UOM  
                                 , @c_Lot  
                                 , @c_FromLoc  
                                 , @c_ID  
                                 , @c_DropID  
                                 , @n_UCCQty  
                                 , @n_Qty  
                                 , @c_PickMethod  
                                 , @c_FromPAZone  
                                 , @c_LogicalFromLoc                            
                                 , @c_FromLocType                               
                                 , @c_Lottable01   
                                 , @c_TaskDetailkey   
                                 , @c_DocType
                                 , @c_ECSingleFlag  
                                 , @c_ExistingTDKey

      --IF @n_Continue = 3 AND @c_UOM_Prev = '7' AND (@c_UOM <> '7' OR @@FETCH_STATUS = -1)   
      --BEGIN  
      --   SET @n_UCCWODPLoc = 0  
      --   SET @n_UCCWOBULKDPLoc = 0  
      --   SELECT @n_UCCWOBULKDPLoc = SUM(CASE WHEN @n_MinPalletCarton > 0 THEN T.TotalCartonInID ELSE 0 END)  
      --         ,@n_UCCWODPLoc = SUM(CASE WHEN @n_MinPalletCarton = 0 THEN T.TotalCartonInID ELSE 0 END)  
      --   FROM (  
      --      SELECT ID  
      --            ,TotalCartonInID = COUNT(DISTINCT DropID)    
      --      FROM #TMP_PICK  
      --      WHERE UOM = '7'  
      --      AND DropID <> ''  
      --      AND ToLoc = ''  
      --      GROUP BY ID        
      --      ) T  
  
      --   SET @n_Err = 81036  
      --   SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Not enough DP Location. '  
      --                +'No of UCC: ' + CONVERT(NVARCHAR(5),@n_UCCWODPLoc) + ' still need(s) Shelving DP Loc (ispRLWAV43_RPF) '  
      --                --+'No of UCC: ' + CONVERT(NVARCHAR(5),@n_UCCWOBULKDPLoc) + ' still need(s) BULK DP Loc (ispRLWAV43_RPF)'  
      --   GOTO QUIT_SP  
      --END
   END  
   CLOSE CUR_PD  
   DEALLOCATE CUR_PD  
   
   --(Wan01) -- START
   SET @c_SkipNormalReplTask = 'N'
   SELECT @c_SkipNormalReplTask = dbo.fnc_GetParamValueFromString('@c_SkipNormalReplTask', @c_Release_Opt5, @c_SkipNormalReplTask) 
   
   IF @c_SkipNormalReplTask = 'Y'
   BEGIN
      GOTO UPDATE_ADPHLDPLoc
   END
   --(Wan01) -- END
   
   -------------------------------------------------------------------------------------  
   -- Enable Gen General replenishment task - START
   -------------------------------------------------------------------------------------  
   DECLARE @n_RemainingQty INT = 0  
         , @n_Severity     INT = 0  
  
         , @CUR_SxL        CURSOR  
         , @CUR_REPLUCC    CURSOR  

   IF OBJECT_ID('tempdb..#UCCPAlloc','u') IS NOT NULL  
      DROP TABLE #UCCPAlloc;  
  
   CREATE TABLE #UCCPAlloc   
   (  SeqNo             INT IDENTITY(1, 1)  PRIMARY Key  
   ,  Storerkey         NVARCHAR(15)   NOT NULL DEFAULT ('')   
   ,  Sku               NVARCHAR(20)   NOT NULL DEFAULT ('')   
   ,  UCCNo             NVARCHAR(20)   NOT NULL DEFAULT ('')   
   ,  UCCQtyAvail       INT            NOT NULL DEFAULT (0)   
   )  
  
   IF OBJECT_ID('tempdb..#UCCRepl','u') IS NOT NULL  
      DROP TABLE #UCCRepl;  
  
   CREATE TABLE #UCCRepl   
   (  SeqNo             INT IDENTITY(1, 1)  PRIMARY Key  
   ,  Storerkey         NVARCHAR(15)   NOT NULL DEFAULT ('')   
   ,  Sku               NVARCHAR(20)   NOT NULL DEFAULT ('')   
   ,  UCCNo             NVARCHAR(20)   NOT NULL DEFAULT ('')   
   ,  UCCReplQty        INT            NOT NULL DEFAULT (0)   
   )  
  
   INSERT INTO #UCCPAlloc ( Storerkey, Sku, UCCNo, UCCQtyAvail )  
   SELECT   
          UCC.Storerkey  
         ,UCC.Sku  
         ,UCC.UCCNo    
         ,UCCQtyAvail = UCC.Qty - ISNULL(SUM(PD.Qty),0)  
   FROM (SELECT DISTINCT Storerkey, Sku FROM #TMP_PICK) S   
   JOIN PICKDETAIL PD (NOLOCK) ON  PD.Storerkey = S.Storerkey  
                               AND PD.Sku = S.Sku  
   JOIN UCC WITH (NOLOCK) ON  UCC.UCCNo = PD.DropID  
   JOIN LOC L WITH (NOLOCK) ON L.Loc = PD.Loc    
   WHERE UCC.[Status] = '3'  
   AND   UCC.UCCNo <> ''  
   AND   PD.[Status] <= '3' -- Close pallet (to intransit or home location not update pickdetail.status to '5')  
   AND   PD.UOM = '7'  
   AND   PD.DropID <> ''  
   AND   L.Facility = @c_Facility  
   AND   L.LocationType NOT IN ('DYNPPICK')     -- Not In Home loc  
   AND   L.LocationCategory NOT IN ('SHELVING') -- Not In Home loc  
   GROUP BY UCC.Storerkey  
         ,  UCC.Sku  
         ,  UCC.UCCNo    
         ,  UCC.Qty  
  
   INSERT INTO #UCCRepl ( Storerkey, Sku, UCCNo, UCCReplQty )  
   SELECT   
          UCC.Storerkey  
         ,UCC.Sku  
         ,UCC.UCCNo    
         ,UCC.Qty  
   FROM (SELECT DISTINCT Storerkey, Sku FROM #TMP_PICK) S   
   JOIN UCC WITH (NOLOCK) ON  UCC.Storerkey = S.Storerkey  
                          AND UCC.Sku = S.Sku  
   JOIN LOC L WITH (NOLOCK) ON L.Loc = UCC.Loc    
   WHERE UCC.[Status] = '1'   
   AND   UCC.UCCNo <> ''  
   AND   L.Facility = @c_Facility  
   AND   EXISTS (SELECT 1 FROM TASKDETAIL TD WITH (NOLOCK) WHERE TD.CaseID = UCC.UCCNo AND TD.[Status] < '9')  
   AND   NOT EXISTS (SELECT 1 FROM #UCCPAlloc AL WHERE AL.UCCNo = UCC.UCCNo)  
  
   SET @CUR_SxL = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
   SELECT SxL.Storerkey  
      ,  SxL.Sku  
      ,  SxL.Loc  
      ,  Severity = SxL.QtyLocationLimit - ((SxL.Qty - SxL.QtyAllocated - SxL.QtyPicked) + ISNULL(SUM(AL.UCCQtyAvail),0) + ISNULL(SUM(RP.UCCReplQty),0))  
      ,  L.LocationHandling  
      --,  L.LogicalLocation  
   FROM (SELECT T.Storerkey, T.Sku FROM #TMP_PICK T GROUP BY T.Storerkey, T.Sku)  PD  
   JOIN SKUxLOC SxL WITH (NOLOCK) ON  PD.Storerkey = SxL.Storerkey AND PD.Sku = SxL.Sku  
   JOIN LOC L WITH (NOLOCK) ON SxL.Loc = L.Loc  
   LEFT JOIN #UCCPAlloc AL  ON  PD.Storerkey = AL.Storerkey  AND PD.Sku = AL.Sku  
   LEFT JOIN #UCCREPL   RP  ON  PD.Storerkey = RP.Storerkey  AND PD.Sku = RP.Sku  
   WHERE SxL.LocationType = 'PICK'  
   AND   SxL.QtyLocationMinimum > 0  
   AND   SxL.QtyLocationLimit > 0      
   AND   L.Facility = @c_Facility  
   AND   L.LocationType = 'DYNPPICK'  
   AND   L.LocationCategory = 'SHELVING'       
   AND   L.LocationFlag NOT IN ('DAMAGE', 'HOLD')     
   AND   L.[Status] = 'OK'   
   GROUP BY  
         SxL.Storerkey  
      ,  SxL.Sku  
      ,  SxL.Loc  
      ,  SxL.QtyLocationLimit   
      ,  SxL.Qty  
      ,  SxL.QtyAllocated  
      ,  SxL.QtyPicked  
      ,  SxL.QtyLocationMinimum  
      ,  L.LocationHandling  
   HAVING (SxL.Qty - SxL.QtyAllocated - SxL.QtyPicked)  + ISNULL(SUM(AL.UCCQtyAvail),0) + ISNULL(SUM(RP.UCCReplQty),0) <= SxL.QtyLocationMinimum                                                                     
   ORDER BY Sku  
     
   OPEN @CUR_SxL  
   FETCH NEXT FROM @CUR_SxL INTO @c_Storerkey  
                              ,  @c_Sku  
                              ,  @c_ToLoc  
                              ,  @n_Severity  
                              ,  @c_LocationHandling  
  
   WHILE @@FETCH_STATUS <> -1  
   BEGIN  
      SET @n_RemainingQty = @n_Severity  
      SET @c_Lot     = ''   
      SET @c_FromLoc = ''  
      SET @c_ID      = ''  
      SET @c_DropID  = ''  
      SET @n_UCCQty  = 0  
  
      SET @CUR_REPLUCC = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
      SELECT   LLI.Lot  
            ,  LLI.Loc  
            ,  LLI.ID  
            ,  CS.UCCNo  
            ,  CS.UCCQty  
            ,  LOC.LogicalLocation  
      FROM LOTxLOCxID LLI WITH (NOLOCK)        
      JOIN LOC WITH (NOLOCK) ON (LLI.Loc = LOC.LOC AND LOC.Status <> 'HOLD')    
      JOIN ID  WITH (NOLOCK) ON (LLI.Id  = ID.ID   AND ID.STATUS <> 'HOLD')    
      JOIN LOT WITH (NOLOCK) ON (LLI.LOT = LOT.LOT AND LOT.STATUS <> 'HOLD')  
      JOIN LOTATTRIBUTE LA WITH (NOLOCK) ON (LLI.LOT = LA.LOT)  
      JOIN (   SELECT UCC.UCCNo, UCC.Lot, UCC.Loc, UCC.ID, UCCQty = ISNULL(SUM(UCC.Qty),0)  
               FROM  UCC WITH (NOLOCK)  
               WHERE UCC.Storerkey = @c_Storerkey  
               AND   UCC.[Status] = '1'  
               AND NOT EXISTS (SELECT 1 FROM TASKDETAIL TD WITH (NOLOCK)    
                               WHERE TD.CaseID = UCC.UCCNo AND TD.Status < '9'   
                               )  
               GROUP BY UCC.UCCNo, UCC.Lot, UCC.Loc, UCC.ID  
               HAVING COUNT(DISTINCT UCC.Sku) = 1 AND MIN(UCC.Sku)  = @c_Sku  
            )   CS ON LLI.Lot = CS.Lot AND LLI.Loc = CS.Loc AND LLI.ID = CS.ID  
      WHERE LLI.Storerkey = @c_Storerkey  
      AND   LLI.Sku = @c_Sku  
      AND   LOC.Facility = @c_Facility
      AND   LOC.LocationType = 'OTHER'  
      AND   LOC.LocationCategory = 'BULK'
      AND   LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked - LLI.QtyReplen > 0
      ORDER BY LOC.LocationHandling DESC  
               ,LOC.LogicalLocation  
               ,LOC.Loc  
  
      OPEN @CUR_REPLUCC  
  
      FETCH NEXT FROM @CUR_REPLUCC INTO @c_Lot       
                                     ,  @c_FromLoc   
                                     ,  @c_ID        
                                     ,  @c_DropID    
                                     ,  @n_UCCQty    
                                     ,  @c_LogicalFromLoc  
  
      WHILE @@FETCH_STATUS <> -1 AND @n_RemainingQty > 0  
      BEGIN  
         IF @n_UCCQty > @n_RemainingQty  
         BEGIN  
            SET @n_RemainingQty = 0  
            GOTO NEXT_REPLUCC  
         END  
  
         IF @c_DropID = ''  
         BEGIN  
            SET @n_RemainingQty = 0  
            GOTO NEXT_REPLUCC  
         END  
         ------------------------------------------------------------------------------------  
         -- Create TaskDetail (START)  
         ------------------------------------------------------------------------------------  
         SET @c_TaskDetailkey = ''  
         SET @c_SourceType = 'ispRLWAV43_RPF-REPLEN' 
         SET @c_TaskType = 'RPF'  
         SET @c_LogicalToLoc = @c_ToLoc  
         SET @c_ToLocType = 'DPP'  
         SET @c_PickMethod= 'PP'  
         SET @c_UOM = '7'  
         SET @n_Qty = 0  
         SET @c_TaskPriority = '5'              --(Wan03)
         
         IF @c_TaskByWavePriority = 'Y'         --(Wan04) - START
         BEGIN
            SET @c_TaskPriority = IIF(@c_Priority_Wave <> '' AND @c_Priority_Wave IS NOT NULL
                                    , @c_Priority_Wave
                                    , @c_TaskPriority)
         END                                   --(Wan04) - END
  
         SET @b_success = 1    
         EXECUTE nspg_getkey    
               'TaskDetailKey'   
               , 10    
               , @c_taskdetailkey OUTPUT    
               , @b_success   OUTPUT    
               , @n_err       OUTPUT    
               , @c_errmsg    OUTPUT  
                   
         IF NOT @b_success = 1    
         BEGIN    
            SET @n_Continue = 3  
            GOTO QUIT_SP    
         END    
   
         SET @c_TransitLoc = ''  
         SET @c_FinalLoc = ''  
         SET @c_FinalID = ''  

         IF @c_ToLocType = 'PS' AND @c_TaskType = 'RPF'  
         BEGIN            
            SET @c_TransitLoc = @c_Toloc  
         END
         ELSE IF @c_ToLocType IN('DP','DPP') AND @c_TaskType = 'RPF'  
         BEGIN  
            SELECT @c_TransitLoc = PICKZONE.InLoc
            FROM LOC (NOLOCK)  
            JOIN PICKZONE (NOLOCK) ON LOC.Pickzone = PICKZONE.Pickzone  
            WHERE LOC.Loc = @c_Toloc 
            
            IF @c_TransitLoc IS NULL  
               SET @c_TransitLoc = ''
         
            SET @c_FinalLoc = @c_LogicalToLoc  
            SET @c_FinalID = @c_ID                                               
         END         

         SELECT @c_AreaKey = ISNULL(AD.AreaKey,'')
         FROM LOC L (NOLOCK)
         JOIN AREADETAIL AD WITH (NOLOCK) ON L.PickZone = AD.PutawayZone  
         WHERE L.LOC = @c_FromLoc
  
         INSERT TASKDETAIL    
            (    
               TaskDetailKey    
            ,  TaskType    
            ,  Storerkey    
            ,  Sku    
            ,  UOM    
            ,  UOMQty    
            ,  Qty    
            ,  SystemQty  
            ,  Lot    
            ,  FromLoc    
            ,  FromID    
            ,  ToLoc    
            ,  ToID    
            ,  SourceType    
            ,  SourceKey    
            ,  [Priority]    
            ,  SourcePriority    
            ,  [Status]    
            ,  LogicalFromLoc    
            ,  LogicalToLoc    
            ,  PickMethod  
            ,  Wavekey  
            ,  Message02   
            ,  Areakey  
            ,  Message03  
            ,  Caseid  
            ,  Loadkey  
            ,  PendingMoveIn                                                       
            ,  TransitLoc                     
            ,  FinalLoc
            ,  FinalID         
            ,  QtyReplen                     
            )    
            VALUES    
            (    
               @c_taskdetailkey    
            ,  @c_TaskType    --Tasktype    
            ,  @c_Storerkey    
            ,  @c_Sku    
            ,  @c_UOM         -- UOM,    
            ,  @n_UCCQty      -- UOMQty,    
            ,  @n_UCCQty      --Qty  
            ,  @n_Qty         --systemqty       --(Wan02) systemqty = 0 @n_UCCQty        
            ,  @c_Lot     
            ,  @c_Fromloc     
            ,  @c_ID          -- from id    
            ,  @c_Toloc   
            ,  @c_ID          -- to id    
            ,  @c_SourceType  --Sourcetype    
            ,  @c_Wavekey     --Sourcekey    
            ,  @c_TaskPriority-- Priority             (Wan03)    
            ,  '9'            -- Sourcepriority    
            ,  '0'            -- Status    
            ,  @c_LogicalFromLoc --Logical from loc    
            ,  @c_LogicalToLoc   --Logical to loc    
            ,  @c_PickMethod  
            ,  @c_Wavekey  
            ,  @c_ToLocType  
            ,  @c_AreaKey 
            ,  ''  
            ,  @c_DropID  
            ,  ''  
            ,  @n_UCCQty       
            ,  @c_TransitLoc   
            ,  @c_FinalLoc
            ,  @c_FinalID  
            ,  0
            )  
      
         SET @n_err = @@ERROR    
         IF @n_err <> 0    
         BEGIN  
            SET @n_continue = 3    
            SET @n_Err = 81130   
            SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert Taskdetail Failed. (ispRLWAV43_RPF)'   
            GOTO QUIT_SP  
         END     
  
         ------------------------------------------------------------------------------------  
         -- Create TaskDetail (END)  
         ------------------------------------------------------------------------------------  

		 --CLVN01 - START--
		 IF EXISTS( SELECT TOP 1 1 
		 FROM UCC WITH (NOLOCK)    
               WHERE SKU = @c_Sku    
                  AND StorerKey = @c_Storerkey
				  AND UCCNO = @c_DropID)
		 BEGIN
			UPDATE UCC SET STATUS = '3'
                    ,   EditDate = GETDATE()  
                    ,   EditWho = SUSER_SNAME()  
                    ,   TrafficCop = NULL
			WHERE STORERKEY = @c_Storerkey AND UCCNO = @c_DropID AND SKU = @c_Sku
		 END
		 --CLVN01 - END--

         SET @n_RemainingQty = @n_RemainingQty - @n_UCCQty  
  
         NEXT_REPLUCC:  
         FETCH NEXT FROM @CUR_REPLUCC INTO @c_Lot       
                                          ,  @c_FromLoc   
                                          ,  @c_ID        
                                          ,  @c_DropID    
                                          ,  @n_UCCQty    
                                          ,  @c_LogicalFromLoc  
      END  
      CLOSE @CUR_REPLUCC  
      DEALLOCATE @CUR_REPLUCC  
  
      FETCH NEXT FROM @CUR_SxL INTO @c_Storerkey  
                                 ,  @c_Sku  
                                 ,  @c_ToLoc  
                                 ,  @n_Severity  
                                 ,  @c_LocationHandling  
   END  
   CLOSE @CUR_SxL  
   DEALLOCATE @CUR_SxL 
   
   ------------------------------------------------------------------------------------  
   -- Enable Gen General replenishment task - END
   ------------------------------------------------------------------------------------   

         
   ------------------------------------------------------------------------------------  
   -- Insert/Update Last DP LOC into Codelkup 
   ------------------------------------------------------------------------------------  
   UPDATE_ADPHLDPLoc:                  --(Wan01)
   DECLARE @CUR_DP CURSOR           
   SET @CUR_DP = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR                
   SELECT LDP.PickZone          
         ,LDP.LogicalLocStart              
   FROM @t_DPRange  LDP                
   ORDER BY LDP.PickZone           
                   
   OPEN @CUR_DP                
   FETCH NEXT FROM @CUR_DP INTO  @c_DPPPKZone               
                              ,  @c_logicalloc              
           
   WHILE @@FETCH_STATUS <> -1                
   BEGIN              
      IF EXISTS ( SELECT 1          
                  FROM CODELKUP CL WITH (NOLOCK)          
                  WHERE CL.ListName = 'ADPHLDPLoc'          
                  AND   CL.Code = @c_DPPPKZone          
                  AND   CL.Storerkey = @c_Storerkey          
                )          
      BEGIN          
         UPDATE CODELKUP          
         SET UDF01 = @c_LogicalLoc          
         WHERE ListName = 'ADPHLDPLoc'          
         AND Code = @c_DPPPKZone          
         AND Storerkey = @c_Storerkey          
         AND Code2 = ''          
      END           
      ELSE          
      BEGIN        
         IF NOT EXISTS (SELECT 1 FROM CODELIST (NOLOCK) WHERE LISTNAME = 'ADPHLDPLoc' )
         BEGIN
            INSERT INTO CODELIST (LISTNAME, DESCRIPTION)
            SELECT 'ADPHLDPLoc', 'ADPHLDPLoc'
         END

         INSERT INTO CODELKUP (ListName, Code, Description, Storerkey, UDF01)          
         VALUES ('ADPHLDPLoc', @c_DPPPKZone, @c_DPPPKZone, @c_Storerkey, @c_LogicalLoc)          
      END          
          
      IF @@ERROR <> 0          
      BEGIN          
         SET @n_continue = 3                
         SET @n_err = 81140                  
         SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)          
                      +': Insert/Update Last DP Location into CODELKUP Table for ListName = ''ADPHLDPLoc'' Failed. (ispRLWAV43_RPF)'                 
         GOTO QUIT_SP           
      END           
                                                     
      FETCH NEXT FROM @CUR_DP INTO @c_DPPPKZone               
                                 , @c_logicalloc           
   END          
   CLOSE @CUR_DP          
   DEALLOCATE @CUR_DP                       
  
QUIT_SP:  
  
   IF CURSOR_STATUS( 'LOCAL', 'CUR_PD') in (0 , 1)    
   BEGIN  
      CLOSE CUR_PD  
      DEALLOCATE CUR_PD  
   END  
  
   IF CURSOR_STATUS( 'LOCAL', 'CUR_ID') in (0 , 1)    
   BEGIN  
      CLOSE CUR_ID  
      DEALLOCATE CUR_ID  
   END  
  
   IF CURSOR_STATUS( 'LOCAL', 'CUR_UPD') in (0 , 1)    
   BEGIN  
      CLOSE CUR_UPD  
      DEALLOCATE CUR_UPD  
   END  
     
   IF OBJECT_ID('tempdb..#TMP_PICK','u') IS NOT NULL  
   BEGIN  
      DROP TABLE #TMP_PICK;  
   END  
  
   IF CURSOR_STATUS( 'LOCAL', 'CUR_DPP') in (0 , 1)    
   BEGIN  
      CLOSE CUR_DPP  
      DEALLOCATE CUR_DPP  
   END  
  
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
  
      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'ispRLWAV43_RPF'  
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
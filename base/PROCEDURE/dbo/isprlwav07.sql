SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Stored Proc: ispRLWAV07                                              */  
/* Creation Date: 21-FEB-2017                                           */  
/* Copyright: LF Logistics                                              */  
/* Written by: YTWan                                                    */  
/*                                                                      */  
/* Purpose:  WMS-1107 - CN-Nike SDC WMS Release Wave                    */  
/*        :                                                             */  
/* Called By: ReleaseWave_SP                                            */  
/*          :                                                           */  
/* PVCS Version: 1.9                                                    */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author  Ver   Purposes                                  */  
/* 22-MAY-2017  Wan01   1.1   Set LogicalToLoc = toloc for tracking     */  
/*                            purpose as toloc will be overwrite by RDT */    
/* 28-JUN_2017  Wan02   1.2   Fixed update wrong pickdetail             */  
/* 08-JUN-2017  Wan02   1.2   WMS-1894 - CN-Nike SDC WMS Release Wave CR*/   
/* 03-JUL-2017  Wan03   1.3   WMS-2303 - CN-Nike SDC WMS Release Wave CR*/  
/* 30-OCT-2017  Wan04   1.4   WMS-2886 - CN-Nike SDC WMS Release Wave CR*/  
/* 05-DEC-2017  NJOW01  1.5   WMS-2886 Fix wrongly update taskdetailkey */  
/*                            to DPP pick                               */  
/* 15-JAN-2018  Wan05   1.5   Not reserve DP loc as pick to zero        */  
/* 08-MAR-2018  Wan06   1.5   Performance Fix.                          */  
/* 24-JUL-2018  Wan07   1.6   WMS-5771 - CN - NIKESDC_WMS_ReleaseWave_CR*/  
/* 16-JAN-2020  NJOW02  1.7   WMS-11717 Generate transmitlog2           */  
/* 01-04-2020   Wan08   1.8   Sync Exceed & SCE                         */
/* 18-JUL-2022  WLChooi 1.9   WMS-20258 - Gen TL2 - WSSOCFMLOGB2B (WL01)*/
/* 18-JUL-2022  WLChooi 1.9   DevOps Combine Script                     */ 
/************************************************************************/  
CREATE PROC [dbo].[ispRLWAV07]
        @c_wavekey      NVARCHAR(10)    
       ,@b_Success      INT            OUTPUT    
       ,@n_err          INT            OUTPUT    
       ,@c_errmsg       NVARCHAR(250)  OUTPUT    
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
  
         , @n_UCCWODPLoc         INT                        --(Wan02)  
         , @c_DPPPKZone          NVARCHAR(10)               --(Wan02)  
         , @c_UOM_Prev           NVARCHAR(10)               --(Wan02)    
  
         , @n_NoOfUCC_Replen     INT                        --(Wan04)  
         , @n_NoOfUCCToDP        INT                        --(Wan04)  
         , @n_TotalEmptyLoc      INT                        --(Wan04)  
         , @c_Lottable01         NVARCHAR(18)               --(Wan04)  
         , @c_LocationHandlings  NVARCHAR(10)               --(Wan04)  
  
         , @CUR_UPDPM            CURSOR                     --(Wan04)  
           
         , @c_PreCTNLevel        CHAR(1)                    --(Wan07)  
         , @c_PackOrderkey       NVARCHAR(10)               --(Wan07)  
         , @c_Zone               NVARCHAR(10)               --(Wan07)  
         , @c_Status             NVARCHAR(10)               --NJOW02  

         , @c_DocType            NVARCHAR(10)               --WL01
     
   SET @n_StartTCnt = @@TRANCOUNT  
   SET @n_Continue = 1  
   SET @n_err      = 0  
   SET @c_errmsg   = ''  
  
   SET @c_DispatchPiecePickMethod = ''  
   SELECT @c_DispatchPiecePickMethod = ISNULL(RTRIM(DispatchPiecePickMethod),'')  
   FROM WAVE WITH (NOLOCK)  
   WHERE Wavekey = @c_Wavekey  
  
   IF @c_DispatchPiecePickMethod NOT IN ('INLINE', 'DTC')  
   BEGIN  
      SET @n_Continue = 3  
      SET @n_Err = 81000  
      SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Invalid DispatchPiecePickMethod. (ispRLWAV07)'  
      GOTO QUIT_SP  
   END   
  
   IF EXISTS (SELECT 1 FROM TASKDETAIL TD (NOLOCK)   
               WHERE TD.Wavekey = @c_Wavekey  
               AND TD.Sourcetype IN('ispRLWAV07-INLINE','ispRLWAV07-DTC')   
               AND TD.Tasktype IN ('RPF')  
               AND TD.Status <> 'X')   
   BEGIN  
      SET @n_Continue = 3  
      SET @n_Err = 81010  
      SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Wave has been released. (ispRLWAV07)'  
      GOTO QUIT_SP  
   END  
       
   IF EXISTS ( SELECT 1   
               FROM WAVEDETAIL WD(NOLOCK)  
               JOIN ORDERS O (NOLOCK) ON WD.Orderkey = O.Orderkey  
               WHERE O.Status > '2'  
               AND WD.Wavekey = @c_Wavekey)  
   BEGIN  
      SET @n_Continue = 3  
      SET @n_Err = 81020  
      SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Release is not allowed. Some orders of this Wave are started picking. (ispRLWAV07)'  
      GOTO QUIT_SP  
   END   
     
   --(Wan03) - START  
   SET @c_Facility = ''  
   SELECT TOP 1 @c_Facility = Facility  
               ,@c_Storerkey= Storerkey         -- (Wan07)  
   FROM ORDERS WITH (NOLOCK)  
   WHERE UserDefine09 = @c_Wavekey  
    
   IF EXISTS ( SELECT   1  
               FROM WAVEDETAIL WD    WITH (NOLOCK)   
               JOIN PICKDETAIL PD    WITH (NOLOCK) ON (WD.Orderkey = PD.Orderkey)  
               WHERE  WD.Wavekey = @c_Wavekey  
               AND    PD.UOM = '2'  
               AND    NOT EXISTS(SELECT 1   
                                 FROM SKUxLOC SxL WITH (NOLOCK)                       
                                 JOIN LOC     LOC WITH (NOLOCK) ON (SxL.Loc = LOC.Loc)   
                                                                AND(LOC.Facility = @c_Facility )  
                                 WHERE PD.Storerkey= SxL.Storerkey          
                                 AND   PD.Sku = SxL.Sku    
                                 AND   SxL.LocationType = 'PICK'    
                                 )                 
            )  
   BEGIN  
      SET @n_Continue = 3  
      SET @n_Err = 81030  
      SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Release rejects. Sku''s home location not found. (ispRLWAV07)'  
      GOTO QUIT_SP  
   END  
   --(Wan03) - END  
  
   IF EXISTS (  
               SELECT 1  
               FROM WAVEDETAIL WD    WITH (NOLOCK)   
               JOIN PICKDETAIL PD    WITH (NOLOCK) ON (WD.Orderkey = PD.Orderkey)  
               JOIN SKUxLOC    SxL   WITH (NOLOCK) ON (PD.Storerkey= SxL.Storerkey)       --(Wan03)  
                             AND(PD.Sku = SxL.Sku)                  --(Wan03)     
               JOIN LOC        LOC   WITH (NOLOCK) ON (SxL.Loc = LOC.Loc)                 --(Wan03)  
               WHERE  WD.Wavekey = @c_Wavekey  
               AND    PD.UOM = '2'  
               AND    LOC.Facility = @c_Facility    
               AND    SxL.LocationType = 'PICK'   
               AND NOT EXISTS (  SELECT 1  
                                 FROM CODELKUP   CL    WITH (NOLOCK)  
                                 JOIN LOC        PS    WITH (NOLOCK) ON (PS.Loc = CL.Short)   
                         WHERE CL.ListName = 'NIKEZONE'    
                                 AND CL.Code = LOC.PickZone                               --(Wan03)  
                                 AND CL.Code2= @c_DispatchPiecePickMethod                 --(Wan03)  
                                 AND CL.Storerkey = PD.Storerkey  
                                 )  
                  )    
   BEGIN  
      SET @n_Continue = 3  
      SET @n_Err = 81030  
      SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Release rejects. Pack Station not setup in codelkup OR Loc table. (ispRLWAV07)'  
      GOTO QUIT_SP  
   END                      
  
   --(Wan02) - START  
   CREATE TABLE #TMP_DP_PMI  
   (  Storerkey         NVARCHAR(15)   NULL  
   ,  Sku               NVARCHAR(20)   NULL  
   ,  Loc               NVARCHAR(10)   NOT NULL PRIMARY KEY  
   ,  MaxPallet         INT            NULL DEFAULT (0)  
   ,  NoOfUCC_PMI       INT            NULL DEFAULT (0)  
   ,  Wavekey           NVARCHAR(10)   NULL  
   )  
   --(Wan02) - END  
  
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
   ,  Style             NVARCHAR(20)   NULL                       --(Wan02)  
   ,  Color             NVARCHAR(10)   NULL                       --(Wan02)  
   ,  Size              NVARCHAR(10)   NULL                       --(Wan02)  
   ,  Lottable01        NVARCHAR(18)   NULL                       --(Wan04)  
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
      ,  Lottable01                                                           --(Wan04)         
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
         ,LogicalFromLoc = ISNULL(RTRIM(LOC.LogicalLocation),'')  
         ,FromLocType = CASE WHEN LOC.LocationType     <> 'DYNPPICK'   
                              AND LOC.LocationCategory <> 'SHELVING'   
                              AND SxL.LocationType NOT IN ('PICK','CASE')   
                              THEN 'BULK'   
                              ELSE 'DPP' END  
         ,FromPAZone       = ISNULL(RTRIM(LOC.PutawayZone),'')  
         ,LocationHandling = ISNULL(RTRIM(LOC.LocationHandling),'')  
         ,LocationType     = ISNULL(RTRIM(LOC.LocationType),'')  
         ,LocationCategory = ISNULL(RTRIM(LOC.LocationCategory),'')  
         ,Style = CASE WHEN PD.UOM = '6'                                      --(Wan02)  
                  THEN ISNULL(RTRIM(SKU.Style),'')                            --(Wan02)  
         ELSE '' END                                                 --(Wan02)        
         ,Color = CASE WHEN PD.UOM = '6'                                      --(Wan02)  
                  THEN ISNULL(RTRIM(SKU.Color),'')                            --(Wan02)  
                  ELSE '' END                                                 --(Wan02)  
         ,Size  = CASE WHEN PD.UOM = '6'                                      --(Wan02)  
                  THEN ISNULL(RTRIM(SKU.Size),'')                             --(Wan02)  
                  ELSE '' END                                                 --(Wan02)  
         ,Lottable01 = ISNULL(RTRIM(LA.Lottable01),'')                        --(Wan04)  
   FROM   WAVEDETAIL WD    WITH (NOLOCK)   
   JOIN   PICKDETAIL PD    WITH (NOLOCK) ON (WD.Orderkey = PD.Orderkey)  
   JOIN   LOTATTRIBUTE LA  WITH (NOLOCK) ON (PD.Lot = LA.Lot)                 --(Wan04)  
   JOIN   LOC        LOC   WITH (NOLOCK) ON (PD.Loc = LOC.Loc)  
   JOIN   SKUxLOC    SxL   WITH (NOLOCK) ON (PD.Storerkey = SxL.Storerkey)  
                                         AND(PD.Sku = SxL.Sku)   
                                         AND(PD.Loc = SxL.Loc)  
   JOIN   SKU        SKU   WITH (NOLOCK) ON (PD.Storerkey = SKU.Storerkey)    --(Wan02)  
                                         AND(PD.Sku = SKU.Sku)                --(Wan02)                            
   LEFT JOIN UCC     UCC   WITH (NOLOCK) ON (PD.DropID = UCC.UCCNo)  
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
         ,  CASE WHEN PD.UOM = '6'                                            --(Wan02)  
                 THEN ISNULL(RTRIM(SKU.Style),'')                             --(Wan02)  
                 ELSE '' END                                                  --(Wan02)        
         ,  CASE WHEN PD.UOM = '6'                                            --(Wan02)  
                 THEN ISNULL(RTRIM(SKU.Color),'')                             --(Wan02)  
                 ELSE '' END                                                  --(Wan02)  
         ,  CASE WHEN PD.UOM = '6'                                            --(Wan02)  
                 THEN ISNULL(RTRIM(SKU.Size),'')                              --(Wan02)  
                 ELSE '' END                                                  --(Wan02)  
         ,  ISNULL(RTRIM(LA.Lottable01),'')                                   --(Wan04)  
   ORDER BY PD.UOM  
         ,  CASE WHEN PD.UOM = '6' THEN '' ELSE PD.Loc END                    --(Wan02)  
         ,  PD.Storerkey  
         ,  PD.Sku  
         ,  Style                                                             --(Wan02)  
         ,  Color                                                         --(Wan02)  
         ,  Size                                                              --(Wan02)  
         ,  Lottable01                                                        --(Wan04)  
  
   --(Wan04) - START  
   SET @n_NoOfUCCToDP = 0  
   SELECT @n_NoOfUCCToDP = ISNULL(SUM(PCK.NoOfUCCToDP),0)  
   FROM   
      (  SELECT NoOfUCCToDP = COUNT(DISTINCT TP.DropID)  
         FROM #TMP_PICK TP WITH (NOLOCK)   
         WHERE TP.UOM = '6'  
         AND   TP.DropID <> ''  
         GROUP BY TP.Storerkey  
                , TP.Sku  
      ) PCK  
  
   SET @n_TotalEmptyLoc = 0  
   SELECT @n_TotalEmptyLoc = COUNT(1)  
   FROM LOC WITH (NOLOCK)   
   WHERE 0 = ( SELECT CASE WHEN COUNT(1) = 0 THEN 0  
                           ELSE SUM(LLI.Qty + LLI.Qty + LLI.QtyAllocated + LLi.QtyPicked + LLI.PendingMoveIN)  
                           END   
               FROM LOTxLOCxID LLI WITH (NOLOCK)   
               WHERE LLI.Loc = LOC.Loc  
             )   
   AND   LOC.Facility = @c_Facility                --(Wan06)  
  
   IF @n_NoOfUCCToDP > @n_TotalEmptyLoc  
   BEGIN  
      SET @n_Err = 81035  
      SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Not enough DP Location. '  
                     +'No of UCC:' + CONVERT(NVARCHAR(5),@n_NoOfUCCToDP - @n_TotalEmptyLoc) + ' still need(s) DP Loc (ispRLWAV07)'  
      GOTO QUIT_SP  
   END   
   --(Wan04) - END  
  
   --(Wan07) - START  
   SET @b_Success = 1  
   EXEC nspGetRight    
         @c_Facility              
      ,  @c_StorerKey               
      ,  ''         
      ,  'NKSPreCartonLevel'               
      ,  @b_Success        OUTPUT      
      ,  @c_PreCTNLevel    OUTPUT    
      ,  @n_err            OUTPUT    
      ,  @c_errmsg         OUTPUT  
  
   IF @b_Success <> 1  
   BEGIN   
      SET @n_Continue= 3      
      SET @n_Err     = 81037     
      SET @c_ErrMsg  = 'NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Error Executing nspGetRight: '    
                     + '.(ispWAVNK01)'  
      GOTO QUIT_SP    
   END  
   --(Wan07) - END  
  
   BEGIN TRAN  
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
      ,  LogicalFromLoc                                                       --(Wan04)   
      ,  FromLocType                                                          --(Wan04)   
      ,  Lottable01                                                           --(Wan04)  
   FROM #TMP_PICK                                                             --(Wan04)  
   --WHERE FromLocType <> 'DPP'                                               --(Wan04)  
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
                              , @c_LogicalFromLoc                             --(Wan04)   
                              , @c_FromLocType                                --(Wan04)   
                              , @c_Lottable01                                 --(Wan04)  
  
   WHILE @@FETCH_STATUS <> -1  
   BEGIN  
      SET @c_ToLoc = ''  
      SET @c_ToLocType = ''  
  
      IF @c_FromLocType = 'DPP'  
      BEGIN  
         GOTO ADD_PSLIP -- Need to Generate Pickslipno  
      END  
  
      IF @c_UOM = '2' -- Single Order pick from Pallet Location  
      BEGIN  
         --(Wan03) - START  
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
         --(Wan03) - END  
  
         SELECT @c_ToLoc = ISNULL(RTRIM(Short),'')  
         FROM CODELKUP WITH (NOLOCK)    
         WHERE ListName = 'NIKEZONE'  
         --AND   Code = @c_FromPAZone                                         --(Wan03)  
         AND   Code = @c_DPPPKZone                                            --(Wan03)  
         AND   Code2= @c_DispatchPiecePickMethod                              --(Wan03)  
         AND   Storerkey = @c_Storerkey  
  
         SET @c_ToLocType = 'PS'  -- Pack Station  
  
         GOTO ADD_TASK  
      END  
      --(Wan04) - START  
  
      SET @c_LocationHandling = CASE WHEN @c_Lottable01 = 'A' THEN '3'  
                                     WHEN @c_Lottable01 = 'B' THEN '4'  
                                     ELSE ''  
                                     END  
      --(Wan04) - END  
  
      --(Wan02) - START  
      IF @c_UOM = '6'  
      BEGIN  
  
         FIND_DP:  
            --SET @c_LocationHandling3 = @c_LocationHandling  
            --SET @c_LocationHandling4 = @c_LocationHandling  
  
            --IF @c_Lottable01 = 'B'  
            --BEGIN  
            --   SET @c_LocationHandling3 = '3'  
            --   SET @c_LocationHandling4 = '4'  
            --END  
  
            --(Wan04) - START  
            SELECT @c_ToLoc = ISNULL(RTRIM(TD.ToLoc),'')  
            FROM LOC          LOC WITH (NOLOCK)  
            JOIN TASKDETAIL   TD  WITH (NOLOCK) ON (LOC.Loc = TD.ToLoc)  
            JOIN LOTATTRIBUTE LA  WITH (NOLOCK) ON (TD.Lot = LA.Lot)  
            WHERE LOC.LocationType = 'DYNPICKP'  
            AND   LOC.LocationHandling = @c_LocationHandling                 
            AND   LOC.Facility = @c_Facility  
            AND   TD.TaskType IN ('RPF','RP1','RPT')  
            AND   TD.UOM       = '6'  
            AND   TD.CaseID    <>''  
            AND   TD.Status    < '9'  
            AND   TD.SourceType   like 'ispRLWAV07-%'  
            AND   TD.Wavekey  = @c_Wavekey  
            AND   TD.Storerkey= @c_Storerkey  
            AND   TD.Sku      = @c_Sku  
  
            GROUP BY TD.Storerkey  
                  ,  TD.Sku  
                  ,  TD.ToLoc  
                  ,  ISNULL(LOC.MaxPallet,0)  
            HAVING ISNULL(LOC.MaxPallet,0) > ISNULL(COUNT( DISTINCT TD.CaseID),0)  
  
            /*  
            --TRUNCATE TABLE #TMP_DP_PMI  
  
            --INSERT INTO #TMP_DP_PMI  
            --   (  Storerkey  
            --   ,  Sku  
            --   ,  Loc  
            --   ,  MaxPallet  
            --   ,  NoOfUCC_PMI  
            --   ,  Wavekey  
            --   )  
            --SELECT TD.Storerkey  
            --   ,  TD.Sku  
            --   ,  TD.ToLoc  
            --   ,  ISNULL(LOC.MaxPallet,0)  
            --   ,  ISNULL(COUNT( DISTINCT TD.CaseID),0)  
            --   ,  TD.Wavekey  
            --FROM LOC        LOC WITH (NOLOCK)  
            --JOIN TASKDETAIL TD  WITH (NOLOCK) ON (LOC.Loc = TD.ToLoc)  
            --WHERE LOC.LocationType = 'DYNPICKP'  
            --AND   LOC.LocationHandling = @c_LocationHandling                     
            --AND   LOC.Facility = @c_Facility  
            --AND   TD.TaskType IN ('RPF','RP1','RPT')  
            --AND   TD.UOM       = '6'  
            --AND   TD.CaseID    <>''  
            --AND   TD.Status    < '9'  
            --AND   SourceType   like 'ispRLWAV07-%'  
            --GROUP BY TD.Storerkey  
    --      ,  TD.Sku  
            --      ,  TD.ToLoc  
            --      ,  ISNULL(LOC.MaxPallet,0)  
            --      ,  TD.Wavekey  
            --ORDER BY TD.Storerkey  
            --      ,  TD.Sku  
  
            IF EXISTS (SELECT 1 FROM #TMP_PICK WHERE ToLoc <> '')  
            BEGIN  
               --UPDATE #TMP_DP_PMI  
               --SET NoOfUCC_PMI = NoOfUCC_PMI  
               --                + (  SELECT ISNULL(COUNT( DISTINCT TP.Dropid ),0)  
               --                     FROM #TMP_PICK TP  
               --                     WHERE TP.ToLoc <> ''  
               --                     AND   TP.UOM = '6'   
               --                     AND   TP.ToLoc = #TMP_DP_PMI.Loc        
               --                  )  
  
               INSERT INTO  #TMP_DP_PMI                 
                        (  Storerkey  
                        ,  Sku  
                        ,  Loc  
                        ,  MaxPallet  
                        ,  NoOfUCC_PMI  
                        ,  Wavekey  
                        )  
               SELECT      TP.Storerkey  
                        ,  TP.Sku  
                        ,  TP.ToLoc  
                        ,  ISNULL(LOC.MaxPallet,0)  
                        ,  NoOfUCC_PMI = ISNULL(COUNT( DISTINCT TP.Dropid ),0)  
                        ,  @c_Wavekey  
           FROM LOC       LOC WITH (NOLOCK)  
               JOIN #TMP_PICK TP  WITH (NOLOCK) ON (LOC.Loc = TP.ToLoc)       
               WHERE LOC.LocationType = 'DYNPICKP'  
               AND   LOC.LocationHandling = @c_LocationHandling               --(Wan04)  
               AND   LOC.Facility     = @c_Facility   
               AND   TP.UOM           = '6'    
               AND   TP.Dropid <> ''  
               AND   TP.ToLoc  <> ''  
               AND   0 = ( SELECT COUNT(1) FROM #TMP_DP_PMI TMP  
                           WHERE TMP.Loc = LOC.Loc  
                         )    
               GROUP BY TP.Storerkey  
                     ,  TP.Sku  
                     ,  TP.ToLoc  
                     ,  ISNULL(LOC.MaxPallet,0)  
            END  
                      
            SET @c_ToLoc = ''  
            SELECT @c_ToLoc = Loc  
            FROM #TMP_DP_PMI  
            WHERE Storerkey = @c_Storerkey  
            AND   Sku       = @c_Sku  
            AND   Wavekey   = @c_wavekey  
            AND   MaxPallet > NoOfUCC_PMI  
            */  
            --(Wan04) - END  
  
            IF @c_ToLoc = ''  
            BEGIN   
               GET_EMPTY_DP:  
  
               SET @c_LocationHandlings = '3'  
  
               IF @c_Lottable01 = 'B'  
               BEGIN  
                  SET @c_LocationHandlings = '3|4'  
               END  
  
               SET @c_DPPPKZone = ''  
               DECLARE CUR_DPP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
               SELECT DPPPKZone = LOC.PickZone  
               FROM SKUxLOC WITH (NOLOCK)  
               JOIN LOC     WITH (NOLOCK) ON (SKUxLOC.Loc = LOC.Loc)  
               JOIN dbo.fnc_DelimSplit ('|', @c_LocationHandlings) HLG        --(Wan04)   
                                          ON (HLG.ColValue = LOC.LocationHandling)--(Wan04)  
               WHERE SKUxLOC.Storerkey= @c_Storerkey  
               AND   SKUxLOC.Sku      = @c_Sku  
               AND   SKUxLOC.LocationType = 'PICK'                            --(Wan04)  
               AND   LOC.LocationType = 'DYNPPICK'  
               AND   LOC.Facility     = @c_Facility  
               GROUP BY LOC.PickZone                                          --(Wan04)  
                     ,  LOC.LocationHandling                                  --(Wan04)     
                     ,  LOC.LogicalLocation                                   --(Wan04)  
                     ,  LOC.Loc                                               --(Wan04)  
               ORDER BY LOC.LocationHandling DESC                   --(Wan04)  
                     ,  LOC.LogicalLocation  
                     ,  LOC.Loc  
  
               OPEN CUR_DPP  
     
               FETCH NEXT FROM CUR_DPP INTO @c_DPPPKZone  
               WHILE @@FETCH_STATUS <> -1 AND @c_ToLoc = ''  
               BEGIN   
                  SELECT TOP 1 @c_ToLoc = LOC.Loc  
                  FROM LOC WITH (NOLOCK)    
                  --JOIN SKUxLOC WITH (NOLOCK) ON (SKUxLOC.Loc = LOC.Loc)           --(Wan04)  
                  WHERE LOC.LocationType = 'DYNPICKP'  
                  AND   LOC.LocationHandling = @c_LocationHandling                  --(Wan04)  
                  AND   LOC.Facility = @c_Facility   
                  AND   LOC.PickZone = @c_DPPPKZone  
                  --AND   SKUxLOC.Qty + SKUxLOC.QtyAllocated + SKUxLOC.QtyPicked = 0--(Wan04)   
                  --AND  0 = (  SELECT COUNT(1) FROM #TMP_DP_PMI TMP                --(Wan04)   
                  --            WHERE TMP.Loc = LOC.Loc                             --(Wan04)   
                  --            )                                                   --(Wan04)   
                  AND  0 =  ( SELECT ISNULL(SUM(LLI.Qty + LLI.QtyAllocated + LLI.QtyPicked + LLI.PendingMoveIN),0)   
                              FROM LOTxLOCxID LLI WITH (NOLOCK)   
                              WHERE LLI.Loc = LOC.Loc  
                             )   
                  AND  0 =  ( SELECT COUNT(1) FROM #TMP_PICK TMP WITH (NOLOCK)      --(Wan05)  
                              WHERE TMP.ToLoc = LOC.Loc                             --(Wan05)  
                           )                                   
                  ORDER BY LOC.LogicalLocation  
                                    , LOC.Loc  
  
                  IF @c_ToLoc = ''  
                  BEGIN   
                     SELECT TOP 1 @c_ToLoc = LOC.Loc  
                     FROM LOC WITH (NOLOCK)    
                     WHERE LOC.LocationType = 'DYNPICKP'  
                     AND   LOC.LocationHandling = @c_LocationHandling               --(Wan04)  
                     AND   LOC.Facility = @c_Facility   
                     AND   LOC.PickZone = @c_DPPPKZone  
                     AND   0 = ( SELECT COUNT(1) FROM LOTxLOCxID LLI WITH (NOLOCK)  --(Wan04)     
                                 WHERE LLI.Loc = LOC.Loc                            --(Wan04)   
                                )                                                   --(Wan04)       
                     --AND   0 = ( SELECT COUNT(1) FROM #TMP_DP_PMI TMP             --(Wan04)   
                     --            WHERE TMP.Loc = LOC.Loc                          --(Wan04)     
                     --            )                                                --(Wan04)  
                     AND  0 =  ( SELECT COUNT(1) FROM #TMP_PICK TMP WITH (NOLOCK)   --(Wan05)  
                                 WHERE TMP.ToLoc = LOC.Loc                          --(Wan05)  
                              )                                                          
                     ORDER BY LOC.LogicalLocation  
                                 ,LOC.Loc  
  
                  END  
                  FETCH NEXT FROM CUR_DPP INTO @c_DPPPKZone  
               END  
               CLOSE  CUR_DPP  
               DEALLOCATE CUR_DPP  
            END   
  
            IF @c_ToLoc = ''  
            BEGIN   
               SET @n_Continue = 3  
            END  
  
            SET @c_ToLocType = 'DP'  -- DYNPICKP  
            GOTO ADD_TASK  
      END  
      --(Wan02) - END  
        
      FIND_DPP:  
         SET @c_ToLocType = 'DPP'  
         -- Find Sku in DPP Loc  
  
         /*  
         -- 1) Find from RPF   
         -- 2) Else find from In Transit  
         SELECT TOP 1 @c_ToLoc = TD.ToLoc  
         FROM TASKDETAIL TD  WITH (NOLOCK)  
         JOIN LOC        LOC WITH (NOLOCK) ON (TD.ToLoc = LOC.Loc)  
         WHERE TD.TaskType IN ('RPF','RP1','RPT')  
         AND   TD.Storerkey= @c_Storerkey  
         AND   TD.Sku = @c_Sku   
         AND   TD.Qty > 0   
         AND   TD.Status = '0'  
         AND   LOC.Facility = @c_Facility  
         AND   LOC.LocationCategory = 'SHELVING'  
         AND   LOC.LocationType = 'DYNPPICK'  
         AND   LOC.LocationHandling = @c_LocationHandling                     --(Wan04)  
         ORDER BY CASE WHEN TD.TaskType = 'RPF' THEN 1 ELSE 9 END  
                , LOC.LogicalLocation  
                , LOC.Loc  
         */  
         IF @c_Lottable01 = 'B'                                               --(Wan04)  
         BEGIN  
            --3) Find loc or pending move in loc with same sku   
            SELECT TOP 1 @c_ToLoc = LOC.Loc  
            FROM LOTxLOCxID   LLI WITH (NOLOCK)  
            JOIN LOC          LOC WITH (NOLOCK) ON (LLI.Loc = LOC.Loc)  
            WHERE LLI.Storerkey= @c_Storerkey  
            AND   LLI.Sku = @c_Sku    
            AND   LLI.Qty + LLI.PendingMoveIN > 0                             --(Wan04)       
            AND   LOC.LocationCategory = 'SHELVING'  
            AND   LOC.LocationType = 'DYNPPICK'  
            AND   LOC.LocationHandling = @c_LocationHandling                  --(Wan04)  
            AND   LOC.Facility = @c_Facility  
            ORDER BY LOC.LogicalLocation  
                  ,  LOC.Loc  
         END  
       
         IF @c_ToLoc = ''  
         BEGIN  
            --4) Ops Pre-defined Loc for Sku. Find pick loc setup in skuxloc   
            SELECT TOP 1 @c_ToLoc = LOC.Loc  
            FROM SKUxLOC SxL WITH (NOLOCK)  
            JOIN LOC     LOC WITH (NOLOCK) ON (SxL.Loc = LOC.Loc)  
            WHERE SxL.Storerkey= @c_Storerkey  
            AND   SxL.Sku = @c_Sku    
            AND   SxL.LocationType = 'PICK'                                   --(Wan04)  
            AND   LOC.Facility = @c_Facility  
            AND   LOC.LocationCategory = 'SHELVING'  
            AND   LOC.LocationType = 'DYNPPICK'  
            AND   LOC.LocationHandling = @c_LocationHandling                  --(Wan04)  
            ORDER BY LOC.LogicalLocation  
              ,  LOC.Loc  
         END  
  
         --(Wan04) - START  
         IF @c_Lottable01 = 'B' AND @c_ToLoc = ''                                               
         BEGIN  
            DECLARE CUR_DPP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
            SELECT DPPPKZone = LOC.PickZone  
            FROM SKUxLOC WITH (NOLOCK)  
            JOIN LOC     WITH (NOLOCK) ON (SKUxLOC.Loc = LOC.Loc)  
            WHERE SKUxLOC.Storerkey= @c_Storerkey  
            AND   SKUxLOC.Sku      = @c_Sku  
            AND   SKUxLOC.LocationType = 'PICK'    
            AND   LOC.LocationType = 'DYNPPICK'  
            AND   LOC.LocationHandling IN ( '3', '4' )  
            AND   LOC.Facility     = @c_Facility  
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
               SELECT TOP 1 @c_ToLoc = LOC.Loc  
               FROM LOC WITH (NOLOCK)    
               WHERE LOC.LocationCategory = 'SHELVING'  
               AND   LOC.LocationType = 'DYNPPICK'  
               AND   LOC.LocationHandling = @c_LocationHandling  
               AND   LOC.Facility = @c_Facility   
               AND   LOC.PickZone = @c_DPPPKZone   
               AND  0 =  ( SELECT ISNULL(SUM(LLI.Qty + LLI.QtyAllocated + LLI.QtyPicked + LLI.PendingMoveIN),0)   
                           FROM LOTxLOCxID LLI WITH (NOLOCK)   
                           WHERE LLI.Loc = LOC.Loc  
                          )      
               AND  0 =  ( SELECT COUNT(1) FROM #TMP_PICK TMP WITH (NOLOCK)   
                           WHERE TMP.Loc = LOC.Loc  
                           )             
               ORDER BY LOC.LogicalLocation  
                     ,  LOC.Loc  
  
               IF @c_ToLoc = ''  
               BEGIN   
                  SELECT TOP 1 @c_ToLoc = LOC.Loc  
                  FROM LOC WITH (NOLOCK)    
                  WHERE LOC.LocationCategory = 'SHELVING'  
                  AND   LOC.LocationType = 'DYNPPICK'  
                  AND   LOC.LocationHandling = @c_LocationHandling  
                  AND   LOC.Facility = @c_Facility   
                  AND   LOC.PickZone = @c_DPPPKZone  
                  AND   0 = ( SELECT COUNT(1) FROM LOTxLOCxID LLI WITH (NOLOCK)  
                              WHERE LLI.Loc = LOC.Loc  
                             )  
                  AND   0 = ( SELECT COUNT(1) FROM #TMP_PICK TMP WITH (NOLOCK)   
                              WHERE TMP.Loc = LOC.Loc  
                             )      
                  ORDER BY LOC.LogicalLocation  
                           ,LOC.Loc  
               END  
               FETCH NEXT FROM CUR_DPP INTO @c_DPPPKZone  
            END  
            CLOSE  CUR_DPP  
            DEALLOCATE CUR_DPP  
         END  
         --(Wan04) - END  
      ADD_TASK:  
         IF @c_ToLoc = '' AND @c_UOM <> '6'     --(Wan02)  
         BEGIN  
            SET @n_Continue = 3  
            SET @n_Err = 81040  
            SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Pack Station / DPP Location Not found. (ispRLWAV07)'  
            GOTO QUIT_SP  
         END  
        
         IF @c_ToLoc <> ''       --Wan02  
         BEGIN  
            UPDATE #TMP_PICK  
            SET ToLoc = @c_ToLoc  
            WHERE RowRef = @n_RowRef  
  
            SET @n_err = @@ERROR    
            IF @n_err <> 0    
            BEGIN  
               SET @n_continue = 3    
               SET @n_Err = 81050   
               SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update #TMP_PICK Failed. (ispRLWAV07)'   
               GOTO QUIT_SP  
            END                  --Wan02  
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
   
            SET @c_SourceType = 'ispRLWAV07-' + RTRIM(@c_DispatchPiecePickMethod)  
  
            SET @c_LogicalToLoc = @c_ToLoc  
  
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
               ,  PendingMoveIn                                                     --(Wan04)  
               )    
               VALUES    
               (    
                  @c_taskdetailkey    
               ,  @c_TaskType --Tasktype    
               ,  @c_Storerkey    
               ,  @c_Sku    
               ,  @c_UOM         -- UOM,    
               ,  @n_UCCQty      -- UOMQty,    
               ,  @n_UCCQty      --Qty  
            ,  @n_Qty         --systemqty  
               ,  @c_Lot     
               ,  @c_Fromloc     
               ,  @c_ID          -- from id    
               ,  @c_Toloc   
               ,  @c_ID          -- to id    
               ,  @c_SourceType  --Sourcetype    
               ,  @c_Wavekey     --Sourcekey    
               ,  '5'            -- Priority    
               ,  '9'            -- Sourcepriority    
               ,  '0'            -- Status    
               ,  @c_LogicalFromLoc --Logical from loc    
               ,  @c_LogicalToLoc   --Logical to loc    
               ,  @c_PickMethod  
               ,  @c_Wavekey  
               ,  @c_ToLocType  
               ,  ''  
               ,  ''  
               ,  @c_DropID  
               ,  ''  
               ,  CASE WHEN @c_UOM IN ('2','6') THEN 0 ELSE @n_UCCQty END        --(Wan05)  
               )  
      
            SET @n_err = @@ERROR    
            IF @n_err <> 0    
            BEGIN  
               SET @n_continue = 3    
               SET @n_Err = 81070   
               SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert Taskdetail Failed. (ispRLWAV07)'   
               GOTO QUIT_SP  
            END     
         END  
         ------------------------------------------------------------------------------------  
         -- Create TaskDetail (END)  
         ------------------------------------------------------------------------------------  
      ADD_PSLIP:  
         ------------------------------------------------------------------------------------  
         -- Stamp TaskDetailKey & Wavekey to PickDetail, Generate Pickslipno (START)  
         ------------------------------------------------------------------------------------  
         DECLARE CUR_UPD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
         SELECT PD.PickDetailKey  
               ,OH.Loadkey  
               ,OH.Orderkey  
               ,Consigneekey = ISNULL(RTRIM(OH.Consigneekey),'')  
               ,Route = ISNULL(RTRIM(OH.Route),'')  
         FROM PICKDETAIL PD WITH (NOLOCK)  
         JOIN ORDERS     OH WITH (NOLOCK) ON (PD.Orderkey = OH.Orderkey)  
         WHERE PD.Lot = @c_Lot  
         AND   PD.Loc = @c_FromLoc  
         AND   PD.ID  = @c_Id  
         AND   PD.UOM = @c_UOM  
         AND   PD.DropID = @c_DropID  
         AND   OH.UserDefine09 = @c_Wavekey                    --(Wan02) - Fixed update wrong pickdetail   
  
         OPEN CUR_UPD  
  
         FETCH NEXT FROM CUR_UPD INTO  @c_PickDetailKey  
                                    ,  @c_Loadkey  
                                    ,  @c_Orderkey  
                                    ,  @c_Consigneekey  
                                    ,  @c_Route  
  
  
         WHILE @@FETCH_STATUS <> -1  
         BEGIN  
            SET @c_PickSlipNo = ''  
  
            --(Wan07) -- START  
            SET @c_Zone = '3'                
            SET @c_PackOrderkey = @c_Orderkey    
  
            IF @c_PreCTNLevel = 'L'         
            BEGIN  
               SELECT @c_PickSlipNo = PickHeaderKey  
               FROM PICKHEADER WITH (NOLOCK)  
               WHERE ExternOrderkey = @c_Loadkey  
               AND   Loadkey  = @c_Loadkey  
               AND   Orderkey = ''  
               AND   Zone     = '7'  
               AND   Wavekey  = @c_Wavekey  
  
               SET @c_Zone = '7'  
               SET @c_PackOrderkey = ''  
            END  
            ELSE IF @c_Orderkey <> ''        --(Wan07)  
            BEGIN  
               SELECT @c_PickSlipNo = PickHeaderKey  
               FROM PICKHEADER WITH (NOLOCK)  
               WHERE ExternOrderkey = @c_Loadkey  
               AND   Orderkey = @c_Orderkey  
               AND   Zone     = '3'  
            END  
            --(Wan07) -- END  
  
            IF @c_Orderkey <> '' AND @c_PickSlipNo = ''   
            BEGIN  
               SET @b_success = 1    
        EXECUTE nspg_getkey    
                     'PickSlip'    
                     , 9    
                     , @c_PickSlipNo   OUTPUT    
                     , @b_success      OUTPUT    
                     , @n_err          OUTPUT    
                     , @c_errmsg       OUTPUT  
                   
               IF NOT @b_success = 1    
               BEGIN    
                  SET @n_continue = 3  
                  GOTO QUIT_SP    
               END    
   
               SET @c_Pickslipno = 'P' + @c_Pickslipno  
  
               INSERT INTO PICKHEADER (PickHeaderKey, ExternOrderKey, Orderkey, PickType, Zone, Loadkey, Wavekey, Storerkey)  --(Wan07)    
               VALUES (@c_Pickslipno , @c_LoadKey, @c_PackOrderkey, '0', @c_Zone, @c_Loadkey, @c_Wavekey, @c_Storerkey)               --(Wan07)  
                 
               SET @n_err = @@ERROR    
               IF @n_err <> 0    
               BEGIN  
                  SET @n_continue = 3    
                  SET @n_Err = 81080   
                  SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert PICKHEADER Failed. (ispRLWAV07)'   
                  GOTO QUIT_SP  
               END     
  
               INSERT INTO PICKINGINFO (PickSlipNo, ScanInDate, PickerID, ScanOutDate)    
               VALUES (@c_Pickslipno , NULL, NULL, NULL)   
  
               SET @n_err = @@ERROR    
               IF @n_err <> 0    
               BEGIN  
                  SET @n_continue = 3    
                  SET @n_Err = 81090   
                  SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert PICKINGINFO Failed. (ispRLWAV07)'   
                  GOTO QUIT_SP  
               END     
  
               IF @c_DispatchPiecePickMethod = 'DTC'     --IF DTC, DO NOT UPDATE PICKSLIP TO Pickdetail & Insert PACKHEADER, PACKHEADER Insert At ECOM PAcking    
               BEGIN   
                  SET @c_PickSlipNo = ''  
               END  
               ELSE  
               BEGIN  
                  INSERT INTO PACKHEADER (PickSlipNo, Storerkey, Orderkey, Loadkey, Consigneekey, Route, OrderRefNo )    
                  VALUES (@c_Pickslipno , @c_Storerkey, @c_PackOrderkey, @c_Loadkey, @c_Consigneekey, @c_Route, '')    --NJOW Fix c_PackOrderkey  
  
                  SET @n_err = @@ERROR    
                  IF @n_err <> 0    
                  BEGIN  
                     SET @n_continue = 3    
                     SET @n_Err = 81100   
                     SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert PACKHEADER Failed. (ispRLWAV07)'   
                     GOTO QUIT_SP  
                  END           
               END  
            END  
  
            UPDATE PICKDETAIL WITH (ROWLOCK)  
            SET TaskDetailKey = CASE WHEN @c_FromLocType = 'DPP' THEN  
                                   ''  
                               ELSE @c_Taskdetailkey END --NJOW01  
               ,Wavekey       = @c_Wavekey  
               ,PickSlipNo    = @c_PickSlipNo  
               ,TrafficCop    = NULL  
               ,EditWho = SUSER_NAME()  
               ,EditDate= GETDATE()  
            WHERE PickDetailkey = @c_PickDetailKey  
  
            SET @n_err = @@ERROR  
            IF @n_err <> 0   
            BEGIN  
               SET @n_continue = 3  
               SET @n_err = 81110     
               SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Pickdetail Table Failed. (ispRLWAV07)'   
               GOTO QUIT_SP  
            END   
  
            FETCH NEXT FROM CUR_UPD INTO  @c_PickDetailKey  
                                       ,  @c_Loadkey  
                                       ,  @c_Orderkey  
                                       ,  @c_Consigneekey  
                                       ,  @c_Route  
         END              
         CLOSE CUR_UPD  
         DEALLOCATE CUR_UPD  
         ------------------------------------------------------------------------------------  
         -- Stamp TaskDetailKey & Wavekey to PickDetail, Generate Pickslipno (END)  
         ------------------------------------------------------------------------------------  
         --(Wan04) - END   
  
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
                                 , @c_LogicalFromLoc                          --(Wan04)   
                                 , @c_FromLocType                             --(Wan04)   
                                 , @c_Lottable01                              --(Wan04)   
  
  
      
      --(Wan02) - START  
      IF @n_Continue = 3 AND @c_UOM_Prev = '6' AND (@c_UOM <> '6' OR @@FETCH_STATUS = -1)   
      BEGIN  
         SET @n_UCCWODPLoc = 0  
         SELECT @n_UCCWODPLoc = COUNT(1)    
         FROM #TMP_PICK  
         WHERE UOM = '6'    
         AND ToLoc = ''           
  
         SET @n_Err = 81035  
         SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Not enough DP Location. '  
                      +'No of UCC:' + CONVERT(NVARCHAR(5),@n_UCCWODPLoc) + ' still need(s) DP Loc (ispRLWAV07)'  
         GOTO QUIT_SP  
      END  
      --(Wan02) - END  
      
   END  
   CLOSE CUR_PD  
   DEALLOCATE CUR_PD  
      
   ------------------------------------------------------------------------------------  
   -- Update Loose Qty From Pallet Loc's PickMethod to 'FP' if all UCC go to same toloc  
   ------------------------------------------------------------------------------------  
   --(Wan04) - START  
   DECLARE CUR_ID CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
   SELECT TD.FromLoc  
      ,   TD.FromID  
      ,   ToLoc   = MIN(TD.ToLoc)  
      ,   NoOfUCC_Replen = COUNT(DISTINCT TD.CaseID)  
   FROM TASKDETAIL TD  WITH (NOLOCK)  
   JOIN LOC        LOC WITH (NOLOCK) ON (TD.FromLoc = LOC.Loc)  
   WHERE TD.Wavekey = @c_Wavekey  
   AND   TD.PickMethod        = 'PP'  
   AND   TD.FromID            <>''  
   AND   LOC.LocationHandling = '1'   
   AND   LOC.LocationType     = 'OTHER'      
   AND   LOC.LocationCategory = 'BULK'   
   GROUP BY TD.FromLoc  
         ,  TD.FromID  
   HAVING COUNT ( DISTINCT TD.Sku )   = 1  
   AND    COUNT ( DISTINCT TD.ToLoc ) = 1  
   ORDER BY TD.FromLoc  
         ,  TD.FromID  
  
   OPEN CUR_ID  
     
   FETCH NEXT FROM CUR_ID INTO  @c_FromLoc  
                              , @c_ID  
                              , @c_ToLoc  
                              , @n_NoOfUCC_Replen  
   WHILE @@FETCH_STATUS <> -1  
   BEGIN  
      IF (  SELECT COUNT(DISTINCT UCCNo)   
            FROM UCC WITH (NOLOCK)  
            WHERE Loc = @c_FromLoc  
            AND   ID  = @c_ID  
            AND   Status <= '3'  
         ) <> @n_NoOfUCC_Replen  
      BEGIN  
         GOTO NEXT_ID  
      END  
  
      SET @CUR_UPDPM = CURSOR FAST_FORWARD READ_ONLY FOR  
      SELECT TD.TaskDetailKey  
      FROM TASKDETAIL TD  WITH (NOLOCK)  
      WHERE TD.Wavekey = @c_Wavekey  
      AND   TD.FromLoc = @c_FromLoc  
      AND   TD.ToID    = @c_ID  
      ORDER BY TD.TaskDetailKey  
  
      OPEN @CUR_UPDPM        
  
      FETCH NEXT FROM @CUR_UPDPM INTO @c_TaskDetailKey  
  
      WHILE @@FETCH_STATUS <> -1  
      BEGIN  
         UPDATE TASKDETAIL WITH (ROWLOCK)  
            SET PickMethod = 'FP'  
         WHERE TaskDetailKey = @c_TaskDetailKey  
  
         SET @n_err = @@ERROR    
         IF @n_err <> 0    
         BEGIN  
            SET @n_continue = 3    
            SET @n_Err = 81060   
            SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update #TASKDETAIL Failed. (ispRLWAV07)'   
            GOTO QUIT_SP  
         END   
         FETCH NEXT FROM @CUR_UPDPM INTO @c_TaskDetailKey  
      END  
        
      NEXT_ID:  
      FETCH NEXT FROM CUR_ID INTO  @c_FromLoc  
                                 , @c_ID  
                           , @c_ToLoc  
                                 , @n_NoOfUCC_Replen  
   END  
   CLOSE CUR_ID  
   DEALLOCATE CUR_ID  
     
   --NJOW02  
   DECLARE CUR_ORD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
      SELECT O.Orderkey, O.Storerkey, O.Status, O.DocType   --WL01
      FROM ORDERS O WITH (NOLOCK)  
      JOIN WAVEDETAIL WD WITH (NOLOCK) ON O.Orderkey = WD.Orderkey  
      WHERE WD.Wavekey = @c_Wavekey        
      ORDER BY O.Orderkey  
  
   OPEN CUR_ORD        
  
   FETCH NEXT FROM CUR_ORD INTO @c_Orderkey, @c_Storerkey, @c_Status, @c_DocType   --WL01
  
   WHILE @@FETCH_STATUS <> -1  
   BEGIN  
      
      EXEC ispGenTransmitlog2  
         @c_TableName = 'WSWAVERESRCMLOG'    
        ,@c_Key1 = @c_Orderkey           
        ,@c_Key2 = @c_Status  
        ,@c_Key3 = @c_Storerkey              
        ,@c_TransmitBatch = ''    
        ,@b_Success = @b_success OUTPUT             
        ,@n_err = @n_err OUTPUT                 
        ,@c_errmsg = @c_errmsg OUTPUT                
        
      IF @b_Success <> 1    
      BEGIN  
         SET @n_continue = 3    
         GOTO QUIT_SP  
      END   
  
      EXEC ispGenTransmitlog2  
         @c_TableName = 'WSITRNLOGWAVE'    
        ,@c_Key1 = @c_Orderkey           
        ,@c_Key2 = @c_Status  
        ,@c_Key3 = @c_Storerkey              
        ,@c_TransmitBatch = ''    
        ,@b_Success = @b_success OUTPUT             
        ,@n_err = @n_err OUTPUT                 
        ,@c_errmsg = @c_errmsg OUTPUT                
        
      IF @b_Success <> 1    
      BEGIN  
         SET @n_continue = 3    
         GOTO QUIT_SP  
      END   
  
      EXEC ispGenTransmitlog2  
         @c_TableName = 'WSSTATUSLOG'    
        ,@c_Key1 = @c_Orderkey           
        ,@c_Key2 = @c_Status  
        ,@c_Key3 = @c_Storerkey              
        ,@c_TransmitBatch = ''    
        ,@b_Success = @b_success OUTPUT             
        ,@n_err = @n_err OUTPUT                 
        ,@c_errmsg = @c_errmsg OUTPUT                
        
      IF @b_Success <> 1    
      BEGIN  
         SET @n_continue = 3    
         GOTO QUIT_SP  
      END   

      --WL01 S
      IF @c_DocType = 'N'
      BEGIN
         EXEC ispGenTransmitlog2  
            @c_TableName = 'WSSOCFMLOGB2B'    
           ,@c_Key1 = @c_Orderkey           
           ,@c_Key2 = '2'  
           ,@c_Key3 = @c_Storerkey              
           ,@c_TransmitBatch = ''    
           ,@b_Success = @b_success OUTPUT             
           ,@n_err = @n_err OUTPUT                 
           ,@c_errmsg = @c_errmsg OUTPUT                
        
         IF @b_Success <> 1    
         BEGIN  
            SET @n_continue = 3    
            GOTO QUIT_SP  
         END 
      END
      --WL01 E
        
      FETCH NEXT FROM CUR_ORD INTO @c_Orderkey, @c_Storerkey, @c_Status, @c_DocType   --WL01
   END       
   CLOSE CUR_ORD  
   DEALLOCATE CUR_ORD  
  
  
   /*  
   DECLARE CUR_ID CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
   SELECT RowRef  
      ,  Storerkey  
      ,  Sku  
      ,  Loc  
      ,  ID  
      ,  ToLoc  
   FROM #TMP_PICK  
   WHERE PickMethod       = 'PP'  
   AND   LocationHandling = '1'   
   AND   LocationType     = 'OTHER'      
   AND   LocationCategory = 'BULK'   
   AND   ID <> ''  
   ORDER BY RowRef  
     
   OPEN CUR_ID  
     
   FETCH NEXT FROM CUR_ID INTO  @n_RowRef  
                              , @c_Storerkey  
                              , @c_Sku  
                              , @c_FromLoc  
                              , @c_ID  
                              , @c_ToLoc  
   WHILE @@FETCH_STATUS <> -1  
   BEGIN  
      IF EXISTS ( SELECT 1  
                  FROM #TMP_PICK   
                  WHERE Loc = @c_FromLoc  
                  AND   ID  = @c_ID  
                  AND  (Sku <> @c_Sku OR ToLoc <> @c_ToLoc)  
                 )  
      BEGIN  
         GOTO NEXT_ID  
      END  
  
      IF EXISTS ( SELECT 1  
                  FROM UCC WITH (NOLOCK)  
                  WHERE Loc = @c_FromLoc  
                  AND   ID  = @c_ID  
                  AND   Status <> '3'  
                 )  
      BEGIN  
         GOTO NEXT_ID  
      END  
  
      UPDATE #TMP_PICK  
         SET PickMethod = 'FP'  
      WHERE RowRef = @n_RowRef  
  
      SET @n_err = @@ERROR    
      IF @n_err <> 0    
      BEGIN  
         SET @n_continue = 3    
         SET @n_Err = 81060   
         SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update #TMP_PICK Failed. (ispRLWAV07)'   
         GOTO QUIT_SP  
      END     
  
      NEXT_ID:  
      FETCH NEXT FROM CUR_ID INTO  @n_RowRef
                                 , @c_Storerkey  
                                 , @c_Sku  
                                 , @c_FromLoc  
                                 , @c_ID  
                                 , @c_ToLoc  
   END  
   CLOSE CUR_ID  
   DEALLOCATE CUR_ID  
  
   ------------------------------------------------------------------------------------  
   -- Create TaskDetail, Update Pickdetail, Generate Pickslipno   
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
      ,  LogicalFromLoc    
      ,  FromLocType   
      ,  ToLoc   
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
                              , @c_LogicalFromLoc   
                              , @c_FromLocType  
                              , @c_ToLoc  
   WHILE @@FETCH_STATUS <> -1  
   BEGIN  
      SET @c_TaskDetailkey = ''  
  
      IF @c_FromLocType = 'DPP'  
      BEGIN  
         GOTO ADD_PSLIP -- Need to Generate Pickslipno  
      END  
  
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
   
      SET @c_SourceType = 'ispRLWAV07-' + RTRIM(@c_DispatchPiecePickMethod)  
  
      --(Wan01) - START  
      --Set LogicalToLoc = toloc for tracking purpose as toloc will be overwrite by RDT   
      SET @c_LogicalToLoc = @c_ToLoc  
      --SET @c_LogicalToLoc = ''  
      --SELECT @c_LogicalToLoc = ISNULL(RTRIM(LogicalLocation),'')  
      --FROM LOC WITH (NOLOCK)  
      --WHERE Loc = @c_ToLoc  
      --(Wan01) - END  
  
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
         ,  PendingMoveIn                                                     --(Wan04)  
         )    
         VALUES    
         (    
            @c_taskdetailkey    
         ,  @c_TaskType --Tasktype    
         ,  @c_Storerkey    
         ,  @c_Sku    
         ,  @c_UOM         -- UOM,    
         ,  @n_UCCQty      -- UOMQty,    
         ,  @n_UCCQty      --Qty  
         ,  @n_Qty         --systemqty  
         ,  @c_Lot     
         ,  @c_Fromloc     
         ,  @c_ID          -- from id    
         ,  @c_Toloc   
         ,  @c_ID          -- to id    
         ,  @c_SourceType  --Sourcetype    
         ,  @c_Wavekey     --Sourcekey    
         ,  '5'            -- Priority    
         ,  '9'            -- Sourcepriority    
         ,  '0'            -- Status    
         ,  @c_LogicalFromLoc --Logical from loc    
         ,  @c_LogicalToLoc   --Logical to loc    
         ,  @c_PickMethod  
         ,  @c_Wavekey  
         ,  @c_ToLocType  
         ,  ''  
         ,  ''  
         ,  @c_DropID  
         ,  ''  
         ,  @n_UCCQty                                                         --(Wan04)  
         )  
      
      SET @n_err = @@ERROR    
      IF @n_err <> 0    
      BEGIN  
         SET @n_continue = 3    
         SET @n_Err = 81070   
         SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert Taskdetail Failed. (ispRLWAV07)'   
         GOTO QUIT_SP  
      END     
  
   ADD_PSLIP:  
      -- Stamp TaskDetailKey & Wavekey to PickDetail  
      DECLARE CUR_UPD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
      SELECT PD.PickDetailKey  
            ,OH.Loadkey  
            ,OH.Orderkey  
            ,Consigneekey = ISNULL(RTRIM(OH.Consigneekey),'')  
            ,Route = ISNULL(RTRIM(OH.Route),'')  
      FROM PICKDETAIL PD WITH (NOLOCK)  
      JOIN ORDERS     OH WITH (NOLOCK) ON (PD.Orderkey = OH.Orderkey)  
      WHERE PD.Lot = @c_Lot  
      AND   PD.Loc = @c_FromLoc  
      AND   PD.ID  = @c_Id  
      AND   PD.UOM = @c_UOM  
      AND   PD.DropID = @c_DropID  
      AND   OH.UserDefine09 = @c_Wavekey                    --(Wan02) - Fixed update wrong pickdetail   
  
      OPEN CUR_UPD  
  
      FETCH NEXT FROM CUR_UPD INTO  @c_PickDetailKey  
                                 ,  @c_Loadkey  
                                 ,  @c_Orderkey  
                                 ,  @c_Consigneekey  
                                 ,  @c_Route  
  
  
      WHILE @@FETCH_STATUS <> -1  
      BEGIN  
  
         SET @c_PickSlipNo = ''  
           
         IF @c_Orderkey <> ''  
         BEGIN  
            SELECT @c_PickSlipNo = PickHeaderKey  
            FROM PICKHEADER WITH (NOLOCK)  
            WHERE ExternOrderkey = @c_Loadkey  
            AND   Orderkey = @c_Orderkey  
            AND   Zone     = '3'  
         END  
  
         IF @c_Orderkey <> '' AND @c_PickSlipNo = ''   
         BEGIN  
            SET @b_success = 1    
            EXECUTE nspg_getkey    
                  'PickSlip'    
                  , 9    
                  , @c_PickSlipNo   OUTPUT    
                  , @b_success      OUTPUT    
                  , @n_err          OUTPUT    
                  , @c_errmsg       OUTPUT  
                   
            IF NOT @b_success = 1    
            BEGIN    
               SET @n_continue = 3  
               GOTO QUIT_SP    
            END    
   
            SET @c_Pickslipno = 'P' + @c_Pickslipno  
  
            INSERT INTO PICKHEADER (PickHeaderKey, ExternOrderKey, Orderkey, PickType, Zone)    
            VALUES (@c_Pickslipno , @c_LoadKey, @c_Orderkey, '0', '3')    
                 
            SET @n_err = @@ERROR    
            IF @n_err <> 0    
            BEGIN  
               SET @n_continue = 3    
               SET @n_Err = 81080   
               SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert PICKHEADER Failed. (ispRLWAV07)'   
               GOTO QUIT_SP  
            END     
  
            INSERT INTO PICKINGINFO (PickSlipNo, ScanInDate, PickerID, ScanOutDate)    
            VALUES (@c_Pickslipno , NULL, NULL, NULL)   
  
            SET @n_err = @@ERROR    
            IF @n_err <> 0    
            BEGIN  
               SET @n_continue = 3    
               SET @n_Err = 81090   
               SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert PICKINGINFO Failed. (ispRLWAV07)'   
               GOTO QUIT_SP  
            END     
  
            IF @c_DispatchPiecePickMethod = 'DTC'     --IF DTC, DO NOT UPDATE PICKSLIP TO Pickdetail & Insert PACKHEADER, PACKHEADER Insert At ECOM PAcking    
            BEGIN   
               SET @c_PickSlipNo = ''  
            END  
            ELSE  
            BEGIN  
               INSERT INTO PACKHEADER (PickSlipNo, Storerkey, Orderkey, Loadkey, Consigneekey, Route, OrderRefNo )    
               VALUES (@c_Pickslipno , @c_Storerkey, @c_Orderkey, @c_Loadkey, @c_Consigneekey, @c_Route, '')   
  
               SET @n_err = @@ERROR    
               IF @n_err <> 0    
               BEGIN  
                  SET @n_continue = 3    
                  SET @n_Err = 81100   
                  SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert PACKHEADER Failed. (ispRLWAV07)'   
                  GOTO QUIT_SP  
               END           
            END  
         END  
  
         UPDATE PICKDETAIL WITH (ROWLOCK)  
         SET TaskDetailKey = @c_Taskdetailkey  
            ,Wavekey       = @c_Wavekey  
            ,PickSlipNo    = @c_PickSlipNo  
            ,TrafficCop    = NULL  
            ,EditWho = SUSER_NAME()  
            ,EditDate= GETDATE()  
         WHERE PickDetailkey = @c_PickDetailKey  
  
         SET @n_err = @@ERROR  
         IF @n_err <> 0   
         BEGIN  
            SET @n_continue = 3  
            SET @n_err = 81110     
            SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Pickdetail Table Failed. (ispRLWAV07)'   
            GOTO QUIT_SP  
         END   
  
         FETCH NEXT FROM CUR_UPD INTO  @c_PickDetailKey  
                                    ,  @c_Loadkey  
                                    ,  @c_Orderkey  
                                    ,  @c_Consigneekey  
                                    ,  @c_Route  
      END              
      CLOSE CUR_UPD  
      DEALLOCATE CUR_UPD  
  
   NEXT_REC:  
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
                                 , @c_LogicalFromLoc   
                                 , @c_FromLocType  
                                 , @c_ToLoc  
   END  
   CLOSE CUR_PD  
   DEALLOCATE CUR_PD   
   */  
   --(Wan04) - END  
   UPDATE WAVE WITH (ROWLOCK)  
   --SET Status = '1' -- Released
   SET TMReleaseFlag = 'Y'             --(Wan08)   
      ,Trafficcop = NULL  
      ,EditWho = SUSER_SNAME()         --(Wan08)  
      ,EditDate= GETDATE()  
   WHERE Wavekey = @c_Wavekey   
     
   SET @n_err = @@ERROR  
   IF @n_err <> 0   
   BEGIN  
      SET @n_continue = 3  
      SET @n_err = 81120    
      SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Pickdetail Table Failed. (ispRLWAV07)'   
      GOTO QUIT_SP  
   END       
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
  
   --(Wan02) - START  
   IF OBJECT_ID('tempdb..#TMP_DP_PMI','u') IS NOT NULL  
   BEGIN  
      DROP TABLE #TMP_DP_PMI;  
   END  
  
   IF CURSOR_STATUS( 'LOCAL', 'CUR_DPP') in (0 , 1)    
   BEGIN  
      CLOSE CUR_DPP  
      DEALLOCATE CUR_DPP  
   END  
      --(Wan02) - END  
     
   --NJOW01     
   IF CURSOR_STATUS( 'LOCAL', 'CUR_ORD') in (0 , 1)    
   BEGIN  
      CLOSE CUR_ORD  
      DEALLOCATE CUR_ORD  
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
  
      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'ispRLWAV07'  
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